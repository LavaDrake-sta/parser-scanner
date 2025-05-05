
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symbol_table.h"
#include "ast.h"

#define MAX_SCOPE_DEPTH 100

typedef struct LocalFuncEntry {
    FuncEntry* global_func;
    struct LocalFuncEntry* next;
} LocalFuncEntry;

typedef struct Scope {
    VarEntry* vars;
    LocalFuncEntry* local_funcs;  
    struct Scope* next;
} Scope;

static Scope* scopes[MAX_SCOPE_DEPTH];
static int scope_depth = 0;
static FuncEntry* function_table = NULL;

void init_symbol_table() {
    printf("DEBUG: Initializing symbol table\n");
    scope_depth = 0;
    function_table = NULL;
    memset(scopes, 0, sizeof(scopes));
    begin_scope();
}

void begin_scope() {
    printf("DEBUG: Begin scope - before: depth=%d\n", scope_depth);
    if (scope_depth >= MAX_SCOPE_DEPTH) {
        fprintf(stderr, "Exceeded max scope depth\n");
        exit(1);
    }
    Scope* s = malloc(sizeof(Scope));
    s->vars = NULL;
    s->local_funcs = NULL;  // חשוב מאוד!
    scopes[scope_depth++] = s;
    printf("DEBUG: Begin scope - after: depth=%d\n", scope_depth);
}


void end_scope() {
    printf("DEBUG: End scope - before: depth=%d\n", scope_depth);
    if (scope_depth <= 0) return;
    Scope* s = scopes[--scope_depth];

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
    Scope* s = scopes[scope_depth - 1];
    for (VarEntry* v = s->vars; v; v = v->next) {
        if (strcmp(v->name, name) == 0) {
            fprintf(stderr, "Semantic Error: Variable '%s' redeclared in same scope\n", name);
            return 0;
        }
    }
    VarEntry* new_var = malloc(sizeof(VarEntry));
    new_var->name = strdup(name);
    new_var->type = strdup(type);
    new_var->next = s->vars;
    s->vars = new_var;
    return 1;
}

int check_variable_usage(const char* name) {
    for (int i = scope_depth - 1; i >= 0; i--) {
        for (VarEntry* v = scopes[i]->vars; v; v = v->next) {
            if (strcmp(v->name, name) == 0) return 1;
        }
    }
    fprintf(stderr, "Semantic Error: Variable '%s' used before declaration\n", name);
    return 0;
}

int insert_function(const char* name, const char* return_type, char** param_types, int param_count, AST* body) {
    // אם זה סקופ מקומי, בדק רק התנגשויות בסקופ הנוכחי
    if (scope_depth > 1) {
        Scope* current_scope = scopes[scope_depth - 1];
        for (LocalFuncEntry* lf = current_scope->local_funcs; lf; lf = lf->next) {
            if (strcmp(lf->global_func->name, name) == 0) {
                fprintf(stderr, "Semantic Error: Function '%s' redeclared\n", name);
                return 0;
            }
        }
    } else {
        // אם זה סקופ גלובלי, בדק התנגשויות בטבלה הגלובלית
        for (FuncEntry* f = function_table; f; f = f->next) {
            if (strcmp(f->name, name) == 0) {
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
    new_func->param_types = malloc(sizeof(char*) * param_count);
    for (int i = 0; i < param_count; i++) {
        new_func->param_types[i] = strdup(param_types[i]);
    }
    
    // שמור תמיד בטבלה הגלובלית (כדי שcheck_main_signature תמצא את _main_)
    new_func->next = function_table;
    function_table = new_func;
    
    // אם זה פונקציה מקומית, שמור גם ברשימה המקומית
    if (scope_depth > 1) {
        Scope* current_scope = scopes[scope_depth - 1];
        LocalFuncEntry* local_entry = malloc(sizeof(LocalFuncEntry));
        local_entry->global_func = new_func;
        local_entry->next = current_scope->local_funcs;
        current_scope->local_funcs = local_entry;
    }
    
    return 1;
}

int check_function_call(const char* name, char** arg_types, int arg_count) {
    for (FuncEntry* f = function_table; f; f = f->next) {
        if (strcmp(f->name, name) == 0) {
            if (f->param_count != arg_count) {
                fprintf(stderr, "Semantic Error: Function '%s' called with wrong number of arguments\n", name);
                return 0;
            }
            for (int i = 0; i < arg_count; i++) {
                if (strcmp(f->param_types[i], arg_types[i]) != 0) {
                    fprintf(stderr, "Semantic Error: Argument %d type mismatch in call to '%s'\n", i + 1, name);
                    return 0;
                }
            }
            return 1;
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
            
            // בדיקה נוספת - האם יש return בתוך הפונקציה
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