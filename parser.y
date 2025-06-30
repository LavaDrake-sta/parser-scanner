%{
    #include "symbol_table.h"
    #include "three_address_code.h"
    #include "ast.h"
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <ctype.h>

    char** get_param_types_from_ast(AST* params, int param_count);
    void process_var_declarations(AST* var_list);
    void process_single_var_declaration(char* type_name, AST* var_node);
    void process_var_decl_with_type(char* type_name, AST* var_item);
    AST* make_node(char* name, int count, ...);
    void print_ast(AST* node, int indent);
    void yyerror(const char* s);
    extern FuncEntry* get_function_by_name(const char* name);
    extern char current_function_name[256];
    void process_declaration_list(AST* type_node, AST* decl_list);
    int yylex();
    int yydebug = 1;
    char current_var_type[64] = "";
    AST* ast_root = NULL; 

char** get_param_types_from_ast(AST* params, int param_count) {
    if (param_count == 0 || !params) return NULL;
    
    char** types = malloc(sizeof(char*) * param_count);
    
    AST* current = params;
    if (strcmp(current->name, "PARS") == 0 && current->child_count > 0) {
        current = current->children[0];
    }
    
    if (param_count == 1) {
        if (strcmp(current->name, "par") == 0 && current->child_count >= 3) {
            types[0] = strdup(current->children[1]->name);
        }
    } else {
        int index = 0;
        while (current && strcmp(current->name, "PLIST") == 0 && current->child_count == 2) {
            AST* param = current->children[1];
            if (strcmp(param->name, "par") == 0 && param->child_count >= 3) {
                types[param_count - 1 - index] = strdup(param->children[1]->name);
            }
            index++;
            current = current->children[0];
        }
        
        if (current && strcmp(current->name, "par") == 0 && current->child_count >= 3) {
            types[param_count - 1 - index] = strdup(current->children[1]->name);
        }
    }
    
    return types;
}

void process_var_declarations(AST* var_list) {
    if (!var_list || strcmp(var_list->name, "EMPTY") == 0) return;
    
    printf("DEBUG: Processing VAR declarations\n");
    
    if (strcmp(var_list->name, "VAR-LIST") == 0) {
        for (int i = 0; i < var_list->child_count; i++) {
            process_var_declarations(var_list->children[i]);
        }
    }
    else if (strcmp(var_list->name, "VAR-DECLS") == 0) {
        for (int i = 0; i < var_list->child_count; i++) {
            process_var_declarations(var_list->children[i]);
        }
    }
    else if (strcmp(var_list->name, "DECL") == 0) {
        if (var_list->child_count >= 2) {
            char* type_name = var_list->children[0]->name;
            AST* var_node = var_list->children[1];
            
            printf("DEBUG: Processing DECL with type %s\n", type_name);

        }
    }
}

void process_single_var_declaration(char* type_name, AST* var_node) {
    return;
}

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

void process_var_decl_with_type(char* type_name, AST* var_item) {
     return;
}

void process_declaration_list(AST* type_node, AST* decl_list) {
    return;
}

%}

%union {
    struct ast_node* ast ;
    char* sval;
}

%start program
%left OR
%left AND
%left EQ NE
%left GT GE LT LE
%left PLUS MINUS
%left MULT DIV MOD
%right NOT

%token <sval> ID CHAR_LITERAL STRING_LITERAL NUM REAL
%token <sval> TYPE_INT TYPE_CHAR TYPE_REAL TYPE_BOOL TYPE_STRING TYPE_INT_PTR TYPE_CHAR_PTR TYPE_REAL_PTR

%token TYPE
%token DEF T_BEGIN T_END IF ELSE ELIF WHILE FOR DO CALL RETURN RETURNS VAR NULLPTR 
%token TRUE FALSE AND OR NOT 

%token EQ NE GT GE LT LE ASSIGN
%token PLUS MINUS MULT DIV MOD ADDRESS 

%token COLON SEMICOLON COMMA LPAREN RPAREN LBRACK RBRACK BAR

%type <ast> program function function_list param_list param_list_item param_list_item_list elif_list call_list var_decl_list
%type <ast> type var_stmt_list_opt par_list_opt nested_block
%type <ast> stmt_list stmt assignment expr if_stmt block return_stmt while_stmt do_while_stmt for_stmt
%type <ast> var_stmt call_args void_call assignment_call var_decl id var_decl_item var_block_stmt
%%

program: function_list {
        printf("ENTERED: program -> function_list\n");
        if (!check_main_signature()) {
            YYABORT;
        }
        print_ast($1, 0);
        ast_root = $1; 
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
    /* FUNCTION WITH RETURN TYPE - with vars before begin */
    DEF ID LPAREN par_list_opt RPAREN COLON RETURNS type {
        begin_function_scope($2);
        begin_scope();
        int param_count = has_params($4);
        char** param_types = get_param_types_from_ast($4, param_count);
        if (!insert_function($2, $8->name, param_types, param_count, NULL)) {
            if (param_types) {
                for (int i = 0; i < param_count; i++) {
                    free(param_types[i]);
                }
                free(param_types);
            }
            YYABORT;
        }
        if (param_types) {
            for (int i = 0; i < param_count; i++) {
                free(param_types[i]);
            }
            free(param_types);
        }
    } var_stmt_list_opt T_BEGIN stmt_list T_END {
        $$ = make_node("FUNC", 5,
            make_node($2, 0),
            $4,
            make_node("RET", 1, $8),
            $10, // var_stmt_list_opt
            make_node("BODY", 1, $12) // stmt_list
        );
        end_scope();
        end_function_scope();
    }
    /* FUNCTION WITHOUT RETURN TYPE - with vars before begin */
    | DEF ID LPAREN par_list_opt RPAREN COLON {
        begin_function_scope($2);
        begin_scope();
        int param_count = has_params($4);
        char** param_types = get_param_types_from_ast($4, param_count);
        if (!insert_function($2, "NONE", param_types, param_count, NULL)) {
            if (param_types) {
                for (int i = 0; i < param_count; i++) {
                    free(param_types[i]);
                }
                free(param_types);
            }
            YYABORT;
        }
        if (param_types) {
            for (int i = 0; i < param_count; i++) {
                free(param_types[i]);
            }
            free(param_types);
        }
    } var_stmt_list_opt T_BEGIN stmt_list T_END {
        $$ = make_node("FUNC", 5,
            make_node($2, 0),
            $4,
            make_node("RET", 1, make_node("NONE", 0)),
            $8, // var_stmt_list_opt
            make_node("BODY", 1, $10) // stmt_list
        );
        end_scope();
        end_function_scope();
    }
    /* FUNCTION WITHOUT RETURN TYPE - begin directly */
    | DEF ID LPAREN par_list_opt RPAREN COLON T_BEGIN {
        begin_function_scope($2);
        begin_scope();
        int param_count = has_params($4);
        char** param_types = get_param_types_from_ast($4, param_count);
        if (!insert_function($2, "NONE", param_types, param_count, NULL)) {
            if (param_types) {
                for (int i = 0; i < param_count; i++) {
                    free(param_types[i]);
                }
                free(param_types);
            }
            YYABORT;
        }
        if (param_types) {
            for (int i = 0; i < param_count; i++) {
                free(param_types[i]);
            }
            free(param_types);
        }
    } stmt_list T_END {
        $$ = make_node("FUNC", 5,
            make_node($2, 0),
            $4,
            make_node("RET", 1, make_node("NONE", 0)),
            make_node("EMPTY", 0),
            make_node("BODY", 1, $9) // stmt_list
        );
        end_scope();
        end_function_scope();
    }
    /* FUNCTION WITH RETURN TYPE - begin directly */
    | DEF ID LPAREN par_list_opt RPAREN COLON RETURNS type T_BEGIN {
        begin_function_scope($2);
        begin_scope();
        int param_count = has_params($4);
        char** param_types = get_param_types_from_ast($4, param_count);
        if (!insert_function($2, $8->name, param_types, param_count, NULL)) {
            if (param_types) {
                for (int i = 0; i < param_count; i++) {
                    free(param_types[i]);
                }
                free(param_types);
            }
            YYABORT;
        }
        if (param_types) {
            for (int i = 0; i < param_count; i++) {
                free(param_types[i]);
            }
            free(param_types);
        }
    } stmt_list T_END {
        $$ = make_node("FUNC", 5,
            make_node($2, 0),
            $4,
            make_node("RET", 1, $8),
            make_node("EMPTY", 0),
            make_node("BODY", 1, $11) // stmt_list
        );
        end_scope();
        end_function_scope();
    }
;


par_list_opt:
    param_list { $$ = $1; }
  | /* empty */ { $$ = make_node("PARS", 1, make_node("NONE", 0)); }
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
        printf("param_list_item matched: %s %s : %s\n", $1, $2->name, $4);
        
        if (!insert_variable($4, $2->name)) {
            yyerror("Semantic Error: Parameter already declared");
            YYABORT;
        }
        
        $$ = make_node("par", 3, make_node($1, 0), make_node($2->name, 0), make_node($4, 0));
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
    assignment { printf("DEBUG: matched stmt -> assignment\n");$$ = $1;}
  | if_stmt    { printf("DEBUG: matched stmt -> if_stmt\n"); $$ = $1; }
  | return_stmt { printf("DEBUG: matched stmt -> return_stmt\n"); $$ = $1; }
  | while_stmt {printf("DEBUG: matched stmt -> while_stmt\n"); $$ = $1; }
  | do_while_stmt {printf("DEBUG: matched stmt -> do_while_stmt\n"); $$ = $1; }
  | for_stmt {printf("DEBUG: matched stmt -> for_stmt\n"); $$ = $1; }
  | void_call {printf("DEBUG: matched stmt -> void_call\n"); $$ = $1; }
  | var_stmt {printf("DEBUG: matched stmt -> var_stmt\n"); $$ = $1; }
  | var_block_stmt {printf("DEBUG: matched stmt -> var_block_stmt\n"); $$ = $1; }
  | assignment_call {printf("DEBUG: matched stmt -> assignment_call\n"); $$ = $1; }
  | function {printf("DEBUG: matched stmt -> nested function\n"); $$ = $1; }  
  | nested_block {printf("DEBUG: matched stmt -> nested_block\n"); $$ = $1; }
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

var_stmt_list_opt:
    var_stmt_list_opt var_stmt { 
        $$ = make_node("VAR-LIST", 2, $1, $2); 
    }
  | var_stmt {
        $$ = $1;
    }
  | /* empty */ { 
        $$ = make_node("EMPTY", 0); 
    }
;

var_stmt:
    VAR var_decl_list {
        printf("DEBUG: Starting var_stmt WITHOUT block\n");
        $$ = make_node("VAR-DECLS", 1, $2);
    }
;

var_block_stmt:
    VAR var_decl_list T_BEGIN {
        begin_scope();
        printf("DEBUG: Created new scope for VAR block\n");
    } stmt_list T_END {
        $$ = make_node("VAR-BLOCK", 2, $2, $5);
        end_scope();
        printf("DEBUG: Exited VAR block scope\n");
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
    TYPE type COLON {
        strcpy(current_var_type, $2->name);
    } var_decl_item SEMICOLON {
        printf("DEBUG: in var_decl - processing var_decl_item\n");
        $$ = make_node("DECL", 2, make_node($2->name, 0), $5);
    }
;

var_decl_item:
    ID {
        printf("DEBUG: simple var '%s'\n", $1);
        if (!insert_variable($1, current_var_type)) {
            yyerror("Semantic Error: Variable already declared");
            YYABORT;
        }
        $$ = make_node($1, 0);
    }
    | ID COLON expr {
        printf("DEBUG: initialized var '%s'\n", $1);
        if (!insert_variable($1, current_var_type)) {
            yyerror("Semantic Error: Variable already declared");
            YYABORT;
        }
        $$ = make_node("INIT-VAR", 2, make_node($1, 0), $3);
    }
    | ID LBRACK NUM RBRACK {
        printf("DEBUG: array var '%s[%s]'\n", $1, $3);
        if (!insert_variable($1, current_var_type)) {
            yyerror("Semantic Error: Variable already declared");
            YYABORT;
        }
        $$ = make_node("ARRAY-VAR", 2, make_node($1, 0), make_node($3, 0));
    }
    | var_decl_item COMMA ID {
        printf("DEBUG: adding var '%s' to list\n", $3);
        if (!insert_variable($3, current_var_type)) {
            yyerror("Semantic Error: Variable already declared");
            YYABORT;
        }
        $$ = make_node("VAR-LIST", 2, $1, make_node($3, 0));
    }
    | var_decl_item COMMA ID COLON expr {
        printf("DEBUG: adding initialized var '%s' to list\n", $3);
        if (!insert_variable($3, current_var_type)) {
            yyerror("Semantic Error: Variable already declared");
            YYABORT;
        }
        $$ = make_node("VAR-LIST", 2, $1, make_node("INIT-VAR", 2, make_node($3, 0), $5));
    }
    | var_decl_item COMMA ID LBRACK NUM RBRACK {
        printf("DEBUG: adding array var '%s[%s]' to list\n", $3, $5);
        if (!insert_variable($3, current_var_type)) {
            yyerror("Semantic Error: Variable already declared");
            YYABORT;
        }
        $$ = make_node("VAR-LIST", 2, $1, make_node("ARRAY-VAR", 2, make_node($3, 0), make_node($5, 0)));
    };
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
            fprintf(stderr,"Semantic Error: Condition in if statement must be of type bool, got %s\n", cond_type);
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
    DO COLON block WHILE expr SEMICOLON
    {
        char* cond_type = get_expr_type($5);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in do-while loop must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("do_while", 2, $3, $5);
    }
;

for_stmt:
    FOR LPAREN {
        begin_scope();
    } assignment expr SEMICOLON expr RPAREN COLON stmt
    {
        char* cond_type = get_expr_type($5);
        if (strcmp(cond_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Condition in for loop must be of type bool, got %s\n", cond_type);
            YYABORT;
        }
        
        $$ = make_node("FOR", 4, $4, $5, $7, $10);
        end_scope();
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
    T_BEGIN {
        begin_scope();
    } stmt_list T_END { 
        $$ = make_node("BLOCK", 1, $3);
        end_scope();
    }
    | T_BEGIN {
        begin_scope();
    } T_END { 
        $$ = make_node("BLOCK", 0);
        end_scope();
    }
;

nested_block:
    T_BEGIN {
        printf("DEBUG: Starting nested block scope\n");
        begin_scope();
    } stmt_list T_END {
        printf("DEBUG: matched nested_block\n"); 
        $$ = make_node("NESTED-BLOCK", 1, $3);
        end_scope();
        printf("DEBUG: Exited nested block scope\n");
    }
    | T_BEGIN {
        printf("DEBUG: Starting empty nested block scope\n");
        begin_scope();
    } T_END {
        printf("DEBUG: matched empty nested_block\n"); 
        $$ = make_node("NESTED-BLOCK", 0);
        end_scope();
        printf("DEBUG: Exited empty nested block scope\n");
    }
;

expr:
expr PLUS expr 
    {
        char* left_type = get_expr_type($1);
        char* right_type = get_expr_type($3);
        
        printf("DEBUG: Parser PLUS - left_type='%s', right_type='%s'\n", left_type, right_type);
        
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
| expr MOD expr 
  {
    char* left_type = get_expr_type($1);
    char* right_type = get_expr_type($3);
    
    if (strcmp(left_type, "int") != 0 || strcmp(right_type, "int") != 0) {
        fprintf(stderr, "Semantic Error: Modulo operator '%%' requires int operands, got %s and %s\n",
                left_type, right_type);
        YYABORT;
    }
    
    $$ = make_node("%", 2, $1, $3);
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
    
    if (strstr(expr_type, "*") == NULL) {
        fprintf(stderr, "Semantic Error: Dereference operator '*' can only be applied to pointers, got %s\n", expr_type);
        YYABORT;
    }
    
    $$ = make_node("DEREF", 1, $2);
  }
| BAR expr BAR {
    char* operand_type = get_expr_type($2);

    if (strcmp(operand_type, "string") == 0) {
        $$ = make_node("LENGTH", 1, $2);
    } else if (strcmp(operand_type, "int") == 0 || strcmp(operand_type, "real") == 0) {
        $$ = make_node("ABS", 1, $2);
    } else if (strstr(operand_type, "array") != NULL) {
        $$ = make_node("SIZEOF", 1, $2);
    } else {
        fprintf(stderr, "Semantic Error: Operator '|' not applicable to type '%s'\n", operand_type);
        YYABORT;
    }
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
    printf("DEBUG: Starting compiler\n");
    init_symbol_table(); 
    begin_scope(); 
    printf("DEBUG: Created global scope 0\n");
    
    int result = yyparse();
    
    if (result == 0) {
        printf("\n=== AC3 Code Generation ===\n");
        
        CodeGenerator cg;
        init_code_generator(&cg);
        generate_code(&cg, ast_root);
        
        printf("=== End of AC3 Code ===\n");
    } else {
        printf("Parsing failed\n");
    }
    
    return result;
}