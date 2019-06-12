CC = gcc -g
YFLAG = -d
FNAME = compiler_hw3
PARSER = myparser
OBJECT = lex.yy.c y.tab.c y.tab.h ${FNAME}.j ${FNAME}.class

all: scanner parser
	@${CC} -o ${PARSER} lex.yy.c y.tab.c

scanner:
	@lex ${FNAME}.l

parser:
	@yacc ${YFLAG} ${FNAME}.y

test:
	@./${PARSER} < ./mytest.c
	@echo -e "\n\033[1;33mmain.class output\033[0m"
	@java -jar jasmin.jar ${FNAME}.j
	@java ${FNAME} 

clean:
	rm -f *.o ${PARSER} ${OBJECT} y.output
