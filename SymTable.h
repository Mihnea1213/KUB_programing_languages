#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <fstream>

using namespace std;

//Structura unui SIMBOL
//Tinem mintre tot ce stim despre o variabila sau functie
struct SymbolInfo
{
    string name; //Numele("x","var")
    string type; //Tipul("BOI","WIGGLY")
    string value; //Valoarea
    string scopeCategory; //"variable", "function", "class_member", "parameter"
    int size; //Pentru array-uri sau dimensiune tip

    //Constructor gol
    SymbolInfo() : name(""), type(""), value(""), scopeCategory(""), size(0) {}

    //Constructor pentru a crea un simbol
    SymbolInfo(string n, string t, string v = "", string cat = "variable")
        : name(n), type(t), value(v), scopeCategory(cat), size(0) {}
};

//Clasa SYMBOL TABLE
//Reprezinta un bloc de cod ({...})
class SymbolTable
{
public:
    string scopeName; //Numele scope-ului ("Global, "FUnction main", "Class Dodge")
    SymbolTable* parent; //Pointer catre scope-ul parinte
    map<string, SymbolInfo> symbols; //Stocam variabile: Cheie="nume", Valoare = Informatii
    vector<SymbolTable*> children; //Lista de scope-uri interioare pentru afisare

    //Constructor
    SymbolTable(string name, SymbolTable* p = nullptr)
    {
        scopeName = name;
        parent = p;
    }

    //Adauga un simbol in tabelul curent
    bool addSymbol(string name, string type, string category = "variable")
    {
        //Verificam daca exista deja in acest scop
        if (symbols.find(name) != symbols.end())
        {
            return false; //Eroare: redeclarare
        }
        symbols.insert({name, SymbolInfo(name, type, "", category)});
        return true;
    }

    //Cauta un simbol. Daca nu e aici, cautam recursiv in parinte
    SymbolInfo* findSymbool(string name)
    {
        //Cautam unde suntem initial
        if (symbols.find(name)!= symbols.end())
        {
            return &symbols[name];
        }

        //Daca nu il gasim si avem parinte, cautam in el
        if (parent != nullptr)
        {
            return parent->findSymbool(name);
        }

        //Nu exista
        return nullptr;
    }

    //Functie pentru a printa tabelul in fisier
    void printTable(ofstream& out, int indentLevel = 0)
    {
        string indent(indentLevel * 4, ' '); //Spatiere

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
                << ", Cat: " <<val.scopeCategory << "]" << endl;
        }
        out << endl;

        //Printam si scope-urile din interior
        for (auto child: children)
        {
            child->printTable(out, indentLevel + 1);
        }
    }

    //Destructor
    ~SymbolTable()
    {
        for (auto child : children)
        {
            delete child;
        }
    }
};

//MANAGERUL DE TABELE
class SymbolTableManager
{
public:
    SymbolTable* globalScope;
    SymbolTable* currentScope;

    SymbolTableManager() {
        globalScope = new SymbolTable("Global");
        currentScope = globalScope;
    }

    //Cand intram intr-un bloc nou (functie, clasa, if ,while)
    void enterScope(string name)
    {
        SymbolTable* newScope = new SymbolTable(name, currentScope);
        currentScope->children.push_back(newScope); //Il tinem minte pentru afisare
        currentScope = newScope; //Ne mutam in el
    }

    //Cand iesim din bloc (})
    void exitScope() {
        if (currentScope->parent != nullptr)
        {
            currentScope = currentScope->parent;
        }
    }

    //Wrapper peste functiile din tabelul curent
    bool declareVariable(string name, string type, string category = "variable")
    {
        return currentScope->addSymbol(name, type, category);
    }

    //Verificam daca o variabila exista
    bool exists(string name)
    {
        return currentScope->findSymbool(name) != nullptr;
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
};