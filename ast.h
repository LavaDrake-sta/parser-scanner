#ifndef AST_H
#define AST_H

typedef struct ast_node {
    char* name;
    struct ast_node** children;
    int child_count;
} AST;

#endif
