(** Fdwatcher - The main event loop. Agnostic to the type of file descriptors
 involved.*)

open Printf
open Globals

let fdset = ref []
let cbtable = Hashtbl.create 1024

(* The in descriptor is always open. Thanks to the broken semantics of
 * fifo outputs, the out descriptor must be opened a nouveau whenever we
 * want to send out data, and so we keep the associated filename as well.
 * Same with input fifos. Yipee.*)
let add_fd (evpair:fname_and_fd) (fd_other:fname_and_fd) (callback:fname_and_fd->fname_and_fd->unit) = 
  let (fname,fd) = evpair in
  fdset := (fd::!fdset);
  Hashtbl.replace cbtable fd (callback,(evpair,fd_other))

let del_fd fd =
  fdset:=List.filter (fun l->l<>fd) !fdset;
  flush logfd

let start_watch () =
    while (true)
    do
              let (fds,_,_) = try Unix.select !fdset [] [] (-1.) 
              with e->
                ([],[],[])
              in
                List.iter (fun elt->
                             let (func,(evd,fd_other)) = Hashtbl.find cbtable elt in
                               func evd fd_other) fds
    done
