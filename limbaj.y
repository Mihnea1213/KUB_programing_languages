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

    SymbolTableManager* manager;

    bool hasErrors = false;
%}

%code requires {
    #include <string>
    #include <vector>
    #include "AST.h"
    
    // Structure to hold parameter information
    struct ParamInfo {
        std::string type;
        std::string name;
    };
}

%union {
    int int_val;
    float float_val;
    char* str_val; 
    std::vector<std::string>* str_vec;
    
    ASTNode* ast_node;
    std::vector<ASTNode*>* ast_vec;
    
    // For parameter info
    ParamInfo* param_info;
    std::vector<ParamInfo>* param_info_vec;
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
%type <ast_node> expression function_call assignment statement control_stmt var_decl_stmt
%type <ast_vec> main_body function_body_statements arg_expr_list
%type <param_info_vec> param_list_with_names

/* Prioritati Operatori */
%left OP_OR
%left OP_AND
%left OP_EQ OP_NEQ
%left '<' '>' OP_LE OP_GE
%left '+' '-'
%left '*' '/'

%%

program: global_declarations main_block
       ;
       
global_declarations: global_declarations global_decl
                   | /* empty */
                   ;
                   
global_decl: class_decl
           | function_decl
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
          | /* empty */
          ;
          
class_member: var_decl
            | function_decl
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
/* Regular var_decl for global/class scope (parse-time only) */
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

/* FIX: var_decl_stmt for function scope - MUST declare in symbol table at parse time
   AND create AST node for runtime execution */
var_decl_stmt: type ID ';' {
    /* Declare at parse time for semantic checking */
    if (!manager->declareVariable($2, $1)) {
        string err = "Variable '" + string($2) + "' already declared!";
        yyerror(err.c_str());
    }
    /* Create AST node for runtime (uses VarDeclNodeRuntime which doesn't re-declare) */
    $$ = new VarDeclNodeRuntime($2, $1, nullptr);
}
        | type ID '=' expression ';'
        {
            /* Declare at parse time for semantic checking */
            if (!manager->declareVariable($2, $1)) {
                string err = "Variable '" + string($2) + "' already declared!";
                yyerror(err.c_str());
            }
            /* Type check */
            if (strcmp($1, $4->dataType.c_str()) != 0 && strcmp($4->dataType.c_str(), "ERROR") != 0) {
                string err = "Type error at initialization: Cannot assign " + $4->dataType + " to " + string($1);
                yyerror(err.c_str());
            }
            /* Create AST node for runtime */
            $$ = new VarDeclNodeRuntime($2, $1, $4);
        }
        ;

/* --- FUNCTII (ENHANCED) --- */
function_decl: type ID {
    manager->declareFunction($2, $1, vector<string>());
    manager->enterScope($2);
    }
    '(' param_list_with_names ')' {
        if($5 && !$5->empty())
        {
            vector<string> types, names;
            for(auto& p : *$5) {
                types.push_back(p.type);
                names.push_back(p.name);
            }
            manager->updateFunctionParams($2, types, names);
            delete $5;
        }
    }
    '{' function_body_statements '}' {
        // Store function body
        if ($9) {
            manager->storeFunctionBody($2, $9);
        }
        manager->exitScope();
    }
    ;

/* Parameter list with names */
param_list_with_names: param_list_with_names ',' type ID
            {
                $$ = $1;
                ParamInfo p;
                p.type = $3;
                p.name = $4;
                $$->push_back(p);
                manager->declareVariable($4, $3, "parameter");
            }
          | type ID
          {
            $$ = new std::vector<ParamInfo>();
            ParamInfo p;
            p.type = $1;
            p.name = $2;
            $$->push_back(p);
            manager->declareVariable($2, $1, "parameter");
          }
          | /* empty */ 
          { 
            $$ = new std::vector<ParamInfo>();
          }
          ;

/* Function body that captures AST */
function_body_statements: function_body_statements statement { 
        $$ = $1;
        if ($2 != nullptr) {
            $$->push_back($2);
        }
    }
    | function_body_statements var_decl_stmt {
        $$ = $1;
        if ($2 != nullptr) {
            $$->push_back($2);
        }
    }
    | /* empty */ {
        $$ = new std::vector<ASTNode*>();
    }
    ;

/* --- MAIN BLOCK (THE_OP) --- */
main_block: TYPE_INT KEY_MAIN '(' ')' '{' main_body '}' {
        manager->enterScope("THE_OP_MAIN");
        std::cout << "\n=== START EXECUTION ===\n";
        if ($6) {
            for (ASTNode* node : *($6)) {
                if (node) {
                    WrapperValue result = node->eval(manager);
                    if (result.isReturn) break;
                }
            }
            // Clean up main_body AST nodes
            for (ASTNode* node : *($6)) {
                delete node;
            }
            delete $6;
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
         | /* empty */
         {
             $$ = new std::vector<ASTNode*>();
         }
         ;

/* --- STATEMENT-URI --- */
statement: assignment { $$ = $1; }
         | control_stmt { $$ = $1; }
         | function_call ';' { $$ = $1; }
         | KEY_PRINT '(' expression ')' ';'
         {
             $$ = new PrintNode($3);
         }
         | KEY_RETURN expression ';' 
         { 
             $$ = new ReturnNode($2);
         }
         | KEY_RETURN ';'
         {
             $$ = new ReturnNode(nullptr);
         }
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
                        $$ = new FieldAssignNode($1, $3, $5);
                    }
                }
            }
          }
          ;

control_stmt: KEY_IF '(' expression ')' '{' statement_list '}' 
            { 
                if ($3) {
                    if ($3->dataType != "TRUTHMODE") {
                        yyerror("IF condition must be of type TRUTHMODE (boolean)");
                    }
                    delete $3; 
                }
                $$ = nullptr; 
            }
            | KEY_IF '(' expression ')' '{' statement_list '}' KEY_ELSE '{' statement_list '}' 
            { 
                if ($3) {
                    if ($3->dataType != "TRUTHMODE") {
                        yyerror("IF condition must be of type TRUTHMODE (boolean)");
                    }
                    delete $3; 
                }
                $$ = nullptr; 
            }
            | KEY_WHILE '(' expression ')' '{' statement_list '}' 
            { 
                if ($3) {
                    if ($3->dataType != "TRUTHMODE") {
                        yyerror("WHILE condition must be of type TRUTHMODE (boolean)");
                    }
                    delete $3; 
                }
                $$ = nullptr; 
            }
            ;

statement_list: statement_list statement { if ($2) delete $2; }
              | /* empty */
              ;

/* --- FUNCTION CALL (ENHANCED) --- */
function_call: ID '(' arg_expr_list ')'
            {
                SymbolInfo* func = manager->getSymbol($1);
                string resType = "ERROR";
                vector<ASTNode*>* args = $3;
                
                if (!func) {
                    yyerror(("Function '" + string($1) + "' not defined!").c_str());
                    if (args) {
                        for (auto arg : *args) delete arg;
                        delete args;
                    }
                    $$ = new OtherNode("ERROR");
                } else if (func->scopeCategory != "function") {
                    yyerror(("'" + string($1) + "' is not a function!").c_str());
                    if (args) {
                        for (auto arg : *args) delete arg;
                        delete args;
                    }
                    $$ = new OtherNode("ERROR");
                } else {
                    // Type check arguments
                    if (func->paramTypes.size() != args->size()) {
                        string err = "Function '" + string($1) + "' expects " + to_string(func->paramTypes.size()) + 
                         " arguments, but got " + to_string(args->size());
                        yyerror(err.c_str());
                    } else {
                        bool ok = true;
                        for(size_t i = 0; i < args->size(); ++i) {
                            if (func->paramTypes[i] != (*args)[i]->dataType) {
                                string err = "Arg " + to_string(i+1) + " type mismatch: expected " + 
                                 func->paramTypes[i] + ", got " + (*args)[i]->dataType;
                                yyerror(err.c_str());
                                ok = false;
                            }
                        }
                        if(ok) resType = func->type;
                    }
                    
                    // Create function call node that will execute the body
                    if (resType != "ERROR") {
                        vector<ASTNode*> argVec;
                        if (args) {
                            argVec = *args;
                            delete args;
                        }
                        $$ = new FunctionCallNode($1, argVec, func->paramNames, resType);
                    } else {
                        if (args) {
                            for (auto arg : *args) delete arg;
                            delete args;
                        }
                        $$ = new OtherNode(resType);
                    }
                }
            }
             | ID '.' ID '(' arg_expr_list ')'
             {
                string resType = "ERROR";
                SymbolInfo* obj = manager->getSymbol($1);
                vector<ASTNode*>* args = $5;
                
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
                        } else if (method->scopeCategory != "function") {
                            yyerror(("Member '" + string($3) + "' is not a function!").c_str());
                        } else {
                            if (method->paramTypes.size() != args->size()) {
                                string err = "Method '" + string($3) + "' expects " + to_string(method->paramTypes.size()) + 
                                 " arguments, but got " + to_string(args->size());
                                yyerror(err.c_str());
                            } else {
                                bool ok = true;
                                for(size_t i = 0; i < args->size(); ++i) {
                                    if (method->paramTypes[i] != (*args)[i]->dataType) {
                                        string err = "Arg " + to_string(i+1) + " type mismatch: expected " + 
                                        method->paramTypes[i] + ", got " + (*args)[i]->dataType;
                                        yyerror(err.c_str());
                                        ok = false;
                                    }
                                }
                                if(ok) resType = method->type;
                            }
                        }
                    }
                }
                
                if (args) {
                    for (auto arg : *args) delete arg;
                    delete args;
                }
                $$ = new OtherNode(resType);
             }
             ;

/* Argument list with expressions */
arg_expr_list: arg_expr_list ',' expression
        {
            $$ = $1;
            $$->push_back($3);
        }
        | expression
        {
           $$ = new std::vector<ASTNode*>();
           $$->push_back($1);
        }
        | /* empty */
        {
            $$ = new std::vector<ASTNode*>();
        }
        ;

/* --- EXPRESII --- */
expression: expression '+' expression
            {
                if ($1->dataType == $3->dataType) { $$ = new AddNode($1, $3); }
                else { yyerror("Type mismatch: Cannot add different types!"); $$ = new OtherNode("ERROR"); delete $1; delete $3; }
            }
          | expression '-' expression
          {
                if ($1->dataType == $3->dataType) { $$ = new SubNode($1, $3); }
                else { yyerror("Type mismatch: Cannot subtract different types!"); $$ = new OtherNode("ERROR"); delete $1; delete $3; }
          }
          | expression '*' expression
          {
                if ($1->dataType == $3->dataType) { $$ = new MulNode($1, $3); }
                else { yyerror("Type mismatch: Cannot multiply different types!"); $$ = new OtherNode("ERROR"); delete $1; delete $3; }
          }
          | expression '/' expression
          {
                if ($1->dataType == $3->dataType) { $$ = new DivNode($1, $3); }
                else { yyerror("Type mismatch: Cannot divide different types!"); $$ = new OtherNode("ERROR"); delete $1; delete $3; }
          }
          | expression OP_AND expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "AND"); }
                else { yyerror("Type mismatch in AND operation!"); $$ = new OtherNode("ERROR"); delete $1; delete $3; }
          }
          | expression OP_OR expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "OR"); }
                else { yyerror("Type mismatch in OR operation!"); $$ = new OtherNode("ERROR"); delete $1; delete $3; }
          }
          | expression OP_EQ expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "EQ"); }
                else { yyerror("Type mismatch in comparison!"); $$ = new OtherNode("ERROR"); delete $1; delete $3; }
          }
          | expression OP_NEQ expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "NEQ"); }
                else { yyerror("Type mismatch in comparison!"); $$ = new OtherNode("ERROR"); delete $1; delete $3; }
          }
          | expression '<' expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "LT"); }
                else { yyerror("Type mismatch in < comparison!"); $$ = new OtherNode("ERROR"); delete $1; delete $3; }
          }
          | expression '>' expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "GT"); }
                else { yyerror("Type mismatch in > comparison!"); $$ = new OtherNode("ERROR"); delete $1; delete $3; }
          }
          | expression OP_LE expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "LE"); }
                else { yyerror("Type mismatch in <= comparison!"); $$ = new OtherNode("ERROR"); delete $1; delete $3; }
          }
          | expression OP_GE expression
          {
                if ($1->dataType == $3->dataType) { $$ = new LogicNode($1, $3, "GE"); }
                else { yyerror("Type mismatch in >= comparison!"); $$ = new OtherNode("ERROR"); delete $1; delete $3; }
          }
          | '(' expression ')'
          {
            $$ = $2;
          }
          | ID
          {
            SymbolInfo* s = manager->getSymbol($1);
            if (s) { $$ = new IdNode($1, s->type); }
            else {
                string err = "Variable '" + string($1) + "' not defined!";
                yyerror(err.c_str());
                $$ = new OtherNode("ERROR");
            }
          }
          | ID '.' ID
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
            if (resType != "ERROR") {
                $$ = new FieldAccessNode($1, $3, resType);
            } else {
                $$ = new OtherNode(resType);
            }
          }
          | function_call { $$ = $1; }
          | VAL_INT { $$ = new ConstNode(WrapperValue::createInt($1)); }
          | VAL_FLOAT { $$ = new ConstNode(WrapperValue::createFloat($1)); }
          | VAL_STRING { $$ = new ConstNode(WrapperValue::createString($1)); }
          | VAL_TRUE { $$ = new ConstNode(WrapperValue::createBool(true)); }
          | VAL_FALSE { $$ = new ConstNode(WrapperValue::createBool(false)); }
          ;

%%

void yyerror(const char* s) {
    hasErrors = true;
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

    if (hasErrors) {
        std::cout << "--------------------------------------" << std::endl;
        std::cout << "CRINGE: Programul contine erori si nu poate fi executat!" << std::endl;

        // Clean up function bodies (done here where ASTNode is fully defined)
    for (auto* body : manager->getFuncBodies()) {
        if (body) {
            for (auto* node : *body) {
                delete node;
            }
            delete body;
        }
    }

    delete manager;
    fclose(myfile);
    
        /* Oprim totul aici */
        return 0; 
    }
    else
    {
    std::cout << "GIGACHAD: Parsare completa cu succes! Generez tables.txt ..." << std::endl;
    manager->printAllTables("tables.txt");

    // Clean up function bodies (done here where ASTNode is fully defined)
    for (auto* body : manager->getFuncBodies()) {
        if (body) {
            for (auto* node : *body) {
                delete node;
            }
            delete body;
        }
    }

    delete manager;
    fclose(myfile);
    return 0;
    }
}