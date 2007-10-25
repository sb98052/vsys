(** main () *)
open Globals
open Printf
open Inotify
open Backend
open Frontend
open Fifowatcher
open Conffile

let input_file_list = ref []
let cur_dir = ref ""
let cur_slice = ref ""

let cmdspeclist =
  [
    ("-conffile",Arg.Set_string(Globals.conffile), "Config file");
    ("-backend",Arg.Set_string(Globals.backend), "Backend directory");
    ("-frontend",Arg.Tuple[Arg.String(fun s->cur_dir:=s);Arg.String(fun s->cur_slice:=s;input_file_list:=(!cur_dir,!cur_slice)::!input_file_list)], "frontendN,slicenameN");
    ("-nochroot",Arg.Set(Globals.nochroot), "Run in non-chroot environment")
  ]

let cont = ref true

let _ =
  printf "Vsys v%s\n" Globals.vsys_version;flush stdout;
  Arg.parse cmdspeclist (fun x->()) "Usage: vsys <list of mount points>";  
  if (!Globals.backend == "") then
      printf "Try vsys --help\n"
  else
    begin
    Dirwatcher.initialize ();
    Fifowatcher.initialize ();
    if (!Globals.conffile != "") then
      let frontends = Conffile.read_frontends !Globals.conffile in
        input_file_list:=List.concat [!input_file_list;frontends];

    let felst = List.map (fun lst->let (x,y)=lst in printf "Slice %s (%s)\n" x y;flush Pervasives.stdout;new frontendHandler lst) !input_file_list in
        let _ = new backendHandler !Globals.backend felst in
         Fdwatcher.start_watch ()
    end
