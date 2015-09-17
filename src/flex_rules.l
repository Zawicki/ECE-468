%{
#include "grammar.tab.h"
using namespace std;
#define YY_DECL extern "C" int yylex(void)
int line_num = 1;
%}

%%

PROGRAM	{return PROGRAM;}
END	{return END;}
FUNCTION	{return FUNCTION;}
READ	{return READ;}
WRITE	{return WRITE;}
IF	{return IF;}
ELSE	{return ELSE;}
FI	{return FI;}
FOR	{return FOR;}
ROF	{return ROF;}
RETURN	{return RETURN;}
INT	{return INT;}
VOID	{return VOID;}
STRING	{return STRING;}
FLOAT	{return FLOAT;}

BEGIN	{return _BEGIN;}

[[:digit:]]+	{yylval.ival = atoi(yytext); return INTLITERAL;}

[[:digit:]]*"."[[:digit:]]+	{yylval.fval = atoi(yytext); return FLOATLITERAL;} 

"+"|"-"|"*"|"/"|"="|"<"|">"|"("|")"|";"|","	{return yytext[0];}

":="	{return ASSIGN;}
"!="	{return NEQ;}
"<="	{return LEQ;} 
">="	{return GEQ;}
	
\"(\\.|[^\"])*\"	{yylval.sval = strdup(yytext); return STRINGLITERAL;}

[[:alpha:]][[:alnum:]]*	{yylval.sval = strdup(yytext); return IDENTIFIER;}

--[^\n]*\n /* catches comments */

[ \t\r]+ /* catch whitespace */

\n	{line_num = line_num + 1;}

%%
