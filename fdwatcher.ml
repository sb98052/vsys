(** Fdwatcher - The main event loop. Agnostic to the type of file descriptors
  involved.*)

open Printf
open Globals
open Printexc

let fdset = ref []
let cbtable = Hashtbl.create 1024

let add_fd (evpair:fname_and_fd) (fd_other:fname_and_fd) (callback:fname_and_fd->fname_and_fd->unit) = 
  let (fname,fd) = evpair in
    fdset := (fd::!fdset);
    Hashtbl.replace cbtable fd (callback,(evpair,fd_other))

let del_fd fd =
  fdset:=List.filter (fun l->l<>fd) !fdset

let start_watch () =
  while (true)
  do
    let (fds,_,_) = try Unix.select !fdset [] [] (-1.) 
    with e->
      ([],[],[])
    in
      List.iter (fun elt->
                   let (func,(evd,fd_other)) = Hashtbl.find cbtable elt in
                     try (* Never fail *)
                       func evd fd_other
                     with e->
                       let wtf = Printexc.to_string e in
                         logprint "%s\n" wtf
                ) fds
  done
