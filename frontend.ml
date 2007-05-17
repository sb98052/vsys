open Printf
open Unix
open Globals
open Fifowatcher

class frontendHandler (root_dir,slice_name) = 
object(this)
  method mkentry (rp:relpath) abspath perm = 
            let realperm = perm land (lnot 0o111) in
    match rp with Relpath(rel) ->
      let fqp = String.concat "/" [root_dir;rel] in
         Fifowatcher.mkentry fqp abspath realperm;
         Fifowatcher.openentry fqp (abspath,slice_name) realperm

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
                        printf "Removing directory %s\n" fqp;
                        flush Pervasives.stdout;
                        Unix.rmdir fqp;
                        Unix.mkdir fqp perm
                end
      with Unix.Unix_error(_,_,_) ->
        Unix.mkdir fqp perm

  method unlink rp =
    match rp with Relpath(rel) ->
    let fqp = String.concat "/" [root_dir;rel] in
      Unix.unlink fqp

  method rmdir rp =
    match rp with Relpath(rel) ->
    let fqp = String.concat "/" [root_dir;rel] in
      Unix.rmdir fqp
end
