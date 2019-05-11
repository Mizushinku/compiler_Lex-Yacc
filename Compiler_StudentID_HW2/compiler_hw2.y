/*	Definition section */
%{
#include <stdio.h>

extern int yylineno;
extern int yylex();
void yyerror(char *);
extern char* yytext;   // Get current token from lex
extern char buf[256];  // Get current code line from lex

/* Symbol table function - you can add new function if needed. */
int lookup_symbol();
void create_symbol();
void insert_symbol();
void dump_symbol();

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
    : type init_declaration_list SEMICOLON
;

function_def
    : type declarator declaration_list compound_stat
    | type declarator compound_stat
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
    : ID
    | '(' declarator ')'
    | declarator '(' param_list ')'
    | declarator '(' ')'
    | declarator '(' id_list ')'
;

param_list
    : type declarator
    | param_list ',' type declarator
;

id_list
    : ID
    | id_list ',' ID
;

type
    : INT
    | FLOAT
    | BOOL
    | STRING
    | VOID
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

void create_symbol() {}
void insert_symbol() {}
int lookup_symbol() {}
void dump_symbol() {
    printf("\n%-10s%-10s%-12s%-10s%-10s%-10s\n\n",
           "Index", "Name", "Kind", "Type", "Scope", "Attribute");
}
