open Globals
open Printf
open Inotify
open Backend
open Frontend
open Fifowatcher

let input_file_list = ref []
let cur_dir = ref ""
let cur_slice = ref ""

let cmdspeclist =
  [
    ("-backend",Arg.Set_string(Globals.backend), "Backend directory");
    ("-frontend",Arg.Tuple[Arg.String(fun s->cur_dir:=s);Arg.String(fun s->cur_slice:=s;input_file_list:=(!cur_dir,!cur_slice)::!input_file_list)], "frontendN,slicenameN")
  ]

let cont = ref true

let _ =
  printf "Vsys v0.3\n";flush stdout;
  Arg.parse cmdspeclist (fun x->()) "Usage: vsys <list of mount points>";  
  if (!Globals.backend == "" || !input_file_list == []) then
      printf "Try vsys --help\n"
  else
    begin
    Dirwatcher.initialize ();
    Fifowatcher.initialize ();
    let felst = List.map (fun lst->new frontendHandler lst) !input_file_list in
        let _ = new backendHandler !Globals.backend felst in
         Fdwatcher.start_watch ()
    end
