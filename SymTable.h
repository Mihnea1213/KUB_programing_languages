#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <fstream>
#include <algorithm>

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
    vector<string> paramTypes; //Lista de tipuri a parametrilor (doar pentru functii)

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

    //Functie care adauga un simbol dar ii si seteaza parametrii
    //Folosita cand definim functii
    bool addFunctionSymbol(string name, string type, vector<string> params)
    {
        if(symbols.find(name) != symbols.end())
        {
            return false;
        }
        SymbolInfo info(name,type, "", "function");
        info.paramTypes = params; //Salvam semnatura functiei
        symbols.insert({name, info});
        return true;
    }

    //Cauta un simbol. Daca nu e aici, cautam recursiv in parinte
    SymbolInfo* findSymbol(string name)
    {
        //Cautam unde suntem initial
        if (symbols.find(name)!= symbols.end())
        {
            return &symbols[name];
        }

        //Daca nu il gasim si avem parinte, cautam in el
        if (parent != nullptr)
        {
            return parent->findSymbol(name);
        }

        //Nu exista
        return nullptr;
    }

    //Cautam un simbol DOAR in tabelul curent (fara parinti)
    //Util pentru verificarea membrilor clasei (d.x -> x trebuie sa fie fix in clasa aia)
    SymbolInfo* findSymbolLocal (string name)
    {
        if (symbols.find(name)!= symbols.end())
        {
            return &symbols[name];
        }
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
                << ", Cat: " <<val.scopeCategory;

            //Afisama si parametrii daca e functie
            if(val.scopeCategory == "function" && !val.paramTypes.empty())
            {
                out << ", Params: (";
                for(size_t i = 0 ; i < val.paramTypes.size(); i++)
                {
                    out << val.paramTypes[i] << (i<val.paramTypes.size()-1 ? ", " : "");
                }
                out << ")";
            }
            out << "]" << endl;
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

    SymbolInfo* getSymbol(string name)
    {
        return currentScope->findSymbol(name);
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

    //Wrapper pentru declararea functiilor cu parametrii
    bool declareFunction(string name, string type, vector<string> params)
    {
        return currentScope->addFunctionSymbol(name,type,params);
    }

    //Metoda pentru a actualiza parametrii unei functii deja declarate
    void updateFunctionParams(string name, vector<string> params)
    {
        //FUnctia este in scope-ul PARINTE, nu in scope-ul propriu
        SymbolTable* searchScope = currentScope->parent;
        if(searchScope)
        {
            auto it = searchScope->symbols.find(name);
            if(it != searchScope->symbols.end())
            {
                it->second.paramTypes = params;
            }
        }
    }

    //Verificam daca o variabila exista
    bool exists(string name)
    {
        return currentScope->findSymbol(name) != nullptr;
    }
    //Gaseste scope-ul unei clase dupa nume
    SymbolTable* findClassScope(string className)
    {
        //Cautam in copiii scope-ului global
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
};