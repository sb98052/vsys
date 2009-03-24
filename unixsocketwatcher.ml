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
open Fdwatcher
open Printf

let close_if_open fd = (try (ignore(close fd);) with _ -> ())

type control_path_name = string
type exec_path_name = string
type slice_name = string

let unix_socket_table: (control_path_name,(exec_path_name*slice_name*Unix.file_descr) option) Hashtbl.t = 
  Hashtbl.create 1024

(** Make a pair of fifo entries *)
let mkentry fqp exec_fqp perm slice_name = 
  logprint "Making control entry %s->%s\n" fqp exec_fqp;
  let control_filename=sprintf "%s.control" fqp in
    try
      let listening_socket = socket PF_UNIX SOCK_STREAM 0 in
        (try Unix.unlink control_filename with _ -> ());
        let socket_address = ADDR_UNIX(control_filename) in
          bind listening_socket socket_address;
          listen listening_socket 10;
          ( (* Make the user the owner of the pipes in a non-chroot environment *)
            if (!Globals.nochroot) then
              let pwentry = Unix.getpwnam slice_name in
                Unix.chown control_filename pwentry.pw_uid pwentry.pw_gid
          );
          Hashtbl.replace unix_socket_table control_filename (Some(exec_fqp,slice_name,listening_socket));
          Success
    with 
        e->logprint "Error creating FIFO: %s->%s. May be something wrong at the frontend.\n" fqp exec_fqp;Failed

let receive_event (listening_socket_spec:fname_and_fd) (_:fname_and_fd) =
  (* Do we care about this file? *)
  try 
    let (_,listening_socket) = listening_socket_spec in
    let (data_socket, addr) = accept listening_socket in
      match addr with 
        | ADDR_UNIX(fname) ->
            let entry_info = try
              Hashtbl.find unix_socket_watcher addr with _ -> None in
              match entry_info with
                | Some(_,execpath,slice_name,fd) ->
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
  with e-> logprint "Error connecting service %s\n" execpath
    | _ -> logprint "Serious error! Got a non UNIX connection over a UNIX socket\n"
  
(** Close sockets that just got removed *)
let closeentry fqp =
  let control_filename = String.concat "." [fqp;"control"] in
  let entry = try Hashtbl.find unix_socket_table control_filename with Not_found -> None in
    match entry with
      | None -> ()
      | Some(_,_,fd) -> 
          shutdown fd SHUTDOWN_ALL;
          close_if_open fd;
          Fdwatcher.add_fd (None,fd) (None,fd) receive_event;
          Hashtbl.remove unix_socket_table control_filename





let initialize () =
  ()
