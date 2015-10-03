%{
#include <cstdio>
#include <iostream>
#include <map>
#include <stack>
#include <sstream>
using namespace std;

extern "C" int yylex(void);
extern "C" int yyparse();
extern "C" FILE *yyin;
extern int line_num;

void yyerror(const char *s);
void push_block();

stack <string> scope;

//map <string, map<string, string[2]> > symbol_table;

int block_cnt = 0;

stringstream ss;

//struct wrapper { string vals[2]; };

%}

%union
{
	int ival;
	float fval;
	char* sval;
};

%token PROGRAM
%token _BEGIN
%token END
%token FUNCTION
%token READ
%token WRITE
%token IF
%token ELSE
%token FI
%token FOR
%token ROF
%token RETURN
%token INT
%token VOID
%token STRING
%token FLOAT

%token ASSIGN
%token NEQ
%token LEQ
%token GEQ

%token <ival> INTLITERAL
%token <fval> FLOATLITERAL
%token <sval> STRINGLITERAL
%token <sval> IDENTIFIER

%type <sval> id

%%

program:
	PROGRAM id _BEGIN	{scope.push("GLOBAL"); cout << "Symbol table " << scope.top() << endl}
	pgm_body END	{scope.pop()}
	;
id:
	IDENTIFIER	{$$ = $1}
	;
pgm_body:
	decl func_declarations
	;
decl:
	string_decl decl | var_decl decl | 
	;

string_decl:
	STRING id ASSIGN str ';'	
	;
str:
	STRINGLITERAL
	;

var_decl:
	var_type id_list ';'
	;
var_type:
	FLOAT | INT
	;
any_type:
	var_type | VOID
	;
id_list:
	id id_tail
	;
id_tail:
	',' id id_tail | 
	;

param_decl_list:
	param_decl param_decl_tail | 
	;
param_decl:
	var_type id
	;
param_decl_tail:
	',' param_decl param_decl_tail | 
	;

func_declarations:
	func_decl func_declarations | 
	;
func_decl:
	FUNCTION any_type id	{scope.push($3); cout << endl << "Symbol table " << scope.top() << endl} 
	'(' param_decl_list ')' _BEGIN func_body 
	END {scope.pop()}
	;
func_body:
	decl stmt_list
	;

stmt_list:
	stmt stmt_list | 
	;
stmt:
	base_stmt | if_stmt {push_block()} | for_stmt {push_block()}
	;
base_stmt:
	assign_stmt | read_stmt | write_stmt | return_stmt
	;

assign_stmt:
	assign_expr ';'
	;
assign_expr:
	id ASSIGN expr
	;
read_stmt:
	READ '(' id_list ')' ';'
	;
write_stmt:
	WRITE '(' id_list ')' ';'
	;
return_stmt:
	RETURN expr ';'
	;

expr:
	expr_prefix factor
	;
expr_prefix:
	expr_prefix factor addop | 
	;
factor:
	factor_prefix postfix_expr
	;
factor_prefix:
	factor_prefix postfix_expr mulop |
	;
postfix_expr:
	primary | call_expr
	;
call_expr:
	id '(' expr_list ')'
	;
expr_list:
	expr expr_list_tail | 
	;
expr_list_tail:
	',' expr expr_list_tail | 
	;
primary:
	'(' expr ')' | id | INTLITERAL | FLOATLITERAL
	;
addop:
	'+' | '-'
	;
mulop:
	'*' | '/'
	;

if_stmt:
	IF '(' cond ')' decl stmt_list else_part 
	FI {scope.pop()}
	;
else_part:
	ELSE {push_block()} 
	decl stmt_list {scope.pop()}|
	;
cond:
	expr compop expr
	;
compop:
	'<' | '>' | '=' | NEQ | LEQ | GEQ
	;

init_stmt:
	assign_expr | 
	;
incr_stmt:
	assign_expr |
	;

for_stmt:
	FOR
	'(' init_stmt ';' cond ';' incr_stmt ')' decl stmt_list 
	ROF	{scope.pop()}
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

	cout << endl << "popping off the rest of the stack" << endl;

	while(!scope.empty())
	{
		cout << scope.top() << endl;
		scope.pop();
	}
	return 0;
}

void push_block()
{
	ss.str(""); 
	ss << "BLOCK " << ++block_cnt; 
	scope.push(ss.str());
	cout << endl << "Symbol table " << scope.top() << endl;
}

void yyerror(const char *s)
{
	cout << "Not accepted" << endl;
	exit(line_num);
}
