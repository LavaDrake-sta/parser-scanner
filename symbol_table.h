#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

struct ast_node;
typedef struct ast_node AST;

#define SCOPE_GLOBAL 0
#define SCOPE_LOCAL 1

typedef struct VarEntry {
    char* name;
    char* type;
    struct VarEntry* next;
} VarEntry;

typedef struct FuncEntry {
    char* name;
    char* return_type;
    char** param_types;
    int param_count;
    AST* body;
    struct FuncEntry* next;
} FuncEntry;

void init_symbol_table();
void begin_scope();
void end_scope();
void insert_var_decl_list(AST* list);
int function_exists(const char* name);
int insert_variable(const char* name, const char* type);
int insert_function(const char* name, const char* return_type, char** param_types, int param_count, AST* body);  // עדכן חתימה
int check_variable_usage(const char* name);
int check_function_call(const char* name, char** arg_types, int arg_count);
int insert_symbol(const char* name, const char* type, int scope);
int lookup_in_current_scope(const char* name);
int check_main_signature();
int main_exists();
int is_return_stmt_in_main(AST* function_body);

#endif