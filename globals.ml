let frontend = ref ""
let backend = ref ""
let debug = ref true

type fd_and_fname = string option * Unix.file_descr
type relpath = Relpath of string

exception Bad_path 
exception Bug
