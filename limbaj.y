%{
    #include <iostream>
    extern int yylex();
    extern int yyparse();
    extern FILE* yyin;
    void yyerror(const char* s);
%}

%union {
    int int_val;
    float float_val;
    char* str_val;
}

/* TOKEN-URILE (Le primim de la Flex) */
%token TYPE_INT TYPE_FLOAT TYPE_STRING TYPE_BOOL TYPE_VOID
%token KEY_CLASS KEY_MAIN KEY_PRINT
%token KEY_IF KEY_ELSE KEY_WHILE KEY_RETURN
%token VAL_INT VAL_FLOAT VAL_STRING VAL_TRUE VAL_FALSE
%token ID
%token OP_EQ OP_NEQ OP_LE OP_GE OP_AND OP_OR

/* Prioritati Operatori */
%left OP_OR
%left OP_AND
%left OP_EQ OP_NEQ
%left '<' '>' OP_LE OP_GE
%left '+' '-'
%left '*' '/'

%%

/* --- REGULI GRAMATICALE --- */

program: global_declarations main_block
       ;

global_declarations: global_declarations global_decl
                   | /* empty */
                   ;

global_decl: class_decl
           | function_decl
           ;

/* --- CLASE (PEPESSACK) --- */
class_decl: KEY_CLASS ID '{' class_body '}' ';'
          ;

class_body: class_body class_member
          | /* empty */
          ;

class_member: var_decl
            | function_decl
            ;

/* --- TIPURI DE DATE --- */
type: TYPE_INT | TYPE_FLOAT | TYPE_STRING | TYPE_BOOL | TYPE_VOID | ID ;

/* --- VARIABILE --- */
var_decl: type ID ';'
        | type ID '=' expression ';'
        ;

/* --- FUNCTII --- */
function_decl: type ID '(' param_list ')' '{' function_body '}' 
             ;

param_list: param_list ',' param
          | param
          | /* empty */
          ;

param: type ID ;

/* Function body: accepts local vars AND statements */
function_body: function_body statement
             | function_body var_decl 
             | /* empty */
             ;

/* --- MAIN BLOCK (THE_OP) --- */
/* Restriction: No variable definitions allowed inside main block */
main_block: TYPE_INT KEY_MAIN '(' ')' '{' main_body '}' 
          ;

main_body: main_body statement
         | /* empty */
         ;

/* --- STATEMENT-URI --- */
statement: assignment
         | control_stmt
         | function_call ';'
         | KEY_PRINT '(' expression ')' ';'
         | KEY_RETURN expression ';'
         ;

assignment: ID '=' expression ';'
          | ID '.' ID '=' expression ';'
          ;

control_stmt: KEY_IF '(' expression ')' '{' statement_list '}'
            | KEY_IF '(' expression ')' '{' statement_list '}' KEY_ELSE '{' statement_list '}'
            | KEY_WHILE '(' expression ')' '{' statement_list '}'
            ;

/* Statements inside IF/WHILE cannot contain variable declarations */
statement_list: statement_list statement
              | /* empty */
              ;

function_call: ID '(' arg_list ')'
             | ID '.' ID '(' arg_list ')'
             ;

arg_list: arg_list ',' expression
        | expression
        | /* empty */
        ;

/* --- EXPRESII --- */
expression: expression '+' expression
          | expression '-' expression
          | expression '*' expression
          | expression '/' expression
          | expression OP_AND expression
          | expression OP_OR expression
          | expression OP_EQ expression
          | expression OP_NEQ expression
          | expression '<' expression
          | expression '>' expression
          | '(' expression ')'
          | ID
          | ID '.' ID
          | function_call
          | VAL_INT
          | VAL_FLOAT
          | VAL_STRING
          | VAL_TRUE
          | VAL_FALSE
          ;

%%

void yyerror(const char* s) {
    std::cerr << "CRINGE ERROR (Syntax): " << s << std::endl;
}

int main(int argc, char** argv) {
    FILE *myfile = fopen("input.txt", "r");
    if (!myfile) {
        std::cout << "Nu gasesc fisierul input.txt! E null pointer, NOTHERE!" << std::endl;
        return -1;
    }
    yyin = myfile;
    yyparse();
    std::cout << "GIGACHAD: Parsare completa cu succes!" << std::endl;
}