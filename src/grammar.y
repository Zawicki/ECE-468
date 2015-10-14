%code top{
#include <cstdio>
#include <iostream>
#include <map>
#include <stack>
#include <sstream>
#include <vector>

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

stringstream ss, IR;

vector <string> id_vec;

int reg_cnt = 0;

}

%code requires
{
	#include "./src/AST.h"
	#include <string>
	void makeIR(ASTNode * n);
	void destroy_AST(ASTNode * n);
}

%union
{
	int ival;
	float fval;
	char *sval;
	ASTNode *AST_ptr;
}

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

%token <sval> INTLITERAL
%token <sval> FLOATLITERAL
%token <sval> STRINGLITERAL
%token <sval> IDENTIFIER

%type <sval> id str var_type
%type <AST_ptr> primary postfix_expr call_expr expr_list expr_list_tail addop mulop assign_expr factor factor_prefix expr_prefix expr
%%

program:
	PROGRAM id _BEGIN	{scope.push("GLOBAL")}
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
					}}
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
			}}
	;
param_decl_tail:
	',' param_decl param_decl_tail | 
	;

func_declarations:
	func_decl func_declarations | 
	;
func_decl:
	FUNCTION any_type id	{scope.push($3);} 
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
	base_stmt | if_stmt| for_stmt	
	;
base_stmt:
	assign_stmt
	| read_stmt 
	| write_stmt 
	| return_stmt
	;

assign_stmt:
	assign_expr ';' {makeIR($1); /*cout << endl;*/ destroy_AST($1)}
	;
assign_expr:
	id ASSIGN expr {map <string, wrapper>  m = symbol_table["GLOBAL"];
			string key = $1;
			Node * n = new Node(key, m[key].vals[0], "VAR");
			 $$ = new OpNode("=", n, $3)}
	;
read_stmt:
	READ '(' id_list ')' ';' {for (vector <string>::reverse_iterator it = id_vec.rbegin(); it != id_vec.rend(); ++it)
				{
					map <string, wrapper> m = symbol_table["GLOBAL"];
					if (m[*it].vals[0] == "INT")
						IR << "READI " << *it << endl;
					else
						IR << "READF " << *it << endl;
				}
				id_vec.clear()}

	;
write_stmt:
	WRITE '(' id_list ')' ';' {for (vector <string>::reverse_iterator it = id_vec.rbegin(); it != id_vec.rend(); ++it)
				{
					map <string, wrapper> m = symbol_table["GLOBAL"];
					if (m[*it].vals[0] == "INT")
						IR << "WRITEI " << *it << endl;
					else
						IR << "WRITEF " << *it << endl;
				}
				id_vec.clear()}
	;
return_stmt:
	RETURN expr ';'
	;

expr:
	expr_prefix factor {if ($1 != NULL) {$1->right = $2; $$ = $1;} else $$ = $2}
	;
expr_prefix:
	expr_prefix factor addop {if ($1 != NULL) {$3->left = $1; $1->right = $2;} else {$3->left = $2;} $$ = $3}
	| {$$ = NULL}
	;
factor:
	factor_prefix postfix_expr {if ($1 != NULL) {$1->right = $2; $$ = $1;} else $$ = $2}
	;
factor_prefix:
	factor_prefix postfix_expr mulop {if ($1 != NULL) {$3->left = $1; $2->right = $2;} else {$3->left = $2;} $$ = $3} 
	| {$$ = NULL}
	;
postfix_expr:
	primary {$$ = $1} | call_expr {$$ = $1}
	;
call_expr:
	id '(' expr_list ')' {$$ = $3}
	;
expr_list:
	expr expr_list_tail {$$ = $1}
	| {$$ = NULL} 
	;
expr_list_tail:
	',' expr expr_list_tail {$$ = $2}
	| {$$ = NULL}
	;
primary:
	'(' expr ')' {$$ = $2}
	| id {map <string, wrapper> m = symbol_table["GLOBAL"]; string key = $1; $$ = new Node(key, m[key].vals[0], "VAR")}
	| INTLITERAL {$$ = new Node($1, "INT", "CONST")}
	| FLOATLITERAL {$$ = new Node($1, "FLOAT", "CONST")}
	;
addop:
	'+' {$$ = new OpNode("+")}
	| '-' {$$ = new OpNode("-")}
	;
mulop:
	'*' {$$ = new OpNode("*")}
	| '/' {$$ = new OpNode("/")}
	;

if_stmt:
	IF  {push_block()}
	'(' cond ')' decl 
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
	FOR  {push_block()}
	'(' init_stmt ';' cond ';' incr_stmt ')' decl 	
	stmt_list ROF	{scope.pop()}
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
		cout << "Could not open file " << in_file << endl;
		return -1;
	}
	yyin = fp;
	
	do
	{
		yyparse();
	} while (!feof(yyin));
	fclose(fp);

	//Uncomment below to print off the symbol table directly from the maps
	/*cout << endl << "-------------------------------------------------" << endl;
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
	}*/

	cout << IR.str();

	return 0;
}

void push_block()
{
	ss.str("");
	ss << "BLOCK " << ++block_cnt;
	scope.push(ss.str());
}

void add_symbol_table()
{
	symbol_table[scope.top()] = table;
	table.clear();
}

void yyerror(const char *s)
{
	cout << "DECLARATION ERROR " << s << endl;
	exit(line_num);
}

void makeIR(ASTNode * n)
{
	if (n != NULL)
	{
		makeIR(n->left);
		makeIR(n->right);
		//cout << n->value() << " ";
		ss.str("");
		switch (n->value()[0])
		{
			case '+':
				if (n->right->data_type() == "INT")
					IR << "ADDI " <<  n->left->reg << " " << n->right->reg << " $T" << ++reg_cnt << endl;
				if (n->right->data_type() == "FLOAT")
					IR << "ADDF " <<  n->left->reg << " " << n->right->reg << " $T" << ++reg_cnt << endl;
				ss << "$T" << reg_cnt;
				n->reg = ss.str();
				break;
			case '-':
				if (n->right->data_type() == "INT")
					IR << "SUBI " <<  n->left->reg << " " << n->right->reg << " $T" << ++reg_cnt << endl;
				if (n->right->data_type() == "FLOAT")
					IR << "SUBF " <<  n->left->reg << " " << n->right->reg << " $T" << ++reg_cnt << endl;
				ss << "$T" << reg_cnt;
				n->reg = ss.str();
				break;
			case '*':
				if (n->right->data_type() == "INT")
					IR << "MULTI " <<  n->left->reg << " " << n->right->reg << " $T" << ++reg_cnt << endl;
				if (n->right->data_type() == "FLOAT")
					IR << "MULTF " <<  n->left->reg << " " << n->right->reg << " $T" << ++reg_cnt << endl;
				ss << "$T" << reg_cnt;
				n->reg = ss.str();
				break;
			case '/': 
				if (n->right->data_type() == "INT")
					IR <<"DIVI " <<  n->left->reg << " " << n->right->reg << " $T" << ++reg_cnt << endl;
				if (n->right->data_type() == "FLOAT")
					IR << "DIVF " <<  n->left->reg << " " << n->right->reg << " $T" << ++reg_cnt << endl;
				ss << "$T" << reg_cnt;
				n->reg = ss.str();
				break;
			case '=': 
				if (n->left->data_type() == "INT")
					IR << "STOREI " << n->right->reg << " " << n->left->value() << endl;
				if (n->left->data_type() == "FLOAT")
					IR << "STOREF " << n->right->reg << " " << n->left->value() << endl;
				break;
			default:
				if (n->node_type() == "CONST")
				{
					if (n->data_type() == "INT")
						IR << "STOREI " << n->value() << " $T" << ++reg_cnt << endl;
					if (n->data_type() == "FLOAT")
						IR << "STOREF " << n->value() << " $T" << ++reg_cnt << endl;
					ss << "$T" << reg_cnt;
					n->reg = ss.str();
				}
				else
					n->reg = n->value();
		}
	}
}

void destroy_AST(ASTNode * n)
{
	if (n != NULL)
	{
		destroy_AST(n->left);
		destroy_AST(n->right);
		delete n;
	}
}
