%%

PROGRAM|BEGIN|END|FUNCTION|READ|WRITE|IF|ELSE|FI|FOR|ROF|CONTINUE|BREAK|RETURN|INT|VOID|STRING|FLOAT	printf("Token Type: KEYWORD\nValue: %s\n", yytext);

[[:digit:]]+	printf("Token Type: INTLITERAL\nValue: %s\n", yytext);

[[:digit:]]*"."[[:digit:]]+	printf("Token Type: FLOATLITERAL\nValue: %s\n", yytext);

":="|"+"|"-"|"*"|"/"|"="|"!="|"<"|">"|"("|")"|";"|","|"<="|">="	printf("Token Type: OPERATOR\nValue: %s\n", yytext);

\"(\\.|[^\"])*\"	printf("Token Type: STRINGLITERAL\nValue: %s\n", yytext);

[[:alpha:]][[:alnum:]]*	printf("Token Type: IDENTIFIER\nValue: %s\n", yytext);

--[^\n]*\n /* catches comments */

[ \t\n\r]+ /* catch whitespace */

%%

int main(int argc, char ** argv)
{
	if (argc != 2)
	{
		printf("\nInvalid number of arguments");
		return EXIT_FAILURE;
	}

	char * in_file = argv[1];

	FILE * fp = fopen(in_file, "r");
	yyset_in(fp);
	yylex();
	fclose(fp);
}
