(** fifowatcher.ml: Routines for creating and managing fifos *)

open Inotify
open Unix
open Globals
open Dirwatcher
open Printf
open Splice

(** A connected process, FIFO *)
type channel_pipe = Process of Unix.file_descr | Fifo of Unix.file_descr | BrokenPipe

(** Signed file descriptors. *)
type signed_fd = Infd of Unix.file_descr | Outfd of Unix.file_descr | Eventfd of Unix.file_descr

(** XXX This will get deprecated when we switch to inotify *)                                                                                  
let fdmap: (Unix.file_descr,string*string) Hashtbl.t = Hashtbl.create 1024

(** Maps pids to slice connections. Needed to clean up fds when a script dies
  with EPIPE *)
let pidmap: (int,signed_fd list) Hashtbl.t = Hashtbl.create 1024
let backend_prefix = ref ""
let open_fds: (Unix.file_descr,channel_pipe) Hashtbl.t = Hashtbl.create 1024


(** Receive an event from a running script. This event must be relayed to the
  slice that invoked it.

  @param idesc fd/fname identifier for process
  *)
let receive_process_event (idesc: fname_and_fd) (_: fname_and_fd) =
  let (_,ifd) = idesc in
  let cp = try Hashtbl.find open_fds ifd with
      Not_found->
        fprintf logfd "Fifo fd disappeared\n";flush logfd;raise Bug
  in
    match (cp) with 
      | Fifo(fifo_outfd) ->
          begin
          try
            printf "Received process event\n";flush Pervasives.stdout;
            let tr0,tr1 = Unix.pipe () in
                ignore(splice ifd tr1 4096);
                ignore(splice tr0 fifo_outfd 4096)
          with 
              Failure(s)->fprintf logfd "Transfer failure: %s\n" s;flush logfd
          end
      | _ -> fprintf logfd "Bug! Process fd received in the channel handler\n";flush logfd;raise Bug

let rec openentry_int fifoin fifoout (abspath:string*string) =
  let fdin =
    try openfile fifoin [O_RDONLY;O_NONBLOCK] 0o777 with 
        e->fprintf logfd "Error opening and connecting FIFO: %s,%o\n" fifoin 0o777;flush logfd;raise e
  in
    Hashtbl.replace fdmap fdin abspath;
    Fdwatcher.add_fd (Some(fifoin),fdin) (Some(fifoout),stdout) receive_fifo_event
and reopenentry_int fdin fifoin fifoout =
  close fdin;
    Fdwatcher.del_fd fdin;
    let abspath = try 
      Hashtbl.find fdmap fdin with _ -> fprintf logfd "Bug: Phantom pipe\n";flush logfd;raise Bug
    in
      openentry_int fifoin fifoout abspath

(** receive an event from a fifo and connect to the corresponding service, or to
  create it if it doesn't exit 
  @param eventdescriptor Name of input pipe,in descriptor
  @param outdescriptor Name of output pipe, out descriptor
  *)
and receive_fifo_event eventdescriptor outdescriptor =
  let (evfname,evfd) = eventdescriptor in
  let (fname_other,fd_other) = outdescriptor in
  (* Open the output pipe, or use stdout instead *)
  let outfd =
    match (fname_other) with
      | Some(str)->
          (
            try openfile str [O_WRONLY;O_NONBLOCK] 0o777 with
                _->fprintf logfd "Output pipe not open, using stdout in place of %s\n" str;flush logfd;stdout
          )
      | None-> fprintf logfd "Bug, nameless pipe\n";flush logfd;raise Bug
  in
  (* Check if the input descriptor is already registered (=> a session is open).
   If not, register it and start a new session.*)
  let pipe = try Hashtbl.find open_fds evfd with
    | Not_found ->
        (* Ok, need to launch script *)
        let execpath,slice_name = Hashtbl.find fdmap evfd in
        let (script_infd,pout) = Unix.pipe () in
        let (pin,script_outfd) = Unix.pipe () in
          set_nonblock script_infd;
          ignore(sigprocmask SIG_BLOCK [Sys.sigchld]);
          let rpid = try Some(create_process execpath [|execpath;slice_name|] pin pout pout) with e -> fprintf logfd "Error executing service: %s\n" execpath;flush logfd;None
          in
            match rpid with
              | None-> BrokenPipe
              | Some(pid)->
                  (* Register fds associated with pid so that they can be cleaned up
                   * when it dies *)
                  Hashtbl.add pidmap pid [Infd(script_infd);Outfd(script_outfd);Eventfd(evfd)];

                  (* Connect pipe to running script *)
                  Hashtbl.add open_fds evfd (Process(script_outfd));

                  (* Connect the running script to the pipe *)
                  Hashtbl.add open_fds script_infd (Fifo(outfd));

                  (* Activate running script *)
                  Fdwatcher.add_fd (None,script_infd) (None,script_infd) receive_process_event;

                  (Process(script_outfd))
  in
  (* We have the connection to the process - because it was open, or because it
   just got established *)
    match (pipe) with
      | Process(fifo_outfd) -> 
          begin
          try
            printf "Received fifo event\n";flush Pervasives.stdout;
            let tr0,tr1 = Unix.pipe() in
          ignore(splice evfd tr1 4096);
          ignore(splice tr0 fifo_outfd 4096)
          with Failure(str) ->
            begin
            fprintf logfd "Error connecting user to service: %s\n" str;
            flush logfd
            end;
            ignore(sigprocmask SIG_UNBLOCK [Sys.sigchld])
          end
      | BrokenPipe -> ()
      | Fifo(_) -> fprintf logfd "BUG! received process event from fifo\n";raise Bug


(** Make a pair of fifo entries *)
let mkentry fqp abspath perm uname = 
  fprintf logfd "Making entry %s->%s\n" fqp abspath;flush logfd;
  let fifoin=sprintf "%s.in" fqp in
  let fifoout=sprintf "%s.out" fqp in
    (try Unix.unlink fifoin with _ -> ());
    (try Unix.unlink fifoout with _ -> ());
    (try 
       let infname =(sprintf "%s.in" fqp) in
       let outfname =(sprintf "%s.out" fqp) in
         Unix.mkfifo infname 0o666;
         Unix.mkfifo outfname 0o666;
         ( (* Make the user the owner of the pipes in a non-chroot environment *)
         if (!Globals.nochroot) then
           let pwentry = Unix.getpwnam uname in
             Unix.chown infname pwentry.pw_uid pwentry.pw_gid; 
             Unix.chown outfname pwentry.pw_uid pwentry.pw_gid
         );
         Success
     with 
         e->fprintf logfd "Error creating FIFO: %s->%s. May be something wrong at the frontend.\n" fqp fifoout;flush logfd;Failed)

(** Open fifos for a session. Will shutdown vsys if the fifos don't exist *)
let openentry fqp abspath perm =
  let fifoin = String.concat "." [fqp;"in"] in
  let fifoout = String.concat "." [fqp;"out"] in
    openentry_int fifoin fifoout abspath

let sigchld_handle s =
  let pid,_=Unix.waitpid [Unix.WNOHANG] 0 in
    try
      let sfd_list = Hashtbl.find pidmap pid in
      let handle_sfd sfd =
        match sfd with
          | Infd(fd) ->
              close fd;
              Fdwatcher.del_fd fd
          | Outfd(fd)->
              close fd
          | Eventfd(fd)->
              Hashtbl.remove open_fds fd (* Disconnect pipe *)
      in
        List.iter handle_sfd sfd_list;
        Hashtbl.remove pidmap pid
    with 
        Not_found-> (* Do nothing, probably a grandchild *)
          ()

let initialize () = 
  Sys.set_signal Sys.sigchld (Sys.Signal_handle sigchld_handle)
