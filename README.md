# parser-scanner
rm -f parser.tab.c parser.tab.h lex.yy.c compiler

bison -d parser.y

flex scanner.l

gcc -o compiler parser.tab.c lex.yy.c ast.c symbol_table.c three_address_code.c -lfl

./compiler < input_test.txt

