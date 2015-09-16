%{
#include <cstdio>
#include <iostream>
using namespace std;
#define YY_DECL extern "C" int yylex()

#include "grammar.tab.h"
%}

%%

PROGRAM|BEGIN|END|FUNCTION|READ|WRITE|IF|ELSE|FI|FOR|ROF|CONTINUE|BREAK|RETURN|INT|VOID|STRING|FLOAT	{yylval.sval = strdup(yytext); return KEYWORD;}

[[:digit:]]+	{yylval.ival = atoi(yytext); return INTLITERAL;}

[[:digit:]]*"."[[:digit:]]+	{yylval.fval = atoi(yytext); return FLOATLITERAL;}

":="|"+"|"-"|"*"|"/"|"="|"!="|"<"|">"|"("|")"|";"|","|"<="|">="	{yylval.sval = strdup(yytext); return OPERATOR;}

\"(\\.|[^\"])*\"	{yylval.sval = strdup(yytext); return STRINGLITERAL;}
;

[[:alpha:]][[:alnum:]]*	{yylval.sval = strdup(yytext); return IDENTIFIER;}

--[^\n]*\n /* catches comments */

[ \t\n\r]+ /* catch whitespace */

%%
