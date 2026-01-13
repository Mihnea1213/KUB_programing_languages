#ifndef SYMTABLE_H
#define SYMTABLE_H

#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <fstream>
#include <algorithm>

using namespace std;

class ASTNode;

struct SymbolInfo
{
    string name;
    string type;
    string value;
    string scopeCategory;
    int size;
    vector<string> paramTypes;
    vector<string> paramNames;  // NEW: Store parameter names for function calls
    vector<ASTNode*>* funcBody = nullptr;
    
    SymbolInfo() : name(""), type(""), value(""), scopeCategory(""), size(0) {}
    
    SymbolInfo(string n, string t, string v = "", string cat = "variable")
        : name(n), type(t), value(v), scopeCategory(cat), size(0) {}
    
    // Note: funcBody cleanup is handled by SymbolTable destructor
    // to avoid circular dependency issues
};

class SymbolTable
{
public:
    string scopeName;
    SymbolTable* parent;
    map<string, SymbolInfo> symbols;
    vector<SymbolTable*> children;

    SymbolTable(string name, SymbolTable* p = nullptr)
    {
        scopeName = name;
        parent = p;
    }

    bool addSymbol(string name, string type, string category = "variable")
    {
        if (symbols.find(name) != symbols.end())
        {
            return false;
        }
        symbols.insert({name, SymbolInfo(name, type, "", category)});
        return true;
    }

    bool addFunctionSymbol(string name, string type, vector<string> params)
    {
        if(symbols.find(name) != symbols.end())
        {
            return false;
        }
        SymbolInfo info(name,type, "", "function");
        info.paramTypes = params;
        symbols.insert({name, info});
        return true;
    }

    SymbolInfo* findSymbol(string name)
    {
        if (symbols.find(name)!= symbols.end())
        {
            return &symbols[name];
        }

        if (parent != nullptr)
        {
            return parent->findSymbol(name);
        }

        return nullptr;
    }

    SymbolInfo* findSymbolLocal (string name)
    {
        if (symbols.find(name)!= symbols.end())
        {
            return &symbols[name];
        }
        return nullptr;
    }

    void printTable(ofstream& out, int indentLevel = 0)
    {
        string indent(indentLevel * 4, ' ');

        out << indent << "=== SCOPE: " << scopeName << " ===" << endl;
        if (parent)
        {
            out << indent << "Parent: " << parent->scopeName << endl;
        }
        out << indent << "Symbols:" << endl;

        for (auto const& [key, val] : symbols)
        {
            out << indent << " [Name: " << val.name
                << ", Type: " << val.type
                << ", Cat: " <<val.scopeCategory
                << ", Val: " << val.value;

            if(val.scopeCategory == "function" && !val.paramTypes.empty())
            {
                out << ", Params: (";
                for(size_t i = 0 ; i < val.paramTypes.size(); i++)
                {
                    out << val.paramTypes[i];
                    if (!val.paramNames.empty() && i < val.paramNames.size()) {
                        out << " " << val.paramNames[i];
                    }
                    if (i < val.paramTypes.size()-1) out << ", ";
                }
                out << ")";
            }
            out << "]" << endl;
        }
        out << endl;

        for (auto child: children)
        {
            child->printTable(out, indentLevel + 1);
        }
    }

    ~SymbolTable()
    {
        // Note: Function body cleanup happens in SymbolTableManager
        // to avoid circular dependency with ASTNode
        for (auto child : children)
        {
            delete child;
        }
    }
};

class SymbolTableManager
{
public:
    SymbolTable* globalScope;
    SymbolTable* currentScope;

    SymbolTableManager() {
        globalScope = new SymbolTable("Global");
        currentScope = globalScope;
    }

    void enterScope(string name)
    {
        SymbolTable* newScope = new SymbolTable(name, currentScope);
        currentScope->children.push_back(newScope);
        currentScope = newScope;
    }

    SymbolInfo* getSymbol(string name)
    {
        return currentScope->findSymbol(name);
    }

    void exitScope() {
        if (currentScope->parent != nullptr)
        {
            currentScope = currentScope->parent;
        }
    }

    bool declareVariable(string name, string type, string category = "variable")
    {
        return currentScope->addSymbol(name, type, category);
    }

    bool declareFunction(string name, string type, vector<string> params)
    {
        return currentScope->addFunctionSymbol(name,type,params);
    }

    void updateFunctionParams(string name, vector<string> params, vector<string> names)
    {
        SymbolTable* searchScope = currentScope->parent;
        if(searchScope)
        {
            auto it = searchScope->symbols.find(name);
            if(it != searchScope->symbols.end())
            {
                it->second.paramTypes = params;
                it->second.paramNames = names;
            }
        }
    }
    
    // NEW: Store function body
    void storeFunctionBody(string name, vector<ASTNode*>* body)
    {
        SymbolTable* searchScope = currentScope->parent;
        if(searchScope)
        {
            auto it = searchScope->symbols.find(name);
            if(it != searchScope->symbols.end())
            {
                it->second.funcBody = body;
            }
        }
    }

    bool exists(string name)
    {
        return currentScope->findSymbol(name) != nullptr;
    }
    
    SymbolTable* findClassScope(string className)
    {
        for(auto child : globalScope->children)
        {
            if(child->scopeName == className)
            {
                return child;
            }
        }
        return nullptr;
    }

    void printAllTables(string filename)
    {
        ofstream out(filename);
        if (out.is_open())
        {
            globalScope->printTable(out);
            out.close();
        }
    }
    
    ~SymbolTableManager() {
        // Clean up function bodies before deleting globalScope
        cleanupFunctionBodies(globalScope);
        delete globalScope;
    }
    
private:
    // Helper to clean up function bodies recursively
    void cleanupFunctionBodies(SymbolTable* table) {
        if (!table) return;
        
        // Clean up function bodies in this scope
        for (auto& [key, val] : table->symbols) {
            if (val.funcBody) {
                for (auto node : *(val.funcBody)) {
                    delete node;
                }
                delete val.funcBody;
                val.funcBody = nullptr;
            }
        }
        
        // Recursively clean up children
        for (auto child : table->children) {
            cleanupFunctionBodies(child);
        }
    }
};

#endif