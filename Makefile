CC=g++
FR=flex_rules
BG=grammar
PROG=Micro

.PHONY: all compiler scanner parser build clean

all: group compiler

group: 
	@echo "David Zawicki dzawicki"

compiler: parser scanner build organize

scanner: ./src/$(FR).l
	flex ./src/$(FR).l

parser: ./src/$(BG).y
	bison -d ./src/$(BG).y

build:
	$(CC) $(BG).tab.c lex.yy.c -lfl -o $(PROG)

organize:
	mkdir -p generated
	mv lex.yy.c ./generated/lex.yy.c
	mv $(BG).tab.c ./generated/$(BG).tab.c
	mv $(BG).tab.h ./generated/$(BG).tab.h

clean:
	rm -f ./Micro
	rm -f -r ./generated
