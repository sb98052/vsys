(** unixsocketwathcer.ml: Routines to handle unix sockets for fd passing *)
(* Semantics for the client C, script S and Vsys, V
 * - V creates a UNIX socket and listens on it, adding a watch
 * - C connects to the socket
 * - V accepts the connection, forks, execve()s S and gets out of the way
 * - S sends an fd to C and closes the connection
 * - If one of S or C dies, then the other gets a SIGPIPE, Vsys gets a sigchld,
 * either way, Vsys should survive the transaction.
 *)

open Unix
open Globals
open Dirwatcher
open Printf

let close_if_open fd = (try (ignore(close fd);) with _ -> ())

type control_path_name = string
type slice_name = string

let unix_socket_table: (control_path_name,Unix.file_descr option) Hashtbl.t = 
  Hashtbl.create 1024

let list_check lst elt _ =
  let rec list_check_rec lst = 
    match lst with
      | [] -> false
      | car::cdr -> 
          if (car==elt) then
               true
          else
            list_check_rec cdr
  in
    list_check_rec lst

let openentry_int fifoin =
  let fdin =
    try openfile fifoin [O_RDONLY;O_NONBLOCK] 0o777 with 
        e->logprint "Error opening and connecting FIFO: %s,%o\n" fifoin 0o777;raise e
  in
    fdin

(** Open entry safely, by first masking out the file to be opened *)
let openentry_safe root_dir fqp_in backend_spec =
  let restore = move_gate fqp_in in
  let fd_in = openentry_int restore in
    move_ungate fqp_in restore;
    let (fqp,slice_name) = backend_spec in
      Hashtbl.replace direct_fifo_table fqp_in (Some(root_dir,fqp,slice_name,fd_in))

let openentry root_dir fqp backend_spec =
  let control_file = String.concat "." [fqp;"control"] in
    openentry_safe root_dir fqp_in backend_spec

let reopenentry fifoin =
  let entry = try Hashtbl.find direct_fifo_table fifoin with _ -> None in
    match entry with
      | Some(dir, fqp,slice_name,fd) -> close_if_open fd;openentry_safe dir fifoin (fqp,slice_name)
      | None -> ()

(* vsys is activated when a client opens an in file *)
let connect_file fqp_in =
  (* Do we care about this file? *)
  let entry_info = try
    Hashtbl.find direct_fifo_table fqp_in with _ -> None in
    match entry_info with
      | Some(_,execpath,slice_name,fifo_fdin) ->
          begin
            let len = String.length fqp_in in
            let fqp = String.sub fqp_in 0 (len-3) in
            let fqp_out = String.concat "." [fqp;"out"] in
            let fifo_fdout =
              try openfile fqp_out [O_WRONLY;O_NONBLOCK] 0o777 with
                  _-> (* The client is opening the descriptor too fast *)
                    sleep 1;try openfile fqp_out [O_WRONLY;O_NONBLOCK] 0o777 with
                        _->
                        logprint "%s Output pipe not open, using stdout in place of %s\n" slice_name fqp_out;stdout
            in
              ignore(sigprocmask SIG_BLOCK [Sys.sigchld]);
              (
                clear_nonblock fifo_fdin;
                let pid=try Some(create_process execpath [|execpath;slice_name|] fifo_fdin fifo_fdout fifo_fdout) with e -> None in
                  match pid with 
                    | Some(pid) ->
                        if (fifo_fdout <> stdout) then close_if_open fifo_fdout;
                        Hashtbl.add pidmap pid (fqp_in,fifo_fdout)
                    | None ->logprint "Error executing service: %s\n" execpath;reopenentry fqp_in
              );
              ignore(sigprocmask SIG_UNBLOCK [Sys.sigchld]);
          end
      | None -> ()


(** Make a pair of fifo entries *)
let mkentry fqp abspath perm uname = 
  logprint "Making control entry %s->%s\n" fqp abspath;
  let control_filename=sprintf "%s.control" fqp in
    try
      let listening_socket = socket PF_UNIX SOCK_STREAM 0 in
        (try Unix.unlink control_filename with _ -> ());
        let socket_address = ADDR_UNIX(control_filename) in
          bind listening_socket socket_address;
          ( (* Make the user the owner of the pipes in a non-chroot environment *)
            if (!Globals.nochroot) then
              let pwentry = Unix.getpwnam uname in
                Unix.chown control_filename pwentry.pw_uid pwentry.pw_gid
          );
          Success
    with 
        e->logprint "Error creating FIFO: %s->%s. May be something wrong at the frontend.\n" fqp fifoout;Failed)


(** Close fifos that just got removed *)
let closeentry fqp =
  let control_filename = String.concat "." [fqp;"control"] in
  let entry = try Hashtbl.find direct_fifo_table control_filename with Not_found -> None in
    match entry with
      | None -> ()
      | Some(_,_,_,fd) -> 
          shutdown fd SHUTDOWN_ALL;
          close_if_open fd

let rec add_dir_watch fqp =
  Dirwatcher.add_watch fqp [S_Open] direct_fifo_handler
and
    direct_fifo_handler wd dirname evlist fname =
  let is_event = list_check evlist in
    if (is_event Open Attrib) then 
      let fqp_in = String.concat "/" [dirname;fname] in
        connect_file fqp_in

let del_dir_watch fqp =
  ()

let initialize () =
  Sys.set_signal Sys.sigchld (Sys.Signal_handle sigchld_handle)
