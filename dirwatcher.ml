(** Watches directories for events. Agnostic to vsys semantics of backends and
frontends *)
open Inotify
open Fdwatcher
open Printf
open Globals

(* I don't know if a wd corresponding to a deleted directory is evicted or just
 * leaks - fix implementation of rmdir accordingly
 *)

type 'a handlertype = Nohandler | Activehandler of 'a | Maskedhandler of 'a

let wdmap = Hashtbl.create 1024

let fd = Inotify.init ()

let handle_dir_event dirname evlist str = 
    let fname = String.concat "/" [dirname;str] in
        fprintf logfd "File: %s. " fname;List.iter 
                  (fun e -> 
                     fprintf logfd "Event: %s\n" (string_of_event e)) 
                  evlist;
        flush logfd

let add_watch dir events handler =
  let wd = Inotify.add_watch fd dir events in
      Hashtbl.add wdmap wd (dir,Activehandler(handler))

let mask_events wd =
  let (dirname,handler) = try Hashtbl.find wdmap wd with Not_found->("",Nohandler)
  in
    match handler with
      | Activehandler(func)->
          Hashtbl.replace wdmap wd (dirname,Maskedhandler(func))
      | _ ->
          ()

let unmask_events wd =
  let (dirname,handler) = try Hashtbl.find wdmap wd with Not_found->("",Nohandler)
  in
    match handler with
      | Maskedhandler(func)->
          Hashtbl.replace wdmap wd (dirname,Activehandler(func))
      | _ ->
          ()


        (* XXX
let del_watch dir =
  fprintf logfd "Removing watch for %s\n" dir;flush logfd;
  let wd = Inotify.rm_watch fd dir in
      Hashtbl.remove wdmap wd 
         *)

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
                      let (dirname,handler) = 
                        try Hashtbl.find wdmap wd with Not_found->("",Nohandler)
                      in
                        (
                        match handler with
                          | Nohandler->fprintf logfd "Unhandled watch descriptor\n";flush logfd
                          | Activehandler(handler)->handler wd dirname evlist purestr
                          | Maskedhandler(_)->()
                        )
                  | _ -> ()) 
          evs

let initialize () =
  Fdwatcher.add_fd (None,fd) (None,fd) receive_event
