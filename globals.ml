let backend = ref ""
let debug = ref true
let vsys_version = "0.5"

type fd_and_fname = string option * Unix.file_descr

(* Relative path, never precededed by a '/' *)
type relpath = Relpath of string

exception Bad_path 
exception Bug
