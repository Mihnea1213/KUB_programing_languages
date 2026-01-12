%{
    #include <iostream>
    #include <string>
    #include <vector>
    #include <cstring>
    #include "SymTable.h"

    extern int yylex();
    extern int yyparse();
    extern FILE* yyin;
    void yyerror(const char* s);

    /*Declaram managerul de tabele */
    SymbolTableManager* manager;
%}

/* Definim tipurile de date pe care le pot transporta regulile create*/
%union {
    int int_val;
    float float_val;
    char* str_val; /*Pentru nume de variabile (ID) si tipuri (BOI, WIGGLY) */
}

/* TOKEN-URILE (Le primim de la Flex) */
/*ID-ul returneaza un text (str_val), nu doar un cod simplu */
%token <str_val> ID
%token TYPE_INT TYPE_FLOAT TYPE_STRING TYPE_BOOL TYPE_VOID
%token KEY_CLASS KEY_MAIN KEY_PRINT
%token KEY_IF KEY_ELSE KEY_WHILE KEY_RETURN
%token VAL_INT VAL_FLOAT VAL_STRING VAL_TRUE VAL_FALSE
%token OP_EQ OP_NEQ OP_LE OP_GE OP_AND OP_OR

/* Spunem ca regula 'type' returneaza un sir de caratere (numele tipului) */
%type <str_val> type

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
//Cand definim o clasa, intram in Scope-ul ei
class_decl: KEY_CLASS ID {
    /* Actiune inainte de corpul clasei: Intram in scope */
    /* Mai intai declaram clasa in global ca sa stim de ea */
    manager->declareVariable($2, "PEPESSACK", "class");
    manager->enterScope($2);
    }
    '{' class_body '}' ';' { 
                /* Actiune dupa ce inchidem acolada : Iesim din scope */
                manager->exitScope(); 
            }
          ;

class_body: class_body class_member
          | /* empty */
          ;

class_member: var_decl
            | function_decl
            ;

/* --- TIPURI DE DATE --- */
//Returnam textul corespunzator tipului ca sa il scriem in tabel
type: TYPE_INT { $$ = strdup("BOI"); }
| TYPE_FLOAT { $$ = strdup("WIGGLY"); }
| TYPE_STRING { $$ = strdup("YAP"); }
| TYPE_BOOL { $$ = strdup("TRUTHMODE"); }
| TYPE_VOID { $$ = strdup("BLACK"); }
| ID { $$ = $1; } /* Pentru tipuri obiect (numele clasei) */
;

/* --- VARIABILE --- */
var_decl: type ID ';' {
    /* Am gasit o declaratie simpla */
    /* Ii spunem managerului sa o noteze in tabelul curent */
    if (manager->declareVariable($2, $1))
    {
        /* Totul ok, s-a declarat */
    }
    else
    {
        string err = "Variabila '" + string($2) + "' a fost deja declarata!";
        yyerror(err.c_str());
    }
}
        | type ID '=' expression ';'
        {
            /* Declaratie cu initializare */
            if (manager->declareVariable($2, $1))
            {
                /* Ok */
            }
            else
            {
                string err = "Variabila '" + string($2) + "' a fost deja declarata!";
                yyerror(err.c_str());
            }
        }
        ;

/* --- FUNCTII --- */
function_decl: type ID {
    /* Declaram functia in scope-ul curent (Global sau Clasa) */
    manager->declareVariable($2, $1, "function");
    /* Intram in Scope-ul functiei */
    manager->enterScope($2);
    }
    '(' param_list ')' '{' function_body '}' {
        /* La final, iesim din scope */
        manager->exitScope();
    }
    ;

param_list: param_list ',' param
          | param
          | /* empty */
          ;

param: type ID {
    /* Parametrii sunt si ei variabile locale in functia curenta */
    manager->declareVariable($2, $1, "parameter");
}
;

/* Corpul functiei accepta var_decl, care vor fi adaugate automat in scope-ul functiei */
function_body: function_body statement
             | function_body var_decl 
             | /* empty */
             ;

/* --- MAIN BLOCK (THE_OP) --- */
main_block: TYPE_INT KEY_MAIN {
    /* Main-ul este si el o functie speciala, are propriul scope */
    manager->enterScope("THE_OP_MAIN");
}
    '(' ')' '{' main_body '}' {
        manager->exitScope();
    }
          ;

main_body: main_body statement
         | /* empty */
         ;

/* --- STATEMENT-URI --- */
/* BLocurile IF/WHILE nu definesc vatiabile locale, deci nu e obligatoriu sa facem Scope nou. Variabilele din if nu exista oricum. */
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
        std::cout << "Nu gasesc fisierul input.txt!" << std::endl;
        return -1;
    }
    yyin = myfile;

    /* Initializam Managerul inainte de a parsa */
    manager = new SymbolTableManager();

    yyparse();
    
    /* Dupa ce terminam, afisam tabelele in fisier */
    std::cout << "GIGACHAD: Parsare completa cu succes! Generez tables.txt ..." << std::endl;
    manager->printAllTables("tables.txt");

    return 0;
}