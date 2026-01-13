#ifndef AST_H
#define AST_H

#include "SymTable.h"
#include <string>
#include <iostream>
#include <cmath>

using namespace std;

// Forward declaration
class SymbolTableManager;

// Wrapper class for values
struct WrapperValue {
    string type; // "BOI", "WIGGLY", "YAP", "TRUTHMODE", "BLACK"
    int intVal = 0;
    float floatVal = 0.0;
    string strVal = "";
    bool boolVal = false;
    bool isReturn = false;  // Flag to indicate a return statement was executed

    WrapperValue() : type("BLACK"), isReturn(false) {}
    
    // Helpers for easy creation
    static WrapperValue createInt(int v) { WrapperValue w; w.type="BOI"; w.intVal=v; return w; }
    static WrapperValue createFloat(float v) { WrapperValue w; w.type="WIGGLY"; w.floatVal=v; return w; }
    static WrapperValue createString(string v) { WrapperValue w; w.type="YAP"; w.strVal=v; return w; }
    static WrapperValue createBool(bool v) { WrapperValue w; w.type="TRUTHMODE"; w.boolVal=v; return w; }
    
    // Helper to get default value for a type
    static WrapperValue createDefault(string t) {
        WrapperValue w;
        w.type = t;
        return w;
    }

    // For debugging/printing
    void print() {
        if (type == "BOI") cout << intVal;
        else if (type == "WIGGLY") cout << floatVal;
        else if (type == "YAP") cout << strVal;
        else if (type == "TRUTHMODE") cout << (boolVal ? "BASED" : "CRINGE");
        else cout << "void";
    }
};

// Abstract Syntax Tree Node
class ASTNode {
public:
    string dataType; // The semantic type ("BOI", etc.) stored during parsing

    virtual WrapperValue eval(SymbolTableManager* mgr) = 0;
    virtual ~ASTNode() {}
};

// --- Nodes for Literals ---
class ConstNode : public ASTNode {
    WrapperValue val;
public:
    ConstNode(WrapperValue v) : val(v) { dataType = v.type; }
    WrapperValue eval(SymbolTableManager* mgr) override { return val; }
};

// --- Node for Identifiers ---
class IdNode : public ASTNode {
    string name;
public:
    IdNode(string n, string t) : name(n) { dataType = t; }
    WrapperValue eval(SymbolTableManager* mgr) override {
        // Look up value in SymbolTable
        SymbolInfo* s = mgr->getSymbol(name);
        if (!s) return WrapperValue();
        
        WrapperValue w;
        w.type = dataType;
        // Parse stored string value back to typed value
        if (dataType == "BOI") w.intVal = s->value.empty() ? 0 : stoi(s->value);
        else if (dataType == "WIGGLY") w.floatVal = s->value.empty() ? 0.0 : stof(s->value);
        else if (dataType == "YAP") w.strVal = s->value;
        else if (dataType == "TRUTHMODE") w.boolVal = (s->value == "1");
        
        return w;
    }
};

// --- Node for Field Access (obj.field) ---
class FieldAccessNode : public ASTNode {
    string objName;
    string fieldName;
public:
    FieldAccessNode(string obj, string field, string t) : objName(obj), fieldName(field) { 
        dataType = t; 
    }
    
    WrapperValue eval(SymbolTableManager* mgr) override {
        SymbolInfo* obj = mgr->getSymbol(objName);
        if (!obj) return WrapperValue::createDefault(dataType);
        
        SymbolTable* classScope = mgr->findClassScope(obj->type);
        if (!classScope) return WrapperValue::createDefault(dataType);
        
        SymbolInfo* field = classScope->findSymbolLocal(fieldName);
        if (!field) return WrapperValue::createDefault(dataType);
        
        WrapperValue w;
        w.type = dataType;
        if (dataType == "BOI") w.intVal = field->value.empty() ? 0 : stoi(field->value);
        else if (dataType == "WIGGLY") w.floatVal = field->value.empty() ? 0.0 : stof(field->value);
        else if (dataType == "YAP") w.strVal = field->value;
        else if (dataType == "TRUTHMODE") w.boolVal = (field->value == "1");
        
        return w;
    }
};

// --- Node for Variable Declaration at Runtime ---
// This is used for function bodies: the variable was already declared at parse time
// for semantic checking, but at runtime we need to declare it in the CALL scope
class VarDeclNodeRuntime : public ASTNode {
    string varName;
    string varType;
    ASTNode* initExpr;
public:
    VarDeclNodeRuntime(string name, string type, ASTNode* init = nullptr) 
        : varName(name), varType(type), initExpr(init) {
        dataType = "BLACK";  // Variable declarations don't return values
    }
    
    WrapperValue eval(SymbolTableManager* mgr) override {
        // Declare the variable in the CURRENT (runtime/call) scope
        mgr->declareVariable(varName, varType, "variable");
        
        // If there's an initialization expression, evaluate and assign
        if (initExpr) {
            WrapperValue val = initExpr->eval(mgr);
            SymbolInfo* s = mgr->getSymbol(varName);
            if (s) {
                if (s->type == "BOI") s->value = to_string(val.intVal);
                else if (s->type == "WIGGLY") s->value = to_string(val.floatVal);
                else if (s->type == "YAP") s->value = val.strVal;
                else if (s->type == "TRUTHMODE") s->value = val.boolVal ? "1" : "0";
            }
        }
        return WrapperValue();
    }
    
    ~VarDeclNodeRuntime() { if (initExpr) delete initExpr; }
};

// --- Node for "Other" (when function execution not supported) ---
class OtherNode : public ASTNode {
public:
    OtherNode(string t) { dataType = t; }
    WrapperValue eval(SymbolTableManager* mgr) override {
        return WrapperValue::createDefault(dataType);
    }
};

// --- Node for Assignments ---
class AssignNode : public ASTNode {
    string varName;
    ASTNode* expr;
public:
    AssignNode(string name, ASTNode* e) : varName(name), expr(e) { 
        if(e) dataType = e->dataType; 
    }
    
    WrapperValue eval(SymbolTableManager* mgr) override {
        if (!expr) return WrapperValue();
        WrapperValue res = expr->eval(mgr);
        
        // Update SymbolTable
        SymbolInfo* s = mgr->getSymbol(varName);
        if (s) {
            if (s->type == "BOI") s->value = to_string(res.intVal);
            else if (s->type == "WIGGLY") s->value = to_string(res.floatVal);
            else if (s->type == "YAP") s->value = res.strVal;
            else if (s->type == "TRUTHMODE") s->value = res.boolVal ? "1" : "0";
        }
        return res;
    }
    ~AssignNode() { delete expr; }
};

// --- Node for Field Assignment (obj.field = expr) ---
class FieldAssignNode : public ASTNode {
    string objName;
    string fieldName;
    ASTNode* expr;
public:
    FieldAssignNode(string obj, string field, ASTNode* e) : objName(obj), fieldName(field), expr(e) {
        if(e) dataType = e->dataType;
    }
    
    WrapperValue eval(SymbolTableManager* mgr) override {
        if (!expr) return WrapperValue();
        WrapperValue res = expr->eval(mgr);
        
        SymbolInfo* obj = mgr->getSymbol(objName);
        if (!obj) return res;
        
        SymbolTable* classScope = mgr->findClassScope(obj->type);
        if (!classScope) return res;
        
        SymbolInfo* field = classScope->findSymbolLocal(fieldName);
        if (field) {
            if (field->type == "BOI") field->value = to_string(res.intVal);
            else if (field->type == "WIGGLY") field->value = to_string(res.floatVal);
            else if (field->type == "YAP") field->value = res.strVal;
            else if (field->type == "TRUTHMODE") field->value = res.boolVal ? "1" : "0";
        }
        return res;
    }
    ~FieldAssignNode() { delete expr; }
};

// --- Node for Return Statement ---
class ReturnNode : public ASTNode {
    ASTNode* expr;
public:
    ReturnNode(ASTNode* e) : expr(e) { 
        if (e) dataType = e->dataType;
        else dataType = "BLACK";
    }
    
    WrapperValue eval(SymbolTableManager* mgr) override {
        if (expr) {
            WrapperValue res = expr->eval(mgr);
            res.isReturn = true;  // Mark as return
            return res;
        }
        WrapperValue res;
        res.isReturn = true;
        return res;
    }
    ~ReturnNode() { if (expr) delete expr; }
};

// --- Node for Print ---
class PrintNode : public ASTNode {
    ASTNode* expr;
public:
    PrintNode(ASTNode* e) : expr(e) { dataType = "BLACK"; }
    WrapperValue eval(SymbolTableManager* mgr) override {
        if (expr) {
            WrapperValue res = expr->eval(mgr);
            cout << "[PRINT OUTPUT]: ";
            res.print();
            cout << endl;
        }
        return WrapperValue();
    }
    ~PrintNode() { delete expr; }
};

// --- Node for Function Calls - Executes function bodies ---
class FunctionCallNode : public ASTNode {
    string funcName;
    vector<ASTNode*> arguments;
    vector<string> paramNames;
    
public:
    FunctionCallNode(string name, vector<ASTNode*> args, vector<string> params, string retType) 
        : funcName(name), arguments(args), paramNames(params) {
        dataType = retType;
    }
    
    WrapperValue eval(SymbolTableManager* mgr) override {
        // Find the function in symbol table
        SymbolInfo* func = mgr->getSymbol(funcName);
        if (!func || !func->funcBody) {
            return WrapperValue::createDefault(dataType);
        }
        
        // Create new scope for function execution
        mgr->enterScope(funcName + "_call");
        
        // Pass parameters: create local variables with argument values
        for (size_t i = 0; i < arguments.size() && i < paramNames.size(); i++) {
            // Evaluate argument in CALLER's scope (before we set up params)
            WrapperValue argVal = arguments[i]->eval(mgr);
            
            // Declare parameter variable in function scope
            mgr->declareVariable(paramNames[i], func->paramTypes[i], "parameter");
            
            // Set its value
            SymbolInfo* param = mgr->getSymbol(paramNames[i]);
            if (param) {
                if (param->type == "BOI") param->value = to_string(argVal.intVal);
                else if (param->type == "WIGGLY") param->value = to_string(argVal.floatVal);
                else if (param->type == "YAP") param->value = argVal.strVal;
                else if (param->type == "TRUTHMODE") param->value = argVal.boolVal ? "1" : "0";
            }
        }
        
        // Execute function body
        WrapperValue result = WrapperValue::createDefault(dataType);
        for (ASTNode* stmt : *(func->funcBody)) {
            if (stmt) {
                WrapperValue stmtResult = stmt->eval(mgr);
                // Check for return statement
                if (stmtResult.isReturn) {
                    result = stmtResult;
                    result.isReturn = false;  // Clear flag for caller
                    break;
                }
            }
        }
        
        mgr->exitScope();
        return result;
    }
    
    ~FunctionCallNode() {
        for (auto arg : arguments) {
            delete arg;
        }
    }
};

// --- Specialized Binary Nodes ---
class AddNode : public ASTNode {
    ASTNode *left, *right;
public:
    AddNode(ASTNode* l, ASTNode* r) : left(l), right(r) { dataType = l->dataType; }
    WrapperValue eval(SymbolTableManager* mgr) override {
        WrapperValue l = left->eval(mgr);
        WrapperValue r = right->eval(mgr);
        if(dataType == "BOI") return WrapperValue::createInt(l.intVal + r.intVal);
        if(dataType == "WIGGLY") return WrapperValue::createFloat(l.floatVal + r.floatVal);
        if(dataType == "YAP") return WrapperValue::createString(l.strVal + r.strVal);
        return WrapperValue();
    }
    ~AddNode() { delete left; delete right; }
};

class SubNode : public ASTNode {
    ASTNode *left, *right;
public:
    SubNode(ASTNode* l, ASTNode* r) : left(l), right(r) { dataType = l->dataType; }
    WrapperValue eval(SymbolTableManager* mgr) override {
        WrapperValue l = left->eval(mgr);
        WrapperValue r = right->eval(mgr);
        if(dataType == "BOI") return WrapperValue::createInt(l.intVal - r.intVal);
        if(dataType == "WIGGLY") return WrapperValue::createFloat(l.floatVal - r.floatVal);
        return WrapperValue();
    }
    ~SubNode() { delete left; delete right; }
};

class MulNode : public ASTNode {
    ASTNode *left, *right;
public:
    MulNode(ASTNode* l, ASTNode* r) : left(l), right(r) { dataType = l->dataType; }
    WrapperValue eval(SymbolTableManager* mgr) override {
        WrapperValue l = left->eval(mgr);
        WrapperValue r = right->eval(mgr);
        if(dataType == "BOI") return WrapperValue::createInt(l.intVal * r.intVal);
        if(dataType == "WIGGLY") return WrapperValue::createFloat(l.floatVal * r.floatVal);
        return WrapperValue();
    }
    ~MulNode() { delete left; delete right; }
};

class DivNode : public ASTNode {
    ASTNode *left, *right;
public:
    DivNode(ASTNode* l, ASTNode* r) : left(l), right(r) { dataType = l->dataType; }
    WrapperValue eval(SymbolTableManager* mgr) override {
        WrapperValue l = left->eval(mgr);
        WrapperValue r = right->eval(mgr);
        if(dataType == "BOI") {
            if (r.intVal == 0) {
                cerr << "Runtime Error: Division by zero!" << endl;
                return WrapperValue::createInt(0);
            }
            return WrapperValue::createInt(l.intVal / r.intVal);
        }
        if(dataType == "WIGGLY") {
            if (r.floatVal == 0.0) {
                cerr << "Runtime Error: Division by zero!" << endl;
                return WrapperValue::createFloat(0.0);
            }
            return WrapperValue::createFloat(l.floatVal / r.floatVal);
        }
        return WrapperValue();
    }
    ~DivNode() { delete left; delete right; }
};

// Logic/Compare Node
class LogicNode : public ASTNode {
    ASTNode *left, *right;
    string opName; // "AND", "OR", "EQ", "NEQ", "LT", "GT", "LE", "GE"
public:
    LogicNode(ASTNode* l, ASTNode* r, string op) : left(l), right(r), opName(op) { dataType = "TRUTHMODE"; }
    WrapperValue eval(SymbolTableManager* mgr) override {
        WrapperValue l = left->eval(mgr);
        WrapperValue r = right->eval(mgr);
        bool res = false;
        
        if (opName == "AND") res = l.boolVal && r.boolVal;
        else if (opName == "OR") res = l.boolVal || r.boolVal;
        else {
            string opType = left->dataType;
            if (opName == "EQ") {
                if (opType == "BOI") res = (l.intVal == r.intVal);
                else if (opType == "WIGGLY") res = (l.floatVal == r.floatVal);
                else if (opType == "TRUTHMODE") res = (l.boolVal == r.boolVal);
                else if (opType == "YAP") res = (l.strVal == r.strVal);
            }
            else if (opName == "NEQ") {
                if (opType == "BOI") res = (l.intVal != r.intVal);
                else if (opType == "WIGGLY") res = (l.floatVal != r.floatVal);
                else if (opType == "TRUTHMODE") res = (l.boolVal != r.boolVal);
                else if (opType == "YAP") res = (l.strVal != r.strVal);
            }
            else if (opName == "LT") {
                if (opType == "BOI") res = (l.intVal < r.intVal);
                else if (opType == "WIGGLY") res = (l.floatVal < r.floatVal);
            }
            else if (opName == "GT") {
                if (opType == "BOI") res = (l.intVal > r.intVal);
                else if (opType == "WIGGLY") res = (l.floatVal > r.floatVal);
            }
            else if (opName == "LE") {
                if (opType == "BOI") res = (l.intVal <= r.intVal);
                else if (opType == "WIGGLY") res = (l.floatVal <= r.floatVal);
            }
            else if (opName == "GE") {
                if (opType == "BOI") res = (l.intVal >= r.intVal);
                else if (opType == "WIGGLY") res = (l.floatVal >= r.floatVal);
            }
        }
        return WrapperValue::createBool(res);
    }
    ~LogicNode() { delete left; delete right; }
};

#endif