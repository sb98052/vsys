all: vsys

include .dep

.SUFFIXES: .ml .cmo
.SUFFIXES: .mli .cmi
.SUFFIXES: .ml .cmx
.SUFFIXES: .mll .ml
.SUFFIXES: .mly .ml

.ml.cmo:
	ocamlc -g -c $(INCLUDEDIR) $<

.mli.cmi:
	ocamlopt -c $<

.ml.cmx: 
	ocamlopt $(CFLAGS) -c $(INCLUDEDIR) $<

.mly.ml: 
	ocamlyacc $< 

.mll.ml:
	ocamllex $< 

vsys: inotify.cmxa inotify.cmi globals.cmx fdwatcher.cmx dirwatcher.cmx fifowatcher.cmx frontend.cmx backend.cmx main.cmx
	ocamlopt str.cmxa unix.cmxa inotify.cmxa globals.cmx fdwatcher.cmx dirwatcher.cmx fifowatcher.cmx frontend.cmx backend.cmx str.cmxa main.cmx -o vsys

vsys.b: inotify.cma inotify.cmi globals.cmo fdwatcher.cmo dirwatcher.cmo fifowatcher.cmo frontend.cmo backend.cmo main.cmo
	ocamlc -g str.cmxa unix.cma inotify.cma globals.cmo fdwatcher.cmo dirwatcher.cmo fifowatcher.cmo frontend.cmo backend.cmo str.cma main.cmo -o vsys.b

dep:
	ocamldep *.ml > .dep

clean:
	rm -fR *.cmi *.cmx sys usys 
