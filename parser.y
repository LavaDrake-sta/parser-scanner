%{
    #include "symbol_table.h"
    #include "ast.h"
    #include "code_generator.h"
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <ctype.h>

    AST* make_node(char* name, int count, ...);
    void print_ast(AST* node, int indent);
    void yyerror(const char* s);
    extern FuncEntry* get_function_by_name(const char* name);
    extern char current_function_name[256];
    int yylex();
    int yydebug = 1;
    AST* program_ast = NULL; 


int has_params(AST* params) {

    if (!params) return 0;
    if (strcmp(params->name, "PARS") == 0 && 
        params->child_count > 0 && 
        strcmp(params->children[0]->name, "NONE") == 0)
        return 0;

    if (strcmp(params->name, "PARS") == 0 && 
        params->child_count > 0) {
        
        AST* child = params->children[0];
        if (strcmp(child->name, "PLIST") == 0) {
            int count = 1;
            while (strcmp(child->name, "PLIST") == 0 && child->child_count == 2) {
                count++;
                child = child->children[0];
            }
            return count;
        }
        return 1; 
    }
    
    return 1; 
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
            YYABORT;
        }
        
        program_ast = $1;
        
        printf("\n=== AST Structure ===\n");
        print_ast($1, 0);
        printf("=== End of AST ===\n");
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
    if (strcmp($8->name, "string") == 0) {
        fprintf(stderr, "Semantic Error: Function '%s' cannot have string as return type\n", $2);
        YYABORT;
    }
    
    begin_function_scope($2);
} stmt_list T_END {
    printf("MATCHED: function WITH RETURNS\n");
    $$ = make_node("FUNC", 4,
        make_node($2, 0),
        $4,
        make_node("RET", 1, $8),
        make_node("BODY", 1, $11));
    
    int param_count = has_params($4);
    if (!insert_function($2, $8->name, NULL, param_count, $11)) {
        YYABORT;
    }
    end_scope();
    reset_function_scope();
}

/* WITHOUT params BUT WITH RETURNS */
| DEF ID LPAREN RPAREN COLON RETURNS type T_BEGIN {
    if (strcmp($7->name, "string") == 0) {
        fprintf(stderr, "Semantic Error: Function '%s' cannot have string as return type\n", $2);
        YYABORT;
    }
    
    begin_function_scope($2);
} stmt_list T_END {
    printf("MATCHED: function WITH RETURNS (empty params)\n");
    $$ = make_node("FUNC", 4,
        make_node($2, 0),
        make_node("PARS", 1, make_node("NONE", 0)),
        make_node("RET", 1, $7),
        make_node("BODY", 1, $10));
    
    if (!insert_function($2, $7->name, NULL, 0, $10)) {
        YYABORT;
    }
    end_scope();
    reset_function_scope();
}
/* WITH params BUT WITHOUT RETURNS */
| DEF ID LPAREN param_list RPAREN COLON T_BEGIN {
    begin_function_scope($2);
} stmt_list T_END {
    printf("MATCHED: function WITHOUT RETURNS\n");
    int param_count = has_params($4);
    $$ = make_node("FUNC", 4,
        make_node($2, 0),
        $4,
        make_node("RET", 1, make_node("NONE", 0)),
        make_node("BODY", 1, $9));
    
    if (!insert_function($2, "NONE", NULL, param_count, $9)) {
        YYABORT;
    }
    end_scope();
    reset_function_scope();
}
/* WITHOUT params AND WITHOUT RETURNS */
| DEF ID LPAREN RPAREN COLON T_BEGIN {
    begin_function_scope($2);
} stmt_list T_END {
    printf("MATCHED: function WITHOUT RETURNS (empty params)\n");
    $$ = make_node("FUNC", 4,
        make_node($2, 0),
        make_node("PARS", 1, make_node("NONE", 0)),
        make_node("RET", 1, make_node("NONE", 0)),
        make_node("BODY", 1, $8));
    
    if (!insert_function($2, "NONE", NULL, 0, $8)) {
        YYABORT;
    }
    end_scope();
    reset_function_scope();
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
        
        if (!insert_variable($1, $2->name)) {
            yyerror("Semantic Error: Parameter already declared");
            YYABORT;
        }
        
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
    | ID LBRACK expr RBRACK ASSIGN expr SEMICOLON
    {
        if (!check_variable_usage($1)) {
            YYABORT;
        }
        char* var_type = get_variable_type($1);
        if (strcmp(var_type, "string") != 0) {
            fprintf(stderr, "Semantic Error: Array indexing operator [] can only be used with string type, got %s\n", var_type);
            YYABORT;
        }
        char* index_type = get_expr_type($3);
        if (strcmp(index_type, "int") != 0) {
            fprintf(stderr, "Semantic Error: Array index must be of type int, got %s\n", index_type);
            YYABORT;
        }
        char* value_type = get_expr_type($6);
        if (strcmp(value_type, "char") != 0) {
            fprintf(stderr, "Semantic Error: String cell can only store characters, cannot assign %s\n", value_type);
            YYABORT;
        }
        printf("DEBUG: matched string index assignment: %s[...] = ...\n", $1);
        $$ = make_node("INDEX_ASSIGN", 3, make_node($1, 0), $3, $6);
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
    RETURN expr SEMICOLON
    {
        char* return_type = get_expr_type($2);
        char* declared_return_type = NULL;
        FuncEntry* func = get_function_by_name(current_function_name);
        if (func) {
            declared_return_type = func->return_type;
        }
        if (declared_return_type && strcmp(declared_return_type, "NONE") != 0) {
            if (strcmp(declared_return_type, return_type) != 0) {
                fprintf(stderr, "Semantic Error: Return type '%s' does not match function declaration '%s' in function '%s'\n",
                        return_type, declared_return_type, current_function_name);
                YYABORT;
            }
        }
        $$ = make_node("RET", 1, $2);
    }
;

if_stmt:
    IF expr COLON block ELSE COLON block
    {
        char* cond_type = get_expr_type($2);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in if statement must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("IF-ELSE", 3, $2, $4, $7);
    }
    | IF expr COLON block
    {
        char* cond_type = get_expr_type($2);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in if statement must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("IF", 2, $2, $4);
    }
    | IF expr COLON stmt
    {
        char* cond_type = get_expr_type($2);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in if statement must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("IF", 2, $2, $4);
    }
    | IF expr COLON stmt ELSE COLON stmt
    {
        char* cond_type = get_expr_type($2);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in if statement must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("IF-ELSE", 3, $2, $4, $7);
    }
    | IF expr COLON block elif_list ELSE COLON block
    {
        char* cond_type = get_expr_type($2);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in if statement must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("IF-ELIF_ELSE", 4, $2, $4, $5, $8);
    }
;

elif_list:
    ELIF expr COLON block
    {
        char* cond_type = get_expr_type($2);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in elif statement must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("ELIF", 2, $2, $4);
    }
    | elif_list ELIF expr COLON block
    {
        char* cond_type = get_expr_type($3);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in elif statement must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("ELIF-elif", 3, $1, make_node("elif", 2, $3, $5));
    }
;

while_stmt:
    WHILE COLON expr SEMICOLON
    {
        char* cond_type = get_expr_type($3);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in while loop must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("while", 1, $3);
    }
    | WHILE expr COLON block
    {
        char* cond_type = get_expr_type($2);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in while loop must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("while", 2, $2, $4);
    }
    | WHILE expr COLON stmt
    {
        char* cond_type = get_expr_type($2);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in while loop must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("while", 2, $2, $4);
    }
;

void_call:
    CALL ID LPAREN call_args RPAREN SEMICOLON {
        int arg_count;
        char** arg_types = get_call_arg_types($4, &arg_count);
        
        if (!check_function_call($2, arg_types, arg_count)) {
            for (int i = 0; i < arg_count; i++) {
                free(arg_types[i]);
            }
            free(arg_types);
            YYABORT;
        }
        
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
        char* cond_type = get_expr_type($4);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in for loop must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("FOR", 4, $3, $4, $6, $9);
    }
    | FOR LPAREN assignment expr SEMICOLON expr RPAREN COLON block
    {
        char* cond_type = get_expr_type($4);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in for loop must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("FOR", 4, $3, $4, $6, $9);
    }
;

assignment_call:
    ID ASSIGN CALL ID LPAREN call_args RPAREN SEMICOLON {
        if (!check_variable_usage($1)) {
            YYABORT;
        }
        
        int arg_count;
        char** arg_types = get_call_arg_types($6, &arg_count);
        
        if (!check_function_call($4, arg_types, arg_count)) {
            for (int i = 0; i < arg_count; i++) {
                free(arg_types[i]);
            }
            free(arg_types);
            YYABORT;
        }
        
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
        if (!check_variable_usage($1)) {
            YYABORT;
        }
        $$ = make_node($1, 0);
    }
;

expr:
expr PLUS expr 
    {
        char* left_type = get_expr_type($1);
        char* right_type = get_expr_type($3);
        
        if ((strcmp(left_type, "int") != 0 && strcmp(left_type, "real") != 0) ||
            (strcmp(right_type, "int") != 0 && strcmp(right_type, "real") != 0)) {
            fprintf(stderr, "Semantic Error: Arithmetic operator '+' requires int or real operands\n");
            YYABORT;
        }
        
        $$ = make_node("+", 2, $1, $3);
    }
| expr MINUS expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($3);
    
    if ((strcmp(left_type, "int") != 0 && strcmp(left_type, "real") != 0) ||
        (strcmp(right_type, "int") != 0 && strcmp(right_type, "real") != 0)) {
        fprintf(stderr, "Semantic Error: Arithmetic operator '-' requires int or real operands, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node("-", 2, $1, $3);
  }
| expr MULT expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($3);
    
    if ((strcmp(left_type, "int") != 0 && strcmp(left_type, "real") != 0) ||
        (strcmp(right_type, "int") != 0 && strcmp(right_type, "real") != 0)) {
        fprintf(stderr, "Semantic Error: Arithmetic operator '*' requires int or real operands, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node("*", 2, $1, $3);
  }
| expr DIV expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($3);
    
    if ((strcmp(left_type, "int") != 0 && strcmp(left_type, "real") != 0) ||
        (strcmp(right_type, "int") != 0 && strcmp(right_type, "real") != 0)) {
        fprintf(stderr, "Semantic Error: Arithmetic operator '/' requires int or real operands, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node("/", 2, $1, $3);
  }
| expr EQ expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($3);
    
    if (strcmp(left_type, right_type) != 0) {
        fprintf(stderr, "Semantic Error: Equality operator '==' requires operands of the same type, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node("==", 2, $1, $3);
  }
| expr NE expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($3);
    
    if (strcmp(left_type, right_type) != 0) {
        fprintf(stderr, "Semantic Error: Inequality operator '!=' requires operands of the same type, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node("!=", 2, $1, $3);
  }
| expr LT expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($3);
    
    if ((strcmp(left_type, "int") != 0 && strcmp(left_type, "real") != 0) ||
        (strcmp(right_type, "int") != 0 && strcmp(right_type, "real") != 0)) {
        fprintf(stderr, "Semantic Error: Comparison operator '<' requires numeric operands, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node("<", 2, $1, $3);
  }
| expr GT expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($3);
    
    if ((strcmp(left_type, "int") != 0 && strcmp(left_type, "real") != 0) ||
        (strcmp(right_type, "int") != 0 && strcmp(right_type, "real") != 0)) {
        fprintf(stderr, "Semantic Error: Comparison operator '>' requires numeric operands, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node(">", 2, $1, $3);
  }
| expr LE expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($3);
    
    if ((strcmp(left_type, "int") != 0 && strcmp(left_type, "real") != 0) ||
        (strcmp(right_type, "int") != 0 && strcmp(right_type, "real") != 0)) {
        fprintf(stderr, "Semantic Error: Comparison operator '<=' requires numeric operands, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node("<=", 2, $1, $3);
  }
| expr GE expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($3);
    
    if ((strcmp(left_type, "int") != 0 && strcmp(left_type, "real") != 0) ||
        (strcmp(right_type, "int") != 0 && strcmp(right_type, "real") != 0)) {
        fprintf(stderr, "Semantic Error: Comparison operator '>=' requires numeric operands, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node(">=", 2, $1, $3);
  }
| expr AND expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($3);
    
    if (strcmp(left_type, "bool") != 0 || strcmp(right_type, "bool") != 0) {
        fprintf(stderr, "Semantic Error: Logical operator 'AND' requires boolean operands, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node("AND", 2, $1, $3);
  }
| expr OR expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($3);
    
    if (strcmp(left_type, "bool") != 0 || strcmp(right_type, "bool") != 0) {
        fprintf(stderr, "Semantic Error: Logical operator 'OR' requires boolean operands, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node("OR", 2, $1, $3);
  }
| NOT expr 
  {
    char* operand_type = get_expr_type($2);
    
    if (strcmp(operand_type, "bool") != 0) {
        fprintf(stderr, "Semantic Error: Logical NOT operator requires a boolean operand, got %s\n",
                operand_type);
        YYABORT;
    }
    
    $$ = make_node("NOT", 1, $2);
  }
| ADDRESS ID LBRACK expr RBRACK
  {
    char* var_type = get_variable_type($2);
    if (strcmp(var_type, "string") != 0) {
        fprintf(stderr, "Semantic Error: Address operator '&' can only be applied to string index, got %s\n", var_type);
        YYABORT;
    }
    
    char* index_type = get_expr_type($4);
    if (strcmp(index_type, "int") != 0) {
        fprintf(stderr, "Semantic Error: Array index must be of type int, got %s\n", index_type);
        YYABORT;
    }
    
    AST* index_node = make_node("INDEX", 2, make_node($2, 0), $4);
    $$ = make_node("&", 1, index_node);
  }
| ADDRESS ID
  {
    if (!check_variable_usage($2)) {
        YYABORT;
    }
    
    char* var_type = get_variable_type($2);
    
    // בדיקה שהמשתנה הוא מהטיפוסים המותרים לאופרטור & (סעיף 16)
    if (strcmp(var_type, "int") != 0 && 
        strcmp(var_type, "real") != 0 && 
        strcmp(var_type, "char") != 0) {
        fprintf(stderr, "Semantic Error: Address operator '&' can only be applied to variables of type int, real, char, or string index\n");
        YYABORT;
    }
    
    $$ = make_node("&", 1, make_node($2, 0));
  }
| MULT expr 
  {
    char* expr_type = get_expr_type($2);
    
    // בדיקה אם הטיפוס הוא מצביע (סעיף 17)
    if (strstr(expr_type, "*") == NULL) {
        fprintf(stderr, "Semantic Error: Dereference operator '*' can only be applied to pointers, got %s\n", expr_type);
        YYABORT;
    }
    
    $$ = make_node("DEREF", 1, $2);
  }
| expr ADDRESS ADDRESS expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($4);
    
    if (strcmp(left_type, "bool") != 0 || strcmp(right_type, "bool") != 0) {
        fprintf(stderr, "Semantic Error: Logical operator '&&' requires boolean operands, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node("AND", 2, $1, $4);
  }
| expr BAR BAR expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($4);
    
    if (strcmp(left_type, "bool") != 0 || strcmp(right_type, "bool") != 0) {
        fprintf(stderr, "Semantic Error: Logical operator '||' requires boolean operands, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node("OR", 2, $1, $4);
  }
| '!' expr 
  {
    char* operand_type = get_expr_type($2);
    
    if (strcmp(operand_type, "bool") != 0) {
        fprintf(stderr, "Semantic Error: Logical NOT operator requires a boolean operand, got %s\n",
                operand_type);
        YYABORT;
    }
    
    $$ = make_node("NOT", 1, $2);
  }
| BAR expr BAR 
  {
    char* operand_type = get_expr_type($2);
    
    if (strcmp(operand_type, "string") != 0) {
        fprintf(stderr, "Semantic Error: Absolute value operator '|' can only be applied to strings, got %s\n",
                operand_type);
        YYABORT;
    }
    
    $$ = make_node("ABS", 1, $2);
  }
| LPAREN expr RPAREN { $$ = $2; }
| LBRACK expr RBRACK { $$ = $2; }
| REAL { $$ = make_node($1, 0); }
| NUM { $$ = make_node($1, 0); }
| id { $$ = $1; }
| CHAR_LITERAL { $$ = make_node($1, 0); }
| STRING_LITERAL { $$ = make_node($1, 0); }
| NULLPTR { $$ = make_node("nullptr", 0); }
| TRUE { $$ = make_node("TRUE", 0); }
| FALSE { $$ = make_node("FALSE", 0); }
| CALL ID LPAREN call_args RPAREN {
    int arg_count;
    char** arg_types = get_call_arg_types($4, &arg_count);
    if (!check_function_call($2, arg_types, arg_count)) {
        for (int i = 0; i < arg_count; i++) {
            free(arg_types[i]);
        }
        free(arg_types);
        YYABORT;
    }
    for (int i = 0; i < arg_count; i++) {
        free(arg_types[i]);
    }
    free(arg_types);
    $$ = make_node("calll", 2, make_node($2, 0), $4);
  }
| ID LBRACK expr RBRACK
  {
    char* var_type = get_variable_type($1);
    if (strcmp(var_type, "string") != 0) {
        fprintf(stderr, "Semantic Error: Array indexing operator [] can only be used with string type, got %s\n", var_type);
        YYABORT;
    }
    
    char* index_type = get_expr_type($3);
    if (strcmp(index_type, "int") != 0) {
        fprintf(stderr, "Semantic Error: Array index must be of type int, got %s\n", index_type);
        YYABORT;
    }
    
    $$ = make_node("INDEX", 2, make_node($1, 0), $3);
  }
;

%%
void yyerror(const char* s) {
    fprintf(stderr, "Syntax Error: %s\n", s);
}

int main() {
    printf("DEBUG: Initializing symbol table\n");
    init_symbol_table();
    
    int parse_result = yyparse();
    
    if (parse_result == 0) {
        printf("\n=== AC3 Code Generation ===\n");
        
        CodeGenerator cg;
        init_code_generator(&cg);
        generate_code(&cg, program_ast);
        
        printf("=== End of AC3 Code ===\n");
    } else {
        printf("Parsing failed\n");
    }
    
    return parse_result;
}