#include "three_address_code.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>

void init_code_generator(CodeGenerator* cg) {
    cg->temp_counter = 0;
    cg->label_counter = 0;
}

char* new_temp(CodeGenerator* cg) {
    char* temp = malloc(10);
    sprintf(temp, "t%d", cg->temp_counter++);
    return temp;
}

char* new_label(CodeGenerator* cg) {
    char* label = malloc(10);
    sprintf(label, "L%d", cg->label_counter++);
    return label;
}

void emit(const char* format, ...) {
    va_list args;
    va_start(args, format);
    vprintf(format, args);
    va_end(args);
    printf("\n");
}

// החלף את הפונקציה generate_code בthree_address_code.c שלך:

void generate_code(CodeGenerator* cg, AST* ast) {
    if (!ast) return;
    
    // הAST שלך הוא מסובך עם CODE שמכיל CODE שמכיל CODE...
    // נצטרך לחפור עמוק יותר למצוא את הפונקציות האמיתיות
    
    if (strcmp(ast->name, "CODE") == 0) {
        // עבור על כל הילדים ברקורסיה
        for (int i = 0; i < ast->child_count; i++) {
            generate_code(cg, ast->children[i]);
        }
    } 
    else if (strcmp(ast->name, "FUNC") == 0) {
        // מצאנו פונקציה אמיתית!
        generate_function(cg, ast);
    }
    else {
        // עבור על הילדים
        for (int i = 0; i < ast->child_count; i++) {
            generate_code(cg, ast->children[i]);
        }
    }
}

void generate_function(CodeGenerator* cg, AST* func_node) {
    if (!func_node || strcmp(func_node->name, "FUNC") != 0) return;
    
    char* func_name = func_node->children[0]->name;
    
    AST* body;
    if (func_node->child_count == 5) {
        body = func_node->children[4]->children[0];
    } else {
        body = func_node->children[3]->children[0];
    }
    
    if (strcmp(func_name, "_main_") == 0) {
        emit("main:");
    } else {
        emit("%s:", func_name);
    }
    
    int frame_size = calculate_frame_size(body);
    emit("    BeginFunc %d", frame_size);
    
    generate_statement(cg, body);
    
    emit("    EndFunc");
}

// החלף גם את generate_statement בגרסה משופרת:

void generate_statement(CodeGenerator* cg, AST* stmt) {
    if (!stmt) return;
    
    if (strcmp(stmt->name, "STMTLIST") == 0) {
        for (int i = 0; i < stmt->child_count; i++) {
            generate_statement(cg, stmt->children[i]);
        }
    }
    else if (strcmp(stmt->name, "=") == 0) {
        generate_assignment(cg, stmt);
    }
    else if (strcmp(stmt->name, "IF") == 0 || strcmp(stmt->name, "IF-ELSE") == 0) {
        generate_if_statement(cg, stmt);
    }
    else if (strcmp(stmt->name, "while") == 0) {
        generate_while_statement(cg, stmt);
    }
    else if (strcmp(stmt->name, "RET") == 0) {
        char* temp_result = NULL;
        generate_expression(cg, stmt->children[0], &temp_result);
        emit("    Return %s", temp_result);
        free(temp_result);
    }
    else if (strcmp(stmt->name, "CALL") == 0) {
        char* temp_result = NULL;
        generate_function_call(cg, stmt, &temp_result);
        free(temp_result);
    }
    else if (strcmp(stmt->name, "ASSIGN-CALL") == 0) {
        // השמה מקריאה לפונקציה
        char* var_name = stmt->children[0]->name;
        char* temp_result = NULL;
        generate_function_call(cg, stmt->children[1], &temp_result);
        emit("    %s = %s", var_name, temp_result);
        free(temp_result);
    }
    else if (strcmp(stmt->name, "FUNC") == 0) {
        // פונקציה מקוננת!
        generate_function(cg, stmt);
    }
    // טיפול בהצהרות משתנים - אל תיצור קוד עבורם
    else if (strcmp(stmt->name, "VAR-DECLS") == 0 ||
             strcmp(stmt->name, "VARLIST") == 0 ||
             strcmp(stmt->name, "DECL") == 0 ||
             strcmp(stmt->name, "VAR-LIST") == 0 ||
             strcmp(stmt->name, "INIT-VAR") == 0 ||
             strcmp(stmt->name, "ARRAY-VAR") == 0) {
        // אל תעשה כלום - אלה הצהרות משתנים
        return;
    }
    else if (strcmp(stmt->name, "VAR-BLOCK") == 0 ||
             strcmp(stmt->name, "NESTED-BLOCK") == 0 ||
             strcmp(stmt->name, "BLOCK") == 0) {
        // בלוקים - עבור על התוכן
        for (int i = 0; i < stmt->child_count; i++) {
            generate_statement(cg, stmt->children[i]);
        }
    }
    else {
        // צמתים אחרים - נסה לעבור על הילדים
        for (int i = 0; i < stmt->child_count; i++) {
            generate_statement(cg, stmt->children[i]);
        }
    }
}

void generate_assignment(CodeGenerator* cg, AST* assign) {
    char* var_name = assign->children[0]->name;
    char* temp_result = NULL;
    
    generate_expression(cg, assign->children[1], &temp_result);
    emit("    %s = %s", var_name, temp_result);
    
    free(temp_result);
}


void generate_expression(CodeGenerator* cg, AST* expr, char** result_temp) {
    if (!expr || !result_temp) return;
    
    if (expr->child_count == 0) {
        if (isdigit(expr->name[0]) || expr->name[0] == '"' || expr->name[0] == '\'' ||
            strcmp(expr->name, "TRUE") == 0 || strcmp(expr->name, "FALSE") == 0) {
            *result_temp = new_temp(cg);
            emit("    %s = %s", *result_temp, expr->name);
        } else {
            *result_temp = strdup(expr->name);
        }
    }
    else if (strcmp(expr->name, "+") == 0 || strcmp(expr->name, "-") == 0 ||
             strcmp(expr->name, "*") == 0 || strcmp(expr->name, "/") == 0) {
        char* left_temp = NULL;
        char* right_temp = NULL;
        
        generate_expression(cg, expr->children[0], &left_temp);
        generate_expression(cg, expr->children[1], &right_temp);
        
        *result_temp = new_temp(cg);
        emit("    %s = %s %s %s", *result_temp, left_temp, expr->name, right_temp);
        
        free(left_temp);
        free(right_temp);
    }
    else if (strcmp(expr->name, "==") == 0 || strcmp(expr->name, "!=") == 0 ||
             strcmp(expr->name, "<") == 0 || strcmp(expr->name, ">") == 0 ||
             strcmp(expr->name, "<=") == 0 || strcmp(expr->name, ">=") == 0) {
        char* left_temp = NULL;
        char* right_temp = NULL;
        
        generate_expression(cg, expr->children[0], &left_temp);
        generate_expression(cg, expr->children[1], &right_temp);
        
        *result_temp = new_temp(cg);
        emit("    %s = %s %s %s", *result_temp, left_temp, expr->name, right_temp);
        
        free(left_temp);
        free(right_temp);
    }
    else if (strcmp(expr->name, "AND") == 0) {
        char* true_label = new_label(cg);
        char* false_label = new_label(cg);
        char* end_label = new_label(cg);
        
        *result_temp = new_temp(cg);
        
        generate_logical_and(cg, expr, result_temp, true_label, false_label);
        
        emit("%s:", true_label);
        emit("    %s = 1", *result_temp);
        emit("    Goto %s", end_label);
        
        emit("%s:", false_label);
        emit("    %s = 0", *result_temp);
        
        emit("%s:", end_label);
        
        free(true_label);
        free(false_label);
        free(end_label);
    }
    else if (strcmp(expr->name, "OR") == 0) {
        char* true_label = new_label(cg);
        char* false_label = new_label(cg);
        char* end_label = new_label(cg);
        
        *result_temp = new_temp(cg);
        
        generate_logical_or(cg, expr, result_temp, true_label, false_label);
        
        emit("%s:", true_label);
        emit("    %s = 1", *result_temp);
        emit("    Goto %s", end_label);
        
        emit("%s:", false_label);
        emit("    %s = 0", *result_temp);
        
        emit("%s:", end_label);
        
        free(true_label);
        free(false_label);
        free(end_label);
    }
    else if (strcmp(expr->name, "LENGTH") == 0) {
        // LENGTH של מחרוזת - |variable|
        if (expr->child_count > 0) {
            char* var_name = expr->children[0]->name;
            *result_temp = new_temp(cg);
            emit("    %s = |%s|", *result_temp, var_name);
        } else {
            // אם אין ילדים, זה שגיאה במבנה
            *result_temp = new_temp(cg);
            emit("    %s = |UNKNOWN|", *result_temp);
        }
    }
    else if (strcmp(expr->name, "calll") == 0) {
        generate_function_call(cg, expr, result_temp);
    }
    else {
        // במקום ליצור temp חדש, בדוק אם זה ביטוי מיוחד
        if (strcmp(expr->name, "LENGTH") == 0) {
            // מקרה נוסף של LENGTH
            *result_temp = new_temp(cg);
            emit("    %s = |UNKNOWN_VAR|", *result_temp);
        } else {
            *result_temp = new_temp(cg);
            emit("    %s = %s", *result_temp, expr->name);
        }
    }
}

void generate_logical_and(CodeGenerator* cg, AST* and_expr, char** result_temp, char* true_label, char* false_label) {
    char* left_temp = NULL;
    char* check_right_label = new_label(cg);
    
    generate_expression(cg, and_expr->children[0], &left_temp);
    emit("    if %s Goto %s", left_temp, check_right_label);
    emit("    goto %s", false_label);
    
    emit("%s:", check_right_label);
    char* right_temp = NULL;
    generate_expression(cg, and_expr->children[1], &right_temp);
    emit("    if %s Goto %s", right_temp, true_label);
    emit("    goto %s", false_label);
    
    free(left_temp);
    free(right_temp);
    free(check_right_label);
}

void generate_logical_or(CodeGenerator* cg, AST* or_expr, char** result_temp, char* true_label, char* false_label) {
    char* left_temp = NULL;
    
    generate_expression(cg, or_expr->children[0], &left_temp);
    emit("    if %s Goto %s", left_temp, true_label);
    
    char* right_temp = NULL;
    generate_expression(cg, or_expr->children[1], &right_temp);
    emit("    if %s Goto %s", right_temp, true_label);
    emit("    goto %s", false_label);
    
    free(left_temp);
    free(right_temp);
}

void generate_if_statement(CodeGenerator* cg, AST* if_stmt) {
    char* true_label = new_label(cg);
    char* false_label = new_label(cg);
    char* end_label = new_label(cg);
    
    generate_condition(cg, if_stmt->children[0], true_label, false_label);
    
    emit("%s:", true_label);
    generate_statement(cg, if_stmt->children[1]);
    
    if (strcmp(if_stmt->name, "IF-ELSE") == 0) {
        emit("    Goto %s", end_label);
        
        emit("%s:", false_label);
        generate_statement(cg, if_stmt->children[2]);
        
        emit("%s:", end_label);
    } else {
        emit("%s:", false_label);
    }
    
    free(true_label);
    free(false_label);
    free(end_label);
}

void generate_while_statement(CodeGenerator* cg, AST* while_stmt) {
    char* loop_label = new_label(cg);
    char* body_label = new_label(cg);
    char* end_label = new_label(cg);
    
    emit("%s:", loop_label);
    
    generate_condition(cg, while_stmt->children[0], body_label, end_label);
    
    emit("%s:", body_label);
    generate_statement(cg, while_stmt->children[1]);
    emit("    Goto %s", loop_label);
    
    emit("%s:", end_label);
    
    free(loop_label);
    free(body_label);
    free(end_label);
}

void generate_condition(CodeGenerator* cg, AST* condition, char* true_label, char* false_label) {
    char* temp_result = NULL;
    generate_expression(cg, condition, &temp_result);
    emit("    if %s Goto %s", temp_result, true_label);
    emit("    goto %s", false_label);
    free(temp_result);
}

void generate_function_call(CodeGenerator* cg, AST* call, char** result_temp) {
    char* func_name = call->children[0]->name;
    AST* args = call->children[1];
    
    int param_count = 0;
    
    if (args && strcmp(args->name, "par") == 0 && 
        !(args->child_count == 1 && strcmp(args->children[0]->name, "NONE") == 0)) {
        
        AST* param_list[10]; // מקסימום 10 פרמטרים
        param_count = collect_parameters(args, param_list);
        
        for (int i = param_count - 1; i >= 0; i--) {
            char* temp = NULL;
            generate_expression(cg, param_list[i], &temp);
            emit("    PushParam %s", temp);
            free(temp);
        }
    }
    
    *result_temp = new_temp(cg);
    emit("    %s = LCall %s", *result_temp, func_name);
    
    if (param_count > 0) {
        emit("    PopParams %d", param_count * 4);
    }
}

int collect_parameters(AST* args, AST** param_list) {
    if (!args) return 0;
    
    int count = 0;
    
    if (strcmp(args->name, "par") == 0) {
        if (args->child_count == 2) {
            // יש שני ילדים - הראשון עוד פרמטרים, השני פרמטר יחיד
            count += collect_parameters(args->children[0], param_list);
            param_list[count] = args->children[1];
            count++;
        } else if (args->child_count == 1) {
            // פרמטר יחיד או NONE
            if (strcmp(args->children[0]->name, "NONE") != 0) {
                param_list[count] = args->children[0];
                count++;
            }
        }
    } else {
        // ביטוי רגיל
        param_list[count] = args;
        count++;
    }
    
    return count;
}

int calculate_frame_size(AST* function_body) {
    return 24;
}