open Printf
open Globals
open Scanf

let split_conf_line s =
  sscanf s "%s %s" (fun s1 s2->(s1,s2))

let rec in_list elt lst =
  match lst with 
    | car::cdr ->
        if (elt = car) then true else in_list elt cdr
    | [] -> false

let read_frontends f =
  let f_file = try open_in f with e -> fprintf logfd "Could not open config file\n";flush logfd;raise e
  in
  let rec read_conf_file cur_list =
    let next_line = try Some(input_line f_file) with _ -> None in
      match next_line with
        | Some(inp_line) -> 
            let fe = split_conf_line inp_line in
            let new_list = if (not (in_list fe cur_list)) then (fe::cur_list) else cur_list
            in
            read_conf_file new_list
        | None -> cur_list
  in
    read_conf_file []
