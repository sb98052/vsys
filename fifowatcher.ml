(** fifowatcher.ml: Routines for creating and managing fifos *)

open Inotify
open Unix
open Globals
open Dirwatcher
open Printf

(** A connected process, FIFO *)
type channel_pipe = Process of out_channel | Fifo of out_channel 

type signed_fd = Infd of Unix.file_descr | Outfd of Unix.file_descr

let fdmap: (Unix.file_descr,string*string) Hashtbl.t = Hashtbl.create 1024
let pidmap: (int,signed_fd*signed_fd*Unix.file_descr) Hashtbl.t = Hashtbl.create 1024
let backend_prefix = ref ""
let open_fds: (Unix.file_descr,channel_pipe) Hashtbl.t = Hashtbl.create 1024

(** Receive an event from a running script. This event must be relayed to the
  slice that invoked it 
  @param idesc fd/fname identifier for process
  *)
let receive_process_event (idesc: fname_and_fd) (_: fname_and_fd) =
  let (_,ifd) = idesc in
  let cp = try Hashtbl.find open_fds ifd with
      Not_found->
        printf "Fifo fd disappeared\n";raise Bug
  in
    match (cp) with 
      | Fifo(fifo_outchan) ->
          let process_inchan = in_channel_of_descr ifd in
          let cont = ref true in
          let count = ref 0 in
            count:=!count + 1;
            while (!cont) do
              try 
                let curline = input_line process_inchan in
                  fprintf fifo_outchan "%s\n" curline;flush fifo_outchan
              with 
                | End_of_file|Sys_blocked_io|Unix_error(EPIPE,_,_)|Unix_error(EBADF,_,_) ->
                    begin
                      cont:=false
                    end
                | Unix_error(_,s1,s2) -> printf "Unix error %s - %s\n" s1 s2;flush Pervasives.stdout;cont:=false
                | e -> printf "Error - received unexpected event from file system !!!\n";raise e
            done
      | _ -> printf "Bug! Process fd received in the channel handler\n";raise Bug


let rec openentry_int fifoin fifoout (abspath:string*string) =
  let fdin =
    try openfile fifoin [O_RDONLY;O_NONBLOCK] 0o777 with 
        e->printf "Error opening and connecting FIFO: %s,%o\n" fifoin 0o777;flush Pervasives.stdout;raise e
  in
    Hashtbl.replace fdmap fdin abspath;
    Fdwatcher.add_fd (Some(fifoin),fdin) (Some(fifoout),stdout) receive_fifo_event
and reopenentry_int fdin fifoin fifoout =
  close fdin;
    Fdwatcher.del_fd fdin;
    let abspath = try 
      Hashtbl.find fdmap fdin with _ -> printf "Bug: Phantom pipe\n";flush Pervasives.stdout;raise Bug
    in
      openentry_int fifoin fifoout abspath
and receive_fifo_event eventdescriptor outdescriptor =
  let evfname,evfd = eventdescriptor in
  let (fname_other,fd_other) = outdescriptor in
  let outfd =
    match (fname_other) with
      | Some(str)->
          (
            try openfile str [O_WRONLY;O_NONBLOCK] 0o777 with
                _->printf "Output pipe not open, using stdout in place of %s\n" str;flush Pervasives.stdout;stdout
          )
      | None-> printf "Bug, nameless pipe\n";raise Bug
  in
  let pipe = try Hashtbl.find open_fds evfd with
    | Not_found ->
        (* This is a fifo fd for sure *)
        let execpath,slice_name = Hashtbl.find fdmap evfd in
        (* Spawn server. We assume that the fd is one fifo opened RW *)
        let (myinfd,pout) = Unix.pipe () in
        let (pin,myoutfd) = Unix.pipe () in
          set_nonblock myinfd;
          let pid = try create_process execpath [|execpath;slice_name|] pin pout pout with e -> printf "Error executing service: %s\n" execpath;flush Pervasives.stdout;raise e
          in
            Hashtbl.add pidmap pid (Infd(myinfd),Outfd(myoutfd),evfd);
            Hashtbl.add open_fds evfd (Process(out_channel_of_descr myoutfd));
            Hashtbl.add open_fds myinfd (Fifo(out_channel_of_descr outfd));
            Fdwatcher.add_fd (None,myinfd) (None,myinfd) receive_process_event;
            (Process(out_channel_of_descr myoutfd))
  in
  let inchan_fd = in_channel_of_descr evfd in
    match (pipe) with
      | Process(out_channel) -> 
          let cont = ref true in
            while (!cont) do
              try 
                printf "Reading...\n";flush Pervasives.stdout;
                let curline = input_line inchan_fd in
                  fprintf out_channel "%s\n" curline;flush out_channel 
              with 
                |End_of_file->
                    (
                      match (evfname,fname_other) with
                        | Some(str1),Some(str2)->
                            reopenentry_int evfd str1 str2
                        | Some(str1),None ->
                            printf "Bug, nameless pipe\n";flush Pervasives.stdout;raise Bug
                        | None,_ ->
                            printf "Race condition -> user deleted file before closing it. Clever ploy, but won't work.\n";
                            flush Pervasives.stdout
                    );
                    cont:=false
                |Sys_blocked_io ->printf "Sysblockedio\n";flush Pervasives.stdout;
                                  cont:=false
                | _ ->printf "Bug: unhandled exception\n";flush Pervasives.stdout;raise Bug
            done
      | _ -> printf "BUG! received process event from fifo\n";raise Bug


let mkentry fqp abspath perm = 
  printf "Making entry %s->%s\n" fqp abspath;flush Pervasives.stdout;
  let fifoin=sprintf "%s.in" fqp in
  let fifoout=sprintf "%s.out" fqp in
    (try Unix.unlink fifoin with _ -> ());
    (try Unix.unlink fifoout with _ -> ());
    (try 
       Unix.mkfifo (sprintf "%s.in" fqp) 0o666
     with 
         e->printf "Error creating FIFO: %s->%s,%o\n" fqp fifoin perm;flush Pervasives.stdout;raise e);
    (try 
       Unix.mkfifo (sprintf "%s.out" fqp) 0o666
     with 
         e->printf "Error creating FIFO: %s->%s,%o\n" fqp fifoout perm;flush Pervasives.stdout;raise e)

(** Open fifos for a session *)
let openentry fqp abspath perm =
  let fifoin = String.concat "." [fqp;"in"] in
  let fifoout = String.concat "." [fqp;"out"] in
    openentry_int fifoin fifoout abspath

let sigchld_handle s =
  let pid,_=Unix.waitpid [Unix.WNOHANG] 0 in
    try
      let value = Hashtbl.find pidmap pid in
        match value with
          | (Infd(ifd),Outfd(ofd),fd) ->
              close(ifd);close(ofd);
              Hashtbl.remove open_fds fd;
              Fdwatcher.del_fd ifd;
              Hashtbl.remove pidmap pid
          | _ -> printf "BUG! Got fds in the wrong order\n";
                 flush Pervasives.stdout;
                 raise Bug
    with 
        Not_found-> (* Do nothing, probably a grandchild *)
          ()

let initialize () = 
  Sys.set_signal Sys.sigchld (Sys.Signal_handle sigchld_handle)
