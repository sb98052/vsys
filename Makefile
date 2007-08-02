all: vsys vsyssh ocaml_inotify-0.4

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

docs: *.ml
	ocamldoc -d . -html -o docs *.ml
	mv *.html docs

vsys: inotify.cmxa inotify.cmi globals.cmx fdwatcher.cmx dirwatcher.cmx fifowatcher.cmx frontend.cmx backend.cmx main.cmx docs
	ocamlopt str.cmxa unix.cmxa inotify.cmxa globals.cmx fdwatcher.cmx dirwatcher.cmx fifowatcher.cmx frontend.cmx backend.cmx str.cmxa main.cmx -o vsys

vsys.b: inotify.cma inotify.cmi globals.ml fdwatcher.ml dirwatcher.ml fifowatcher.ml frontend.ml backend.ml main.ml
	ocamlc -g str.cma unix.cma inotify.cma globals.cmo fdwatcher.cmo dirwatcher.cmo fifowatcher.cmo frontend.cmo backend.cmo str.cma main.cmo -o vsys.b

install: vsys
	cp vsys /usr/bin
	cp vsys.b /usr/bin
	cp vsys-initscript /etc/init.d/vsys 

dep:
	ocamldep *.ml > .dep

clean:
	rm -fR *.cmi *.cmx sys usys 
