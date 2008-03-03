(** backend.ml: 
  Defines handlers for events related to the backend directory, where the
       scripts are stored. Eg. a new script results in a new part of pipes in
       the frontend etc. These handlers are defined in the backendHandler
       class.

  @author Sapan Bhatia <sapanb\@cs.princeton.edu>
  *)

open Unix
open Globals
open Dirwatcher
open Inotify
open Fifowatcher
open Frontend
open Printf

(** Helper functions:

*)

(** Turn an absolute path into a relative path. *)
let delete_prefix prefix str =
  let len = String.length str in
  let plen = String.length prefix in
    if (String.sub str 0 plen <> prefix) 
    then 
      (* XXX can a user make this happen? *)
      raise Bad_path
    else
        Relpath(String.sub str (plen+1) (len-plen-1))

let rec list_check lst elt =
  match lst with
    | [] -> false
    | car::cdr -> if (car==elt) then true else list_check cdr elt


(** The backendhandler class: defines event handlers for events in
the backend backend directory.
  @param dir_root The location of the backend in the server context (eg. root context for vservers)
  @param frontend_list List of frontends to serve with this backend
  *)
class backendHandler dir_root (frontend_lst: frontendHandler list) =
   let mk_rel_path = delete_prefix dir_root in object(this)

     (** Regular expression that defines a legal script name. Filter out
       * temporary files using this *)
     val file_regexp = Str.regexp "[a-zA-Z][a-zA-Z0-9_\.]*"
     val acl_file_regexp = Str.regexp ".*acl$"

     val dir_regexp = Str.regexp "^dir_";
     val acl_regexp = Str.regexp ".*_.*";

     (** Somebody created a new directory *)
     (* XXX Race condition here *)
     method private new_dir slice_list fqp func =
       let s = Unix.stat fqp in
         List.iter 
           (fun frontend->
              try begin 
                frontend#mkdir (mk_rel_path fqp) (s.st_perm);
                Dirwatcher.add_watch fqp [S_Create;S_Delete] func 
              end
              with _ ->
                fprintf logfd "Could not create %s. Looks like a slice shot itself in the foot\n" fqp;flush logfd;
           )
           slice_list

     (** Somebody copied in a new script *)
     (* XXX Race condition here *)
     method private new_script slice_list fqp =
       let s = Unix.stat fqp in
         List.iter (fun frontend->
                      frontend#mkentry (mk_rel_path fqp) fqp (s.st_perm)) slice_list 

     method private make_filter acl_fqp =
       let filter = Hashtbl.create 16 in
       try 
         let acl_file = open_in acl_fqp in
         let rec read_acl cur_filter = 
           let next_item = 
             try Some(input_line acl_file)
             with _ -> None
           in
             match next_item with
               | None -> cur_filter
               | Some(item) -> 
                   Hashtbl.add cur_filter item true;
                   read_acl cur_filter
         in
           Some(read_acl filter)
       with _ ->
         None

     (** Gets called every time there's an inotify event at the backend 
       @param dirname Name of the backend directory
       @param evlist Description of what happened
       @param fname Name of the file that the event applies to
     *)
     method handle_dir_event _ dirname evlist fname = 
       let fqp = String.concat "/" [dirname;fname] in
         if ((Str.string_match file_regexp fname 0) && not (Str.string_match acl_file_regexp fname 0)) then  
           begin
             (* Filter frontend list based on acl *)
             let acl_fqp = String.concat "." [fqp;"acl"] in
             let acl_filter = this#make_filter acl_fqp in
             let slice_list = 
               match acl_filter with
                 | None -> frontend_lst 
                 | Some(filter) -> List.filter (fun fe->Hashtbl.mem filter (fe#get_slice_name ())) frontend_lst 
             in 
             let is_event = list_check evlist in
               if (is_event Create) then
                 begin
                   if (is_event Isdir) then
                     begin
                       this#new_dir slice_list fqp this#handle_dir_event
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
                       this#new_script slice_list fqp
                     end
                 end
               else if (is_event Delete) then
                 begin
                   if (is_event Isdir) then
                     begin
                       (*this#rm_watch fqp;*)
                       List.iter (fun frontend->
                                    frontend#rmdir (mk_rel_path fqp)) slice_list
                     end
                   else List.iter (fun frontend ->
                                     frontend#unlink (mk_rel_path fqp)) slice_list
                 end
           end
         else (* regex not matched *)
           ()

     (** Initializer - build the initial tree based on the contents of /vsys *)
     initializer 
     let rec build_initial_tree dir =
       let dir_handle = opendir dir in
       let cont = ref true in
         while (!cont) do
           try 
             let curfile = readdir dir_handle  in
             let fqp = String.concat "/" [dir;curfile] in
             let acl_fqp = String.concat "." [fqp;"acl"] in
             let acl_filter = this#make_filter acl_fqp in
             let slice_list = 
               match acl_filter with
                 | None -> frontend_lst 
                 | Some(filter) -> List.filter (fun fe->Hashtbl.mem filter (fe#get_slice_name ())) frontend_lst 
             in
               if (Str.string_match file_regexp curfile 0 && not (Str.string_match acl_file_regexp curfile 0)) then
                 let s = Unix.stat fqp in
                   begin
                     match s.st_kind with
                       | S_DIR ->
                           this#new_dir slice_list fqp this#handle_dir_event;
                           build_initial_tree fqp;
                       | S_REG ->
                           this#new_script slice_list fqp
                       | _ ->
                           fprintf logfd "Don't know what to do with %s\n" curfile;flush logfd
                   end
           with 
               _->cont:=false;()
         done 
     in
       begin
         build_initial_tree dir_root;
         Dirwatcher.add_watch dir_root [S_Create;S_Delete] (this#handle_dir_event);
       end
   end
