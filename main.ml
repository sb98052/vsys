(** main () *)
open Globals
open Printf
open Inotify
open Backend
open Frontend
open Conffile

let input_file_list = ref []
let cur_dir = ref ""
let cur_slice = ref ""
let daemonize = ref false

let cmdspeclist =
  [
    ("-daemon",Arg.Set(daemonize), "Daemonize");
    ("-conffile",Arg.Set_string(Globals.conffile), "Config file");
    ("-backend",Arg.Set_string(Globals.backend), "Backend directory");
    ("-frontend",Arg.Tuple[Arg.String(fun s->cur_dir:=s);
                           Arg.String(fun s->cur_slice:=s;
                                             input_file_list:=(!cur_dir,!cur_slice)::!input_file_list)], 
     "frontendN,slicenameN");
    ("-nochroot",Arg.Set(Globals.nochroot), "Run in non-chroot environment");
    ("-failsafe",Arg.Set(Globals.failsafe), "Never crash. Be stupid, but never crash. Use at your own risk.");
  ]

let _ =
  printf "Starting Vsys v%s\n" Globals.vsys_version;flush stdout;
  fprintf logfd "Starting Vsys v%s\n" Globals.vsys_version;flush logfd;
  Arg.parse cmdspeclist (fun x->()) "Usage: vsys <list of mount points>";  
  if (!Globals.backend == "") then
    printf "Try vsys --help\n"
  else
    begin
      if (!daemonize) then
        begin
          printf "Daemonizing\n";flush Pervasives.stdout;
          let child = Unix.fork () in
            if (child <> 0) then
              begin
                let pidfile = open_out !Globals.pid_filepath in
                  fprintf pidfile "%d" child;
                  close_out pidfile;
                  exit(0)
              end
        end;

      Dirwatcher.initialize ();
      Directfifowatcher.initialize ();

      if (!Globals.conffile <> "") then
        begin
          let frontends = Conffile.read_frontends !Globals.conffile in
            input_file_list:=List.concat [!input_file_list;frontends]
        end;

      let felst = List.map 
                    (fun lst->let (x,y)=lst in 
                       fprintf logfd "Slice %s (%s)\n" x y;
                       flush logfd;
                       new frontendHandler lst) 
                    !input_file_list in
      let _ = new backendHandler !Globals.backend felst in
        Fdwatcher.start_watch ()
    end
