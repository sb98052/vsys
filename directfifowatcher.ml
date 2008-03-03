(** directfifowatcher.ml: Routines to handle non-persistent scripts *)
(* Semantics:
 *      - The 'out' descriptor must be opened first
 *      - As soon as the backend script dies, the connection to the entry is
 *      closed.
 *      - To avoid user-inflicted pain, all entries are opened at the time
 *      that they are created. Reopening these entries is a little complicated
 *      but nevertheless sound:
 *              * When a script dies, its fd is reopened
 *              * If a script fails to execute, its fd is closed and reopened to
 *              beat a race that can happen when the user closes the connection
 *              before the script can be launched.
 *)

open Inotify
open Unix
open Globals
open Dirwatcher
open Printf
open Splice

let close_if_open fd = (try (ignore(close fd);) with _ -> ())


let direct_fifo_table: (string,(string*string*string*Unix.file_descr) option) Hashtbl.t = Hashtbl.create 1024
let pidmap: (int,string) Hashtbl.t = Hashtbl.create 1024

let rec list_check lst elt =
  match lst with
    | [] -> false
    | car::cdr -> if (car==elt) then true else list_check cdr elt

let openentry_int fifoin =
  let fdin =
    try openfile fifoin [O_RDONLY;O_NONBLOCK] 0o777 with 
        e->fprintf logfd "Error opening and connecting FIFO: %s,%o\n" fifoin 0o777;flush logfd;raise e
  in
    fdin


(** Open fifos for a session. SHOULD NOt shutdown vsys if the fifos don't exist *)
let openentry_in root_dir fqp_in backend_spec =
    Dirwatcher.mask_watch root_dir;
  let fd_in = openentry_int fqp_in in
    Dirwatcher.unmask_watch root_dir [S_Open];
  let (fqp,slice_name) = backend_spec in
    Hashtbl.replace direct_fifo_table fqp_in (Some(root_dir,fqp,slice_name,fd_in))

let openentry root_dir fqp backend_spec =
  let fqp_in = String.concat "." [fqp;"in"] in
    openentry_in root_dir fqp_in backend_spec

let reopenentry fifoin =
  let entry = try Hashtbl.find direct_fifo_table fifoin with _ -> None in
    match entry with
      | Some(dir, fqp,slice_name,fd) -> close_if_open fd;openentry_in dir fifoin (fqp,slice_name)
      | None -> ()

(* vsys is activated when a client opens an in file *)
let connect_file fqp_in =
  (* Do we care about this file? *)
  let entry_info = try
    Hashtbl.find direct_fifo_table fqp_in with _ -> None in
    match entry_info with
      | Some(_,execpath,slice_name,fifo_fdin) ->
          fprintf logfd "Executing %s for slice %s\n" execpath slice_name;flush logfd;
          begin
            let len = String.length fqp_in in
            let fqp = String.sub fqp_in 0 (len-3) in
            let fqp_out = String.concat "." [fqp;"out"] in
            let fifo_fdout =
              try openfile fqp_out [O_WRONLY;O_NONBLOCK] 0o777 with
                  _->fprintf logfd "%s Output pipe not open, using stdout in place of %s\n" slice_name fqp_out;flush logfd;stdout
            in
            ignore(sigprocmask SIG_BLOCK [Sys.sigchld]);
            (
            clear_nonblock fifo_fdin;
            let pid=try Some(create_process execpath [|execpath;slice_name|] fifo_fdin fifo_fdout fifo_fdout) with e -> None in
              match pid with 
                | Some(pid) ->Hashtbl.add pidmap pid fqp_in
                | None ->fprintf logfd "Error executing service: %s\n" execpath;flush logfd;reopenentry fqp_in
            );
            ignore(sigprocmask SIG_UNBLOCK [Sys.sigchld]);
          end
      | None -> ()


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


(** Close fifos that just got removed *)
let closeentry fqp =
  let fqp_in = String.concat "." [fqp;"in"] in
  let entry = try Hashtbl.find direct_fifo_table fqp_in with Not_found -> None in
    match entry with
      | None -> ()
      | Some(_,_,_,fd) -> 
          close_if_open fd;
          Hashtbl.remove direct_fifo_table fqp_in

let sigchld_handle s =
  let pid,_=Unix.waitpid [Unix.WNOHANG] 0 in
    try
      let fqp_in = Hashtbl.find pidmap pid in
        printf "Reopening fifo\n";flush Pervasives.stdout;
        reopenentry fqp_in
    with _ -> ()

let rec add_dir_watch fqp =
  Dirwatcher.add_watch fqp [S_Open] direct_fifo_handler
and
direct_fifo_handler wd dirname evlist fname =
  let is_event = list_check evlist in
    if (is_event Open) then 
      let fqp_in = String.concat "/" [dirname;fname] in
      begin
        connect_file fqp_in;
        add_dir_watch dirname
      end

let del_dir_watch fqp =
  (* XXX Dirwatcher.del_watch fqp *)
  ()

let initialize () =
      Sys.set_signal Sys.sigchld (Sys.Signal_handle sigchld_handle)
