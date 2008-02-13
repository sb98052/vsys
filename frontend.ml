(* frontend.ml: Routines that implement frontend actions, such as creating directories in a slice, creating pipes etc. *)

open Printf
open Unix
open Globals
open Fifowatcher

(** frontendhandler class: Methods to create and unlink pipes and directories 
  @param root_dir vsys directory inside a slice
  @param slice_name actual slice name - set with care, since the acl functionality refers to these names *)
class frontendHandler (root_dir,slice_name) = 
object(this)
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
      let res = Fifowatcher.mkentry fqp abspath realperm slice_name in
        match res with 
          | Success ->
              Fifowatcher.openentry fqp (abspath,slice_name) realperm
          | _ -> ()

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
                        fprintf logfd "Removing directory %s\n" fqp;
                        flush logfd;
                        Unix.rmdir fqp;
                        Unix.mkdir fqp perm
                end
      with Unix.Unix_error(_,_,_) ->
        Unix.mkdir fqp perm

  (** Functions corresponding to file deletion/directory removal *)

  (** *)
  method unlink rp =
    match rp with Relpath(rel) ->
    let fqp1 = String.concat "/" [root_dir;rel;".in"] in
    let fqp2 = String.concat "/" [root_dir;rel;".out"] in
      try 
        Unix.unlink fqp1;
        Unix.unlink fqp2
      with _ ->
        fprintf logfd "Hm. %s disappeared. Looks like slice %s shot itself in the foot\n" fqp1 (this#get_slice_name ());flush logfd

  method rmdir rp =
    match rp with Relpath(rel) ->
    let fqp = String.concat "/" [root_dir;rel] in
      try
      Unix.rmdir fqp
      with _ ->
        fprintf logfd "Hm. %s disappeared. Looks like slice %s shot itself in the foot\n" fqp (this#get_slice_name ());flush logfd
end
