%{
    #include "parser.tab.h"
    #include "ast.h"
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
%}

DIGIT [0-9]
ID [a-zA-Z_][a-zA-Z0-9_]*
CHAR_LIT \'(\\.|[^\\'])\'
STRING_LIT \"(\\\\.|[^\\\"])*\"
HEX_NUM 0[xX][0-9a-fA-F]+
REAL_NUM [-+]?([0-9]*[.])?[0-9]+([eE][-+]?[0-9]+)?
INT_NUM [1-9][0-9]*|0

%%

"def"        { printf("[DEF] "); return DEF; }
"begin"      { printf("[T_BEGIN] "); return T_BEGIN; }
"end"        { printf("[T_END] "); return T_END; }
"if"         { printf("[IF] "); return IF; }
"elif"       { printf("[ELIF] "); return ELIF; }
"else"       { printf("[ELSE] "); return ELSE; }
"while"      { printf("[WHILE] "); return WHILE; }
"for"        { printf("[FOR] "); return FOR; }
"do"         { printf("[DO] "); return DO; }
"true"       { printf("[TRUE] "); return TRUE; }
"false"      { printf("[FALSE] "); return FALSE; }
"and"        { printf("[AND] "); return AND; }
"or"         { printf("[OR] "); return OR; }
"not"        { printf("[NOT] "); return NOT; }
"call"       { printf("[CALL] "); return CALL; }
"var"        { printf("[VAR] "); return VAR; }
"null"       { printf("[NULLPTR] "); return NULLPTR; }
"return"     { printf("[RETURN] "); return RETURN; }
"returns"    { printf("[RETURNS] "); return RETURNS; }



"int"        { printf("[TYPE_INT] "); yylval.sval = strdup(yytext); return TYPE_INT; }
"real"       { printf("[TYPE_REAL] "); yylval.sval = strdup(yytext); return TYPE_REAL; }
"char"       { printf("[TYPE_CHAR] "); yylval.sval = strdup(yytext); return TYPE_CHAR; }
"bool"       { printf("[TYPE_BOOL] "); yylval.sval = strdup(yytext); return TYPE_BOOL; }
"string"     { printf("[TYPE_STRING] "); yylval.sval = strdup(yytext); return TYPE_STRING; }

":"          { printf("[COLON] "); return COLON; }
";"          { printf("[SEMICOLON] "); return SEMICOLON; }
","          { printf("[COMMA] "); return COMMA; }
"("          { printf("[LPAREN] "); return LPAREN; }
")"          { printf("[RPAREN] "); return RPAREN; }
"["          { printf("[LBRACK] "); return LBRACK; }
"]"          { printf("[RBRACK] "); return RBRACK; }
"|"          { printf("[BAR] "); return BAR; }

"=="         { return EQ; }
"!="         { return NE; }
">="         { return GE; }
"<="         { return LE; }
">"          { return GT; }
"<"          { return LT; }
"="          { return ASSIGN; }
"+"          { return PLUS; }
"-"          { return MINUS; }
"*"          { return MULT; }
"/"          { return DIV; }
"&"          { return ADDRESS; }

{CHAR_LIT}       { printf("[CHAR:%s] ", yytext); yylval.sval = strdup(yytext); return CHAR_LITERAL; }
{STRING_LIT}     { printf("[STRING:%s] ", yytext); yylval.sval = strdup(yytext); return STRING_LITERAL; }
{HEX_NUM}        { printf("[HEX:%s] ", yytext); yylval.sval = strdup(yytext); return NUM; }
{REAL_NUM}       { printf("[REAL:%s] ", yytext); yylval.sval = strdup(yytext); return NUM; }
{INT_NUM}        { printf("[NUM:%s] ", yytext); yylval.sval = strdup(yytext); return NUM; }

[ \t\r\n]+       { /* דילוג על רווחים */ }

{ID}             { printf("[ID:%s] ", yytext); yylval.sval = strdup(yytext); return ID; }

.                { printf("[UNKNOWN:%s]\n", yytext); }

%%

int yywrap() {
    return 1;
}


