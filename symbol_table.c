
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
} Scope;

static Scope* scopes[MAX_SCOPE_DEPTH];
static int scope_depth = 0;
static FuncEntry* function_table = NULL;

int function_start_scope = 0;

// פונקציה לקביעת הטיפוס של ביטוי
char* get_expr_type(AST* expr) {
    if (!expr) return "unknown";
    
    // אם זה משתנה (ID)
    if (expr->child_count == 0) {
        // חפש בטבלת הסמלים
        for (int i = scope_depth - 1; i >= 0; i--) {
            for (VarEntry* v = scopes[i]->vars; v; v = v->next) {
                if (strcmp(v->name, expr->name) == 0) {
                    return v->type;
                }
            }
        }
        
        // אם זה מספר
        if (strchr(expr->name, '.')) {
            return "real";
        } else if (isdigit(expr->name[0])) {
            return "int";
        } else if (expr->name[0] == '"') {
            return "string";
        } else if (expr->name[0] == '\'') {
            return "char";
        } else if (strcmp(expr->name, "TRUE") == 0 || strcmp(expr->name, "FALSE") == 0) {
            return "bool";
        }
    }
    
    // אם זה ביטוי מתמטי
    if (strcmp(expr->name, "+") == 0 || strcmp(expr->name, "-") == 0 ||
        strcmp(expr->name, "*") == 0 || strcmp(expr->name, "/") == 0) {
        char* left_type = get_expr_type(expr->children[0]);
        char* right_type = get_expr_type(expr->children[1]);
        
        if (strcmp(left_type, "real") == 0 || strcmp(right_type, "real") == 0) {
            return "real";
        } else {
            return "int";
        }
    }
    
    // אם זה ביטוי לוגי
    if (strcmp(expr->name, "==") == 0 || strcmp(expr->name, "!=") == 0 ||
        strcmp(expr->name, "<") == 0 || strcmp(expr->name, ">") == 0 ||
        strcmp(expr->name, "<=") == 0 || strcmp(expr->name, ">=") == 0 ||
        strcmp(expr->name, "AND") == 0 || strcmp(expr->name, "OR") == 0 ||
        strcmp(expr->name, "NOT") == 0) {
        return "bool";
    }
    
    // אם זה קריאה לפונקציה
    if (strcmp(expr->name, "calll") == 0) {
        char* func_name = expr->children[0]->name;
        for (FuncEntry* f = function_table; f; f = f->next) {
            if (strcmp(f->name, func_name) == 0) {
                return f->return_type;
            }
        }
    }
    
    return "unknown";
}

char** get_call_arg_types(AST* call_args, int* arg_count) {
    printf("DEBUG: Extracting argument types from: %s\n", call_args->name);
    
    // אם אין פרמטרים
    if (!call_args || (strcmp(call_args->name, "par") == 0 && 
                     call_args->child_count == 1 && 
                     strcmp(call_args->children[0]->name, "NONE") == 0)) {
        printf("DEBUG: No arguments found\n");
        *arg_count = 0;
        return NULL;
    }
    
    // אם זה פרמטר בודד (לא par)
    if (strcmp(call_args->name, "par") != 0) {
        printf("DEBUG: Found single argument (not par)\n");
        *arg_count = 1;
        char** types = malloc(sizeof(char*) * 1);
        types[0] = strdup(get_expr_type(call_args));
        printf("DEBUG: Argument type: %s\n", types[0]);
        return types;
    }
    
    // כעת יש לנו מבנה par
    // בדיקת המבנה: אם יש שני ילדים, אז יש לנו שני פרמטרים
    if (call_args->child_count == 2) {
        printf("DEBUG: Found par node with 2 children - likely 2 params\n");
        *arg_count = 2;
        char** types = malloc(sizeof(char*) * 2);
        
        // הילד הראשון והשני הם הפרמטרים
        types[0] = strdup(get_expr_type(call_args->children[0]));
        types[1] = strdup(get_expr_type(call_args->children[1]));
        
        printf("DEBUG: Found 2 arguments of types: %s, %s\n", types[0], types[1]);
        return types;
    }
    
    // מקרה כללי - צריך לרקורסיבית לנתח את מבנה ה-par
    // ספירת הפרמטרים
    int count = 1; // לפחות פרמטר אחד
    AST* current = call_args;
    
    // אם יש לנו מבנה מורכב של par, נצטרך למצוא את כל הפרמטרים
    if (current->child_count >= 2 && strcmp(current->children[0]->name, "par") == 0) {
        count = 0;
        
        // עובר על כל שרשרת ה-par
        while (current) {
            count++; // הפרמטר האחרון בכל רמה
            
            // אם הילד הראשון הוא par, המשך לעבור עליו
            if (current->child_count >= 2 && strcmp(current->children[0]->name, "par") == 0) {
                current = current->children[0];
            } else {
                break;
            }
        }
    }
    
    printf("DEBUG: Found total of %d arguments\n", count);
    *arg_count = count;
    
    // הקצאת זיכרון למערך הטיפוסים
    char** types = malloc(sizeof(char*) * count);
    
    // מילוי הטיפוסים
    current = call_args;
    for (int i = count - 1; i >= 0; i--) {
        if (i == count - 1) {
            // הפרמטר האחרון הוא הילד האחרון של ה-par הנוכחי
            types[i] = strdup(get_expr_type(current->children[current->child_count - 1]));
        } else {
            // פרמטרים אחרים הם הילדים השניים של שרשרת ה-par
            types[i] = strdup(get_expr_type(current->children[1]));
            current = current->children[0];
        }
        
        printf("DEBUG: Argument %d type: %s\n", i, types[i]);
    }
    
    return types;
}

void begin_function_scope() {
    begin_scope();
    function_start_scope = scope_depth - 1;
    printf("DEBUG: Function scope starts at %d\n", function_start_scope);
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
    printf("DEBUG: Checking variable '%s' from scope %d-%d\n", 
            name, function_start_scope, scope_depth - 1);
    
    // בדוק רק סקופים מהפונקציה הנוכחית ומעלה
    for (int i = scope_depth - 1; i >= function_start_scope; i--) {
        for (VarEntry* v = scopes[i]->vars; v; v = v->next) {
            if (strcmp(v->name, name) == 0) {
                printf("DEBUG: Found variable '%s' in scope %d\n", name, i);
                return 1;
            }
        }
    }
    
    // בדיקה גם בסקופ הגלובלי (0) - זה עבור משתנים גלובליים
    if (function_start_scope > 0) {
        for (VarEntry* v = scopes[0]->vars; v; v = v->next) {
            if (strcmp(v->name, name) == 0) {
                printf("DEBUG: Found variable '%s' in global scope\n", name);
                return 1;
            }
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
    
    // בדיקה האם יש פרמטרים בכלל
    if (param_count > 0) {
        new_func->param_types = malloc(sizeof(char*) * param_count);
        
        // בדיקה האם param_types הוא NULL
        if (param_types != NULL) {
            // אם param_types תקין, העתק את הטיפוסים
            for (int i = 0; i < param_count; i++) {
                new_func->param_types[i] = strdup(param_types[i]);
            }
        } else {
            // אם param_types הוא NULL, השתמש בערך ברירת מחדל "int" לכל הפרמטרים
            for (int i = 0; i < param_count; i++) {
                new_func->param_types[i] = strdup("int");
            }
        }
    } else {
        // אם אין פרמטרים, אפס את המצביע
        new_func->param_types = NULL;
    }
    
    // שמור תמיד בטבלה הגלובלית (כדי ש-check_main_signature תמצא את _main_)
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
    printf("DEBUG: Checking function call to '%s' with %d arguments\n", name, arg_count);
    
    for (FuncEntry* f = function_table; f; f = f->next) {
        if (strcmp(f->name, name) == 0) {
            printf("DEBUG: Found function '%s' in table with %d parameters\n", name, f->param_count);
            
            // בדיקת מספר פרמטרים (סעיף 7)
            if (f->param_count != arg_count) {
                fprintf(stderr, "Semantic Error: Function '%s' called with wrong number of arguments (%d), expected %d\n", 
                        name, arg_count, f->param_count);
                return 0;
            }
            
            // בדיקת טיפוסי פרמטרים (סעיף 8)
            for (int i = 0; i < arg_count; i++) {
                printf("DEBUG: Checking parameter %d: expected '%s', got '%s'\n", 
                       i, f->param_types[i], arg_types[i]);
                
                if (strcmp(f->param_types[i], arg_types[i]) != 0) {
                    fprintf(stderr, "Semantic Error: Argument %d type mismatch in call to '%s', expected '%s', got '%s'\n", 
                            i + 1, name, f->param_types[i], arg_types[i]);
                    return 0;
                }
            }
            
            printf("DEBUG: Function call validation successful\n");
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