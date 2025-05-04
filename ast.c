#include "ast.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

AST* make_node(char* name, int count, ...) {
    AST* node = (AST*)malloc(sizeof(AST));
    node->name = name ? strdup(name) : NULL;
    node->child_count = count;
    node->children = (AST**)malloc(sizeof(AST*) * count);
    if (!node) {
    fprintf(stderr, "make_node: malloc failed\n");
    exit(1);
}

    va_list args;
    va_start(args, count);
    if (count > 0 && !node->children) {
    fprintf(stderr, "make_node: children malloc failed\n");
    exit(1);
}
    for (int i = 0; i < count; i++) {
        node->children[i] = va_arg(args, AST*);
    }
    va_end(args);
    return node;
}

void print_ast(AST* node, int indent) {
    if (!node) return;
    for (int i = 0; i < indent; i++) printf(" ");
    if (node->name) printf("(%s\n", node->name);
    for (int i = 0; i < node->child_count; i++) {
        print_ast(node->children[i], indent + 2);
    }
    if (node->name) {
        for (int i = 0; i < indent; i++) printf(" ");
        printf(")\n");
    }
}