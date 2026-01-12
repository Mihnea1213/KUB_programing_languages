%{
    #include <iostream>
    #include <string>
    #include <vector>
    #include <cstring>
    #include "SymTable.h"
    #include "AST.h" 

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
    #include "AST.h" 
}

/* Definim tipurile de date pe care le pot transporta regulile create*/
%union {
    int int_val;
    float float_val;
    char* str_val; 
    std::vector<std::string>* str_vec;
    
    // Step IV: AST types
    ASTNode* ast_node;
    std::vector<ASTNode*>* ast_vec;
}

/* TOKEN-URILE */
%token <str_val> ID
%token TYPE_INT TYPE_FLOAT TYPE_STRING TYPE_BOOL TYPE_VOID
%token KEY_CLASS KEY_MAIN KEY_PRINT
%token KEY_IF KEY_ELSE KEY_WHILE KEY_RETURN
%token <int_val> VAL_INT
%token <float_val> VAL_FLOAT
%token <str_val> VAL_STRING
%token VAL_TRUE VAL_FALSE
%token OP_EQ OP_NEQ OP_LE OP_GE OP_AND OP_OR

%type <str_val> type 

/* ASTNode* return types */
%type <ast_node> expression function_call assignment statement control_stmt

/* Vector types */
%type <str_vec> param_list arg_list
%type <ast_vec> main_body

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
                   |
                   /* empty */
                   ;
global_decl: class_decl
           |
           function_decl
           ;

/* --- CLASE (PEPESSACK) --- */
class_decl: KEY_CLASS ID {
    manager->declareVariable($2, "PEPESSACK", "class");
    manager->enterScope($2);
    }
    '{' class_body '}' ';' { 
                manager->exitScope();
    }
          ;
class_body: class_body class_member
          |
          /* empty */
          ;
class_member: var_decl
            |
            function_decl
            ;

/* --- TIPURI DE DATE --- */
type: TYPE_INT { $$ = strdup("BOI"); }
| TYPE_FLOAT { $$ = strdup("WIGGLY"); }
| TYPE_STRING { $$ = strdup("YAP"); }
| TYPE_BOOL { $$ = strdup("TRUTHMODE"); }
| TYPE_VOID { $$ = strdup("BLACK"); }
| ID { $$ = $1; } 
;

/* --- VARIABILE --- */
var_decl: type ID ';' {
    if (!manager->declareVariable($2, $1))
    {
        string err = "Variabila '" + string($2) + "' a fost deja declarata!";
        yyerror(err.c_str());
    }
}
        | type ID '=' expression ';'
        {
            if (manager->declareVariable($2, $1))
            {
                if (strcmp($1, $4->dataType.c_str()) != 0 && strcmp($4->dataType.c_str(), "ERROR") != 0)
                {
                   string err = "Type error at initialization: Cannot assign " + $4->dataType + " to " + string($1);
                   yyerror(err.c_str());
                }
            }
            else
            {
                string err = "Variabila '" + string($2) + "' a fost deja declarata!";
                yyerror(err.c_str());
            }
            delete $4;
        }
        ;

/* --- FUNCTII --- */
function_decl: type ID {
    manager->declareFunction($2, $1, vector<string>());
    manager->enterScope($2);
    }
    '(' param_list ')' {
        if($5)
        {
            manager->updateFunctionParams($2, *$5);
            delete $5;
        }
    }
    '{' function_body '}' {
        manager->exitScope();
    }
    ;

param_list: param_list ',' type ID
            {
                $$ = $1;
                $$->push_back($3);
                manager->declareVariable($4, $3, "parameter");
            }
          |
          type ID
          {
            $$ = new std::vector<std::string>();
            $$->push_back($1);
            manager->declareVariable($2, $1, "parameter");
          }
          | /* empty */ { $$ = new std::vector<std::string>();
          }
          ;

function_body: function_body statement { 
                if ($2) delete $2; 
             }
             |
             function_body var_decl 
             |
             /* empty */
             ;

/* --- MAIN BLOCK (THE_OP) --- */
/* FIXED: Access main_body at $7 */
main_block: TYPE_INT KEY_MAIN {
    manager->enterScope("THE_OP_MAIN");
}
    '(' ')' '{' main_body '}' {
        std::cout << "\n=== START EXECUTION ===\n";
        // Check $7 because: $1=TYPE, $2=MAIN, $3=ACTION, $4=(, $5=), $6={, $7=main_body
        if ($7) {
            for (ASTNode* node : *($7)) {
                if (node) {
                    node->eval(manager);
                }
            }
            delete $7;
        }
        std::cout << "=== END EXECUTION ===\n\n";

        manager->exitScope();
    }
          ;

main_body: main_body statement
         {
             $$ = $1;
             if ($2 != nullptr) {
                 $$->push_back($2);
             }
         }
         |
         /* empty */
         {
             $$ = new std::vector<ASTNode*>();
         }
         ;

/* --- STATEMENT-URI --- */
statement: assignment { $$ = $1; }
         |
         control_stmt { $$ = nullptr; }
         | function_call ';' { $$ = new OtherNode($1->dataType); delete $1; }
         | KEY_PRINT '(' expression ')' ';'
         {
             $$ = new PrintNode($3);
         }
         |
         KEY_RETURN expression ';' { $$ = nullptr; delete $2; }
         ;

assignment: ID '=' expression ';'
        {
            SymbolInfo* s = manager->getSymbol($1);
            if (s == nullptr)
            {
                string err = "Variable '" + string($1) + "' used but not defined!";
                yyerror(err.c_str());
                $$ = nullptr; delete $3;
            }
            else
            {
                if (strcmp($3->dataType.c_str(), "ERROR") != 0 && s->type != $3->dataType)
                {
                    string err = "Type error: Cannot assign " + $3->dataType + " to " + s->type + " (" + string($1) + ")";
                    yyerror(err.c_str());
                }
                $$ = new AssignNode($1, $3);
            }
        }
          | ID '.' ID '=' expression ';'
          {
            SymbolInfo* obj = manager->getSymbol($1);
            if(!obj)
            {
                yyerror(("Object '" + string($1) + "' not found!").c_str());
                $$ = nullptr; delete $5;
            }
            else
            {
                SymbolTable* classScope = manager->findClassScope(obj->type);
                if(!classScope)
                {
                    yyerror(("Type '" + obj->type + "' is not a class!").c_str());
                    $$ = nullptr; delete $5;
                }
                else
                {
                    SymbolInfo* field = classScope->findSymbolLocal($3);
                    if(!field)
                    {
                        yyerror(("Class '" + obj->type + "' has no member '" + string($3) + "'").c_str());
                        $$ = nullptr; delete $5;
                    }
                    else
                    {
                         if (strcmp($5->dataType.c_str(), "ERROR") != 0 && field->type != $5->dataType)
                        {
                            yyerror(("Type error: Cannot assign " + $5->dataType + " to field " + field->type).c_str());
                        }
                        $$ = new OtherNode("ASSIGN_FIELD"); 
                        delete $5;
                    }
                }
            }
          }
          ;

control_stmt: KEY_IF '(' expression ')' '{' statement_list '}' { $$ = nullptr; delete $3; }
            |
            KEY_IF '(' expression ')' '{' statement_list '}' KEY_ELSE '{' statement_list '}' { $$ = nullptr; delete $3; }
            |
            KEY_WHILE '(' expression ')' '{' statement_list '}' { $$ = nullptr; delete $3; }
            ;

statement_list: statement_list statement { if ($2) delete $2; }
              |
              /* empty */
              ;

function_call: ID '(' arg_list ')'
            {
                SymbolInfo* func = manager->getSymbol($1);
                string resType = "ERROR";
                
                if (!func) {
                    yyerror(("Function '" + string($1) + "' not defined!").c_str());
                } else {
                    if (func->scopeCategory != "function") {
                        yyerror(("'" + string($1) + "' is not a function!").c_str());
                    } else {
                        if (func->paramTypes.size() != $3->size()) {
                            string err = "Function '" + string($1) + "' expects " + to_string(func->paramTypes.size()) + 
                             " arguments, but got " + to_string($3->size());
                            yyerror(err.c_str());
                        } else {
                            bool ok = true;
                            for(size_t i = 0; i < func->paramTypes.size(); ++i) {
                                if (func->paramTypes[i] != (*$3)[i]) {
                                    string err = "Arg " + to_string(i+1) + " type mismatch: expected " + 
                                     func->paramTypes[i] + ", got " + (*$3)[i];
                                    yyerror(err.c_str());
                                    ok = false;
                                }
                            }
                            if(ok) resType = func->type;
                        }
                    }
                }
                delete $3;
                $$ = new OtherNode(resType);
            }
             |
             ID '.' ID '(' arg_list ')'
             {
                string resType = "ERROR";
                SymbolInfo* obj = manager->getSymbol($1);
                if (!obj) {
                    yyerror(("Object '" + string($1) + "' not found!").c_str());
                } else {
                    SymbolTable* classScope = manager->findClassScope(obj->type);
                    if (!classScope) {
                        yyerror(("Type '" + obj->type + "' is not a class!").c_str());
                    } else {
                        SymbolInfo* method = classScope->findSymbolLocal($3);
                        if (!method) {
                        yyerror(("Method '" + string($3) + "' not defined in class " + obj->type).c_str());
                        } else {
                            if (method->scopeCategory != "function") {
                                yyerror(("Member '" + string($3) + "' is not a function!").c_str());
                            } else {
                                if (method->paramTypes.size() != $5->size()) {
                                    string err = "Method '" + string($3) + "' expects " + to_string(method->paramTypes.size()) + 
                                     " arguments, but got " + to_string($5->size());
                                    yyerror(err.c_str());
                                } else {
                                    bool ok = true;
                                    for(size_t i = 0; i < method->paramTypes.size(); ++i) {
                                        if (method->paramTypes[i] != (*$5)[i]) {
                                            string err = "Arg " + to_string(i+1) + " type mismatch in method call: expected " + 
                                            method->paramTypes[i] + ", got " + (*$5)[i];
                                            yyerror(err.c_str());
                                            ok = false;
                                        }
                                    }
                                    if(ok) resType = method->type;
                                }
                            }
                        }
                    }
                }
                delete $5;
                $$ = new OtherNode(resType);
             }
             ;

arg_list: arg_list ',' expression
        {
            $$ = $1;
            $$->push_back($3->dataType);
            delete $3;
        }
        |
        expression
        {
           $$ = new std::vector<std::string>();
           $$->push_back($1->dataType); 
           delete $1;
        }
        |
        /* empty */
        {
            $$ = new std::vector<std::string>();
        }
        ;

/* --- EXPRESII CU VERIFICARE SEMANTICA--- */
expression: expression '+' expression
            {
                if ($1->dataType == $3->dataType) { $$ = new AddNode($1, $3); }
                else { yyerror("Type mismatch: Cannot add different types!"); $$ = new OtherNode("ERROR"); }
            }
          |
          expression '-' expression
          {
                if ($1->dataType == $3->dataType) { $$ = new SubNode($1, $3); }
                else { yyerror("Type mismatch: Cannot subtract different types!"); $$ = new OtherNode("ERROR"); }
          }
          |
          expression '*' expression
          {
                if ($1->dataType == $3->dataType) { $$ = new MulNode($1, $3); }
                else { yyerror("Type mismatch: Cannot multiply different types!"); $$ = new OtherNode("ERROR"); }
          }
          |
          expression '/' expression
          {
                if ($1->dataType == $3->dataType) { $$ = new DivNode($1, $3); }
                else { yyerror("Type mismatch: Cannot divide different types!"); $$ = new OtherNode("ERROR"); }
          }
          |
          expression OP_AND expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "AND"); }
                else { yyerror("Type mismatch in AND operation!"); $$ = new OtherNode("ERROR"); }
          }
          |
          expression OP_OR expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "OR"); }
                else { yyerror("Type mismatch in OR operation!"); $$ = new OtherNode("ERROR"); }
          }
          |
          expression OP_EQ expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "EQ"); }
                else { yyerror("Type mismatch in comparison!"); $$ = new OtherNode("ERROR"); }
          }
          |
          expression OP_NEQ expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "NEQ"); }
                else { yyerror("Type mismatch in comparison!"); $$ = new OtherNode("ERROR"); }
          }
          |
          expression '<' expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "LT"); }
                else { yyerror("Type mismatch in < comparison!"); $$ = new OtherNode("ERROR"); }
          }
          |
          expression '>' expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "GT"); }
                else { yyerror("Type mismatch in > comparison!"); $$ = new OtherNode("ERROR"); }
          }
          |
          '(' expression ')'
          {
            $$ = $2;
          }
          |
          ID
          {
            SymbolInfo* s = manager->getSymbol($1);
            if (s) { $$ = new IdNode($1, s->type); }
            else {
                string err = "Variable '" + string($1) + "' not defined!";
                yyerror(err.c_str());
                $$ = new OtherNode("ERROR");
            }
          }
          |
          ID '.' ID
          {
            SymbolInfo* obj = manager->getSymbol($1);
            string resType = "ERROR";
            if (!obj) {
                yyerror(("Object '" + string($1) + "' not found!").c_str());
            } else {
                SymbolTable* classScope = manager->findClassScope(obj->type);
                if (!classScope) {
                    yyerror(("Type '" + obj->type + "' is not a class!").c_str());
                } else {
                    SymbolInfo* field = classScope->findSymbolLocal($3);
                    if (!field) {
                        yyerror(("Member '" + string($3) + "' not found in " + obj->type).c_str());
                    } else {
                        resType = field->type;
                    }
                }
            }
            $$ = new OtherNode(resType);
          }
          |
          function_call { $$ = $1; }
          |
          VAL_INT { $$ = new ConstNode(WrapperValue::createInt($1)); }
          |
          VAL_FLOAT { $$ = new ConstNode(WrapperValue::createFloat($1)); }
          |
          VAL_STRING { $$ = new ConstNode(WrapperValue::createString($1)); }
          |
          VAL_TRUE { $$ = new ConstNode(WrapperValue::createBool(true)); }
          |
          VAL_FALSE { $$ = new ConstNode(WrapperValue::createBool(false)); }
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

    manager = new SymbolTableManager();
    yyparse();
    
    std::cout << "GIGACHAD: Parsare completa cu succes! Generez tables.txt ..." << std::endl;
    manager->printAllTables("tables.txt");

    return 0;
}