let backend = ref ""
let debug = ref true
let vsys_version = "0.5"

type fname_and_fd = string option * Unix.file_descr

(* Relative path, never precededed by a '/' *)
type relpath = Relpath of string

exception Bad_path 
exception Bug
