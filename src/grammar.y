%{
#include <cstdio>
#include <iostream>
using namespace std;

extern "C" int yylex();
extern "C" int yyparse();
extern "C" FILE *yyin;

void yyerror(const char *s);
%}

%union
{
	int ival;
	float fval;
	char * sval;
}

%token <sval> KEYWORD
%token <ival> INTLITERAL
%token <fval> FLOATLITERAL
%token <sval> OPERATOR
%token <sval> STRINGLITERAL
%token <sval> IDENTIFIER

%%

stuff:
	stuff KEYWORD {cout << "KEYWORD: " << $2 << endl;}
	| stuff INTLITERAL {cout << "INTLITERAL: " << $2 << endl;}
	| stuff FLOATLITERAL {cout << "FLOATLITERL: " << $2 << endl;}
	| stuff OPERATOR {cout << "OPERATOR: " << $2 << endl;}
	| stuff STRINGLITERAL {cout << "STRINGLITERAL: " << $2 << endl;}
	| stuff IDENTIFIER {cout << "IDENTIFIER: " << $2 << endl;}
	| KEYWORD {cout << "KEYWORD: " << $1 << endl;}
	| INTLITERAL {cout << "INTLITERAL: " << $1 << endl;}
	| FLOATLITERAL {cout << "FLOATLITERL: " << $1 << endl;}
	| OPERATOR {cout << "OPERATOR: " << $1 << endl;}
	| STRINGLITERAL {cout << "STRINGLITERAL: " << $1 << endl;}
	| IDENTIFIER {cout << "IDENTIFIER: " << $1 << endl;}
	;


%%

int main(int argc, char * argv[])
{
	if (argc != 2)
	{
		cout << endl << "Invalid number of arguments" << endl;
		return -1;
	}

	char * in_file = argv[1];

	FILE * fp = fopen(in_file, "r");
	if (!fp)
	{
		cout << "Could not open " << in_file << endl;
		return -1;
	}
	yyin = fp;
	
	do
	{
		yyparse();
	} while (!feof(yyin));
	fclose(fp);
}

void yyerror(const char *s)
{
	cout << "Parse error! Message: " << s << endl;
	exit(-1);
}
