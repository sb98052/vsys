(** fifowatcher.ml: Routines to handle non-persistent scripts *)

open Inotify
open Unix
open Globals
open Dirwatcher
open Printf
open Splice

let backend_prefix = ref ""
let direct_fifo_table: (string,(string*string) option) Hashtbl.t = Hashtbl.create 1024

let rec list_check lst elt =
  match lst with
    | [] -> false
    | car::cdr -> if (car==elt) then true else list_check cdr elt




(* vsys is activated when a client opens an in file *)
let connect_file fqp_in =
  (* Do we care about this file? *)
  let entry_info = try
    Hashtbl.find direct_fifo_table fqp_in with _ -> fprintf logfd "[Alert] Access via unauthorized vsys entry: %s\n" fqp_in;flush logfd;None in
    match entry_info with
      | Some(execpath,slice_name) ->
          fprintf logfd "Executing %s for slice %s\n" execpath slice_name;flush logfd;
          begin
            let len = String.length fqp_in in
            let fqp = String.sub fqp_in 0 (len-3) in
            let fqp_out = String.concat "." [fqp;"out"] in
            let fifo_fdin =
              try openfile fqp_in [O_RDONLY;O_NONBLOCK] 0o777 with
                  e->fprintf logfd "Error opening and connecting FIFO: %s\n" fqp_in;flush logfd;raise e
            in
            let fifo_fdout =
              try openfile fqp_out [O_WRONLY;O_NONBLOCK] 0o777 with
                  _->fprintf logfd "%s Output pipe not open, using stdout in place of %s\n" slice_name fqp_out;flush logfd;stdout
            in
              try ignore(create_process execpath [|execpath;slice_name|] fifo_fdin fifo_fdout fifo_fdout) with e -> fprintf logfd "Error executing service: %s\n" execpath;flush logfd
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

(** Open fifos for a session. SHOULD NOt shutdown vsys if the fifos don't exist *)
let openentry fqp backend_spec =
  let fqp_in = String.concat "." [fqp;"in"] in
    Hashtbl.replace direct_fifo_table fqp_in (Some(backend_spec))

(** Close fifos that just got removed *)
let closeentry fqp =
  let fqp_in = String.concat "." [fqp;"in"] in
    Hashtbl.remove direct_fifo_table fqp_in

let direct_fifo_handler dirname evlist fname =
  printf "Received event %s %s\n" dirname fname;flush Pervasives.stdout;
  let is_event = list_check evlist in
    if (is_event Open) then 
      let fqp_in = String.concat "/" [dirname;fname] in
        connect_file fqp_in

let add_dir_watch fqp =
  Dirwatcher.add_watch fqp [S_Open] (Some(direct_fifo_handler))

let del_dir_watch fqp =
  (* XXX Dirwatcher.del_watch fqp *)
  ()
