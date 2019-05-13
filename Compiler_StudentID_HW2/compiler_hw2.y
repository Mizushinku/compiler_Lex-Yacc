/*	Definition section */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylineno;
extern int yylex();
void yyerror(char *);
extern char* yytext;   // Get current token from lex
extern char buf[256];  // Get current code line from lex

// define symbol table entry
typedef struct TABLE_ENTYR {
    int index;
    char name[10];
    char kind[12];
    char type[10];
    int scope;
    char attribute[10];
    struct TABLE_ENTYR *next;
}ste_t;

/* Symbol table function - you can add new function if needed. */
int lookup_symbol();
void create_symbol(int, int);
void insert_symbol(ste_t *);
void dump_symbol(int, int);
void add_attri();
void clear_tmp(int);


// define enum for entry data 'kind' and 'type'
enum E_KIND { init_kind = -1, var, func, param };
enum E_TYPE { init_type = -1, e_int, e_float, e_bool, e_string, e_void };

// define string which is related to enum
char *kind_str[3] = { "variable", "function", "parameter" };
char *type_str[5] = { "int", "float", "bool", "string", "void" };

int scope = 0;

char name_tmp[10] = {}, attri_tmp[30] = {};
enum E_KIND kind_num = init_kind;
enum E_TYPE type_num = init_type;

char name_tmp_p[10] = {};
enum E_KIND kind_num_p = init_kind;
enum E_TYPE type_num_p = init_type;

ste_t *table_heads[10] = {NULL};

%}

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 */
%union {
    int i_val;
    double f_val;
    char* string;
}

/* Token without return */
%token PRINT 
%token IF FOR WHILE
%token ID SEMICOLON QUO
%token INT FLOAT STRING BOOL VOID
%token INC DEC
%token MT LT MTE LTE EQ NE
%token ADDASGN SUBASGN MULASGN DIVASGN MODASGN
%token AND OR NOT
%token TRUE FALSE
%token RET

/* for if-else shift/reduce conflict */
%nonassoc NO_ELSE
%nonassoc ELSE



/* Token with return, which need to sepcify type */
%token <i_val> I_CONST
%token <f_val> F_CONST
%token <string> STRING_CONST

/* Nonterminal with return, which need to sepcify type */
//%type <f_val> stat
//%type <string> string_with_quo

/* Yacc will start at this nonterminal */
%start program

/* Grammar section */
%%

program
    : external_things
    | program external_things
;

external_things
    : declaration
    | function_def
;

declaration
    : type init_declaration_list SEMICOLON {
        if(kind_num == var)
            create_symbol(scope, 0);
        clear_tmp(0);
        if(table_heads[scope+1] != NULL) {
            dump_symbol(scope+1, 1);
        }
    }
;

function_def
    : type declarator declaration_list compound_stat
    | type declarator compound_stat {
        if(kind_num == func)
            create_symbol(scope, 0);
        clear_tmp(0);
    }
;

declaration_list
    : declaration
    | declaration_list declaration
;

init_declaration_list
    : init_declaration
    | init_declaration_list ',' init_declaration
;

init_declaration
    : declarator '=' initializer
    | declarator
;

declarator
    : ID {
        strcpy(name_tmp, yytext);
        kind_num = var;
    }
    | '(' declarator ')'
    | declarator '(' param_list ')' { kind_num = func; }
    | declarator '(' ')' { kind_num = func; }
    | declarator '(' id_list ')'
;

param_list
    : type_p ID { strcpy(name_tmp_p, yytext); kind_num_p = param; create_symbol(scope+1, 1); clear_tmp(1); }
    | param_list ',' type_p ID { strcpy(name_tmp_p, yytext); kind_num_p = param; create_symbol(scope+1, 1); clear_tmp(1); }
;

id_list
    : ID
    | id_list ',' ID
;

type
    : INT    { type_num = e_int; }
    | FLOAT  { type_num = e_float; }
    | BOOL   { type_num = e_bool; }
    | STRING { type_num = e_string; }
    | VOID   { type_num = e_void; }
;

type_p
    : INT    { type_num_p = e_int; add_attri(); }
    | FLOAT  { type_num_p = e_float; add_attri(); }
    | BOOL   { type_num_p = e_bool; add_attri(); }
    | STRING { type_num_p = e_string; add_attri(); }
    | VOID   { type_num_p = e_void; add_attri(); }
;

initializer
    : assigment_exp
;

assigment_exp
    : conditional_exp
    | unary_exp asgn_operator assigment_exp
;

conditional_exp
    : logical_or_exp
;

logical_or_exp
    : logical_and_exp
    | logical_or_exp OR logical_and_exp
;

logical_and_exp
    : equality_exp
    | logical_and_exp AND equality_exp
;

equality_exp
    : relational_exp
    | equality_exp EQ relational_exp
    | equality_exp NE relational_exp
;

relational_exp
    : additive_exp
    | relational_exp MT additive_exp
    | relational_exp LT additive_exp
    | relational_exp MTE additive_exp
    | relational_exp LTE additive_exp
;

additive_exp
    : multiplicative_exp
    | additive_exp '+' multiplicative_exp
    | additive_exp '-' multiplicative_exp
;

multiplicative_exp
    : unary_exp
    | multiplicative_exp '*' unary_exp
    | multiplicative_exp '/' unary_exp
    | multiplicative_exp '%' unary_exp
;

unary_exp
    : postfix_exp
    | INC unary_exp
    | DEC unary_exp
    | unary_operator unary_exp
;

unary_operator
    : '+'
    | '-'
    | NOT
;

postfix_exp
    : primary_exp
    | postfix_exp '[' expression ']'
    | postfix_exp '(' ')'
    | postfix_exp '(' argument_exp_list ')'
    | postfix_exp INC
    | postfix_exp DEC
;

primary_exp
    : ID
    | constant
    | '(' expression ')'
;

expression
    : assigment_exp
    | expression ',' assigment_exp
;

constant
    : I_CONST
    | F_CONST
    | STRING_CONST
    | TRUE
    | FALSE
;


argument_exp_list
    : assigment_exp
    | argument_exp_list ',' assigment_exp
;

asgn_operator
    : '='
    | MULASGN
    | DIVASGN
    | MODASGN
    | ADDASGN
    | SUBASGN
;

statement
    : compound_stat
    | expression_stat
    | selection_stat
    | iteration_stat
    | jump_stat
    | print_stat
;

compound_stat
    : '{' '}'
    | '{' block_item_list '}'
;

block_item_list
    : block_item
    | block_item_list block_item
;

block_item
    : declaration
    | statement
;

expression_stat
    : SEMICOLON
    | expression SEMICOLON
;

selection_stat
    : IF '(' expression ')' statement ELSE statement
    | IF '(' expression ')' statement %prec NO_ELSE
;

iteration_stat
    : WHILE '(' expression ')' statement
;

jump_stat
    : RET SEMICOLON
    | RET expression SEMICOLON
;

print_stat
    : PRINT '(' expression ')' SEMICOLON
;

%%

/* C code section */
int main(int argc, char** argv)
{
    yylineno = 0;

    yyparse();
    dump_symbol(scope, 0);
	printf("\nTotal lines: %d \n",yylineno);

    return 0;
}

void yyerror(char *s)
{
    printf("\n|-----------------------------------------------|\n");
    printf("| Error found in line %d: %s\n", yylineno, buf);
    printf("| %s", s);
    printf("\n|-----------------------------------------------|\n\n");
}

void create_symbol(int target, int mod)
{
    /* if mod == 0 ... normal symbol
     *    mod == 1 ... parameter symbol
     */
    if(mod == 0) {
        ste_t *ste = malloc(sizeof(ste_t));
        strcpy(ste->name, name_tmp);
        strcpy(ste->kind, kind_str[kind_num]);
        strcpy(ste->type, type_str[type_num]);
        ste->scope = target;
        strcpy(ste->attribute, attri_tmp);
        ste->next = NULL;

        insert_symbol(ste);
    } else if(mod == 1) {
        ste_t *ste = malloc(sizeof(ste_t));
        strcpy(ste->name, name_tmp_p);
        strcpy(ste->kind, kind_str[kind_num_p]);
        strcpy(ste->type, type_str[type_num_p]);
        ste->scope = target;
        strcpy(ste->attribute, "");
        ste->next = NULL;

        insert_symbol(ste);
    }
}

void insert_symbol(ste_t *ste)
{
    int head_index = ste->scope;
    if(table_heads[head_index] == NULL) {
        table_heads[head_index] = ste;
        ste->index = 0;
    } else {
        ste_t *it = table_heads[head_index];
        int cur_index = it->index;
        while(it->next != NULL) {
            it = it->next;
            cur_index = it->index;
        }
        it->next = ste;
        ste->index = cur_index + 1;
    }
}

int lookup_symbol()
{

}

void dump_symbol(int target, int mod)
{   
    /* if mod == 0, print and free the symbol table
     * if mod != 0, only free the symbol table
    */
    if(table_heads[target] != NULL) {
        if(mod == 0) {
            printf("\n%-10s%-10s%-12s%-10s%-10s%-10s\n\n",
                "Index", "Name", "Kind", "Type", "Scope", "Attribute");
        
            ste_t *it = table_heads[target];
            ste_t *cur;
            while(it != NULL) {
                printf("%-10d%-10s%-12s%-10s%-10d%-10s\n",
                    it->index, it->name, it->kind, it->type, it->scope, it->attribute);
                cur = it;
                it = it->next;
                free(cur);
            }
            table_heads[target] = NULL;
            
            printf("\n");
        }else {
            ste_t *it = table_heads[target];
            ste_t *cur;
            while(it != NULL) {
                cur = it;
                it = it->next;
                free(cur);
            }
            table_heads[target] = NULL;
        }
    }
}

void add_attri()
{
    if(strlen(attri_tmp) == 0) {
        strcpy(attri_tmp, yytext);
    }else {
        strcat(attri_tmp, ", ");
        strcat(attri_tmp, yytext);
    } 
}

void clear_tmp(int mod)
{
    if(mod == 0) {
        memset(name_tmp, 0, 10);
        memset(attri_tmp, 0, 30);      
        kind_num = init_kind;
        type_num = init_type;
    }else if(mod == 1) {
        memset(name_tmp_p, 0, 10);
        kind_num_p = init_kind;
        type_num_p = init_type;
    }
}
