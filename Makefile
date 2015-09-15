CC=gcc
FR=flex_rules.lex
PROG=Micro

.PHONY: all compiler scanner clean

all: group compiler

group: 
	@echo "David Zawicki dzawicki"

compiler: scanner

scanner: ./src/$(FR)
	flex ./src/$(FR)
	mkdir generated
	mv lex.yy.c ./generated/lex.yy.c
	mkdir build
	$(CC) ./generated/lex.yy.c -lfl -o ./build/$(PROG) 

clean:
	rm -f -r ./build
	rm -f -r ./generated
