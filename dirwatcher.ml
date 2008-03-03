(** Watches directories for events. Agnostic to vsys semantics of backends and
  frontends *)
open Inotify
open Fdwatcher
open Printf
open Globals

(* I don't know if a wd corresponding to a deleted directory is evicted or just
 * leaks - fix implementation of rmdir accordingly
 *)
let wdmap = Hashtbl.create 1024
let masks = Hashtbl.create 1024

let fd = Inotify.init ()

let rec list_check lst elt =
  match lst with
    | [] -> false
    | car::cdr -> if (car==elt) then true else list_check cdr elt

let handle_dir_event dirname evlist str = 
  let fname = String.concat "/" [dirname;str] in
    fprintf logfd "File: %s. " fname;List.iter 
                                       (fun e -> 
                                          fprintf logfd "Event: %s\n" (string_of_event e)) 
                                       evlist;
    flush logfd

let add_watch dir events handler =
  let evcheck = list_check events in
  let oneshot = if (evcheck S_Oneshot) then true else false
  in
  let wd = Inotify.add_watch fd dir events in
    Hashtbl.add masks dir (wd,handler);
    Hashtbl.add wdmap wd (dir,Some(handler),oneshot)

let mask_watch dir =
  try 
    let wd,_ = Hashtbl.find masks dir in
      Inotify.rm_watch fd wd;
      Hashtbl.remove wdmap wd
  with _ ->
    ()

let unmask_watch dir events =
  let _,handler = Hashtbl.find masks dir in
    try 
      Hashtbl.remove masks dir;
      add_watch dir events handler
    with Not_found -> ()

let asciiz s =
  let rec findfirstnul str idx len =
    if ((idx==len) || 
        (str.[idx]==(char_of_int 0))) then idx
    else
      findfirstnul str (idx+1) len
  in
  let nulterm = findfirstnul s 0 (String.length s) in
    String.sub s 0 nulterm

let receive_event (eventdescriptor:fname_and_fd) (bla:fname_and_fd) =
  let (_,fd) = eventdescriptor in
  let evs = Inotify.read fd in
    List.iter (fun x->
                 match x with
                   | (wd,evlist,_,Some(str)) ->
                       let purestr = asciiz(str) in
                       let (dirname,handler,oneshot) = 
                         try Hashtbl.find wdmap wd with Not_found->("",None,false)
                       in
                         if (oneshot) then Hashtbl.remove wdmap wd;
                         (
                           match handler with
                             | None->fprintf logfd "Unhandled watch descriptor\n";flush logfd
                             | Some(handler)->handler wd dirname evlist purestr
                         )
                   | _ -> ()) 
      evs

let initialize () =
  Fdwatcher.add_fd (None,fd) (None,fd) receive_event
