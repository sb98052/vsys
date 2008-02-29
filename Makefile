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

docs: *.ml
	ocamldoc -d . -html -o docs *.ml
	mv *.html *.css docs

ocaml_inotify-0.4/inotify.cmxa:
	$(MAKE) -C ocaml_inotify-0.4 && cp -f ocaml_inotify-0.4/inotify_stubs.o ./

vsys: ocaml_inotify-0.4/inotify.cmxa globals.cmx fdwatcher.cmx conffile.cmx dirwatcher.cmx fifowatcher.cmx frontend.cmx backend.cmx main.cmx docs
	ocamlopt -I ocaml_inotify-0.4 str.cmxa unix.cmxa inotify.cmxa globals.cmx fdwatcher.cmx dirwatcher.cmx fifowatcher.cmx frontend.cmx backend.cmx str.cmxa conffile.cmx main.cmx -o vsys

vsys.b: ocaml_inotify-0.4/inotify.cma inotify.cmi globals.ml fdwatcher.ml dirwatcher.ml fifowatcher.ml frontend.ml backend.ml main.ml
	ocamlc -g str.cma unix.cma ocaml_inotify-0.4/inotify.cma globals.cmo fdwatcher.cmo dirwatcher.cmo fifowatcher.cmo frontend.cmo backend.cmo str.cma conffile.cmo main.cmo -o vsys.b

install: vsys
	cp vsys $(INSTALL_DIR)/usr/bin
	cp vsys-initscript $(INSTALL_DIR)/etc/init.d/vsys 

dep:
	ocamldep *.ml > .dep

clean:
	$(MAKE) -C ocaml_inotify-0.4 clean
	rm -f *.cmi *.cmx sys usys *.o vsys vsys.b *.html *.css 
