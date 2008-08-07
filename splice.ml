open Unix

external splice : Unix.file_descr -> Unix.file_descr -> int -> int
                   = "stub_splice"

external tee : Unix.file_descr -> Unix.file_descr -> int -> int
                   = "stub_tee"
