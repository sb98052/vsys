open Printf
open Scanf

let split_conf_line s =
  sscanf s "%s %s" (fun s1 s2->(s1,s2))

let read_frontends f =
  let f_file = try open_in f with e -> printf "Could not open config
                                         file\n";flush Pervasives.stdout;raise e
  in
  let rec read_conf_file cur_list =
    let next_line = try Some(input_line f_file) with _ -> None in
      match next_line with
        | Some(inp_line) -> read_conf_file (split_conf_line(inp_line)::cur_list)
        | None -> cur_list
  in
    read_conf_file []
