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

%code requires {
    #include <string>
    #include <vector>
}

/* Definim tipurile de date pe care le pot transporta regulile create*/
%union {
    int int_val;
    float float_val;
    char* str_val; /*Pentru nume de variabile (ID) si tipuri (BOI, WIGGLY) */
    std::vector<std::string>* str_vec;
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
%type <str_val> type expression function_call
/* Definim tipul pentru liste de parametri/argumente */
%type <str_vec> param_list arg_list

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
    if (!manager->declareVariable($2, $1))
    {
        string err = "Variabila '" + string($2) + "' a fost deja declarata!";
        yyerror(err.c_str());
    }
}
        | type ID '=' expression ';'
        {
            /* Declaratie cu initializare */
            /* Verificam existenta */
            if (manager->declareVariable($2, $1))
            {
                if (strcmp($1,$4) != 0 && strcmp($4, "ERROR") != 0)
                {
                    string err = "Type error at initialization: Cannot assign " + string($4) + " to " + string($1);
                    yyerror(err.c_str());
                }
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
    /* Declaram functia simplu initial */
    manager->declareFunction($2, $1, vector<string>());
    /* Intram in Scope-ul functiei */
    manager->enterScope($2);
    }
    '(' param_list ')' {
        /* Dupa ce am parsat parametrii ($5), updatam simbolul functiei */
        /* cu lista de tipuri gasita. */
        if($5)
        {
            manager->updateFunctionParams($2, *$5);
            delete $5; //Curatam memoria
        }
    }
    '{' function_body '}' {
        manager->exitScope();
    }
    ;

/* param_list returneaza un vector de string-uri (tipurile parametrilor) */
param_list: param_list ',' type ID
            {
                $$ = $1;
                $$->push_back($3); /* Adaugam tipul in vector */
                manager->declareVariable($4, $3, "parameter");
            }
          | type ID
          {
            $$ = new std::vector<std::string>();
            $$->push_back($1); /* Adaugam tipul in vector */
            manager->declareVariable($2, $1, "parameter");
          }
          | /* empty */ { $$ = new std::vector<std::string>(); }
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
        {
            SymbolInfo* s = manager->getSymbol($1);
            if (s == nullptr)
            {
                string err = "Variable '" + string($1) + "' used but not defined!";
                yyerror(err.c_str());
            }
            else
            {
                /* Verificam daca tipul variabilei (s->type) e la fel cu tipul expresiei ($3)... DOAR daca nu avem deja o eroare detectata anterior */
                if (strcmp($3, "ERROR") != 0 && strcmp(s->type.c_str(), $3) != 0)
                {
                    string err = "Type error: Cannot assign " + string($3) + " to " + s->type + " (" + string($1) + ")";
                    yyerror(err.c_str());
                }
            }
        }
        /* Initializarea din var_decl trebuie si ea verificata! */
          | ID '.' ID '=' expression ';'
          {
            /* Verificam membru clasa la stanga */
            SymbolInfo* obj = manager->getSymbol($1);
            if(!obj)
            {
                yyerror(("Object '" + string($1) + "' not found!").c_str());
            }
            else
            {
                /* Cautam scope-ul clasei */
                SymbolTable* classScope = manager->findClassScope(obj->type);
                if(!classScope)
                {
                    yyerror(("Type '" + obj->type + "' is not a class!").c_str());
                }
                else
                {
                    /* Cautam membrul in clasa */
                    SymbolInfo* field = classScope->findSymbolLocal($3);
                    if(!field)
                    {
                        yyerror(("Class '" + obj->type + "' has no member '" + string($3) + "'").c_str());
                    }
                    else
                    {
                        /* Verificam tipul */
                        if (strcmp($5, "ERROR") != 0 && field->type != $5)
                        {
                            yyerror(("Type error: Cannot assign " + string($5) + " to field " + field->type).c_str());
                        }
                    }
                }
            }
          }
          ;

control_stmt: KEY_IF '(' expression ')' '{' statement_list '}'
            | KEY_IF '(' expression ')' '{' statement_list '}' KEY_ELSE '{' statement_list '}'
            | KEY_WHILE '(' expression ')' '{' statement_list '}'
            ;

statement_list: statement_list statement
              | /* empty */
              ;

function_call: ID '(' arg_list ')'
            {
                /* Verificam apelul functiei */
                SymbolInfo* func = manager->getSymbol($1);
                if (!func)
                {
                    yyerror(("Function '" + string($1) + "' not defined!").c_str());
                    $$ = strdup("ERROR");
                }
                else
                {
                    if (func->scopeCategory != "function")
                    {
                        yyerror(("'" + string($1) + "' is not a function!").c_str());
                        $$ = strdup("ERROR");
                    }
                    else
                    {
                        /* Verificam nr argumente */
                        if (func->paramTypes.size() != $3->size())
                        {
                            string err = "Function '" + string($1) + "' expects " + to_string(func->paramTypes.size()) + 
                             " arguments, but got " + to_string($3->size());
                            yyerror(err.c_str());
                            $$ = strdup("ERROR");
                        }
                        else
                        {
                            /* Verificam tipurile argumentelor */
                            bool ok = true;
                            for(size_t i = 0; i < func->paramTypes.size(); ++i)
                            {
                                if (func->paramTypes[i] != (*$3)[i]) 
                                {
                                    string err = "Arg " + to_string(i+1) + " type mismatch: expected " + 
                                     func->paramTypes[i] + ", got " + (*$3)[i];
                                    yyerror(err.c_str());
                                    ok = false;
                                }
                            }
                            if(ok) $$ = strdup(func->type.c_str());
                            else $$ = strdup("ERROR");
                        }
                    }
                }
                delete $3; /* Clean up vector */
            }
             | ID '.' ID '(' arg_list ')'
             {
                /* Cautam obiectul (ex: d) */
                SymbolInfo* obj = manager->getSymbol($1);
                if (!obj)
                {
                yyerror(("Object '" + string($1) + "' not found!").c_str());
                $$ = strdup("ERROR");
                }
                else
                {
                    /* Cautam scope-ul clasei obiectului (ex: DogeCoin) */
                    SymbolTable* classScope = manager->findClassScope(obj->type);
                    if (!classScope)
                    {
                        yyerror(("Type '" + obj->type + "' is not a class!").c_str());
                        $$ = strdup("ERROR");
                    }
                    else
                    {
                        /* Cautam metoda in interiorul clasei (ex: bark) */
                        SymbolInfo* method = classScope->findSymbolLocal($3);
                        if (!method)
                        {
                        yyerror(("Method '" + string($3) + "' not defined in class " + obj->type).c_str());
                        $$ = strdup("ERROR");
                        }
                        else
                        {
                            /* Verificam ca e functie */
                            if (method->scopeCategory != "function")
                            {
                                yyerror(("Member '" + string($3) + "' is not a function!").c_str());
                                $$ = strdup("ERROR");
                            }
                            else
                            {
                                /* Verificam parametri (Numar si Tipuri) */
                                if (method->paramTypes.size() != $5->size())
                                {
                                    string err = "Method '" + string($3) + "' expects " + to_string(method->paramTypes.size()) + 
                                     " arguments, but got " + to_string($5->size());
                                    yyerror(err.c_str());
                                    $$ = strdup("ERROR");
                                }
                                else
                                {
                                    bool ok = true;
                                    for(size_t i = 0; i < method->paramTypes.size(); ++i)
                                    {
                                        if (method->paramTypes[i] != (*$5)[i]) 
                                        {
                                            string err = "Arg " + to_string(i+1) + " type mismatch in method call: expected " + 
                                             method->paramTypes[i] + ", got " + (*$5)[i];
                                            yyerror(err.c_str());
                                            ok = false;
                                        }
                                    }
                                    if(ok) $$ = strdup(method->type.c_str());
                                    else $$ = strdup("ERROR");
                                }
                            }
                        }
                    }
                }
                delete $5; /* Curatam vectorul de argumente */
             }
             ;

/* arg_list colecteaza tipurile expresiilor trimise la functie */
arg_list: arg_list ',' expression
        {
            $$ = $1;
            $$->push_back($3);
        }
        | expression
        {
           $$ = new std::vector<std::string>();
            $$->push_back($1); 
        }
        | /* empty */
        {
            $$ = new std::vector<std::string>();
        }
        ;

/* --- EXPRESII CU VERIFICARE SEMANTICA--- */
expression: expression '+' expression
            {
                /* Verificam daca tipurile sunt identice */
                if (strcmp($1, $3) == 0)
                {
                    $$ = $1; /* Rezultatul are acelasi tip (ex: BOI + BOI = BOI) */
                }
                else
                {
                    yyerror("Type mismatch: Cannot add different types!");
                    $$ = strdup("ERROR"); /* Marcam ca eroare */
                }
            }
          | expression '-' expression
          {
            /* Verificam daca tipurile sunt identice */
                if (strcmp($1, $3) == 0)
                {
                    $$ = $1; /* Rezultatul are acelasi tip (ex: BOI - BOI = BOI) */
                }
                else
                {
                    yyerror("Type mismatch: Cannot subtract different types!");
                    $$ = strdup("ERROR"); /* Marcam ca eroare */
                }
          }
          | expression '*' expression
          {
            /* Verificam daca tipurile sunt identice */
                if (strcmp($1, $3) == 0)
                {
                    $$ = $1; /* Rezultatul are acelasi tip */
                }
                else
                {
                    yyerror("Type mismatch: Cannot multiply different types!");
                    $$ = strdup("ERROR"); /* Marcam ca eroare */
                }
          }
          | expression '/' expression
          {
            /* Verificam daca tipurile sunt identice */
                if (strcmp($1, $3) == 0)
                {
                    $$ = $1; /* Rezultatul are acelasi tip */
                }
                else
                {
                    yyerror("Type mismatch: Cannot divide different types!");
                    $$ = strdup("ERROR"); /* Marcam ca eroare */
                }
          }
          /* Operatorii logici returneaza mereu TRUTHMODE (bool), dar cer ca operanzii sa fie la fel */
          | expression OP_AND expression
          {
            /* Verificam daca tipurile sunt identice */
                if (strcmp($1, $3) == 0)
                {
                    $$ = strdup("TRUTHMODE"); /* Rezultatul are acelasi tip */
                }
                else
                {
                    yyerror("Type mismatch in AND operation!");
                    $$ = strdup("ERROR"); /* Marcam ca eroare */
                }
          }
          | expression OP_OR expression
          {
            /* Verificam daca tipurile sunt identice */
                if (strcmp($1, $3) == 0)
                {
                    $$ = strdup("TRUTHMODE"); /* Rezultatul are acelasi tip */
                }
                else
                {
                    yyerror("Type mismatch in OR operation!");
                    $$ = strdup("ERROR"); /* Marcam ca eroare */
                }
          }
          /* Comparatiile returneaza TRUTHMODE */
          | expression OP_EQ expression
          {
            /* Verificam daca tipurile sunt identice */
                if (strcmp($1, $3) == 0)
                {
                    $$ = strdup("TRUTHMODE"); /* Rezultatul are acelasi tip */
                }
                else
                {
                    yyerror("Type mismatch in comparison!");
                    $$ = strdup("ERROR"); /* Marcam ca eroare */
                }
          }
          | expression OP_NEQ expression
          {
            /* Verificam daca tipurile sunt identice */
                if (strcmp($1, $3) == 0)
                {
                    $$ = strdup("TRUTHMODE"); /* Rezultatul are acelasi tip */
                }
                else
                {
                    yyerror("Type mismatch in comparison!");
                    $$ = strdup("ERROR"); /* Marcam ca eroare */
                }
          }
          | expression '<' expression
          {
            /* Verificam daca tipurile sunt identice */
                if (strcmp($1, $3) == 0)
                {
                    $$ = strdup("TRUTHMODE"); /* Rezultatul are acelasi tip */
                }
                else
                {
                    yyerror("Type mismatch in < comparison!");
                    $$ = strdup("ERROR"); /* Marcam ca eroare */
                }
          }
          | expression '>' expression
          {
            /* Verificam daca tipurile sunt identice */
                if (strcmp($1, $3) == 0)
                {
                    $$ = strdup("TRUTHMODE"); /* Rezultatul are acelasi tip */
                }
                else
                {
                    yyerror("Type mismatch in > comparison!");
                    $$ = strdup("ERROR"); /* Marcam ca eroare */
                }
          }
          | '(' expression ')'
          {
            $$ = $2;
          }
          /* Variabil (ID) */
          | ID
          {
            /* Verificam daca exista variabila */
            SymbolInfo* s = manager->getSymbol($1);
            if (s)
            {
                /* Daca exista, returnam tipul ei (ex: "BOI") */
                $$ = strdup(s->type.c_str());
            }
            else
            {
                string err = "Variable '" + string($1) + "' not defined!";
                yyerror(err.c_str());
                $$ = strdup("ERROR");
            }
          }
          | ID '.' ID
          {
            /* Verificam membru clasa in expresie (la dreapta) */
            SymbolInfo* obj = manager->getSymbol($1);
            if (!obj) {
                yyerror(("Object '" + string($1) + "' not found!").c_str());
                $$ = strdup("ERROR");
            } else {
                SymbolTable* classScope = manager->findClassScope(obj->type);
                if (!classScope) {
                    yyerror(("Type '" + obj->type + "' is not a class!").c_str());
                    $$ = strdup("ERROR");
                } else {
                    SymbolInfo* field = classScope->findSymbolLocal($3);
                    if (!field) {
                        yyerror(("Member '" + string($3) + "' not found in " + obj->type).c_str());
                        $$ = strdup("ERROR");
                    } else {
                        $$ = strdup(field->type.c_str());
                    }
                }
            }
          }
          | function_call
          { $$ = $1; }
          | VAL_INT
          { $$ = strdup("BOI"); }
          | VAL_FLOAT
          { $$ = strdup("WIGGLY"); }
          | VAL_STRING
          { $$ = strdup("YAP"); }
          | VAL_TRUE
          { $$ = strdup("TRUTHMODE"); }
          | VAL_FALSE
          { $$ = strdup("TRUTHMODE"); }
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