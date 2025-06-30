#ifndef THREE_ADDRESS_CODE_H
#define THREE_ADDRESS_CODE_H

#include "ast.h"

typedef struct {
    int temp_counter;
    int label_counter;
} CodeGenerator;

void init_code_generator(CodeGenerator* cg);
void generate_code(CodeGenerator* cg, AST* ast);
char* new_temp(CodeGenerator* cg);
char* new_label(CodeGenerator* cg);
void emit(const char* format, ...);
void generate_function(CodeGenerator* cg, AST* func_node);
void generate_statement(CodeGenerator* cg, AST* stmt);
void generate_expression(CodeGenerator* cg, AST* expr, char** result_temp);
void generate_assignment(CodeGenerator* cg, AST* assign);
void generate_if_statement(CodeGenerator* cg, AST* if_stmt);
void generate_while_statement(CodeGenerator* cg, AST* while_stmt);
void generate_function_call(CodeGenerator* cg, AST* call, char** result_temp);
void generate_logical_and(CodeGenerator* cg, AST* and_expr, char** result_temp, char* true_label, char* false_label);
void generate_logical_or(CodeGenerator* cg, AST* or_expr, char** result_temp, char* true_label, char* false_label);
int calculate_frame_size(AST* function_body);
int collect_parameters(AST* args, AST** param_list);
void generate_condition(CodeGenerator* cg, AST* condition, char* true_label, char* false_label);

#endif