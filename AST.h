#ifndef AST_H
#define AST_H

#include "SymTable.h"
#include <string>
#include <iostream>
#include <cmath>

using namespace std;

// Wrapper class for values
struct WrapperValue {
    string type; // "BOI", "WIGGLY", "YAP", "TRUTHMODE", "BLACK"
    int intVal = 0;
    float floatVal = 0.0;
    string strVal = "";
    bool boolVal = false;

    WrapperValue() : type("BLACK") {}
    
    // Helpers for easy creation
    static WrapperValue createInt(int v) { WrapperValue w; w.type="BOI"; w.intVal=v; return w; }
    static WrapperValue createFloat(float v) { WrapperValue w; w.type="WIGGLY"; w.floatVal=v; return w; }
    static WrapperValue createString(string v) { WrapperValue w; w.type="YAP"; w.strVal=v; return w; }
    static WrapperValue createBool(bool v) { WrapperValue w; w.type="TRUTHMODE"; w.boolVal=v; return w; }
    
    // Helper to get default value for a type (used for OTHER nodes)
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
        if (!s) return WrapperValue(); // Should not happen if semantic check passed
        
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

// --- Node for "Other" (Function calls, etc.) ---
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

// --- Node for Binary Operations ---
class BinOpNode : public ASTNode {
    ASTNode *left, *right;
    int op; // Token ID (e.g. '+', OP_AND)
public:
    BinOpNode(ASTNode* l, ASTNode* r, int o) : left(l), right(r), op(o) {}
    
    WrapperValue eval(SymbolTableManager* mgr) override {
        WrapperValue l = left->eval(mgr);
        WrapperValue r = right->eval(mgr);
        WrapperValue res; 
        
        // Assume semantic checks ensured types match (or logicals allow it)
        res.type = dataType; // Set by parser

        if (op == '+') {
            if (l.type == "BOI") res = WrapperValue::createInt(l.intVal + r.intVal);
            else if (l.type == "WIGGLY") res = WrapperValue::createFloat(l.floatVal + r.floatVal);
            else if (l.type == "YAP") res = WrapperValue::createString(l.strVal + r.strVal);
        } else if (op == '-') {
            if (l.type == "BOI") res = WrapperValue::createInt(l.intVal - r.intVal);
            else if (l.type == "WIGGLY") res = WrapperValue::createFloat(l.floatVal - r.floatVal);
        } else if (op == '*') {
            if (l.type == "BOI") res = WrapperValue::createInt(l.intVal * r.intVal);
            else if (l.type == "WIGGLY") res = WrapperValue::createFloat(l.floatVal * r.floatVal);
        } else if (op == '/') {
            if (l.type == "BOI" && r.intVal != 0) res = WrapperValue::createInt(l.intVal / r.intVal);
            else if (l.type == "WIGGLY" && r.floatVal != 0) res = WrapperValue::createFloat(l.floatVal / r.floatVal);
        } 
        // Boolean Ops
        // Note: For parsing convenience, tokens like OP_AND are passed as is
        // We need to know the int values of these tokens from limbaj.tab.h but we can't include it easily here due to cycles.
        // We will trust the Op code passed in constructor.
        // Logic operations return TRUTHMODE
        else {
             // Basic comparison logic impl
             bool b = false;
             // Helper for comparisons to avoid massive switch
             // Assuming op codes map to what bison defines. 
             // We can use the 'dataType' of children to decide how to compare
             
             if (left->dataType == "BOI") {
                 // compare ints
                 // Note: This is simplified. In a real project we'd map tokens clearly.
             }
        }
        
        // Implementing logic based on the specific required ops for Step IV
        // Since we can't easily access token enums here without circular deps, 
        // we'll implement the logic in the Parser action where we create the specific subclass or 
        // we just handle basic + - * / and treat others generic or use simple integer constants if valid.
        // For the sake of this assignment, I'll rely on the parser setting the specific result.
        
        // Actually, let's implement the logic properly by numeric mapping if possible, 
        // OR better: define the logic inline here.
        // For boolean ops, result is TRUTHMODE.
        return res;
    }

    // Overload for specific Ops where we know the implementation
    // But since `op` is just an int, we'd need the definitions.
    // Instead, I'll implement a flexible eval in `limbaj.y`'s node creation? No, logic must be here.
    // I will assume standard ASCII for single chars and handle named tokens generically or specific cases.
    
    // RE-IMPLEMENTATION: Simple logic for + - * / is above.
    // For relational/logical, we need the token values. 
    // I will add public methods to set operation type or subclass.
};

// Specialized Binary Nodes to avoid token dependency issues in AST.h
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
};

class DivNode : public ASTNode {
    ASTNode *left, *right;
public:
    DivNode(ASTNode* l, ASTNode* r) : left(l), right(r) { dataType = l->dataType; }
    WrapperValue eval(SymbolTableManager* mgr) override {
        WrapperValue l = left->eval(mgr);
        WrapperValue r = right->eval(mgr);
        if(dataType == "BOI") return WrapperValue::createInt(r.intVal ? l.intVal / r.intVal : 0);
        if(dataType == "WIGGLY") return WrapperValue::createFloat(r.floatVal ? l.floatVal / r.floatVal : 0);
        return WrapperValue();
    }
};

// Logic/Compare Node
class LogicNode : public ASTNode {
    ASTNode *left, *right;
    string opName; // "AND", "OR", "EQ", "NEQ", "LT", "GT"
public:
    LogicNode(ASTNode* l, ASTNode* r, string op) : left(l), right(r), opName(op) { dataType = "TRUTHMODE"; }
    WrapperValue eval(SymbolTableManager* mgr) override {
        WrapperValue l = left->eval(mgr);
        WrapperValue r = right->eval(mgr);
        bool res = false;
        
        if (opName == "AND") res = l.boolVal && r.boolVal;
        else if (opName == "OR") res = l.boolVal || r.boolVal;
        else {
            // Comparisons
            // Need to know operand type to compare correctly
            string opType = left->dataType; // Assume left==right due to semantic check
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
        }
        return WrapperValue::createBool(res);
    }
};



#endif