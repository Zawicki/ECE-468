%{
#include <cstdio>
#include <iostream>
#include <map>
#include <stack>
#include <sstream>
#include <vector>
#include <string>
using namespace std;

extern "C" int yylex(void);
extern "C" int yyparse();
extern "C" FILE *yyin;
extern int line_num;

void yyerror(const char *s);
void push_block();
void add_symbol_table();

struct wrapper 
{ 
	string vals[2]; 
}w, p;

stack <string> scope;

pair<map <string, wrapper>::iterator, bool> r;
map <string, wrapper> table;

map <string, map<string, wrapper> > symbol_table;

int block_cnt = 0;

stringstream ss;

vector <string> id_vec;

%}

%union
{
	int ival;
	float fval;
	char * sval;
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
%token <sval> INT
%token VOID
%token STRING
%token <sval> FLOAT

%token ASSIGN
%token NEQ
%token LEQ
%token GEQ

%token <ival> INTLITERAL
%token <fval> FLOATLITERAL
%token <sval> STRINGLITERAL
%token <sval> IDENTIFIER

%type <sval> id str var_type

%%

program:
	PROGRAM id _BEGIN	{scope.push("GLOBAL"); cout << "Symbol table " << scope.top() << endl}
	pgm_body END	{scope.pop()}
	;
id:
	IDENTIFIER	{$$ = $1}
	;
pgm_body:
	decl	
	func_declarations
	;
decl:
	string_decl decl | var_decl decl | {add_symbol_table()} 
	;

string_decl:
	STRING id ASSIGN str ';'	{w.vals[0] = "STRING";
					w.vals[1] = $4;
					r = table.insert(pair<string, wrapper>($2, w));
					if (!r.second)
					{
						yyerror($2);
					}
					p = table.find($2)->second;
					cout << "name " << $2 << " type " << p.vals[0] << " value " << p.vals[1] << endl}	
	;
str:
	STRINGLITERAL	{$$ = $1}
	;

var_decl:
	var_type id_list ';'	{for (vector <string>::reverse_iterator it = id_vec.rbegin(); it != id_vec.rend(); ++it)
				{
					w.vals[0] = $1;
					w.vals[1] = "";
					r = table.insert(pair<string, wrapper>(*it, w));
					if (!r.second)
					{
						string tmp = *it;
						yyerror(tmp.c_str());
					}
					p = table.find(*it)->second;
					cout << "name " << *it << " type " << p.vals[0] << endl;
				}
				id_vec.clear()}
	;
var_type:
	FLOAT {$$ = $1} 
	| INT {$$ = $1}
	;
any_type:
	var_type | VOID
	;
id_list:
	id id_tail	{id_vec.push_back($1)}
	;
id_tail:
	',' id id_tail {id_vec.push_back($2)}| 
	;

param_decl_list:
	param_decl param_decl_tail | 
	;
param_decl:
	var_type id	{w.vals[0] = $1; w.vals[1] = "";
			r = table.insert(pair<string, wrapper>($2, w));
			if (!r.second)
			{
				yyerror($2);
			}
			p = table.find($2)->second;
			cout << "name " << $2 << " type " << p.vals[0] << endl}
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
	decl
	stmt_list
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
	IF '(' cond ')' decl
	stmt_list else_part 
	FI {scope.pop()}
	;
else_part:
	ELSE {push_block()} 
	decl
	stmt_list {scope.pop()}|
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
	FOR '(' init_stmt ';' cond ';' incr_stmt ')' decl stmt_list 
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

	cout << endl << "-------------------------------------------------" << endl;
	cout << "Iterating through the symbol table" << endl << endl;
	
	for (map <string, map <string, wrapper> >::iterator it = symbol_table.begin(); it != symbol_table.end(); ++it)
	{
		cout << endl << "Symbol table " << it->first << endl;
		map <string, wrapper> &internal_map = it->second;
		for (map <string, wrapper>::iterator it2 = internal_map.begin(); it2 != internal_map.end(); ++it2)
		{
			p = it2->second;
			if (p.vals[0] == "STRING")
				cout << "name " << it2->first << " type " << p.vals[0] << " value " << p.vals[1] << endl;
			else
				cout << "name " << it2->first << " type " << p.vals[0] << endl;

		}
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

void add_symbol_table()
{
	cout << "Adding table for scope " << scope.top() << endl;
	symbol_table[scope.top()] = table;
	//table.clear();
}

void yyerror(const char *s)
{
	cout << "DECLARATION ERROR " << s << endl;
	exit(line_num);
}
