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
"YAP"             { return TYPE_STRING; }
"TRUTHMODE"       { return TYPE_BOOL; }
"BLACK"           { return TYPE_VOID; }

"BASED"           { return VAL_TRUE; }
"CRINGE"          { return VAL_FALSE; }

"PEPESSACK"       { return KEY_CLASS; }
"THE_OP"          { return KEY_MAIN; } 

"KIRKCHECK"       { return KEY_IF; }
"FINOKOREAN"      { return KEY_ELSE; }
"DIDDLER"         { return KEY_WHILE; }
"YEET"            { return KEY_RETURN; }
"SHOUT"           { return KEY_PRINT; } 

"=="              { return OP_EQ; }
"!="              { return OP_NEQ; }
"<="              { return OP_LE; }
">="              { return OP_GE; }
"&&"              { return OP_AND; }
"||"              { return OP_OR; }

[a-zA-Z_][a-zA-Z0-9_]* { 
    // Save the text (variable name) for use in Bison
    yylval.str_val = strdup(yytext);
    return ID;
}

[0-9]+            { 
    yylval.int_val = atoi(yytext); // <--- FIXED: Assign integer value
    return VAL_INT; 
}

[0-9]*\.[0-9]+    { 
    yylval.float_val = atof(yytext); // <--- FIXED: Assign float value
    return VAL_FLOAT; 
}

\"[^\"]*\"        { 
    // We duplicate yytext (which includes quotes). 
    // Ideally you might want to strip quotes here, but strdup is sufficient to pass data.
    yylval.str_val = strdup(yytext); // <--- FIXED: Assign string value
    return VAL_STRING; 
}

"/*"([^*]|\*+[^*/])*\*+"/"   ;  /* Rule to ignore C-style comments */
[ \t\n]+          ; /* Ignore whitespace */
.                 { return yytext[0]; } /* Return ; { } ( ) = etc */

%%