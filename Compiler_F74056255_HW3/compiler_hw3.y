/*	Definition section */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FNAME "compiler_hw3.j"

extern int yylineno;
extern int yylex();
void yyerror(char *);
extern char* yytext;   // Get current token from lex
extern char buf[256];  // Get current code line from lex
FILE *fp;

// define symbol table entry
typedef struct TABLE_ENTYR {
    int index;
    char name[10];
    char kind[12];
    char type[10];
    int scope;
    char attribute[30];
    struct TABLE_ENTYR *next;
}ste_t;

// define j_stack item and stack
/*
typedef struct J_ITEM {
    union
    {
        int i_data;
    };
}j_item_t;

typedef struct J_STACK {
    ste_t *head;
    ste_t *curn;
    void (*push)(int);
}j_stack_t;
*/



/* Symbol table function - you can add new function if needed. */
int lookup_symbol(ste_t *);
int lookup_symbol_by_name(char *, int);
void create_symbol(int, int);
void insert_symbol(ste_t *);
void dump_symbol(int, int);
void add_attri();
void clear_tmp(int);

//Jasmin Functions
void dcl_var(int, int, char*);
void j_func_def();
int j_lookup_symbol(char *);
void j_check_cast(int, int);
void j_arithmetic_cast(int*, int*);
int j_add(int, int);
int j_sub(int, int);
int j_mul(int, int);
int j_div(int, int);
int j_mod(int, int);
void j_get_2_tos_type(int *, int *);
void j_make_label(int, int, int);
void j_call_func(int);



//Jasmin things
char *jtype[5] = { "I", "F", "Z", "Ljava/lang/String;", "V" };
char *jicmps[6] = {
    "if_icmpeq",
    "if_icmpne",
    "if_icmpgt",
    "if_icmplt",
    "if_icmpge",
    "if_icmple"
};
int label_stack[100] = {0};

int g_int = 0;
float g_float = 0.0;
int g_bool = 0;
char g_string[100] = {};
int cur_func_type = -1;
int call_func_info = -1;
char cur_fname[10] = {};

int digit_for_type = 0;
int has_init = 0;
int has_inc_or_dec = 0;
int is_cur_zero_const = 0;
int is_while = 0;
int not_gen_jfile = 0;

int asgn_code = -1;
int label_tos = -1;
int if_label = 0;
int while_label = 1;


// define enum
enum E_KIND { init_kind = -1, var, func, param };
enum E_TYPE { init_type = -1, e_int, e_float, e_bool, e_string, e_void };
enum E_ERRNO { init_errno = -1, uv, uf, rv, rf, dz, mf };
enum E_ASGN { inti_asgn = -1, noma, adda, suba, mula, diva, moda };

// define string which is related to enum
char *kind_str[3] = { "variable", "function", "parameter" };
char *type_str[5] = { "int", "float", "bool", "string", "void" };
char *serr_str[6] = {
    "Undeclared variable ",
    "Undeclared function ",
    "Redeclared variable ",
    "Redeclared function ",
    "Divide by zero", 
    "Mod on float"
};

int scope = 0, has_error = 0;

char name_tmp[10] = {}, attri_tmp[30] = {};
enum E_KIND kind_num = init_kind;
enum E_TYPE type_num = init_type;

char name_tmp_p[10] = {};
enum E_KIND kind_num_p = init_kind;
enum E_TYPE type_num_p = init_type;

char err_msg[50] = {};
enum E_ERRNO err_num = init_errno;

ste_t *table_heads[10] = {NULL};
//te_stack_t stack;



%}

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 */
%union {
    int i_val;
    double f_val;
    char* string;
    char* curID;
}

/* Token without return */
%token PRINT 
%token IF FOR WHILE
%token SEMICOLON QUO
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
%token <curID> ID

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
    | function_def { fprintf(fp, ".end method\n"); }
;

declaration
    : type init_declaration_list SEMICOLON {
        if(kind_num == var) {
            create_symbol(scope, 0);
        
            if(scope == 0) {
                dcl_var(scope, type_num, name_tmp);
            }
            else {
                int tos_type = type_num;
                if(has_init == 0) {
                    if(type_num == e_string) {
                        fprintf(fp, "    ldc \"\"\n");
                    }
                    else if(type_num == e_float){
                        fprintf(fp, "    ldc 0.0\n");
                    }
                    else {
                        fprintf(fp, "    ldc 0\n");
                    }
                }
                else {
                    tos_type = digit_for_type % 10 - 1;
                    digit_for_type /= 10;
                    has_init = 0;
                }

                int stack_num = j_lookup_symbol(name_tmp);

                if(type_num == e_float) {
                    j_check_cast(type_num, tos_type);
                    fprintf(fp, "    fstore %d\n", stack_num);
                }
                else if(type_num == e_string) {
                    fprintf(fp, "    astore %d\n", stack_num);
                }
                else {
                    if(type_num == e_int) j_check_cast(type_num, tos_type);
                    fprintf(fp, "    istore %d\n", stack_num);
                }
            }
        }
        clear_tmp(0);
    }
    | type declarator '(' ')' SEMICOLON { clear_tmp(0); }
    | type declarator '(' param_list ')' SEMICOLON { clear_tmp(0); dump_symbol(scope+1, 1); }
;

function_def
    : type declarator_2 declaration_list compound_stat
    | type declarator_2 compound_stat
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
    : declarator '=' initializer { has_init = 1; }
    | declarator { has_init = 0; }
;

declarator
    : ID {
        strcpy(name_tmp, yytext);
        kind_num = var;
    }
    | '(' declarator ')'
    | declarator '(' id_list ')'
;

declarator_2
    : declarator '(' ')' {
        kind_num = func;
        create_symbol(scope-1, 0);
        j_func_def();
        clear_tmp(0);
    }
    | declarator '(' param_list ')' {
        kind_num = func;
        create_symbol(scope-1, 0);
        j_func_def();
        clear_tmp(0);
    }
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
    : types
;

types
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
    : conditional_exp {
        if(has_inc_or_dec) {
            has_inc_or_dec = 0;
        }
    }
;

assigment_exp
    : conditional_exp {
        if(has_inc_or_dec) {
            has_inc_or_dec = 0;
            fprintf(fp, "    pop\n");
            digit_for_type /= 10;
        }
    }
    | ID asgn_operator assigment_exp {
        if(has_inc_or_dec) {
            has_inc_or_dec = 0;
        }

        int id_type = lookup_symbol_by_name($1, 1);
        int stack_num = j_lookup_symbol($1);
        int tos_type = digit_for_type % 10 - 1;
        digit_for_type /= 10;

        if(stack_num < 0) {
            fprintf(fp, "    getstatic compiler_hw3/%s %s\n", $1, jtype[id_type]);
        }
        else {
            if(id_type == e_float) {
                fprintf(fp, "    fload %d\n", stack_num);
            }
            else if(id_type == e_string) {
                fprintf(fp, "    aload %d\n", stack_num);
            }
            else {
                fprintf(fp, "    iload %d\n", stack_num);
            }
        }
        fprintf(fp, "    swap\n");

        if(asgn_code == noma) {
            fprintf(fp, "    swap\n");
            fprintf(fp, "    pop\n");
        }
        else if(asgn_code == adda) {
            tos_type = j_add(tos_type, id_type);
        }
        else if(asgn_code == suba) {
            tos_type = j_sub(tos_type, id_type);
        }
        else if(asgn_code == mula) {
            tos_type = j_mul(tos_type, id_type);
        }
        else if(asgn_code == diva) {
            if(is_cur_zero_const) {
                is_cur_zero_const = 0;
                fprintf(fp, "    pop\n");
                tos_type = id_type;
                err_num = dz;
                strcpy(err_msg, serr_str[err_num]);
                has_error = 1;
            }
            else {
                tos_type = j_div(tos_type, id_type);
            }
        }
        else if(asgn_code == moda){
            if(tos_type != e_int || id_type != e_int) {
                fprintf(fp, "    pop\n");
                tos_type = id_type;
                err_num = mf;
                strcpy(err_msg, serr_str[err_num]);
                has_error = 1;
            }
            else {
                tos_type = j_mod(tos_type, id_type);
            }
        }

        j_check_cast(id_type, tos_type);

        if(stack_num < 0) {
            fprintf(fp, "    putstatic compiler_hw3/%s %s\n", $1, jtype[id_type]);
        }
        else {
            if(id_type == e_float) {
                fprintf(fp, "    fstore %d\n", stack_num);
            }
            else if(id_type == e_string) {
                fprintf(fp, "    astore %d\n", stack_num);
            }
            else {
                fprintf(fp, "    istore %d\n", stack_num);
            }
        }

        asgn_code = inti_asgn;
    }
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
    | equality_exp EQ relational_exp {
        j_make_label(0, 1, 1);
    }
    | equality_exp NE relational_exp {
        j_make_label(0, 0, 0);
    }
;

relational_exp
    : additive_exp
    | relational_exp MT additive_exp {
        j_make_label(1, 1, 5);
    }
    | relational_exp LT additive_exp {
        j_make_label(-1, 1, 4);
    }
    | relational_exp MTE additive_exp {
        j_make_label(-1, 0, 3);
    }
    | relational_exp LTE additive_exp {
        j_make_label(1, 0, 2);
    }
;

additive_exp
    : multiplicative_exp
    | additive_exp '+' multiplicative_exp {
        int tos_type, snd_type;
        j_get_2_tos_type(&tos_type, &snd_type);
        digit_for_type *= 10;
        digit_for_type += j_add(tos_type, snd_type) + 1;
    }
    | additive_exp '-' multiplicative_exp {
        int tos_type, snd_type;
        j_get_2_tos_type(&tos_type, &snd_type);
        digit_for_type *= 10;
        digit_for_type += j_sub(tos_type, snd_type) + 1;
    }
;

multiplicative_exp
    : unary_exp
    | multiplicative_exp '*' unary_exp {
        int tos_type, snd_type;
        j_get_2_tos_type(&tos_type, &snd_type);
        digit_for_type *= 10;
        digit_for_type += j_mul(tos_type, snd_type) + 1;
    }
    | multiplicative_exp '/' unary_exp {
        if(is_cur_zero_const) {
            is_cur_zero_const = 0;
            fprintf(fp, "    pop\n");
            digit_for_type /= 10;
            err_num = dz;
            strcpy(err_msg, serr_str[err_num]);
            has_error = 1;
        }
        else {
            int tos_type, snd_type;
            j_get_2_tos_type(&tos_type, &snd_type);
            digit_for_type *= 10;
            digit_for_type += j_div(tos_type, snd_type) + 1;
        }
    }
    | multiplicative_exp '%' unary_exp {
        int tos_type, snd_type;
        j_get_2_tos_type(&tos_type, &snd_type);
        if(tos_type != e_int || snd_type != e_int) {
            fprintf(fp, "    pop\n");
            digit_for_type *= 10;
            digit_for_type += snd_type + 1;
            err_num = mf;
            strcpy(err_msg, serr_str[err_num]);
            has_error = 1;
        }
        else {
            digit_for_type *= 10;
            digit_for_type += j_mod(tos_type, snd_type) + 1;
        }
    }
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
    | function_call_exp
    | ID INC {
        digit_for_type *= 10;
        ++digit_for_type;
        int stack_num = j_lookup_symbol($1);

        if(stack_num < 0) {
            fprintf(fp, "    getstatic compiler_hw3/%s I\n", $1);
        }
        else {
            fprintf(fp, "    iload %d\n", stack_num);
        }

        fprintf(fp, "    dup\n");
        fprintf(fp, "    ldc 1\n");
        fprintf(fp, "    iadd\n");
        if(stack_num < 0) {
            fprintf(fp, "    putstatic compiler_hw3/%s I\n", $1);
        }
        else {
            fprintf(fp, "    istore %d\n", stack_num);
        }
        has_inc_or_dec  = 1;
    }
    | ID DEC {
        digit_for_type *= 10;
        ++digit_for_type;
        int stack_num = j_lookup_symbol($1);

        if(stack_num < 0) {
            fprintf(fp, "    getstatic compiler_hw3/%s I\n", $1);
        }
        else {
            fprintf(fp, "    iload %d\n", stack_num);
        }

        fprintf(fp, "    dup\n");
        fprintf(fp, "    ldc 1\n");
        fprintf(fp, "    isub\n");
        if(stack_num < 0) {
            fprintf(fp, "    putstatic compiler_hw3/%s I\n", $1);
        }
        else {
            fprintf(fp, "    istore %d\n", stack_num);
        }
        has_inc_or_dec  = 1;
    }
;

function_call_exp
    : function_ID '(' ')' {
        j_call_func(call_func_info);
    }
    | function_ID '(' argument_exp_list ')' {
        j_call_func(call_func_info);
    }
;

function_ID
    : ID {
        if(has_error == 0) {
            call_func_info = lookup_symbol_by_name($1, 2);
            strcpy(cur_fname, $1);
        }
    }
;

primary_exp
    : ID {
        if(has_error == 0) {
            int id_type = lookup_symbol_by_name($1, 1);
            if(id_type >= 0) {
                digit_for_type *= 10;
                digit_for_type += id_type + 1;
                int stack_num = j_lookup_symbol($1);
                if(stack_num < 0) {
                    fprintf(fp, "    getstatic compiler_hw3/%s %s\n", $1, jtype[id_type]);
                }
                else {
                    if(id_type == e_float) {
                        fprintf(fp, "    fload %d\n", stack_num);
                    }
                    else if(id_type == e_string) {
                        fprintf(fp, "    aload %d\n", stack_num);
                    }
                    else {
                        fprintf(fp, "    iload %d\n", stack_num);
                    }
                }
            }
            is_cur_zero_const = 0;
        }
    }
    | constant
    | '(' expression ')'
;

expression
    : assigment_exp
    | expression ',' assigment_exp
;

constant
    : I_CONST {
        if(has_error == 0) {
            if(scope == 0) {
                if(type_num == e_float) {
                    g_float = (float)$1;
                }
                else {
                    g_int = $1;
                }
            }
            else {
                fprintf(fp, "    ldc %d\n", $1);
                digit_for_type *= 10;
                digit_for_type += 1;
                if($1 == 0) {
                    is_cur_zero_const = 1;
                } else {
                    is_cur_zero_const = 0;
                }
            }
        }
    }
    | F_CONST {
        if(has_error == 0) {
            if(scope == 0) {
                if(type_num == e_int) {
                    g_int = (int)$1;
                }
                else {
                    g_float = $1;
                }
            }
            else {
                fprintf(fp, "    ldc %f\n", $1);
                digit_for_type *= 10;
                digit_for_type += 2;
                is_cur_zero_const = 0;
            }
        }
    }
    | STRING_CONST {
        if(has_error == 0) {
            if(scope == 0) strcpy(g_string, $1);
            else {
                fprintf(fp, "    ldc \"%s\"\n", $1);
                digit_for_type *= 10;
                digit_for_type += 4;
                is_cur_zero_const = 0;
            }
        }
    }
    | TRUE {
        if(has_error == 0) {
            if(scope == 0) g_bool = 1;
            else {
                fprintf(fp, "    ldc 1\n");
                digit_for_type *= 10;
                digit_for_type += 3;
                is_cur_zero_const = 0;
            }
        }
    }
    | FALSE {
        if(has_error == 0) {
            if(scope == 0) g_bool = 0;
            else {
                fprintf(fp, "    ldc 0\n");
                digit_for_type *= 10;
                digit_for_type += 3;
                is_cur_zero_const = 0;
            }
        }
    }
;


argument_exp_list
    : assigment_exp
    | argument_exp_list ',' assigment_exp
;

asgn_operator
    : '=' { asgn_code = noma; }
    | ADDASGN { asgn_code = adda; }
    | SUBASGN { asgn_code = suba; }
    | MULASGN { asgn_code = mula; }
    | DIVASGN { asgn_code = diva; }
    | MODASGN { asgn_code = moda; }
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
    : if_stat '(' expression ')' statement else_stat statement {
        fprintf(fp, "E%d :\n", label_stack[label_tos]);
        label_stack[label_tos] = 0;
        --label_tos;
    }
    | if_stat '(' expression ')' statement %prec NO_ELSE {
        fprintf(fp, "L%d :\n", label_stack[label_tos]);
        label_stack[label_tos] = 0;
        --label_tos;
    }
;

if_stat
    : IF {
        if(label_tos <= 100) {
            ++label_tos;
            ++if_label;
            label_stack[label_tos] = if_label;
        }
    }
;

else_stat
    : ELSE {
        fprintf(fp, "    goto E%d\n", label_stack[label_tos]);
        fprintf(fp, "L%d :\n", label_stack[label_tos]);
    }
;

iteration_stat
    : while_stat '(' expression ')' statement {
        fprintf(fp, "    goto W%d\n", while_label - 1);
        fprintf(fp, "WE%d :\n", while_label - 1);
    }
;

while_stat
    : WHILE {
        is_while = 1;
        fprintf(fp, "W%d :\n", while_label);
        ++while_label;
    }
;

jump_stat
    : RET SEMICOLON { fprintf(fp, "    return\n"); }
    | RET expression SEMICOLON {
        int tos_type = digit_for_type % 10 - 1;
        if(tos_type == e_float) {
            fprintf(fp, "    freturn\n");
        }
        else {
            fprintf(fp, "    ireturn\n");
        }
    }
;

print_stat
    : PRINT '(' expression ')' SEMICOLON {
        int digit = digit_for_type % 10 - 1;
        digit_for_type /= 10;
        fprintf(fp, "    getstatic java/lang/System/out Ljava/io/PrintStream;\n");
        fprintf(fp, "    swap\n");
        fprintf(fp, "    invokevirtual java/io/PrintStream/println(%s)V\n", jtype[digit]);
    }
;

%%

/* C code section */
int main(int argc, char** argv)
{
    yylineno = 0;
    fp = fopen(FNAME, "w");

    fprintf(fp, ".class public compiler_hw3\n");
    fprintf(fp, ".super java/lang/Object\n");

    yyparse();
    dump_symbol(scope, 0);
	printf("\nTotal lines: %d \n",yylineno);

    fclose(fp);

    if(not_gen_jfile) {
        remove(FNAME);
    }

    return 0;
}

void yyerror(char *s)
{
    printf("\n|-----------------------------------------------|\n");
    printf("| Error found in line %d: %s\n", yylineno, buf);
    printf("| %s", s);
    printf("\n|-----------------------------------------------|\n\n");
    
    memset(err_msg, 0, 50);
    err_num = init_errno;
    has_error = 0;
    not_gen_jfile = 1;
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
        
        int v = lookup_symbol(ste);
        if(v > 0) {
            if(has_error == 0) {
                if(v == 1) {
                    //Redeclared variable
                    err_num = rv;
                } else if(v == 2) {
                    //Redeclared function
                    err_num = rf;
                }
                strcpy(err_msg, serr_str[err_num]);
                strcat(err_msg, ste->name);
                has_error = 1;
            }
        } else {
            insert_symbol(ste);
        }
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

int lookup_symbol(ste_t *ste)
{
    ste_t *it = table_heads[ste->scope];
    while(it != NULL) {
        if(strcmp(ste->name, it->name) == 0) {
            if(strcmp(ste->kind, kind_str[0]) == 0) {
                //kind == var
                return 1;
            } else if(strcmp(ste->kind, kind_str[1]) == 0) {
                //kind == func
                return 2;
            }
        }
        it = it->next;
    }
    return 0;
}

int lookup_symbol_by_name(char *sid, int mod) {
    if(mod == 2) {
        int result = 0;
        ste_t *it = table_heads[0];
        while(it != NULL) {
            if(strcmp(it->name, sid) == 0) {
                for(int i = 0; i < 5; ++i) {
                    if(strcmp(it->type, type_str[i]) == 0) {
                        result = i + 1;
                    }
                }
                char attr[30];
                strcpy(attr, it->attribute);
                char *token = strtok(attr, ", ");
                while(token != NULL) {
                    for(int i = 0; i < 5; ++i) {
                        if(strcmp(token, type_str[i]) == 0) {
                            result *= 10;
                            result += i + 1;
                        }
                    }
                    token = strtok(NULL, ", ");
                }
                return result;
            }
            it = it->next;
        }
    }
    else {
        for(int i = scope; i >= 0; --i) {
            ste_t *it = table_heads[i];
            while(it != NULL) {
                if(strcmp(sid, it->name) == 0) {
                    for(int j = 0; j < 5; ++j) {
                        if(strcmp(it->type, type_str[j]) == 0) {
                            return j;
                        }
                    }
                }
                it = it->next;
            }
        }
    }
    has_error = 1;
    if(mod == 1) {
        err_num = uv;
    } else {
        err_num = uf;
    }
    strcpy(err_msg, serr_str[err_num]);
    strcat(err_msg, sid);
    return -1;
}

int j_lookup_symbol(char *sid) {
    int stack_num, count = -1;
    for(int s = 0; s <= scope; ++s) {
        ste_t *it = table_heads[s];
        while(it != NULL) {
            if(s > 0) ++count;
            if(strcmp(sid, it->name) == 0)
                stack_num = count;
            it = it->next;
        }
    }
    return stack_num;
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

void dcl_var(int s, int t, char *vn)
{
    if(s == 0)
    {
        fprintf(fp, ".field public static %s %s = ", vn, jtype[t]);
        if(t == e_int) {
            fprintf(fp, "%d\n", g_int);
            g_int = 0;
            g_float = 0.0;
        }
        else if(t == e_float) {
            fprintf(fp, "%f\n", g_float);
            g_int = 0;
            g_float = 0.0;
        }
        else if(t == e_string) {
            fprintf(fp, "\"%s\"\n", g_string);
            memset(g_string, 0, 100);
        }
        else if(t == e_bool) {
            fprintf(fp, "%d\n", g_bool);
            g_bool = 0;
        }
    }
}

void j_func_def()
{
    ste_t *it = table_heads[0];
    while(it != NULL) {
        if(strcmp(name_tmp, it->name) == 0 && strcmp("function", it->kind) == 0) {
            break;
        }
        it = it->next;
    }
    if(it != NULL) {
        if(strcmp("main", it->name) == 0) {
            fprintf(fp, ".method public static main([Ljava/lang/String;)V\n");
        }
        else {
            char attr[30], j_attri_type[50] = "", j_func_type[25] = "";
            strcpy(attr, it->attribute);
            char *token = strtok(attr, ", ");
            while(token != NULL) {
                for(int i = 0; i < 5; ++i) {
                    if(strcmp(token, type_str[i]) == 0) {
                        strcat(j_attri_type, jtype[i]);
                        break;
                    }
                }
                token = strtok(NULL, ", ");
            }
            for(int i = 0; i < 5; ++i) {
                if(strcmp(it->type, type_str[i]) == 0) {
                    strcat(j_func_type, jtype[i]);
                    cur_func_type = i;
                    break;
                }
            }
            fprintf(fp, ".method public static %s(%s)%s\n",
                it->name, j_attri_type, j_func_type);
        }
        fprintf(fp, ".limit stack 50\n.limit locals 50\n");
    }
}

void j_check_cast(int target_type, int tos_type)
{
    if(target_type != tos_type) {
        if(target_type == e_float && tos_type == e_int) {
            fprintf(fp, "    i2f\n");
        }
        else if(target_type == e_int && tos_type == e_float) {
            fprintf(fp, "    f2i\n");
        }
    }
}

void j_arithmetic_cast(int *tos_type, int *snd_type)
{
    if(*tos_type != *snd_type) {
        if(*tos_type != e_float) {
            fprintf(fp, "    i2f\n");
            *tos_type = e_float;
        }
        else {
            fprintf(fp, "    swap\n");
            fprintf(fp, "    i2f\n");
            fprintf(fp, "    swap\n");
            *snd_type = e_float;
        }
    }
}

int j_add(int tos_type, int snd_type)
{
    j_arithmetic_cast(&tos_type, &snd_type);
    if(tos_type == e_int) {
        fprintf(fp, "    iadd\n");
    }
    else {
        fprintf(fp, "    fadd\n");
    }
    return tos_type;
}

int j_sub(int tos_type, int snd_type)
{
    j_arithmetic_cast(&tos_type, &snd_type);
    if(tos_type == e_int) {
        fprintf(fp, "    isub\n");
    }
    else {
        fprintf(fp, "    fsub\n");
    }
    return tos_type;
}

int j_mul(int tos_type, int snd_type)
{
    j_arithmetic_cast(&tos_type, &snd_type);
    if(tos_type == e_int) {
        fprintf(fp, "    imul\n");
    }
    else {
        fprintf(fp, "    fmul\n");
    }
    return tos_type;
}

int j_div(int tos_type, int snd_type)
{
    j_arithmetic_cast(&tos_type, &snd_type);
    if(tos_type == e_int) {
        fprintf(fp, "    idiv\n");
    }
    else {
        fprintf(fp, "    fdiv\n");
    }
    return tos_type;
}

int j_mod(int tos_type, int snd_type)
{
    if(tos_type == e_int && snd_type == e_int) {
        fprintf(fp, "    irem\n");
    }
    return tos_type;
}

void j_get_2_tos_type(int *tos_type, int *snd_type)
{
    *tos_type = digit_for_type % 10 - 1;
    digit_for_type /= 10;
    *snd_type = digit_for_type % 10 - 1;
    digit_for_type /= 10;
}

void j_make_label(int cmp, int fc, int ic)
{
    int tos_type, snd_type;
    j_get_2_tos_type(&tos_type, &snd_type);
    char mark[8] = {};
    int cnt;
    if(is_while) {
        strcpy(mark, "WE");
        cnt = while_label - 1;
        is_while = 0;
    }
    else {
        strcpy(mark, "L");
        cnt = label_stack[label_tos];
    }
    if(tos_type == e_float) {
        fprintf(fp, "    fcmpl\n");
        fprintf(fp, "    ldc %d\n", cmp);
        fprintf(fp, "    %s %s%d\n", jicmps[fc], mark, cnt);
    }
    else {
        fprintf(fp, "    %s %s%d\n", jicmps[ic], mark, cnt);
    }
}

void j_call_func(int info)
{
    if(has_error) return;
    fprintf(fp, "    invokestatic compiler_hw3/%s", cur_fname);
    int param_stack[10] = {0};
    int i = -1;
    while(info >= 10) {
        ++i;
        param_stack[i] = info % 10 - 1;
        info /= 10;
    }
    int rnt_type = info % 10 - 1;

    fprintf(fp, "(");
    for( ; i >= 0; --i) {
        fprintf(fp, "%s", jtype[param_stack[i]]);
        digit_for_type /= 10;
    }
    fprintf(fp, ")%s\n", jtype[rnt_type]);

}


/*
void j_stack_push(int n)
{
    ste_t *ste = malloc(sizeof(ste_t));
    strcpy(ste->type, type_str[n]);
    ste->scope = scope;
    ste->next = NULL;
    if(stack.head == NULL) {
        stack.head = ste;
        stack.curn = stack.head;
    }else {
        stack.curn->next = ste;
        stack.curn = stack.curn->next;
    }
}
*/
