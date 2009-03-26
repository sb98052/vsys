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

let unix_socket_table_fname: (control_path_name,Unix.file_descr option) Hashtbl.t = 
  Hashtbl.create 1024

let unix_socket_table_fd: (Unix.file_descr, (exec_path_name * slice_name) option) Hashtbl.t =
  Hashtbl.create 1024

let receive_event (listening_socket_spec:fname_and_fd) (_:fname_and_fd) =
  let (_,listening_socket) = listening_socket_spec in
    try 
      let (data_socket, _) = accept listening_socket in
      let (mapping) = 
        try
          Hashtbl.find unix_socket_table_fd listening_socket
        with _ -> None in
        match mapping with
          |None -> logprint "Received unexpected socket event\n";()
          |Some (execpath, slice_name) ->
              begin
                let child = fork () in
                  if (child == 0) then
                    begin
                      (* Child *)
                      (* Close all fds except for the socket *)
                      let fd = Obj.magic data_socket in
                        let _ = 
                          (* Close fds *)
                          for i = 3 to 1023 do
                            if (i != fd) then close_if_open(Obj.magic i)
                          done;
                            execv execpath [|execpath;slice_name;sprintf "%d" fd|] (*with
                                Unix_error(num,str1,str2)->logprint "Error %d: %s (%s)" (Obj.magic num) str1 str2;raise (Unix_error(num,str1,str2))*)
                        in
                            logprint "Could not execve %s" execpath
                    end
                  else
                    close_if_open(data_socket)
              end
          | None -> ()
    with e-> logprint "Error accepting socket\n"

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
          Hashtbl.replace unix_socket_table_fname control_filename (Some(listening_socket));
          Hashtbl.replace unix_socket_table_fd listening_socket (Some(exec_fqp,slice_name));
          Fdwatcher.add_fd (None,listening_socket) (None,listening_socket) receive_event;
          Success
    with 
        e->logprint "Error creating FIFO: %s->%s. May be something wrong at the frontend.\n" fqp exec_fqp;Failed

  
(** Close sockets that just got removed *)
let closeentry fqp =
  let control_filename = String.concat "." [fqp;"control"] in
  let entry = try Hashtbl.find unix_socket_table_fname control_filename with Not_found -> None in
    match entry with
      | None -> ()
      | Some(fd) -> 
          Hashtbl.remove unix_socket_table_fd fd;
          shutdown fd SHUTDOWN_ALL;
          close_if_open fd;
          Hashtbl.remove unix_socket_table_fname control_filename



let initialize () =
  ()
