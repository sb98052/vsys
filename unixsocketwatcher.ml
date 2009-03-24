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
    let (_,listening_socket) = listening_socket_spec in
  try 
    let (data_socket, addr) = accept listening_socket in
      match addr with 
        | ADDR_UNIX(fname) ->
            begin
              let entry_info = 
                try
                  Hashtbl.find unix_socket_table fname 
                with _ -> None in
                match entry_info with
                  | Some(execpath,slice_name,fd) ->
                      begin
                        let child = fork () in
                          if (child == 0) then
                               begin
                                 (*Child*)
                                 (* Close all fds except for the socket *)
                                 execv execpath,[execpath];
                                 logprint "Could not execve %s" execpath
                               end
                      end
                  | None -> ()
            end
        | _ -> logprint "Serious error! Got a non UNIX connection over a UNIX socket\n"
  with e-> logprint "Error accepting socket\n"
  
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
