CC=gcc
CFLAGS=-g -O2

SCRIPT_LIST:=$(shell cat ADD_YOUR_SCRIPT_TO_THIS_FILE_OR_ELSE_IT_WONT_GET_DEPLOYED | sed 's/\n/ /g')

all: dcookie
	touch .done
	cp $(SCRIPT_LIST) exec


clean: 
	rm -f exec/*
