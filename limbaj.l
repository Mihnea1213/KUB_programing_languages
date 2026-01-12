%{
    #include <iostream>
    #include <string>
    #include "limbaj.tab.h" // Token-urile din Bison
    using namespace std;
%}

%option noyywrap

%%
"BOI"             { return TYPE_INT; }
"WIGGLY"          { return TYPE_FLOAT; }
"YAP"             { return TYPE_STRING; } /* Added for homework req */
"TRUTHMODE"       { return TYPE_BOOL; }
"BLACK"           { return TYPE_VOID; }

"BASED"           { return VAL_TRUE; }
"CRINGE"          { return VAL_FALSE; }

"PEPESSACK"       { return KEY_CLASS; } /* struct/class */
"THE_OP"          { return KEY_MAIN; }  /* main function */

"KIRKCHECK"       { return KEY_IF; }
"FINOKOREAN"      { return KEY_ELSE; }
"DIDDLER"         { return KEY_WHILE; }
"YEET"            { return KEY_RETURN; }
"SHOUT"           { return KEY_PRINT; } /* Predefined Print function */

"=="              { return OP_EQ; }
"!="              { return OP_NEQ; }
"<="              { return OP_LE; }
">="              { return OP_GE; }
"&&"              { return OP_AND; }
"||"              { return OP_OR; }

[a-zA-Z_][a-zA-Z0-9_]* { 
    //Salvam textul (numele variabilei) ca sa il folosim in Bison.
    yylval.str_val = strdup(yytext);
    return ID;
}

[0-9]+            { return VAL_INT; }
[0-9]*\.[0-9]+    { return VAL_FLOAT; }
\"[^\"]*\"        { return VAL_STRING; }

[ \t\n]+          ; /* Ignora spatiile */
.                 { return yytext[0]; } /* Returneaza ; { } ( ) = etc */

%%