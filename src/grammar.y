%{
#include <cstdio>
#include <iostream>
#include <map>
#include <stack>
#include <sstream>
#include <vector>
#include <iterator>
#include <string>

using namespace std;

extern "C" int yylex(void);
extern "C" int yyparse();
extern "C" FILE *yyin;
extern int line_num;

struct wrapper 
{ 
	string vals[2];
}w, p;

void yyerror(const char *s);

void push_block();
void add_symbol_table();
map <string, wrapper> find_symbol_table(string id);

void assemble_addop(string opcode, string op1, string op2, int * curr_reg, int * add_temp, int * mul_temp, int * output_reg);
void assemble_mulop(string opcode, string op1, string op2, int * curr_reg, int * temp, int * output_reg);
void assemble_cmpi(string op1, string op2, string saved_reg, int output_reg, int * curr_reg);
void assemble_cmpr(string op1, string op2, string saved_reg, int output_reg, int * curr_reg);



stack <string> scope; // A stack holding the current valid scopes during parsing
stack <string> scope_help; // A stack to hold scopes when using a variable that was not declared in the current scope

pair<map <string, wrapper>::iterator, bool> r;
map <string, wrapper> table; // A scope of the symbol table

map <string, map<string, wrapper> > symbol_table; // The symbol table

int block_cnt = 0; // A counter for naming block scopes during parsing
int lbl_cnt = 0; // A counter for naming IR labels during parsing

stringstream ss; // A string stream used to make printing int/floats easier simple

vector <string> id_vec, vars, str_const;

int reg_cnt = 0; // A counter used for generating the registers in the IR code
stack <int> regs; // Keeps track of registers in an expression
stack <string> labels; // Holds the labels for control flow statements
%}

%code requires
{
	#include "./src/Nodes.h"
	void makeIR(ASTNode * n);
	string CondExprIR(ASTNode * n, string * t);
	void destroy_AST(ASTNode * n);
}

%code 
{
vector <IRNode> IR;
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

%type <sval> id str var_type compop
%type <AST_ptr> primary postfix_expr call_expr expr_list expr_list_tail addop mulop
%type <AST_ptr> init_stmt incr_stmt assign_expr factor factor_prefix expr_prefix expr
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
					}
					ss.str("");
					ss << "str " << $2 << " " << $4; 
					str_const.push_back(ss.str())}
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
					vars.push_back(*it);
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
	assign_expr ';' {makeIR($1); destroy_AST($1)}
	;
assign_expr:
	id ASSIGN expr {string key = $1;
			map <string, wrapper>  m = find_symbol_table(key);
			VarNode * n = new VarNode(key, m[key].vals[0]);
			 $$ = new OpNode("=", n, $3)}
	;
read_stmt:
	READ '(' id_list ')' ';' {for (vector <string>::reverse_iterator it = id_vec.rbegin(); it != id_vec.rend(); ++it)
				{
					map <string, wrapper> m = find_symbol_table(*it);
					if (m[*it].vals[0] == "INT")
						IR.push_back(IRNode("READI", "", "", *it));
					else
						IR.push_back(IRNode("READF", "", "", *it));
				}
				id_vec.clear()}

	;
write_stmt:
	WRITE '(' id_list ')' ';' {for (vector <string>::reverse_iterator it = id_vec.rbegin(); it != id_vec.rend(); ++it)
				{
					map <string, wrapper> m = find_symbol_table(*it);
					if (m[*it].vals[0] == "INT")
						IR.push_back(IRNode("WRITEI", "", "", *it));
					else if (m[*it].vals[0] == "FLOAT")
						IR.push_back(IRNode("WRITEF", "", "", *it));
					else
						IR.push_back(IRNode("WRITES", "", "", *it));

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
	| id {string key = $1; map <string, wrapper> m = find_symbol_table(key); $$ = new VarNode(key, m[key].vals[0])}
	| INTLITERAL {$$ = new ConstIntNode($1)}
	| FLOATLITERAL {$$ = new ConstFloatNode($1)}
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
	'(' cond ')' 
	decl stmt_list {ss.str(""); ss << "label" << lbl_cnt++; IR.push_back(IRNode("JUMP", "", "", ss.str())); IR.push_back(IRNode("LABEL", "", "", labels.top())); labels.pop(); labels.push(ss.str())}
	else_part {IR.push_back(IRNode("LABEL", "", "", labels.top())); labels.pop()}
	FI {scope.pop()}
	;
else_part:
	ELSE {push_block()} 
	decl  
	stmt_list {scope.pop()} |
	;
cond:
	expr compop expr {string t; string op1 = CondExprIR($1, &t); IR.push_back(IRNode("", "", "", "", "SAVE")); string op2 = CondExprIR($3, &t); ss.str(""); ss << "label" << lbl_cnt++;  IR.push_back(IRNode($2, op1, op2, ss.str(), t)); labels.push(ss.str()); destroy_AST($1); destroy_AST($3)}
	;
compop:
	'<' {$$ = (char *)"GE"} | '>' {$$ = (char *)"LE"} | '=' {$$ = (char *)"NE"} | NEQ {$$ = (char *)"EQ"} | LEQ {$$ = (char *)"GT"} | GEQ {$$ = (char *)"LT"}
	;

init_stmt:
	assign_expr {$$ = $1} | {$$ = NULL} 
	;
incr_stmt:
	assign_expr {$$ = $1} | {$$ = NULL}
	;

for_stmt:
	FOR  {push_block()}
	'(' 
	init_stmt ';' {makeIR($4); destroy_AST($4); ss.str(""); ss << "label" << lbl_cnt++; labels.push(ss.str()); IR.push_back(IRNode("LABEL", "", "", ss.str()))}
	cond ';'
	incr_stmt 
	')' 
	decl stmt_list {makeIR($9); destroy_AST($9); string temp = labels.top(); labels.pop(); IR.push_back(IRNode("JUMP", "", "", labels.top())); labels.push(temp); IR.push_back(IRNode("LABEL", "", "", temp))}
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

	// Print the IR code
	cout << ";IR code" << endl;
	for (vector <IRNode>::iterator it = IR.begin(); it != IR.end(); ++it)
	{
		it->print_Node();
	}
	
	cout << ";tiny code" << endl;

	// Print each int/float variable used in the assembly code
	for (vector <string>::iterator it = vars.begin(); it != vars.end(); ++it)
	{
		cout << "var " << *it << endl;
	}

	// Print each string variable used in the assembly code
	for (vector <string>::iterator it = str_const.begin(); it != str_const.end(); ++it)
	{
		cout << *it << endl;
	}
		
	int curr_reg = 0;
	int output_reg = 0;
	int addop_temp = 0;
	int mulop_temp = 0;
	string code, op1, op2, result, saved_reg;
	for (vector <IRNode>::iterator it = IR.begin(); it != IR.end(); ++it) // Loop through the IR nodes in order
	{
		code = it->opcode;
		op1 = it->op1;
		op2 = it->op2;
		result = it->result;

		if (it->cmp_type == "SAVE") // This saves the register holding the value of the left side of a compare
		{
			saved_reg = output_reg;
		}


		// This if else chain checks the opcode and generates the corresponding assembly code.
		if (code == "WRITEI")
		{
			cout << "sys writei " << result << endl;
		}
		else if (code == "WRITEF")
		{
			cout << "sys writer " << result << endl;
		}
		else if (code == "WRITES")
		{
			cout << "sys writes " << result << endl;
		}
		else if (code == "READI")
		{
			cout << "sys readi " << result << endl;
		}
		else if (code == "READF")
		{
			cout << "sys readr " << result << endl;
		}
		else if (code == "JUMP")
		{
			cout << "jmp " << result << endl;
		}
		else if (code == "GT")
		{
			if (it->cmp_type == "INT")
			{
				assemble_cmpi(op1, op2, saved_reg, output_reg, &curr_reg);
			}
			else
			{
				assemble_cmpr(op1, op2, saved_reg, output_reg, &curr_reg);
			}
			cout << "jgt " << result << endl;
			while (!regs.empty())
				regs.pop();
		}
		else if (code == "GE")
		{
			if (it->cmp_type == "INT")
			{
				assemble_cmpi(op1, op2, saved_reg, output_reg, &curr_reg);
			}
			else
			{
				assemble_cmpr(op1, op2, saved_reg, output_reg, &curr_reg);
			}
			cout << "jge " << result << endl;
			while (!regs.empty())
				regs.pop();
		}
		else if (code == "LT")
		{
			if (it->cmp_type == "INT")
			{
				assemble_cmpi(op1, op2, saved_reg, output_reg, &curr_reg);
			}
			else
			{
				assemble_cmpr(op1, op2, saved_reg, output_reg, &curr_reg);
			}
			cout << "jlt " << result << endl;			
			while (!regs.empty())
				regs.pop();
		}
		else if (code == "LE")
		{
			if (it->cmp_type == "INT")
			{
				assemble_cmpi(op1, op2, saved_reg, output_reg, &curr_reg);
			}
			else
			{
				assemble_cmpr(op1, op2, saved_reg, output_reg, &curr_reg);
			}
			cout << "jle " << result << endl;
			while (!regs.empty())
				regs.pop();
		}
		else if (code == "NE")
		{
			if (it->cmp_type == "INT")
			{
				assemble_cmpi(op1, op2, saved_reg, output_reg, &curr_reg);
			}
			else
			{
				assemble_cmpr(op1, op2, saved_reg, output_reg, &curr_reg);
			}
			cout << "jne " << result << endl;
			while (!regs.empty())
				regs.pop();
		}
		else if (code == "EQ")
		{
			if (it->cmp_type == "INT")
			{
				assemble_cmpi(op1, op2, saved_reg, output_reg, &curr_reg);
			}
			else
			{
				assemble_cmpr(op1, op2, saved_reg, output_reg, &curr_reg);
			}
			cout << "jeq " << result << endl;
			while (!regs.empty())
				regs.pop();
		}
		else if (code == "LABEL")
		{
			cout << "label " << result << endl;
		}
		else if (code == "STOREI" || code == "STOREF")
		{
			if (result[0] != '$') // storing into a variable
			{
				if (op1[0] != '$') // the op is a variable
				{
					cout << "move " << op1 << " r" << curr_reg << endl;
					cout << "move r" << curr_reg << " " << result << endl;
					curr_reg = curr_reg + 1;
				}
				else // the op is a register
				{
					cout << "move r" << output_reg << " " << result << endl;
					while (!regs.empty())
						regs.pop();
				}
			}
			else // storing into a register
			{
				cout << "move " << op1 << " r" << curr_reg << endl;
				output_reg = curr_reg;
				regs.push(curr_reg);
				curr_reg++;
			}
		}
		// Plus
		else if (code == "ADDI")
		{
			assemble_addop("addi", op1, op2, &curr_reg, &addop_temp, &mulop_temp, &output_reg);
		}
		else if (code == "ADDF")
		{
			assemble_addop("addr", op1, op2, &curr_reg, &addop_temp, &mulop_temp, &output_reg);
		}
		// Sub
		else if (code == "SUBI")
		{
			assemble_addop("subi", op1, op2, &curr_reg, &addop_temp, &mulop_temp, &output_reg);
		}
		else if (code == "SUBF")
		{
			assemble_addop("subr", op1, op2, &curr_reg, &addop_temp, &mulop_temp, &output_reg);
		}
		// Mult
		else if (code == "MULTI")
		{
			assemble_mulop("muli", op1, op2, &curr_reg, &mulop_temp, &output_reg);
		}
		else if (code == "MULTF")
		{
			assemble_mulop("mulr", op1, op2, &curr_reg, &mulop_temp, &output_reg);
		}
		// Div
		else if (code == "DIVI")
		{
			assemble_mulop("divi", op1, op2, &curr_reg, &mulop_temp, &output_reg);
		}
		else if (code == "DIVF")
		{
			assemble_mulop("divr", op1, op2, &curr_reg, &mulop_temp, &output_reg);
		}
	}
	cout << "sys halt";


	return 0;
}

void yyerror(const char *s)
{
	cout << s << endl;
	exit(line_num);
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

map <string, wrapper> find_symbol_table(string id) // Checks for the existence of id in any of the currently valid scopes
{
	map <string, wrapper> m;
	while (!scope.empty()) // Checks every available scope
	{
		m = symbol_table[scope.top()];
		if (m.count(id) > 0) // id has been found!
			break;
		else // id was not found, save the current scope and check the next one
		{
			scope_help.push(scope.top());
			scope.pop();
		}
	}
	if (scope.empty()) // id was never found and is used illegally
	{
		string error = "Variable " + id + " was not found in any scope";
		yyerror(error.c_str());
	}

	while (!scope_help.empty()) // Put all the saved scopes back in order
	{
		scope.push(scope_help.top());
		scope_help.pop();
	}

	return m;
}

string CondExprIR(ASTNode * n, string * t) // Generates the IR for a conditional expression and returns the register holding 
{
	if (n != NULL)
	{
		CondExprIR(n->left, t);
		CondExprIR(n->right, t);
		ss.str("");
		if (n->node_type == "OP")
		{
			n->data_type = n->left->data_type;
			ss << "$T" << ++reg_cnt;
			n->reg = ss.str();
		}
		if (n->node_type == "CONST")
		{
			ss << "$T" << ++reg_cnt;
			n->reg = ss.str();
		}
		IR.push_back(n->gen_IR());
		*t = n->data_type;
		return n->reg;
	}
	*t = "none";
	return "";
}

void makeIR(ASTNode * n) // Generates the IR of assign statements
{
	if (n != NULL)
	{
		makeIR(n->left);
		makeIR(n->right);
		ss.str("");
		if (n->node_type == "OP")
		{
			n->data_type = n->left->data_type;
			if (n->val != "=")
			{
				ss << "$T" << ++reg_cnt;
				n->reg = ss.str();
			}
			else
				n->reg = n->left->reg;
		}
		if (n->node_type == "CONST")
		{
			ss << "$T" << ++reg_cnt;
			n->reg = ss.str();
		}
		IR.push_back(n->gen_IR());
	}
}

void destroy_AST(ASTNode * n) // Destroys an AST tree
{
	if (n != NULL)
	{
		destroy_AST(n->left);
		destroy_AST(n->right);
		delete n;
	}
}

// Takes the IR for an addop and turns it into assembly code.
// This function has several pointers/temp variables and a stack to keep track of registers. These things are shared with assemble_mulop
void assemble_addop(string opcode, string op1, string op2, int * curr_reg, int * addop_temp, int * mulop_temp, int * output_reg)
{
	if (op1[0] != '$') // op1 is a variable
	{
		cout << "move " << op1 << " r" << *curr_reg << endl;
		*addop_temp = *curr_reg - 1;
		*curr_reg = *curr_reg + 1;

		if (op2[0] != '$') // op2 is a variable
		{
			cout << opcode << " " << op2 << " r" << *curr_reg - 1 << endl;
			regs.push(*curr_reg - 1);
		}
		else // op2 is a register
		{
			cout << opcode << " r" << *addop_temp << " r" << *curr_reg - 1 << endl;
			if (!regs.empty()) 
			{
				regs.pop();
			}
			regs.push(*curr_reg - 1);
		}
		*output_reg = *curr_reg - 1;
		*addop_temp = *curr_reg - 1;
	}
	else // op1 is a register
	{
		if (op2[0] != '$') // op2 is a variable
		{
			cout << opcode << " " << op2 << " r" << *curr_reg - 1 << endl;
			*output_reg = *curr_reg - 1;
		}
		else // op2 is a register
		{
			while (!regs.empty())
			{
				*addop_temp = regs.top();
				regs.pop();
			}
			cout << opcode << " r" << *curr_reg - 1 << " r" << *addop_temp << endl;
			*output_reg = *addop_temp;
			regs.push(*addop_temp);
		}
	}
	*mulop_temp = *addop_temp;
}

// Takes the IR for a mulop and turns it into assembly code.
// This function has several pointers/temp variables and a stack to keep track of registers. These things are shared with assemble_addop.
void assemble_mulop(string opcode, string op1, string op2, int * curr_reg, int * temp, int * output_reg)
{
	if (op1[0] != '$') // op1 is a variable
	{
		cout << "move " << op1 << " r" << *curr_reg << endl;
		*temp = *curr_reg - 1;
		*curr_reg = *curr_reg + 1;

		if (op2[0] != '$') // op2 is a variable
		{
			cout << opcode << " " << op2 << " r" << *curr_reg - 1 << endl;
			regs.push(*curr_reg - 1);
		}
		else // op2 is a register
		{
			cout << opcode << " r" << *temp << " r" << *curr_reg - 1 << endl;
			if (!regs.empty()) 
			{
				regs.pop();
			}
			regs.push(*curr_reg - 1);
		}
		*output_reg = *curr_reg - 1;
		*temp = *curr_reg - 1;
	}
	else // op1 is a register
	{
		if (op2[0] != '$') // op2 is a variable
		{
			cout << opcode << " " << op2 << " r" << *curr_reg - 1 << endl;
			*output_reg = *curr_reg - 1;
		}
		else // op2 is a register
		{
			while (!regs.empty())
			{
				*temp = regs.top();
				regs.pop();
			}
			cout << opcode << " r" << *curr_reg - 1 << " r" << *temp << endl;
			*output_reg = *temp;
			regs.push(*temp);
		}
	}
}

// Takes the IR for an integer compare and generates assembly code.
void assemble_cmpi(string op1, string op2, string saved_reg, int output_reg, int * curr_reg)
{
	if (op1[0] != '$' && op2[0] != '$') // op1 and op2 are variables
	{
		cout << "move " << op2 << " r" << *curr_reg << endl;
		output_reg = *curr_reg;
		*curr_reg = *curr_reg + 1;
		cout << "cmpi " << op1 << " r" << output_reg << endl;
	}
	else if (op1[0] != '$') // only op1 is a variable
	{
		cout << "cmpi " << op1 << " r" << output_reg << endl;
	}
	else if (op2[0] != '$') // only op2 is variable
	{
		cout << "cmpi r" << output_reg << " " << op2 << endl;
	}
	else // both ops are constant
	{
		cout << "cmpi r" << saved_reg << " r" << output_reg;
	}
}

// Takes the IR for a float compare and generates assembly code.
void assemble_cmpr(string op1, string op2, string saved_reg, int output_reg, int * curr_reg)
{
	if (op1[0] != '$' && op2[0] != '$') // op1 and op2 are variables
	{
		cout << "move " << op2 << " r" << *curr_reg << endl;
		output_reg = *curr_reg;
		*curr_reg = *curr_reg + 1;
		cout << "cmpr " << op1 << " r" << output_reg << endl;
	}
	else if (op1[0] != '$') // only op1 is a variable
	{
		cout << "cmpr " << op1 << " r" << output_reg << endl;
	}
	else if (op2[0] != '$') // only op2 is variable
	{
		cout << "cmpr r" << output_reg << " " << op2 << endl;
	}
	else // both ops are constant
	{
		cout << "cmpr r" << saved_reg << " r" << output_reg;
	}
}
