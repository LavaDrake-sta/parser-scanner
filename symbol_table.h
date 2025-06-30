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

extern char current_function_name[256];
extern int function_start_scope;
void init_symbol_table();
void begin_scope();
void end_scope();
void insert_var_decl_list(AST* list);
void begin_function_scope(const char* function_name);
void end_function_scope();
void reset_function_scope();
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
int get_scope_depth();
int is_var_in_current_scope(const char* name);
int check_return_type(const char* func_name, const char* return_type);
char* get_expr_type(AST* expr);
char** get_call_arg_types(AST* call_args, int* arg_count);
char* get_variable_type(const char* var_name);

FuncEntry* get_function_by_name(const char* name);
VarEntry* find_var(const char* var_name);

#endif