%{
    #include "symbol_table.h"
    #include "ast.h"
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <ctype.h>

    AST* make_node(char* name, int count, ...);
    void print_ast(AST* node, int indent);
    void yyerror(const char* s);
    int yylex();
    int yydebug = 1;

    int has_params(AST* params) {
        if (!params) return 0;
        if (strcmp(params->name, "PARS") == 0 && 
            params->child_count > 0 && 
            strcmp(params->children[0]->name, "NONE") == 0)
            return 0;
        return 1; // יש לפחות פרמטר אחד
    }

%}

%union {
    struct ast_node* ast ;
    char* sval;
}

%start program
%left PLUS MINUS
%left MULT DIV
%left EQ NE GT GE LT LE

%token <sval> ID CHAR_LITERAL STRING_LITERAL NUM REAL
%token <sval> TYPE_INT TYPE_CHAR TYPE_REAL TYPE_BOOL TYPE_STRING TYPE_INT_PTR TYPE_CHAR_PTR TYPE_REAL_PTR

%token DEF T_BEGIN T_END IF ELSE ELIF WHILE FOR DO CALL RETURN RETURNS VAR NULLPTR 
%token TRUE FALSE AND OR NOT

%token EQ NE GT GE LT LE ASSIGN
%token PLUS MINUS MULT DIV ADDRESS

%token COLON SEMICOLON COMMA LPAREN RPAREN LBRACK RBRACK BAR

%type <ast> program function function_list param_list param_list_item param_list_item_list elif_list call_list var_decl_list var_assign_list
%type <ast> type stmt_list stmt assignment expr if_stmt block return_stmt while_stmt do_while_stmt for_stmt var_stmt call_args void_call assignment_call var_assign var_decl id

%%

program:
    function_list {
        printf("ENTERED: program -> function_list\n");
        if (!check_main_signature()) {
            // השגיאה כבר מודפסת בפונקציה
            YYABORT;
        }
        print_ast($1, 0);
    }
    | error {
        yyerror("Could not parse input");
    }
;

function_list:
    function_list function { $$ = make_node("CODE", 2, $1, $2); }
  | function { $$ = make_node("CODE", 1, $1); }
;

function:
 /* WITH params AND RETURNS */
DEF ID LPAREN param_list RPAREN COLON RETURNS type T_BEGIN {
    begin_function_scope(); // פתח סקופ פונקציה
} stmt_list T_END {
    printf("MATCHED: function WITH RETURNS\n");
    $$ = make_node("FUNC", 4,
                  make_node($2, 0),
                  $4,
                  make_node("RET", 1, $8),
                  make_node("BODY", 1, $11)); // שים לב שזה $11 ולא $10
                   
    if (!insert_function($2, $8->name, NULL, 1, $11)) { // כאן גם
        YYABORT;
    }
    
    end_scope(); // סגור סקופ
    reset_function_scope(); // איפוס הסקופ בין פונקציות
}

/* WITHOUT params BUT WITH RETURNS */
| DEF ID LPAREN RPAREN COLON RETURNS type T_BEGIN {
    begin_function_scope(); // פתח סקופ פונקציה
} stmt_list T_END {
    printf("MATCHED: function WITH RETURNS (empty params)\n");
    $$ = make_node("FUNC", 4,
                  make_node($2, 0),
                  make_node("PARS", 1, make_node("NONE", 0)),
                  make_node("RET", 1, $7),
                  make_node("BODY", 1, $10)); // $10 כאן
                   
    if (!insert_function($2, $7->name, NULL, 0, $10)) {
        YYABORT;
    }
    
    end_scope(); // סגור סקופ
    reset_function_scope(); // איפוס הסקופ בין פונקציות
}

/* WITH params BUT WITHOUT RETURNS */
| DEF ID LPAREN param_list RPAREN COLON T_BEGIN {
    begin_function_scope(); // פתח סקופ פונקציה
} stmt_list T_END {
    printf("MATCHED: function WITHOUT RETURNS\n");
    int param_count = has_params($4);
    $$ = make_node("FUNC", 4,
                  make_node($2, 0),
                  $4,
                  make_node("RET", 1, make_node("NONE", 0)),
                  make_node("BODY", 1, $9)); // $9 כאן
                   
    if (!insert_function($2, "NONE", NULL, param_count, $9)) {
        YYABORT;
    }
    
    end_scope(); // סגור סקופ
    reset_function_scope(); // איפוס הסקופ בין פונקציות
}

/* WITHOUT params AND WITHOUT RETURNS */
| DEF ID LPAREN RPAREN COLON T_BEGIN {
    begin_function_scope(); // פתח סקופ פונקציה
} stmt_list T_END {
    printf("MATCHED: function WITHOUT RETURNS (empty params)\n");
    $$ = make_node("FUNC", 4,
                  make_node($2, 0),
                  make_node("PARS", 1, make_node("NONE", 0)),
                  make_node("RET", 1, make_node("NONE", 0)),
                  make_node("BODY", 1, $8)); // $8 כאן
                   
    if (!insert_function($2, "NONE", NULL, 0, $8)) {
        YYABORT;
    }
    
    end_scope(); // סגור סקופ
    reset_function_scope(); // איפוס הסקופ בין פונקציות
}
;

param_list:
    param_list_item_list { $$ = make_node("PARS", 1, $1); }
;

param_list_item_list:
    param_list_item_list SEMICOLON param_list_item {
        printf("matched param_list_item_list SEMI\\n");
        $$ = make_node("PLIST", 2, $1, $3);
    }
  | param_list_item {
        printf("matched param_list_item_list BASE\\n");
        $$ = $1;
    }
;

param_list_item:
    ID type COLON ID {
        printf("param_list_item matched: %s : %s\n", $1, $4);
        $$ = make_node("par", 3, make_node($1, 0), make_node($2->name, 0), make_node($4, 0));
    }
;

type:
    TYPE_INT   { $$ = make_node($1, 0); }
  | TYPE_CHAR  { $$ = make_node($1, 0); }
  | TYPE_REAL  { $$ = make_node($1, 0); }
  | TYPE_BOOL  { $$ = make_node($1, 0); }
  | TYPE_STRING { $$ = make_node($1, 0); }
  | TYPE_INT_PTR { $$ = make_node($1, 0); }
  | TYPE_CHAR_PTR { $$ = make_node($1, 0); }
  | TYPE_REAL_PTR { $$ = make_node($1, 0); }
;

stmt_list:
    stmt_list stmt { $$ = make_node("STMTLIST", 2, $1, $2); }
  | stmt { $$ = $1; }
;

stmt:
    assignment { printf("DEBUG: matched stmt -> assignment\n"); $$ = $1; }
  | if_stmt    { printf("DEBUG: matched stmt -> if_stmt\n"); $$ = $1; }
  | return_stmt { printf("DEBUG: matched stmt -> return_stmt\n"); $$ = $1; }
  | while_stmt {printf("DEBUG: matched stmt -> while_stmt\n"); $$ = $1; }
  | do_while_stmt {printf("DEBUG: matched stmt -> do_while_stmt\n"); $$ = $1; }
  | for_stmt {printf("DEBUG: matched stmt -> for_stmt\n"); $$ = $1; }
  | call_args {printf("DEBUG: matched stmt -> call_args\n"); $$ = $1; }
  | var_stmt {printf("DEBUG: matched stmt -> var_stmt\n"); $$ = $1; }
  | assignment_call {printf("DEBUG: matched stmt -> assignment_call\n"); $$ = $1; }
  | void_call {printf("DEBUG: matched stmt -> void_call\n"); $$ = $1; }
  | function {printf("DEBUG: matched stmt -> function\n"); $$ = $1; }
;

assignment:
    ID ASSIGN expr SEMICOLON
    {
        if (!check_variable_usage($1)) {
            YYABORT;
        }
        printf("DEBUG: matched assignment: %s = ...\n", $1);
        $$ = make_node("=", 2, make_node($1, 0), $3);
    }
;


var_stmt:
    VAR var_decl_list {
        printf("DEBUG: Starting var_stmt\n");
        insert_var_decl_list($2);
        $$ = make_node("VAR-DECLS", 1, $2);
    }
;


var_decl_list:
    var_decl_list var_decl {
        printf("DEBUG: var_decl_list with 2 items\n");
        $$ = make_node("VARLIST", 2, $1, $2);
    }
  | var_decl {
        printf("DEBUG: var_decl_list with 1 item\n");
        $$ = $1;
    }
;

var_decl:
    TYPE_INT COLON ID COLON expr SEMICOLON {
        printf("DEBUG: in var_decl - TYPE_INT for variable '%s'\n", $3);
        if (!insert_variable($3, "int")) {
            yyerror("Semantic Error: Variable already declared");
            YYABORT;
        }
        $$ = make_node("DECL", 2, make_node($3, 0), $5);
    }
    | TYPE_REAL COLON ID COLON expr SEMICOLON {
        printf("DEBUG: in var_decl - TYPE_REAL for variable '%s'\n", $3);
        if (!insert_variable($3, "real")) {
            yyerror("Semantic Error: Variable already declared");
            YYABORT;
        }
        $$ = make_node("DECL", 2, make_node($3, 0), $5);
    }
    | TYPE_CHAR COLON ID COLON expr SEMICOLON {
        printf("DEBUG: in var_decl - TYPE_CHAR for variable '%s'\n", $3);
        if (!insert_variable($3, "char")) {
            yyerror("Semantic Error: Variable already declared");
            YYABORT;
        }
        $$ = make_node("DECL", 2, make_node($3, 0), $5);
    }
    | TYPE_BOOL COLON ID COLON expr SEMICOLON {
        printf("DEBUG: in var_decl - TYPE_BOOL for variable '%s'\n", $3);
        if (!insert_variable($3, "bool")) {
            yyerror("Semantic Error: Variable already declared");
            YYABORT;
        }
        $$ = make_node("DECL", 2, make_node($3, 0), $5);
    }
    | TYPE_STRING COLON ID COLON STRING_LITERAL SEMICOLON {
        printf("DEBUG: in var_decl - TYPE_STRING for variable '%s'\n", $3);
        if (!insert_variable($3, "string")) {
            yyerror("Semantic Error: Variable already declared");
            YYABORT;
        }
        $$ = make_node("DECL", 2, make_node($3, 0), make_node($5, 0));
    }
;

var_assign_list:
    var_assign_list COMMA var_assign {
        printf("DEBUG: var_assign_list with comma\n");
        $$ = make_node("VAR-ASSIGN-LIST", 2, $1, $3);
    }
  | var_assign {
        printf("DEBUG: var_assign_list single item\n");
        $$ = $1;
    }
;

var_assign:
    ID COLON expr {
        printf("DEBUG: var_assign for ID '%s'\n", $1);
        $$ = make_node("ASSIGN", 2, make_node($1, 0), $3);
    }
;
return_stmt:
    RETURN expr SEMICOLON { $$ = make_node("RET", 1, $2); }
;

if_stmt:
    IF expr COLON block ELSE COLON block
    {
        $$ = make_node("IF-ELSE", 3, $2, $4, $7);
    }
    | IF expr COLON block
    {
        $$ = make_node("IF", 2, $2, $4);
    }
    | IF expr COLON stmt
    {
        $$ = make_node("IF",2,$2,$4);
    }
    | IF expr COLON stmt ELSE COLON stmt
    {
        $$ = make_node("IF-ELSE",3,$2,$4,$7);
    }
    |IF expr COLON block elif_list ELSE COLON block
    {
        $$ = make_node("IF-ELIF_ELSE",4,$2,$4,$5,$8);
    }            
;
elif_list:
    ELIF expr COLON block
    {
        $$ = make_node("ELIF",2,$2,$4);
    }
    |elif_list ELIF expr COLON block 
    {
       $$ = make_node("ELIF-elif",3,$1,make_node("elif",2,$3,$5));
    }
;

while_stmt:
    WHILE COLON expr SEMICOLON 
    {
        $$ = make_node("while",1,$3);
    }
    |WHILE expr COLON block 
    {
        $$ = make_node("while",2,$2,$4);
    } 
    |WHILE expr COLON stmt
    {
        $$ = make_node("while",2,$2,$4);
    }  
;

void_call:
    CALL ID LPAREN call_args RPAREN SEMICOLON {
        // בדיקת הפונקציה כולל פרמטרים
        int arg_count;
        char** arg_types = get_call_arg_types($4, &arg_count);
        
        if (!check_function_call($2, arg_types, arg_count)) {
            // שחרור הזכרון
            for (int i = 0; i < arg_count; i++) {
                free(arg_types[i]);
            }
            free(arg_types);
            YYABORT;
        }
        
        // שחרור הזכרון
        for (int i = 0; i < arg_count; i++) {
            free(arg_types[i]);
        }
        free(arg_types);
        
        $$ = make_node("CALL", 2, make_node($2, 0), $4);
    }
;

do_while_stmt:
    DO COLON block while_stmt
    {
        $$= make_node("do_while",1,$3,make_node("while",1,$4));
    }
;

for_stmt:
    FOR LPAREN assignment expr SEMICOLON expr RPAREN COLON stmt
    {
        $$ = make_node("FOR",4,$3,$4,$6,$9);
    }
    | FOR LPAREN assignment expr SEMICOLON expr RPAREN COLON block
    {
        $$ = make_node("FOR",4,$3,$4,$6,$9);
    }
;

assignment_call:
    ID ASSIGN CALL ID LPAREN call_args RPAREN SEMICOLON {
        // בדוק שהמשתנה מוכרז
        if (!check_variable_usage($1)) {
            YYABORT;
        }
        
        // בדיקת הפונקציה כולל פרמטרים
        int arg_count;
        char** arg_types = get_call_arg_types($6, &arg_count);
        
        if (!check_function_call($4, arg_types, arg_count)) {
            // שחרור הזכרון
            for (int i = 0; i < arg_count; i++) {
                free(arg_types[i]);
            }
            free(arg_types);
            YYABORT;
        }
        
        // שחרור הזכרון
        for (int i = 0; i < arg_count; i++) {
            free(arg_types[i]);
        }
        free(arg_types);
        
        $$ = make_node("ASSIGN-CALL", 2,
                      make_node($1, 0),
                      make_node("CALL", 2, make_node($4, 0), $6));
    }
;

call_args:
    call_list { $$ = $1; }
    | /* empty */ {
        $$ = make_node("par", 1, make_node("NONE", 0)); 
    }
;

call_list:
    expr { $$ = $1; }
  | call_list COMMA expr { $$ = make_node("par", 2, $1, $3); }
;

block:
    T_BEGIN stmt_list T_END { 
        begin_scope();
        $$ = make_node("BLOCK", 1, $2);
        end_scope();
    }
;

id:
    ID {
        // בדוק שהמשתנה מוכרז
        if (!check_variable_usage($1)) {
            YYABORT;
        }
        $$ = make_node($1, 0);
    }
;

expr:
    expr PLUS expr   { $$ = make_node("+", 2, $1, $3); }
  | expr MINUS expr  { $$ = make_node("-", 2, $1, $3); }
  | expr MULT expr   { $$ = make_node("*", 2, $1, $3); }
  | expr DIV expr    { $$ = make_node("/", 2, $1, $3); }
  | expr EQ expr     { $$ = make_node("==", 2, $1, $3); }
  | expr NE expr     { $$ = make_node("!=", 2, $1, $3); }
  | expr LT expr     { $$ = make_node("<", 2, $1, $3); }
  | expr GT expr     { $$ = make_node(">", 2, $1, $3); }
  | expr LE expr     { $$ = make_node("<=", 2, $1, $3); }
  | expr GE expr     { $$ = make_node(">=", 2, $1, $3); }
  | expr AND expr    { $$ = make_node("AND", 2, $1, $3); }
  | expr OR expr     { $$ = make_node("OR", 2, $1, $3); }
  | NOT expr         { $$ = make_node("NOT", 1, $2); }
  | LPAREN expr RPAREN { $$ = $2; }
  | LBRACK expr RBRACK   { $$ = $2; }
  | REAL { $$ = make_node($1, 0); }
  | NUM             { $$ = make_node($1, 0); }
  | id              { $$ = $1; }  // שינוי: שימוש בכלל id במקום ID
  | CHAR_LITERAL    { $$ = make_node($1, 0); }
  | STRING_LITERAL  { $$ = make_node($1,0); }
  | NULLPTR         { $$ = make_node("nullptr",0);}
  | TRUE            { $$ = make_node("TRUE",0);}
  | FALSE           { $$ = make_node("FALSE",0);}
  | CALL ID LPAREN call_args RPAREN { 
        // בדיקת הפונקציה כולל פרמטרים
        int arg_count;
        char** arg_types = get_call_arg_types($4, &arg_count);
        
        if (!check_function_call($2, arg_types, arg_count)) {
            // שחרור הזכרון
            for (int i = 0; i < arg_count; i++) {
                free(arg_types[i]);
            }
            free(arg_types);
            YYABORT;
        }
        
        // שחרור הזכרון
        for (int i = 0; i < arg_count; i++) {
            free(arg_types[i]);
        }
        free(arg_types);
        
        $$ = make_node("calll", 2, make_node($2, 0), $4);
    }
;

%%
void yyerror(const char* s) {
    fprintf(stderr, "Syntax Error: %s\n", s);
}

int main() {
    printf("DEBUG: Initializing symbol table\n");
    init_symbol_table(); 
    return yyparse();
}