(* frontend.ml: Routines that implement frontend actions, such as creating directories in a slice, creating pipes etc. *)

open Printf
open Unix
open Globals
open Directfifowatcher
open Unixsocketwatcher

(** frontendhandler class: Methods to create and unlink pipes and directories 
  @param root_dir vsys directory inside a slice
  @param slice_name actual slice name - set with care, since the acl functionality refers to these names *)
class frontendHandler (root_dir,slice_name) = 
object(this)

  (** regex indicating that the script passes fds around *)
  val fd_regex = Str.regexp "fd_"

  method is_fd_passer fname = 
    try let _ = Str.search_forward fd_regex fname 0 
    in 
      true
    with
      | Not_found -> false 
      | _ -> false

  method get_slice_name () = slice_name
  (** A new script was copied into the backend, make a corresponding entry in
    the frontend.
    @param rp Relative path of the entry in the backend
    @param abspath Absolute path of the entry
    @param perm Permissions of the entry at the frontend *)
  method mkentry (rp:relpath) abspath perm = 
    let realperm = perm land (lnot 0o111) in
      match rp with Relpath(rel) ->
        let fqp = String.concat "/" [root_dir;rel] in
          if (this#is_fd_passer rel) then
            let res = Unixsocketwatcher.mkentry fqp abspath realperm slice_name in
              begin
                match res with
                  | Success ->
                      ()
                  | _ -> 
                      logprint "Could not create entry %s" abspath
              end
              else
                let res = Directfifowatcher.mkentry fqp abspath realperm slice_name in
                  begin
                    match res with 
                      | Success ->
                          Directfifowatcher.openentry root_dir fqp (abspath,slice_name)
                      | _ -> 
                          logprint "Could not create entry %s" abspath
                  end
          



  (** A new directory was created at the backend, make a corresponding directory
    at the frontend. Refer to mkentry for parameters *)
  method mkdir rp perm =
    match rp with Relpath(rel) ->
      let fqp = String.concat "/" [root_dir;rel] in
        try 
          let s = Unix.stat fqp in
            if (s.st_kind<>S_DIR) then
              begin
                Unix.unlink fqp;
                Unix.mkdir fqp perm
              end
            else if (s.st_perm <> perm) then
              begin
                Unix.rmdir fqp;
                Unix.mkdir fqp perm
              end;
        with Unix.Unix_error(_,_,_) ->
          Unix.mkdir fqp perm;
          Directfifowatcher.add_dir_watch fqp

  (** Functions corresponding to file deletion/directory removal *)

  (** *)
  method unlink rp =
    match rp with Relpath(rel) ->
      let fqp = String.concat "/" [root_dir;rel] in
      let fqp_in = String.concat "." [fqp;"in"] in
      let fqp_out = String.concat "." [fqp;"out"] in
      let fqp_control = String.concat "." [fqp;"out"] in

        if (this#is_fd_passer rel) then
          begin
            Unixsocketwatcher.closeentry fqp;
            try 
              Unix.unlink fqp_control
            with _ ->
              logprint "Hm. %s disappeared. Looks like slice %s shot itself in the foot\n" fqp (this#get_slice_name ())
          end
        else
          begin
            Directfifowatcher.closeentry fqp;
            try 
              Unix.unlink fqp_in;
              Unix.unlink fqp_out
            with _ ->
              logprint "Hm. %s disappeared. Looks like slice %s shot itself in the foot\n" fqp (this#get_slice_name ())
          end

  method rmdir rp =
    match rp with Relpath(rel) ->
      let fqp = String.concat "/" [root_dir;rel] in
        Directfifowatcher.del_dir_watch fqp;
        try
          Unix.rmdir fqp
        with _ ->
          logprint "Hm. %s disappeared or not empty. Looks like slice %s shot itself in the foot\n" fqp (this#get_slice_name ())

  initializer 
    (
      try 
        let s = Unix.stat root_dir in
          if (s.st_kind<>S_DIR) then
            begin
              Unix.unlink root_dir;
              Unix.mkdir root_dir 0o700
            end
          else if (s.st_perm <> 0o700) then
            begin
              Unix.rmdir root_dir;
              Unix.mkdir root_dir 0o700
            end;
      with Unix.Unix_error(_,_,_) ->
        begin
          try 
            Unix.mkdir root_dir 0o700;
          with _ -> ();
        end);
          Directfifowatcher.add_dir_watch root_dir
end
