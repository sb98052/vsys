open Unix
open Globals
open Dirwatcher
open Inotify
open Fifowatcher
open Frontend
open Printf

let delete_prefix prefix str =
  let len = String.length str in
  let plen = String.length prefix in
    if (String.sub str 0 plen <> prefix) 
    then 
      raise Bad_path
    else
      Relpath(String.sub str (plen+1) (len-plen-1))

let rec list_check lst elt =
  match lst with
    | [] -> false
    | car::cdr -> if (car==elt) then true else list_check cdr elt


                                                 (*
                                                  * One backendHandler class for each
                                                  * backend. Builds the initial
                                                  * tree for the frontend and
                                                  * watches for directory
                                                  * events.
                                                  *)

class backendHandler dir_root (frontend_lst: frontendHandler list) =
        let mk_rel_path = delete_prefix dir_root in object(this)

  val file_regexp = ref (Str.regexp "[a-zA-Z][a-zA-Z0-9_-'.']*")

  method new_dir fqp func =
    let s = Unix.stat fqp in
      List.iter 
        (fun frontend->
           frontend#mkdir (mk_rel_path fqp) (s.st_perm);
           Dirwatcher.add_watch fqp [S_Create;S_Delete] (Some(func)))
        frontend_lst;

  method new_script fqp =
    let s = Unix.stat fqp in
      List.iter (fun frontend->
                   frontend#mkentry (mk_rel_path fqp) fqp (s.st_perm)) frontend_lst 

  val dir_regexp = Str.regexp "^dir_";

  method handle_dir_event dirname evlist fname = 
    let fqp = String.concat "/" [dirname;fname] in
      if (Str.string_match !file_regexp fname 0) then  
        begin
          let is_event = list_check evlist in
            if (is_event Create) then
              begin
                if (is_event Isdir) then
                  begin
                    this#new_dir fqp this#handle_dir_event
                  end 
                else
                  (* It's a new script *)
                  begin
                    (*
                     if (Str.string_match dir_regexp fname 0) then
                     let fqp = String.concat "/" [dirname;String.sub fname 4 ((String.length fname)-4+1)]  in 
                     let real_fqp = String.concat "/" [dirname;fname]  in 
                     this#new_dir fqp this#handle_spool_event;
                     Hashtbl.add spools fqp real_fqp
                     else*)
                    this#new_script fqp
                  end
              end
            else if (is_event Delete) then
              begin
                if (is_event Isdir) then
                  begin
                    (*this#rm_watch fqp;*)
                    List.iter (fun frontend->
                                 frontend#rmdir (mk_rel_path fqp)) frontend_lst
                  end
                else List.iter (fun frontend ->
                                  frontend#unlink (mk_rel_path fqp)) frontend_lst
              end
        end
      else (* regex not matched *)
        ()

  initializer 
  let rec build_initial_tree dir =
    let dir_handle = opendir dir in
    let cont = ref true in
      while (!cont) do
        try 
          let curfile = readdir dir_handle  in
          let fqp = String.concat "/" [dir;curfile] in
            if (Str.string_match !file_regexp curfile 0) then
              let s = Unix.stat fqp in
                begin
                  match s.st_kind with
                    | S_DIR ->
                        this#new_dir fqp this#handle_dir_event;
                        build_initial_tree fqp;
                    | S_REG ->
                        this#new_script fqp
                    | _ ->
                        printf "Don't know what to do with %s\n" curfile;flush Pervasives.stdout
                end
        with 
            _->cont:=false;()
      done 
  in
    begin
      build_initial_tree dir_root;
      Dirwatcher.add_watch dir_root [S_Create;S_Delete] (Some(this#handle_dir_event));
    end
end
