
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symbol_table.h"
#include "ast.h"
#include <ctype.h>

#define MAX_SCOPE_DEPTH 100

typedef struct LocalFuncEntry {
    FuncEntry* global_func;
    struct LocalFuncEntry* next;
} LocalFuncEntry;

typedef struct Scope {
    VarEntry* vars;
    LocalFuncEntry* local_funcs;  
    struct Scope* next;
    int is_function_scope;        
    char function_name[256];      
} Scope;

static Scope* scopes[MAX_SCOPE_DEPTH];
static int scope_depth = 0;
static FuncEntry* function_table = NULL;
char current_function_name[256] = "";
int function_start_scope = 0;

char* get_expr_type(AST* expr) {
    if (!expr) return "unknown";
    
    if (expr->child_count == 0) {
        VarEntry* var = find_var(expr->name);
        if (var) {
            printf("DEBUG: get_expr_type('%s') found type '%s'\n", expr->name, var->type);
            return var->type;
        }
        printf("DEBUG: get_expr_type('%s') - var not found, checking literals\n", expr->name);
        
        if (strchr(expr->name, '.')) {
            return "real";
        } else if (isdigit(expr->name[0])) {
            return "int";
        } else if (expr->name[0] == '"') {
            return "string";
        } else if (expr->name[0] == '\'') {
            return "char";
        } else if (strcmp(expr->name, "TRUE") == 0 || strcmp(expr->name, "FALSE") == 0 ||
                strcmp(expr->name, "True") == 0 || strcmp(expr->name, "False") == 0) {
            return "bool";
        }
    }
    
    if (strcmp(expr->name, "LENGTH") == 0) {
        return "int";
    }
    
    if (strcmp(expr->name, "ABS") == 0) {
        return get_expr_type(expr->children[0]);
    }

    if (strcmp(expr->name, "+") == 0 || strcmp(expr->name, "-") == 0 ||
        strcmp(expr->name, "*") == 0 || strcmp(expr->name, "/") == 0) {
        char* left_type = get_expr_type(expr->children[0]);
        char* right_type = get_expr_type(expr->children[1]);
    
        printf("DEBUG: Arithmetic operator '%s' - left_type='%s', right_type='%s'\n", 
            expr->name, left_type, right_type);
        
        if ((strcmp(left_type, "int") != 0 && strcmp(left_type, "real") != 0) ||
            (strcmp(right_type, "int") != 0 && strcmp(right_type, "real") != 0)) {
            fprintf(stderr, "Semantic Error: Arithmetic operator '%s' requires int or real operands, got %s and %s\n",
                    expr->name, left_type, right_type);
            return "error";
        }
        
        if (strcmp(left_type, "real") == 0 || strcmp(right_type, "real") == 0) {
            return "real";
        } else {
            return "int";
        }
    }
    
    if (strcmp(expr->name, "AND") == 0 || strcmp(expr->name, "OR") == 0) {
        char* left_type = get_expr_type(expr->children[0]);
        char* right_type = get_expr_type(expr->children[1]);
        
        if (strcmp(left_type, "bool") != 0 || strcmp(right_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Logical operator '%s' requires boolean operands, got %s and %s\n",
                    expr->name, left_type, right_type);
            return "error";
        }
        
        return "bool";
    }
    
    if (strcmp(expr->name, "<") == 0 || strcmp(expr->name, ">") == 0 ||
        strcmp(expr->name, "<=") == 0 || strcmp(expr->name, ">=") == 0) {
        char* left_type = get_expr_type(expr->children[0]);
        char* right_type = get_expr_type(expr->children[1]);
        
        if ((strcmp(left_type, "int") != 0 && strcmp(left_type, "real") != 0) ||
            (strcmp(right_type, "int") != 0 && strcmp(right_type, "real") != 0)) {
            fprintf(stderr, "Semantic Error: Comparison operator '%s' requires numeric operands, got %s and %s\n",
                    expr->name, left_type, right_type);
            return "error";
        }
        
        return "bool";
    }
    
    if (strcmp(expr->name, "==") == 0 || strcmp(expr->name, "!=") == 0) {
        char* left_type = get_expr_type(expr->children[0]);
        char* right_type = get_expr_type(expr->children[1]);
        
        if (strcmp(left_type, right_type) != 0) {
            fprintf(stderr, "Semantic Error: Equality operator '%s' requires operands of the same type, got %s and %s\n",
                    expr->name, left_type, right_type);
            return "error";
        }
        
        return "bool";
    }
    
    if (strcmp(expr->name, "ABS") == 0) {  
        char* operand_type = get_expr_type(expr->children[0]);
        
        if (strcmp(operand_type, "string") != 0) {
            fprintf(stderr, "Semantic Error: Absolute value operator '||' can only be applied to strings, got %s\n",
                    operand_type);
            return "error";
        }
        
        return "int";
    }
    
    if (strcmp(expr->name, "NOT") == 0) {
        char* operand_type = get_expr_type(expr->children[0]);
        
        if (strcmp(operand_type, "bool") != 0) {
            fprintf(stderr, "Semantic Error: Logical NOT operator '!' can only be applied to boolean values, got %s\n",
                    operand_type);
            return "error";
        }
        
        return "bool";
    }
    
    if (strcmp(expr->name, "&") == 0) {
        char* operand_type = get_expr_type(expr->children[0]);
        
        if (expr->children[0]->child_count > 0 && strcmp(expr->children[0]->name, "INDEX") == 0) {
            return "char*";
        }
        
        if (strcmp(operand_type, "int") != 0 && 
            strcmp(operand_type, "real") != 0 && 
            strcmp(operand_type, "char") != 0) {
            fprintf(stderr, "Semantic Error: Address operator '&' can only be applied to variables of type int, real, char, or string index, got %s\n",
                    operand_type);
            return "error";
        }
        
        char* ptr_type = malloc(strlen(operand_type) + 2);
        strcpy(ptr_type, operand_type);
        strcat(ptr_type, "*");
        return ptr_type;
    }
    
    if (strcmp(expr->name, "DEREF") == 0) {
        char* operand_type = get_expr_type(expr->children[0]);
        
        if (strchr(operand_type, '*') == NULL) {
            fprintf(stderr, "Semantic Error: Dereference operator '*' can only be applied to pointers, got %s\n",
                    operand_type);
            return "error";
        }
        
        char* base_type = malloc(strlen(operand_type));
        strncpy(base_type, operand_type, strlen(operand_type) - 1);
        base_type[strlen(operand_type) - 1] = '\0';
        return base_type;
    }
    
    if (strcmp(expr->name, "calll") == 0) {
        char* func_name = expr->children[0]->name;
        for (FuncEntry* f = function_table; f; f = f->next) {
            if (strcmp(f->name, func_name) == 0) {
                return f->return_type;
            }
        }
    }
    
    if (strcmp(expr->name, "INDEX") == 0) {
        return "char";
    }
    
    return "unknown";
}

char** get_call_arg_types(AST* call_args, int* arg_count) {
    printf("DEBUG: Extracting argument types from: %s\n", call_args->name);
    
    if (!call_args || (strcmp(call_args->name, "par") == 0 && 
                     call_args->child_count == 1 && 
                     strcmp(call_args->children[0]->name, "NONE") == 0)) {
        printf("DEBUG: No arguments found\n");
        *arg_count = 0;
        return NULL;
    }
    
    if (strcmp(call_args->name, "par") != 0) {
        printf("DEBUG: Found single argument (not par)\n");
        *arg_count = 1;
        char** types = malloc(sizeof(char*) * 1);
        types[0] = strdup(get_expr_type(call_args));
        printf("DEBUG: Argument type: %s\n", types[0]);
        return types;
    }
    
    AST* nodes[10]; 
    int count = 0;
    
    AST* current = call_args;
    while (current) {
        if (strcmp(current->name, "par") == 0) {
            if (current->child_count == 2) {
                nodes[count] = current->children[1];
                count++;
                current = current->children[0];
            } else {
                break;
            }
        } else {
            nodes[count] = current;
            count++;
            break;
        }
    }
    
    printf("DEBUG: Found total of %d arguments\n", count);
    *arg_count = count;
    
    char** types = malloc(sizeof(char*) * count);
    
    for (int i = 0; i < count; i++) {
        types[i] = strdup(get_expr_type(nodes[count - 1 - i]));
        printf("DEBUG: Argument %d type: %s\n", i, types[i]);
    }
    
    return types;
}

void begin_function_scope(const char* function_name) {
    strncpy(current_function_name, function_name, sizeof(current_function_name) - 1);
    current_function_name[sizeof(current_function_name) - 1] = '\0';
    function_start_scope = scope_depth+1; 
    
    printf("DEBUG: Starting function '%s' at scope depth %d\n", function_name, scope_depth);
}

void end_function_scope() {
    printf("DEBUG: Ending function scope - depth before: %d\n", scope_depth);
    

    
    current_function_name[0] = '\0';
    function_start_scope = 0;
    
    printf("DEBUG: Function scope ended - depth after: %d\n", scope_depth);
}

int get_scope_depth() {
    return scope_depth;
}

void reset_function_scope() {
    function_start_scope = 0;
    printf("DEBUG: Reset function scope\n");
}

void init_symbol_table() {
    printf("DEBUG: Initializing symbol table\n");
    scope_depth = 0;  
    function_table = NULL;
    memset(scopes, 0, sizeof(scopes));
}

void begin_scope() {
    printf("DEBUG: Begin scope - before: depth=%d\n", scope_depth);
    if (scope_depth >= MAX_SCOPE_DEPTH) {
        fprintf(stderr, "Exceeded max scope depth\n");
        exit(1);
    }
    Scope* s = malloc(sizeof(Scope));
    s->vars = NULL;
    s->local_funcs = NULL;
    s->is_function_scope = 0;          
    strcpy(s->function_name, "");      
    scopes[scope_depth++] = s;
    printf("DEBUG: Begin scope - after: depth=%d\n", scope_depth);
}


void end_scope() {
    printf("DEBUG: End scope - before: depth=%d\n", scope_depth);
    if (scope_depth <= 0) return;
    Scope* s = scopes[--scope_depth];

    VarEntry* v = s->vars;
    while (v) {
        VarEntry* temp = v;
        v = v->next;
        free(temp->name);
        free(temp->type);
        free(temp);
    }

    LocalFuncEntry* lf = s->local_funcs;
    while (lf) {
        LocalFuncEntry* temp = lf;
        lf = lf->next;
        free(temp);
    }
    
    free(s);
    printf("DEBUG: End scope - after: depth=%d\n", scope_depth);
}

int insert_variable(const char* name, const char* type) {
    if (!name || !type) {
        fprintf(stderr, "Semantic Error: NULL name or type\n");
        return 0;
    }
    
    if (scope_depth <= 0) {
        fprintf(stderr, "ERROR: Trying to insert variable '%s' but no scope is active!\n", name);
        return 0;
    }
    
    Scope* s = scopes[scope_depth - 1];
    if (!s) {
        fprintf(stderr, "Semantic Error: NULL scope at depth %d\n", scope_depth - 1);
        return 0;
    }
        
    VarEntry* new_var = malloc(sizeof(VarEntry));
    if (!new_var) {
        fprintf(stderr, "Error: Memory allocation failed\n");
        return 0;
    }
    new_var->name = strdup(name);
    new_var->type = strdup(type);
    new_var->next = s->vars;
    s->vars = new_var;
    
    printf("DEBUG: Successfully inserted variable '%s' of type '%s' in scope %d (shadowing allowed)\n",
           name, type, scope_depth - 1);
    
    return 1;
}

int check_variable_usage(const char* name) {
    printf("DEBUG: Checking usage of variable '%s' in scopes %d to 0\n", name, scope_depth - 1);
    
    for (int i = scope_depth - 1; i >= 0; i--) {
        printf("DEBUG: Searching in scope %d\n", i);
        for (VarEntry* v = scopes[i]->vars; v; v = v->next) {
            printf("DEBUG:   Found var '%s' in scope %d\n", v->name, i);
            if (strcmp(v->name, name) == 0) {
            fprintf(stderr, "DEBUG: Variable '%s' already exists in current scope level %d\n", name, scope_depth - 1);
                printf("DEBUG: Variable '%s' found in scope %d\n", name, i);
                return 1;
            }
        }
    }
    
    fprintf(stderr, "Semantic Error: Variable '%s' used before declaration\n", name);
    return 0;
}

int insert_function(const char* name, const char* return_type, char** param_types, int param_count, AST* body) {
    if (scope_depth > 1) {
        Scope* current_scope = scopes[scope_depth - 1];
        for (LocalFuncEntry* lf = current_scope->local_funcs; lf && lf->global_func; lf = lf->next) {
            if (strcmp(lf->global_func->name, name) == 0) {
                fprintf(stderr, "Semantic Error: Function '%s' redeclared in same scope\n", name);
                return 0;
            }
        }
    } 
    
    for (FuncEntry* f = function_table; f; f = f->next) {
        if (strcmp(f->name, name) == 0) {
            if (scope_depth > 1) {
                printf("DEBUG: Function '%s' shadows global function\n", name);
            } else {
                fprintf(stderr, "Semantic Error: Function '%s' redeclared\n", name);
                return 0;
            }
        }
    }
    
    FuncEntry* new_func = malloc(sizeof(FuncEntry));
    new_func->name = strdup(name);
    new_func->return_type = strdup(return_type);
    new_func->param_count = param_count;
    new_func->body = body;
    
    if (param_count > 0) {
        new_func->param_types = malloc(sizeof(char*) * param_count);
        
        if (param_types != NULL) {
            for (int i = 0; i < param_count; i++) {
                new_func->param_types[i] = strdup(param_types[i]);
            }
        } else {
            for (int i = 0; i < param_count; i++) {
                new_func->param_types[i] = strdup("int");
            }
        }
    } else {
        new_func->param_types = NULL;
    }
    
    new_func->next = function_table;
    function_table = new_func;
    
    if (scope_depth > 1) {
        Scope* current_scope = scopes[scope_depth - 1];
        
        if (current_scope->local_funcs == NULL) {
            current_scope->local_funcs = malloc(sizeof(LocalFuncEntry));
            current_scope->local_funcs->global_func = NULL;
            current_scope->local_funcs->next = NULL;
        }
        
        LocalFuncEntry* local_entry = malloc(sizeof(LocalFuncEntry));
        local_entry->global_func = new_func;
        local_entry->next = current_scope->local_funcs;
        current_scope->local_funcs = local_entry;
        
        printf("DEBUG: Added nested function '%s' to scope %d\n", name, scope_depth - 1);
    }
    
    return 1;
}

int check_function_call(const char* name, char** arg_types, int arg_count) {
    printf("DEBUG: Checking function call to '%s' with %d arguments\n", name, arg_count);
    
    for (FuncEntry* f = function_table; f; f = f->next) {
        if (strcmp(f->name, name) == 0) {
            printf("DEBUG: Found global function '%s' in table with %d parameters\n", name, f->param_count);
            
            if (f->param_count != arg_count) {
                fprintf(stderr, "Semantic Error: Function '%s' called with wrong number of arguments (%d), expected %d\n",
                        name, arg_count, f->param_count);
                return 0;
            }
            
            if (arg_count > 0 && f->param_types != NULL) {
                for (int i = 0; i < arg_count; i++) {
                    printf("DEBUG: Checking parameter %d: expected '%s', got '%s'\n",
                        i, f->param_types[i], arg_types[i]);
                    
                    if (strcmp(f->param_types[i], arg_types[i]) != 0) {
                        fprintf(stderr, "Semantic Error: Parameter %d type mismatch in call to '%s', expected '%s', got '%s'. Parameters must be in correct order.\n",
                                i + 1, name, f->param_types[i], arg_types[i]);
                        return 0;
                    }
                }
            }
            
            printf("DEBUG: Function call validation successful\n");
            return 1;
        }
    }
    
    for (int i = scope_depth - 1; i >= 0; i--) {
        if (scopes[i]->is_function_scope && 
            strlen(current_function_name) > 0 &&
            strcmp(scopes[i]->function_name, current_function_name) != 0) {
            printf("DEBUG: Stopped searching for nested functions at function boundary\n");
            break;
        }
        
        for (LocalFuncEntry* lf = scopes[i]->local_funcs; lf && lf->global_func; lf = lf->next) {
            if (strcmp(lf->global_func->name, name) == 0) {
                printf("DEBUG: Found local function '%s' in scope %d\n", name, i);
                
                FuncEntry* f = lf->global_func;
                if (f->param_count != arg_count) {
                    fprintf(stderr, "Semantic Error: Function '%s' called with wrong number of arguments (%d), expected %d\n",
                            name, arg_count, f->param_count);
                    return 0;
                }
                
                if (arg_count > 0 && f->param_types != NULL) {
                    for (int j = 0; j < arg_count; j++) {
                        if (strcmp(f->param_types[j], arg_types[j]) != 0) {
                            fprintf(stderr, "Semantic Error: Parameter %d type mismatch in call to '%s', expected '%s', got '%s'\n",
                                    j + 1, name, f->param_types[j], arg_types[j]);
                            return 0;
                        }
                    }
                }
                
                return 1;
            }
        }
    }
    
    fprintf(stderr, "Semantic Error: Function '%s' used before declaration\n", name);
    return 0;
}
int check_main_signature() {
    for (FuncEntry* f = function_table; f; f = f->next) {
        if (strcmp(f->name, "_main_") == 0) {
            if (f->param_count != 0 || strcmp(f->return_type, "NONE") != 0) {
                fprintf(stderr, "Semantic Error: '_main_' function must not have params or return type\n");
                return 0;
            }
            
            if (f->body && is_return_stmt_in_main(f->body)) {
                fprintf(stderr, "Semantic Error: '_main_' function must not have return statement\n");
                return 0;
            }
            
            return 1;
        }
    }
    fprintf(stderr, "Semantic Error: '_main_' function not found\n");
    return 0;
}

int main_exists() {
    for (FuncEntry* f = function_table; f; f = f->next) {
        if (strcmp(f->name, "_main_") == 0) {
            return 1;
        }
    }
    return 0;
}

void insert_var_decl_list(AST* list) {
    if (!list) return;
    if (strcmp(list->name, "VARLIST") == 0) {
        for (int i = 0; i < list->child_count; i++) {
            insert_var_decl_list(list->children[i]);
        }
    }
    else if (strcmp(list->name, "DECL") == 0) {
        if (list->child_count >= 2) {
            const char* varname = list->children[0]->name;
        }
    }
}

int lookup_in_current_scope(const char* name) {
    Scope* s = scopes[scope_depth - 1];
    for (VarEntry* v = s->vars; v; v = v->next) {
        if (strcmp(v->name, name) == 0)
            return 1;
    }
    return 0;
}

int insert_symbol(const char* name, const char* type, int scope) {
    return insert_function(name, type, NULL, 0, NULL);
}

int function_exists(const char* name) {
    for (FuncEntry* f = function_table; f; f = f->next) {
        if (strcmp(f->name, name) == 0) {
            return 1;
        }
    }
    return 0;
}

int is_return_stmt_in_main(AST* function_body) {
    if (!function_body) return 0;

    if (strcmp(function_body->name, "RET") == 0) {
        return 1;
    }
    
    for (int i = 0; i < function_body->child_count; i++) {
        if (is_return_stmt_in_main(function_body->children[i])) {
            return 1;
        }
    }
    return 0;
}

int check_return_type(const char* func_name, const char* return_type) {
    for (FuncEntry* f = function_table; f; f = f->next) {
        if (strcmp(f->name, func_name) == 0) {
            if (strcmp(f->return_type, return_type) != 0) {
                fprintf(stderr, "Semantic Error: Return type mismatch in function '%s'. Expected '%s', got '%s'\n",
                        func_name, f->return_type, return_type);
                return 0;
            }
            
            if (strcmp(f->return_type, "string") == 0) {
                fprintf(stderr, "Semantic Error: Function '%s' cannot return string type\n", func_name);
                return 0;
            }
            
            return 1;
        }
    }
    
    fprintf(stderr, "Semantic Error: Function '%s' not found\n", func_name);
    return 0;
}

FuncEntry* get_function_by_name(const char* name) {
    for (FuncEntry* f = function_table; f; f = f->next) {
        if (strcmp(f->name, name) == 0) {
            return f;
        }
    }
    return NULL;
}

VarEntry* find_var(const char* name) {
    for (int i = scope_depth - 1; i >= 0; i--) {
        for (VarEntry* v = scopes[i]->vars; v; v = v->next) {
            if (strcmp(v->name, name) == 0) {
                fprintf(stderr, "DEBUG: Variable '%s' already exists in current scope level %d\n", name, scope_depth - 1);
                return v;
            }
        }
    }
    return NULL;
}

char* get_variable_type(const char* var_name) {
    VarEntry* var = find_var(var_name);
    if (var) {
        return var->type;
    }
    return "unknown";
}

int is_var_in_current_scope(const char* name) {
    if (scope_depth <= 0) return 0;
    
    Scope* s = scopes[scope_depth - 1];
    for (VarEntry* v = s->vars; v; v = v->next) {
        if (strcmp(v->name, name) == 0) {
            fprintf(stderr, "DEBUG: Variable '%s' already exists in current scope level %d\n", name, scope_depth - 1);
            return 1;
        }
    }
    return 0;
}


