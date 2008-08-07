(** Some things that didn't fit in elsewhere *)
let backend = ref ""
let debug = ref true
let vsys_version = "0.7"
let nochroot = ref false
let conffile = ref ""
let pid_filepath = ref "/var/run/vsys.pid"
let log_filepath = ref "/var/log/vsys"
let failsafe = ref false

let logfd = open_out_gen [Open_append;Open_creat] 0o644 !log_filepath
let logprint fmt = Printf.fprintf logfd (fmt ^^ "%!")
let debprint fmt = if (!debug) then Printf.fprintf logfd (fmt ^^ "%!")
let print fmt = Printf.printf (fmt ^^ "%!")

type result = Success | Failed
type fname_and_fd = string option * Unix.file_descr

(* Relative path, never precededed by a '/' *)
type relpath = Relpath of string

exception Bad_path 
exception Bug
