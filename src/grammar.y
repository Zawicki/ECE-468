%{
#include <cstdio>
#include <iostream>
#include <map>
#include <stack>
#include <sstream>
#include <vector>
#include <iterator>
#include <string>
#include <stdlib.h>
#include <ctype.h>

using namespace std;

extern "C" int yylex(void);
extern "C" int yyparse();
extern "C" FILE *yyin;
extern int line_num;

struct wrapper 
{ 
	string vals[2];
}w, p;

struct info
{
	int L_cnt;
	int P_cnt;
	int T_cnt;
}f;

void yyerror(const char *s);

void push_block();
void add_symbol_table();
map <string, wrapper> find_symbol_table(string id);

void func_IR_setup(string);

/*
void IR_to_tiny(string fid);
string tiny_opr(string func_name, string opr, int curr_reg);
void assemble_addop(string opcode, string op1, string op2, int * curr_reg, string * addop_temp, string * mulop_temp, string * output_reg, string func_name);
void assemble_mulop(string opcode, string op1, string op2, int * curr_reg, string * temp, string * output_reg, string func_name);
void assemble_cmpi(string op1, string op2, string saved_reg, string output_reg, int * curr_reg, string func_name);
void assemble_cmpr(string op1, string op2, string saved_reg, string output_reg, int * curr_reg, string func_name);
*/

stack <string> scope; // A stack holding the current valid scopes during parsing
stack <string> scope_help; // A stack to hold scopes when using a variable that was not declared in the current scope

pair<map <string, wrapper>::iterator, bool> r;
map <string, wrapper> table; // A scope within the symbol table

map <string, map<string, wrapper> > symbol_table; // The symbol table

int block_cnt = 0; // A counter for naming block scopes during parsing
int lbl_cnt = 0; // A counter for naming IR labels during parsing

stringstream ss; // A string stream used to make printing int/floats easier

vector <string> id_vec, vars, str_const; // Each vector holds all variable names. This is used to declare the variable names at the start of the tiny code

int reg_cnt = 0; // A counter for numbering the temp registers of functions
int local_cnt = 0; // A counter for numbering the local varaibles of functions
int param_cnt = 0; // A counter for numbering the parameters of functions
map <string, string> var_map; // A map of variable names to local/parameter variable identifiers
map <string, info> func_info; // A map from a function name to a struct holding information about the function

stack <string> regs; // Keeps track of registers in an expression
stack <string> labels; // Holds the labels for control flow statements
%}

%code requires
{
	#include "./src/Nodes.h"
	void makeIR(ASTNode * n);
	string ExprIR(ASTNode * n, string * t);
	void destroy_AST(ASTNode * n);
}

%code 
{
string tinyOp(string op);
void IR_to_4RegTiny(string func_name);
Register * ensure(string op);
Register * store_ensure(string op);
void free_reg(Register * r);
Register * allocate(string op);
Register * spill();
void end_of_bb();
void save_globals();
void assemble_mathop1(string opcode, string op1, string op2, string result, IRNode n);
void assemble_mathop2(string opcode, string op1, string op2, string result, IRNode n);
void assemble_4reg_cmp(string opcode, string op1, string op2, IRNode n);

vector <IRNode> IR; // Holds the nodes for the IR code
vector <tinyNode> assembly; // Holds the nodes for the tiny code
map <string, vector <IRNode> > func_IR; // maps a function name to a vector of its IR nodes
stack <IRNode *> lbl_nodes;
Register r0 = Register("r0");
Register r1 = Register("r1");
Register r2 = Register("r2");
Register r3 = Register("r3");
IRNode * curr_node;
vector <IRNode> curr_IR;
vector <IRNode>::iterator IR_it;
}

%union
{
	int ival;
	float fval;
	char *sval;
	ASTNode * AST_ptr;
	IRNode * IR_ptr;
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
%type <IR_ptr> cond

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
					// Add the declarations to the symbol table
					w.vals[0] = $1;
					w.vals[1] = "";
					r = table.insert(pair<string, wrapper>(*it, w));
					if (!r.second)
					{
						string tmp = *it;
						yyerror(tmp.c_str());
					}

					// If the scope is in a function, map the variables to a local register
					if (scope.top() != "GLOBAL")
					{
						ss.str("");
						ss << "$L" << ++local_cnt;
						var_map[*it] = ss.str();
						ss.str("");
					}
					else // If the variable is global, flag it to be listed at the start of the tiny code
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
	',' id id_tail {id_vec.push_back($2)} |
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
			string id = $2;
			ss.str("");
			ss << "$P" << ++param_cnt;
			var_map[id] = ss.str();
			ss.str("")}
	;
param_decl_tail:
	',' param_decl param_decl_tail | 
	;

func_declarations:
	func_decl func_declarations | 
	;
func_decl:
	FUNCTION any_type id	{scope.push($3); func_IR_setup($3)}
	'(' param_decl_list ')' _BEGIN func_body
	END {IRNode n = IR.back(); if (n.opcode != "RET") IR.push_back(IRNode("RET", "", "", "")); 
		string func_id = $3; func_IR[func_id] = IR; IR.clear(); 
		f.L_cnt = local_cnt; f.P_cnt = param_cnt; f.T_cnt = reg_cnt; func_info[func_id] = f; scope.pop()}
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
					string temp;
					map <string, wrapper> m = find_symbol_table(*it);

					if (var_map.count(*it) > 0) // Reading into a local variable
						temp = var_map[*it];
					else // Reading into a global variable
						temp = *it;

					if (m[*it].vals[0] == "INT")
						IR.push_back(IRNode("READI", "", "", temp));
					else
						IR.push_back(IRNode("READF", "", "", temp));

				}
				id_vec.clear()}

	;
write_stmt:
	WRITE '(' id_list ')' ';' {for (vector <string>::reverse_iterator it = id_vec.rbegin(); it != id_vec.rend(); ++it)
				{
					string temp;
					map <string, wrapper> m = find_symbol_table(*it);

					if (var_map.count(*it) > 0) // Writing a local variable
						temp = var_map[*it];
					else // Writing a global variable
						temp = *it;
					
					if (m[*it].vals[0] == "INT")
						IR.push_back(IRNode("WRITEI", "", "", temp));
					else if (m[*it].vals[0] == "FLOAT")
						IR.push_back(IRNode("WRITEF", "", "", temp));
					else
						IR.push_back(IRNode("WRITES", "", "", temp));
				}
				id_vec.clear()}
	;
return_stmt:
	RETURN expr ';' {string t; string r = ExprIR($2, &t);
			if (t == "INT")
				IR.push_back(IRNode("STOREI", r, "", "$R"));
			else
				IR.push_back(IRNode("STOREF", r, "", "$R"));
			IR.push_back(IRNode("RET", "", "", ""));
			destroy_AST($2)}
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
	id '(' expr_list ')' {IR.push_back(IRNode("PUSH", "", "", "")); // Push space for the return value
			      	for (vector <string>::iterator it = id_vec.begin(); it != id_vec.end(); ++it) // Push all arguments onto the stack
				{
					IR.push_back(IRNode("PUSH", "", "", *it));
				}
				IR.push_back(IRNode("JSR", "", "", $1)); // Jump to the function
				for (vector <string>::iterator it = id_vec.begin(); it != id_vec.end(); ++it) // Pop all arguments from the stack
				{
					IR.push_back(IRNode("POP", "", "", ""));
				}
				id_vec.clear();
				ss.str("");
				ss << "$T" << ++reg_cnt;
				IR.push_back(IRNode("POP", "", "", ss.str())); // Pop the return value into a new register
				$$ = new FuncNode(ss.str());
				ss.str("");}
	;
expr_list:
	expr expr_list_tail {string t; string r = ExprIR($1, &t); destroy_AST($1); id_vec.push_back(r); $$ = $1}
	| {$$ = NULL} 
	;
expr_list_tail:
	',' expr expr_list_tail {string t; string r = ExprIR($2, &t); destroy_AST($2); id_vec.push_back(r); $$ = $2}
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
	'(' cond ')'	{
			IRNode * n = new IRNode("LABEL", "", "", labels.top()); labels.pop(); 
			/*$4->next.insert(n); n->prev.insert($4);*/ IR.push_back(*$4); lbl_nodes.push(n)
			/*IRNode n = IRNode("LABEL", "", "", labels.top()); labels.pop(); 
			IR.push_back(*$4); lbl_nodes.push_back(n);
			vector <IRNode>::iterator cond = IR.end() - 1; vector <IRNode>::iterator lbl = lbl_nodes.end() - 1;
			(&(*cond))->next.insert((&(*lbl))); (&(*lbl))->prev.insert((&(*cond)))*/
			} 
	decl stmt_list	{
			ss.str(""); ss << "label" << lbl_cnt++; 
			IRNode * j = new IRNode("JUMP", "", "", ss.str()); IRNode * l = new IRNode("LABEL", "", "", ss.str());
			/*j->next.insert(l); l->prev.insert(j);*/ IR.push_back(*j); 
			IR.push_back(*lbl_nodes.top()); lbl_nodes.pop(); lbl_nodes.push(l)
			/*ss.str(""); ss << "label" << lbl_cnt++; 
			IRNode * j = new IRNode("JUMP", "", "", ss.str()); IRNode * l = new IRNode("LABEL", "", "", ss.str());
			vector <IRNode>::iterator lbl = lbl_nodes.end() - 1;
			IR.push_back(*lbl); lbl_nodes.pop_back(); lbl_nodes.push_back(*l); IR.push_back(*j); 
			vector <IRNode>::iterator jmp = IR.end() - 1; lbl = lbl_nodes.end() - 1;
			(&(*jmp))->next.insert((&(*lbl))); (&(*lbl))->prev.insert((&(*jmp)))*/
			}
	else_part 	{IR.push_back(*lbl_nodes.top()); lbl_nodes.pop()
			/*vector <IRNode>::iterator lbl = lbl_nodes.end() - 1; IR.push_back(*lbl); lbl_nodes.pop_back()*/}
	FI {scope.pop()}
	;
else_part:
	ELSE {push_block()} 
	decl  
	stmt_list {scope.pop()} |
	;
cond:
	expr compop expr	{string t; string op1 = ExprIR($1, &t); IR.push_back(IRNode("", "", "", "", "SAVE"));
				string op2 = ExprIR($3, &t); ss.str(""); ss << "label" << lbl_cnt++;
				IRNode * n = new IRNode($2, op1, op2, ss.str(), t); $$ = n;
				labels.push(ss.str()); destroy_AST($1); destroy_AST($3)}
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
	init_stmt ';'	{
			makeIR($4); destroy_AST($4); 
			ss.str(""); ss << "label" << lbl_cnt++; IRNode * n = new IRNode("LABEL", "", "", ss.str());
			IRNode * j = new IRNode("JUMP", "", "", ss.str()); /*j->next.insert(n); n->prev.insert(j);*/
			lbl_nodes.push(j); IR.push_back(*n)
			/*makeIR($4); destroy_AST($4);
			ss.str(""); ss << "label" << lbl_cnt++; IRNode * n = new IRNode("LABEL", "", "", ss.str());
			IRNode * j = new IRNode("JUMP", "", "", ss.str());
			lbl_nodes.push_back(*j); IR.push_back(*n);
			vector <IRNode>::iterator lbl = IR.end() - 1; vector <IRNode>::iterator jmp = lbl_nodes.end() - 1;
			(&(*jmp))->next.insert((&(*lbl))); (&(*lbl))->prev.insert((&(*jmp)))*/
			}
	cond ';'	{
			IRNode * n = new IRNode("LABEL", "", "", labels.top()); labels.pop();
			/*$7->next.insert(n); n->prev.insert($7);*/ IR.push_back(*$7); lbl_nodes.push(n)
			/*IRNode * n = new IRNode("LABEL", "", "", labels.top()); labels.pop();
			IR.push_back(*$7); lbl_nodes.push_back(*n);
			vector <IRNode>::iterator cond = IR.end() - 1; vector <IRNode>::iterator lbl = lbl_nodes.end() - 1;
			(&(*cond))->next.insert((&(*lbl))); (&(*lbl))->prev.insert((&(*cond)))*/
			}
	incr_stmt 
	')' 
	decl stmt_list	{
			makeIR($10); destroy_AST($10); IRNode * l = lbl_nodes.top(); lbl_nodes.pop();
			IRNode * j = lbl_nodes.top(); IR.push_back(*j); lbl_nodes.pop(); IR.push_back(*l)
			/*makeIR($10); destroy_AST($10); 
			vector <IRNode>::iterator lbl = lbl_nodes.end() - 1; lbl_nodes.pop_back();
			vector <IRNode>::iterator jmp = lbl_nodes.end() - 1; lbl_nodes.pop_back();
			IR.push_back(*jmp); IR.push_back(*lbl)*/
			}
	ROF	{scope.pop()}
	;

%%

int main(int argc, char * argv[])
{
	if (argc != 2)
	{
		cout << endl << "Usage: ./Micro <file to compile>" << endl;
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

	vector <IRNode *> worklist;
	for (map <string, vector <IRNode> >::iterator it = func_IR.begin(); it != func_IR.end(); ++it)
	{
		vector <IRNode> &func = it->second;
		// This loop creates the GEN and KILL sets, fills out the CFG, and puts nodes in the worklist, also sets the live-out set for return statements
		for (vector <IRNode>::iterator it2 = func.begin(); it2 != func.end(); ++it2)
		{
			string opcode, op1, op2, result;
			opcode = it2->opcode;
			op1 = it2->op1;
			op2 = it2->op2;
			result = it2->result;

			if (opcode != "")
			{
				if (opcode == "PUSH" || opcode == "WRITEI" || opcode == "WRITEF")
				{
					it2->gen.insert(result);
				}
				else if (opcode == "POP" || opcode == "READI" || opcode == "READF")
				{
					it2->kill.insert(result);
				}
				else if (opcode == "JSR")
				{
					for (vector <string>::iterator it3 = vars.begin(); it3 != vars.end(); ++it3)
					{
						it2->gen.insert(*it3);
					}
				}
				else if (opcode != "LABEL" && opcode != "JUMP" && opcode != "LINK" && opcode != "RET")
				{
					if (!isdigit(op1[0]) && op1 != "")
						it2->gen.insert(op1);
					if (!isdigit(op2[0]) && op2 != "")
						it2->gen.insert(op2);
					if (opcode != "GT" && opcode != "GE" && opcode != "LT" && opcode != "LE" && opcode != "EQ" && opcode != "NE")
						it2->kill.insert(result);
				}
				
				int num = 1;
				IRNode * prev;
				IRNode * next;
				// find prev IR
				if (it2 != func.begin())
				{
					while ((*(it2 - num)).opcode == "")
					{
						num++;
					}
					prev = (&(*(it2 - num)));
				}
						
				num = 1;
				// find next IR
				if (it2 != (func.end() - 1))
				{
					while ((*(it2 + num)).opcode == "")
					{
						num++;
					}
					next = (&(*(it2 + num)));
				}
			
				if (opcode == "RET")
				{
					for (vector <string>::iterator it3 = vars.begin(); it3 != vars.end(); ++it3)
					{
						it2->out.insert(*it3); // initialize the live-out set to the global variables
					}
					it2->prev.insert(prev); // insert the previous element as a predecessor
				}
				else if (opcode == "GT" || opcode == "GE" || opcode == "LT" || opcode == "LE" || opcode == "EQ" || opcode == "NE")
				{
					if (it2 != func.begin() && prev->opcode != "JUMP")
					{
						it2->prev.insert(prev); // insert the previous element as a predecessor
					}
					it2->next.insert(next); // insert the next element as a successor
					for (vector <IRNode>::iterator it3 = func.begin(); it3 != func.end(); ++it3)
					{
						if (it3->opcode == "LABEL" && it3->result == it2->result)
						{
							it2->next.insert(&(*it3)); // add the label as a successor
							it3->prev.insert(&(*it2)); // add the compare as a predecessor
						}
					}
				}
				else if (opcode != "JUMP")
				{
					if (it2 != func.begin() && prev->opcode != "JUMP")
					{
						it2->prev.insert(prev); // insert the previous element as a predecessor
					}
					it2->next.insert(next); // insert the next element as a successor
				}
				else
				{
					it2->prev.insert(prev); // insert the previous element as a predecessor
					for (vector <IRNode>::iterator it4 = func.begin(); it4 != func.end(); ++it4)
					{
						if (it4->opcode == "LABEL" && it4->result == it2->result)
						{
							it2->next.insert(&(*it4)); // add the label as a successor
							it4->prev.insert(&(*it2)); // add the compare as a predecessor
						}
					}

				}
				
				worklist.push_back(&(*it2));
			}
		}

		// Liveness computation
		// 1. Get a node
		// 2. Compute live-in and live-out sets 
		// live-in = live-out vars - KILL vars + GEN vars
		// live-out = union of vars that are live-in to successor
		// 3. if the live-in set is updated in step 2, put all predecessors on the worklist
		// 4. Repeat steps 2 and 3 until worklist is empty
		while(!worklist.empty())
		{
			IRNode * n = *(worklist.begin()); // select the last node on the worklist
			worklist.erase(worklist.begin()); // remove the node from the worklist
			IRNode * successor;
			
			set <IRNode *>::iterator i;
			set <string>::iterator j;
			set <string>::iterator st;

			set <string> live_in_copy(n->in);

			// get the live-out set, setup the live-in set
			for (i = n->next.begin(); i != n->next.end(); ++i) // loop through each successor
			{
				successor = *i;
				for (j = successor->in.begin(); j != successor->in.end(); ++j) // loop through the live-in set of the successor
				{
					n->out.insert(*j); // add the element to the live-out set
					n->in.insert(*j);
				}
			}

			for (j = n->kill.begin(); j != n->kill.end(); ++j)
			{
				st = n->in.find(*j); // get an iterator to the element
				if (st != n->in.end())
					n->in.erase(st); // remove each KILL var
			}
			for (j = n->gen.begin(); j != n->gen.end(); ++j)
			{
				n->in.insert(*j); // add each GEN var to the live-in set
			}
			
			if (live_in_copy != n->in) // if the live-in set changed, put all predecessors on the worklist
			{
				for (i = n->prev.begin(); i != n->prev.end(); ++i) // loop through each predecessor
				{
					worklist.push_back(*i); // add the predeccessor to the worklist
					
				}
			}
		}
	}

	//Print the IR nodes
	cout << ";IR code" << endl << endl;
	for (map <string, vector <IRNode> >::iterator it = func_IR.begin(); it != func_IR.end(); ++it)
	{
		vector <IRNode> &func = it->second;
		for (vector <IRNode>::iterator it2 = func.begin(); it2 != func.end(); ++it2)
		{
			it2->print_Node();
		}
		cout << endl;
	}


	// Start of tiny code
	cout << ";tiny code" << endl;

	// Print each global int/float variable used in the assembly code
	for (vector <string>::iterator it = vars.begin(); it != vars.end(); ++it)
	{
		cout << "var " << *it << endl;
	}

	// Print each global string variable used in the assembly code
	for (vector <string>::iterator it = str_const.begin(); it != str_const.end(); ++it)
	{
		cout << *it << endl;
	}
		
	// tiny code to enter the main function
	assembly.push_back(tinyNode("push", "", ""));
	assembly.push_back(tinyNode("push", "", "r0"));
	assembly.push_back(tinyNode("push", "", "r1"));
	assembly.push_back(tinyNode("push", "", "r2"));
	assembly.push_back(tinyNode("push", "", "r3"));
	assembly.push_back(tinyNode("jsr", "", "main"));
	assembly.push_back(tinyNode("sys halt", "", ""));

	// Generate the tiny code
	//IR_to_tiny("main");
	IR_to_4RegTiny("main");
	for (map <string, vector <IRNode> >::iterator it = func_IR.begin(); it != func_IR.end(); ++it)
	{
		if (it->first != "main")
		{
			//IR_to_tiny(it->first);
			IR_to_4RegTiny(it->first);
		}
	}

	// Print the tiny code
	for (vector <tinyNode>::iterator it = assembly.begin(); it != assembly.end(); ++it) // Loop through the tiny nodes in order
	{
		it->print_Node();
	}

	return 0;
}

void yyerror(const char *s)
{
	cout << s << " " << line_num << endl;
	exit(EXIT_FAILURE);
}

void push_block() // Pushes a block onto tthe scope stack
{
	ss.str("");
	ss << "BLOCK " << ++block_cnt;
	scope.push(ss.str());
}

void add_symbol_table() // Adds the table for a single scope to the symbol table
{
	symbol_table[scope.top()] = table;
	table.clear();
}

void func_IR_setup(string func_id) // Reset the register/offset counters and add IR code for the start of a function
{
	reg_cnt = 0;
	local_cnt = 0;
	param_cnt = 0;

	IR.push_back(IRNode("LABEL","","", func_id));
	IR.push_back(IRNode("LINK","","",""));
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

string ExprIR(ASTNode * n, string * t) // Generates the IR for an expression and returns the register holding the final value. t is the data type.
{
	if (n != NULL)
	{
		ExprIR(n->left, t);
		ExprIR(n->right, t);
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
		if (n->node_type == "VAR")
		{
			if (var_map.count(n->val) > 0) // If the variable is part of the current stack frame, change the register to the correct value
			{
				n->reg = var_map[n->val];
			}
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
		if (n->node_type == "VAR")
		{
			if (var_map.count(n->val) > 0)
			{
				n->reg = var_map[n->val];
			}
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

void IR_to_4RegTiny(string func_name) // Takes a function name and translates the IR for that function to tiny nodes
{
	vector <IRNode> n = func_IR[func_name];
	curr_IR = func_IR[func_name];
	f = func_info[func_name];

	string code, op1, op2, result;

	Register * reg1;
	Register * reg2;

	set <string>::iterator st;

	r0.Pcnt = func_info[func_name].P_cnt;
	r1.Pcnt = func_info[func_name].P_cnt;
	r2.Pcnt = func_info[func_name].P_cnt;
	r3.Pcnt = func_info[func_name].P_cnt;

	r0.Lcnt = func_info[func_name].L_cnt;
	r1.Lcnt = func_info[func_name].L_cnt;
	r2.Lcnt = func_info[func_name].L_cnt;
	r3.Lcnt = func_info[func_name].L_cnt;


	for (vector <IRNode>::iterator it = n.begin(); it != n.end(); ++it) // Loop through the IR nodes in order
	{
		code = it->opcode;
		op1 = it->op1;
		op2 = it->op2;
		result = it->result;
		curr_node = &(*it);
		IR_it = it;

		assembly.push_back(tinyNode(it->str(), "", ""));

		// This if else chain checks the opcode and generates the corresponding tiny node.
		if (code == "WRITEI")
		{
			//reg1 = ensure(result);	
			//assembly.push_back(tinyNode("sys writei", reg1->name, ""));
			assembly.push_back(tinyNode("move", tinyOp(result), "r0"));	
			assembly.push_back(tinyNode("sys writei", "r0", ""));
		}
		else if (code == "WRITEF")
		{
			//reg1 = ensure(result);
			//assembly.push_back(tinyNode("sys writer", reg1->name, ""));
			assembly.push_back(tinyNode("move", tinyOp(result), "r0"));	
			assembly.push_back(tinyNode("sys writer", "r0", ""));
		}
		else if (code == "WRITES")
		{
			assembly.push_back(tinyNode("sys writes", result, ""));
		}
		else if (code == "READI")
		{
			//reg1 = ensure(result);
			//assembly.push_back(tinyNode("sys readi", reg1->name, ""));	
			assembly.push_back(tinyNode("sys readi", "r0", ""));
			assembly.push_back(tinyNode("move", "r0", tinyOp(result)));
		}
		else if (code == "READF")
		{
			//reg1 = ensure(result);
			//assembly.push_back(tinyNode("sys readr", reg1->name, ""));
			assembly.push_back(tinyNode("sys readr", "r0", ""));
			assembly.push_back(tinyNode("move", "r0", tinyOp(result)));
		}
		else if (code == "JUMP")
		{
			//end_of_bb();
			assembly.push_back(tinyNode("jmp", result, ""));
		}
		else if (code == "GT")
		{
			if (it->cmp_type == "INT")
			{
				assemble_4reg_cmp("cmpi", op1, op2, *it);
			}
			else
			{
				assemble_4reg_cmp("cmpr", op1, op2, *it);
			}
			//end_of_bb();
			assembly.push_back(tinyNode("jgt", result, ""));
		}
		else if (code == "GE")
		{
			if (it->cmp_type == "INT")
			{
				assemble_4reg_cmp("cmpi", op1, op2, *it);
			}
			else
			{
				assemble_4reg_cmp("cmpr", op1, op2, *it);
			}
			//end_of_bb();
			assembly.push_back(tinyNode("jge", result, ""));
		}
		else if (code == "LT")
		{
			if (it->cmp_type == "INT")
			{
				assemble_4reg_cmp("cmpi", op1, op2, *it);
			}
			else
			{
				assemble_4reg_cmp("cmpr", op1, op2, *it);
			}
			//end_of_bb();
			assembly.push_back(tinyNode("jlt", result, ""));			
		}
		else if (code == "LE")
		{
			if (it->cmp_type == "INT")
			{
				assemble_4reg_cmp("cmpi", op1, op2, *it);
			}
			else
			{
				assemble_4reg_cmp("cmpr", op1, op2, *it);
			}
			//end_of_bb();
			assembly.push_back(tinyNode("jle", result, ""));
		}
		else if (code == "NE")
		{
			if (it->cmp_type == "INT")
			{
				assemble_4reg_cmp("cmpi", op1, op2, *it);
			}
			else
			{
				assemble_4reg_cmp("cmpr", op1, op2, *it);
			}
			//end_of_bb();
			assembly.push_back(tinyNode("jne", result, ""));
		}
		else if (code == "EQ")
		{
			if (it->cmp_type == "INT")
			{
				assemble_4reg_cmp("cmpi", op1, op2, *it);
			}
			else
			{
				assemble_4reg_cmp("cmpr", op1, op2, *it);
			}
			//end_of_bb();
			assembly.push_back(tinyNode("jeq", result, ""));
		}
		else if (code == "LABEL")
		{
			assembly.push_back(tinyNode("label", result, ""));
		}
		else if (code == "JSR")
		{
			assembly.push_back(tinyNode("push" , "r0", ""));
			assembly.push_back(tinyNode("push" , "r1", ""));
			assembly.push_back(tinyNode("push" , "r2", ""));
			assembly.push_back(tinyNode("push" , "r3", ""));
			//save_globals();
			assembly.push_back(tinyNode("jsr", result, ""));
			assembly.push_back(tinyNode("pop" , "r3", ""));
			assembly.push_back(tinyNode("pop" , "r2", ""));
			assembly.push_back(tinyNode("pop" , "r1", ""));
			assembly.push_back(tinyNode("pop" , "r0", ""));
		}
		else if (code == "PUSH")
		{
			if (result != "") 
			{
				//reg1 = ensure(result);
				//assembly.push_back(tinyNode("push", reg1->name, ""));
				assembly.push_back(tinyNode("move", tinyOp(result), "r0"));
				assembly.push_back(tinyNode("push" , "r0", ""));
			}
			else
				assembly.push_back(tinyNode("push", "", ""));

		}
		else if (code == "POP")
		{	
			if (result != "") 
			{
				//reg1 = ensure(result);	
				//assembly.push_back(tinyNode("pop", reg1->name, ""));
				assembly.push_back(tinyNode("pop" , "r0", ""));
				assembly.push_back(tinyNode("move", "r0", tinyOp(result)));
			}
			else
				assembly.push_back(tinyNode("pop", "", ""));
		}
		else if (code == "LINK")
		{
			ss.str("");
			ss << f.L_cnt + f.T_cnt;
			assembly.push_back(tinyNode("link", ss.str(), ""));
			ss.str("");
		}
		else if (code == "RET")
		{
			//end_of_bb();
			assembly.push_back(tinyNode("unlnk", "", ""));
			assembly.push_back(tinyNode("ret", "", ""));
		}
		else if (code == "STOREI" || code == "STOREF")
		{
			/*
			reg1 = ensure(op1);
			reg2 = store_ensure(result);
			assembly.push_back(tinyNode("move", reg1->name, reg2->name));
			reg2->dirty = true;

			st = it->out.find(op1);
			if (st == it->out.end())
				free_reg(reg1); // free op1
			st = it->out.find(result);
			if (st == it->out.end())
				free_reg(reg2); // free op1*/
	
			assembly.push_back(tinyNode("move", tinyOp(op1), "r0"));
			assembly.push_back(tinyNode("move", "r0", tinyOp(result)));
			if (!isdigit(op1[0]))
				assembly.push_back(tinyNode("move", "r0", tinyOp(op1)));
		}
		// Plus
		else if (code == "ADDI")
		{
			assemble_mathop1("addi", op1, op2, result, *it);
		}
		else if (code == "ADDF")
		{
			assemble_mathop1("addr", op1, op2, result, *it);
		}
		// Subtarc
		else if (code == "SUBI")
		{
			assemble_mathop2("subi", op1, op2, result, *it);
		}
		else if (code == "SUBF")
		{
			assemble_mathop2("subr", op1, op2, result, *it);
		}
		// Multiply
		else if (code == "MULTI")
		{
			assemble_mathop1("muli", op1, op2, result, *it);
		}
		else if (code == "MULTF")
		{
			assemble_mathop1("mulr", op1, op2, result, *it);
		}
		// Divide
		else if (code == "DIVI")
		{
			assemble_mathop2("divi", op1, op2, result, *it);
		}
		else if (code == "DIVF")
		{
			assemble_mathop2("divr", op1, op2, result, *it);
		}
	}
}

string tinyOp(string op)
{
	ss.str("");
	stringstream ss;
	int Lcnt = r0.Lcnt;
	int Pcnt = r0.Pcnt;
	if (op[0] == '$')
	{
		if (op[1] == 'T')
		{
			string t = op.substr(2, string::npos);
			ss << "$-" << atoi(t.c_str()) + Lcnt;
			return ss.str();
		}
		else if (op[1] == 'L')
		{
			return "$-" + op.substr(2, string::npos);
		}
		else if (op[1] == 'P')
		{
			string t = op.substr(2, string::npos);
			ss << "$" << atoi(t.c_str()) + 5; 
			return ss.str();
		}
		else
		{
			ss << "$" << Pcnt + 6;
			return ss.str();
		}
			
	}
	else
		return op;
}

Register * store_ensure(string op)
{
	Register * r;
	if (r0.data == op)
		r = &r0;
	else if (r1.data == op)
		r = &r1;
	else if (r2.data == op)
		r = &r2;
	else if (r3.data == op)
		r = &r3;
	else
		r = allocate(op);

	assembly.push_back(tinyNode(";store_ensure()", op, " r0->" + r0.data + " r1->" + r1.data + " r2->" + r2.data + " r3->" + r3.data));
	return r;
}

Register * ensure(string op)
{
	Register * r;
	bool last = false;
	if (r0.data == op)
		r = &r0;
	else if (r1.data == op)
		r = &r1;
	else if (r2.data == op)
		r = &r2;
	else if (r3.data == op)
		r = &r3;
	else
	{
		r = allocate(op);
		last = true;
	}

	assembly.push_back(tinyNode(";ensure()", op, " r0->" + r0.data + " r1->" + r1.data + " r2->" + r2.data + " r3->" + r3.data));
	if (last)
		assembly.push_back(tinyNode("move", tinyOp(op), r->name));
	return r;
}

void free_reg(Register * r)
{
	/*bool live = true;
	set <string>::iterator st;
	st = curr_node->out.find(r->data);
	if (st == curr_node->out.end()) // the variable is not live
	{
		live = false;
	}*/

	if (r->dirty)
	{
		assembly.push_back(tinyNode(";spilling dirty", r->name, r->data));
		assembly.push_back(tinyNode("move", r->name, r->str()));
		r->dirty = false;
		r->data = "";
	}
	else
	{
		assembly.push_back(tinyNode(";freeing ", r->name, r->data));
		r->data = "";
	}


	/*assembly.push_back(tinyNode(";freeing unused var", r->name, r->data));
	r->dirty = false;
	r->data = "";*/
}

Register * allocate(string op)
{
	if (r3.data == "")
	{
		r3.data = op;
		return &r3;
	}
	else if (r2.data == "")
	{
		r2.data = op;
		return &r2;
	}
	else if (r1.data == "")
	{
		r1.data = op;
		return &r1;
	}
	else if (r0.data == "")
	{
		r0.data = op;
		return &r0;
	}

	Register * r = spill();
	free_reg(r);
	r->data = op;
	return r;
}

Register * spill()
{
	int dist0 = 0;
	int dist1 = 0;
	int dist2 = 0;
	int dist3 = 0;

	Register * r;
	vector <IRNode>::iterator it;
	if (!isdigit(r0.data[0]) && r0.data != curr_node->op1 && r0.data != curr_node->op2)
	{
		for (it = IR_it; it != curr_IR.end() && (*it).out.find(r0.data) != (*it).out.end(); ++it)
		{
			dist0++;
		}
	}
	r = &r0;

	if (!isdigit(r1.data[0]) && r1.data != curr_node->op1 && r1.data != curr_node->op2)
	{
		for (it = IR_it; it != curr_IR.end() && (*it).out.find(r1.data) != (*it).out.end(); ++it)
		{
			dist1++;
		}
	}
	if (dist1 > dist0)
		r = &r1;

	if (!isdigit(r2.data[0]) && r2.data != curr_node->op1 && r2.data != curr_node->op2)
	{
		for (it = IR_it; it != curr_IR.end() && (*it).out.find(r2.data) != (*it).out.end(); ++it)
		{
			dist2++;
		}
	}
	if (dist2 > dist0 && dist2 > dist1)
		r = &r1;

	if (!isdigit(r3.data[0]) && r3.data != curr_node->op1 && r3.data != curr_node->op2)
	{
		for (it = IR_it; it != curr_IR.end() && (*it).out.find(r3.data) != (*it).out.end(); ++it)
		{
			dist3++;
		}
	}
	if (dist3 > dist0 && dist3 > dist1 && dist3 > dist2)
		r = &r1;

	return r;
}

void assemble_mathop1(string opcode, string op1, string op2, string result, IRNode n)
{
	/*
	Register * reg1;
	Register * reg2;
	reg1 = ensure(op1);
	reg2 = ensure(op2);

	set <string>::iterator st;

	st = n.out.find(op1);
	if (st == n.out.end())
		free_reg(reg1); // free if op1 is not live

	st = n.out.find(op2);
	if (st == n.out.end())
		free_reg(reg2); // free if op2 is not live

	if (reg2->data != "" && reg2->dirty)
		free(reg2);

	assembly.push_back(tinyNode(opcode, reg1->name, reg2->name));

	reg2->data = result;
	assembly.push_back(tinyNode(";changing data of", reg2->name, " r0->" + r0.data + " r1->" + r1.data + " r2->" + r2.data + " r3->" + r3.data));
	reg2->dirty = true;
	*/
	assembly.push_back(tinyNode("move", tinyOp(op1), "r0"));
	assembly.push_back(tinyNode("move", tinyOp(op2), "r1"));
	assembly.push_back(tinyNode(opcode, "r0", "r1"));
	assembly.push_back(tinyNode("move", "r1", tinyOp(result)));
}

void assemble_mathop2(string opcode, string op1, string op2, string result, IRNode n)
{
	/*
	Register * reg1;
	Register * reg2;
	reg1 = ensure(op1);
	reg2 = ensure(op2);

	set <string>::iterator st;

	st = n.out.find(op1);
	if (st == n.out.end())
		free_reg(reg1); // free if op1 is not live

	st = n.out.find(op2);
	if (st == n.out.end())
		free_reg(reg2); // free if op2 is not live

	if (reg1->data != "" && reg1->dirty)
		free(reg1);

	assembly.push_back(tinyNode(opcode, reg2->name, reg1->name));
	reg1->data = result;
	assembly.push_back(tinyNode(";changing data of", reg1->name, " r0->" + r0.data + " r1->" + r1.data + " r2->" + r2.data + " r3->" + r3.data));
	reg1->dirty = true;
	*/
	assembly.push_back(tinyNode("move", tinyOp(op1), "r0"));
	assembly.push_back(tinyNode("move", tinyOp(op2), "r1"));
	assembly.push_back(tinyNode(opcode, "r1", "r0"));
	assembly.push_back(tinyNode("move", "r0", tinyOp(result)));
}

void assemble_4reg_cmp(string opcode, string op1, string op2, IRNode n)
{
	/*
	Register * reg1;
	Register * reg2;
	reg1 = ensure(op1);
	reg2 = ensure(op2);

	set <string>::iterator st;

	st = n.out.find(op1);
	if (st != n.out.end())
		free_reg(reg1); // free op1 if it is not live

	st = n.out.find(op2);
	if (st != n.out.end())
		free_reg(reg2); // free op2 if it is not live

	assembly.push_back(tinyNode(opcode, reg1->name, reg2->name));
	*/
	assembly.push_back(tinyNode("move", tinyOp(op1), "r0"));
	assembly.push_back(tinyNode("move", tinyOp(op2), "r1"));
	assembly.push_back(tinyNode(opcode, "r0", "r1"));
}

void end_of_bb()
{
	assembly.push_back(tinyNode(";End of basic block", "", ""));
	if ((r0.dirty || (r0.data[0] == '$' && r0.data[1] == 'L') || (r0.data[0] != '$' && !isdigit(r0.data[0]))) && r0.data != "")
			assembly.push_back(tinyNode("move", r0.name, r0.str()));
	if (r0.dirty)
		r0.dirty = false;

	if ((r1.dirty || (r1.data[0] == '$' && r1.data[1] == 'L') || (r1.data[0] != '$' && !isdigit(r1.data[0]))) && r1.data != "")
			assembly.push_back(tinyNode("move", r1.name, r1.str()));
	if (r1.dirty)
		r1.dirty = false;

	if ((r2.dirty || (r2.data[0] == '$' && r2.data[1] == 'L') || (r2.data[0] != '$' && !isdigit(r2.data[0]))) && r2.data != "")
			assembly.push_back(tinyNode("move", r2.name, r2.str()));
	if (r2.dirty)
		r2.dirty = false;

	if ((r3.dirty || (r3.data[0] == '$' && r3.data[1] == 'L') || (r3.data[0] != '$' && !isdigit(r3.data[0]))) && r3.data != "")
			assembly.push_back(tinyNode("move", r3.name, r3.str()));
	if (r3.dirty)
		r3.dirty = false;

	r0.data = "";
	r1.data = "";
	r2.data = "";
	r3.data = "";
}

void save_globals()
{
	assembly.push_back(tinyNode(";Save globals and free regs before function call", "", ""));
	if (r0.data[0] != '$' && !isdigit(r0.data[0]) && r0.data != "")
		assembly.push_back(tinyNode("move", r0.name, r0.str()));
	if (r0.dirty)
		r0.dirty = false;

	if (r1.data[0] != '$' && !isdigit(r1.data[0]) && r1.data != "")
		assembly.push_back(tinyNode("move", r1.name, r1.str()));
	if (r1.dirty)
		r1.dirty = false;	

	if (r2.data[0] != '$' && !isdigit(r2.data[0]) && r2.data != "")
		assembly.push_back(tinyNode("move", r2.name, r2.str()));
	if (r2.dirty)
		r2.dirty = false;	

	if (r3.data[0] != '$' && !isdigit(r3.data[0]) && r3.data != "")
		assembly.push_back(tinyNode("move", r3.name, r3.str()));
	if (r3.dirty)
		r3.dirty = false;

	r0.data = "";
	r1.data = "";
	r2.data = "";
	r3.data = "";		
}
/*
void IR_to_tiny(string fid) // Takes a function name and translates the IR for that function to tiny nodes
{
	vector <IRNode> n = func_IR[fid];
	f = func_info[fid];

	int curr_reg = 0;
	string output_reg = "";
	string addop_temp = "";
	string mulop_temp = "";
	string code, op1, op2, result, saved_reg;

	r0.Pcnt = func_info[fid].P_cnt;
	r1.Pcnt = func_info[fid].P_cnt;
	r2.Pcnt = func_info[fid].P_cnt;
	r3.Pcnt = func_info[fid].P_cnt;

	r0.Lcnt = func_info[fid].L_cnt;
	r1.Lcnt = func_info[fid].L_cnt;
	r2.Lcnt = func_info[fid].L_cnt;
	r3.Lcnt = func_info[fid].L_cnt;


	for (vector <IRNode>::iterator it = n.begin(); it != n.end(); ++it) // Loop through the IR nodes in order
	{
		code = it->opcode;
		op1 = it->op1;
		op2 = it->op2;
		result = it->result;

		if (it->cmp_type == "SAVE") // This saves the register holding the value of the left side of a compare
		{
			saved_reg = output_reg;
		}

		// This if else chain checks the opcode and generates the corresponding tiny node.
		if (code == "WRITEI")
		{
			//cout << "sys writei " << result << endl;
			assembly.push_back(tinyNode("sys writei", tiny_opr(fid, result, curr_reg), ""));
		}
		else if (code == "WRITEF")
		{
			//cout << "sys writer " << result << endl;
			assembly.push_back(tinyNode("sys writer", tiny_opr(fid, result, curr_reg), ""));
		}
		else if (code == "WRITES")
		{
			//cout << "sys writes " << result << endl;
			assembly.push_back(tinyNode("sys writes", tiny_opr(fid, result, curr_reg), ""));
		}
		else if (code == "READI")
		{
			//cout << "sys readi " << result << endl;
			assembly.push_back(tinyNode("sys readi", tiny_opr(fid, result, curr_reg), ""));
		}
		else if (code == "READF")
		{
			//cout << "sys readr " << result << endl;
			assembly.push_back(tinyNode("sys readr", tiny_opr(fid, result, curr_reg), ""));
		}
		else if (code == "JUMP")
		{
			//cout << "jmp " << result << endl;
			assembly.push_back(tinyNode("jmp", result, ""));
		}
		else if (code == "GT")
		{
			if (it->cmp_type == "INT")
			{
				assemble_cmpi(op1, op2, saved_reg, output_reg, &curr_reg, fid);
			}
			else
			{
				assemble_cmpr(op1, op2, saved_reg, output_reg, &curr_reg, fid);
			}
			//cout << "jgt " << result << endl;
			assembly.push_back(tinyNode("jgt", result, ""));
			while (!regs.empty())
				regs.pop();
		}
		else if (code == "GE")
		{
			if (it->cmp_type == "INT")
			{
				assemble_cmpi(op1, op2, saved_reg, output_reg, &curr_reg, fid);
			}
			else
			{
				assemble_cmpr(op1, op2, saved_reg, output_reg, &curr_reg, fid);
			}
			//cout << "jge " << result << endl;
			assembly.push_back(tinyNode("jge", result, ""));
			while (!regs.empty())
				regs.pop();
		}
		else if (code == "LT")
		{
			if (it->cmp_type == "INT")
			{
				assemble_cmpi(op1, op2, saved_reg, output_reg, &curr_reg, fid);
			}
			else
			{
				assemble_cmpr(op1, op2, saved_reg, output_reg, &curr_reg, fid);
			}
			//cout << "jlt " << result << endl;
			assembly.push_back(tinyNode("jlt", result, ""));			
			while (!regs.empty())
				regs.pop();
		}
		else if (code == "LE")
		{
			if (it->cmp_type == "INT")
			{
				assemble_cmpi(op1, op2, saved_reg, output_reg, &curr_reg, fid);
			}
			else
			{
				assemble_cmpr(op1, op2, saved_reg, output_reg, &curr_reg, fid);
			}
			//cout << "jle " << result << endl;
			assembly.push_back(tinyNode("jle", result, ""));
			while (!regs.empty())
				regs.pop();
		}
		else if (code == "NE")
		{
			if (it->cmp_type == "INT")
			{
				assemble_cmpi(op1, op2, saved_reg, output_reg, &curr_reg, fid);
			}
			else
			{
				assemble_cmpr(op1, op2, saved_reg, output_reg, &curr_reg, fid);
			}
			//cout << "jne " << result << endl;
			assembly.push_back(tinyNode("jne", result, ""));
			while (!regs.empty())
				regs.pop();
		}
		else if (code == "EQ")
		{
			if (it->cmp_type == "INT")
			{
				assemble_cmpi(op1, op2, saved_reg, output_reg, &curr_reg, fid);
			}
			else
			{
				assemble_cmpr(op1, op2, saved_reg, output_reg, &curr_reg, fid);
			}
			//cout << "jeq " << result << endl;
			assembly.push_back(tinyNode("jeq", result, ""));
			while (!regs.empty())
				regs.pop();
		}
		else if (code == "LABEL")
		{
			//cout << "label " << result << endl;
			assembly.push_back(tinyNode("label", result, ""));
		}
		else if (code == "JSR")
		{
			assembly.push_back(tinyNode("push" , "r0", ""));
			assembly.push_back(tinyNode("push" , "r1", ""));
			assembly.push_back(tinyNode("push" , "r2", ""));
			assembly.push_back(tinyNode("push" , "r3", ""));
			assembly.push_back(tinyNode("jsr", result, ""));
			assembly.push_back(tinyNode("pop" , "r3", ""));
			assembly.push_back(tinyNode("pop" , "r2", ""));
			assembly.push_back(tinyNode("pop" , "r1", ""));
			assembly.push_back(tinyNode("pop" , "r0", ""));
		}
		else if (code == "PUSH")
		{
			assembly.push_back(tinyNode("push", tiny_opr(fid, result, curr_reg - 1), ""));
		}
		else if (code == "POP")
		{	
			assembly.push_back(tinyNode("pop", tiny_opr(fid, result, curr_reg), ""));
			output_reg =  tiny_opr(fid, result, curr_reg);
			curr_reg++;
		}
		else if (code == "LINK")
		{
			ss.str("");
			ss << f.L_cnt;
			assembly.push_back(tinyNode("link", ss.str(), ""));
			ss.str("");
		}
		else if (code == "RET")
		{
			assembly.push_back(tinyNode("unlnk", "", ""));
			assembly.push_back(tinyNode("ret", "", ""));
		}
		else if (code == "STOREI" || code == "STOREF")
		{
			if (result[0] != '$' || result[1] != 'T') // storing into a variable or stack value
			{
				if (op1[0] != '$' || op1[1] != 'T') // storing a variable or stack value
				{
						ss << "r" << curr_reg;
						string t = ss.str();
						ss.str("");
						assembly.push_back(tinyNode("move", tiny_opr(fid, op1, curr_reg), t));	
						assembly.push_back(tinyNode("move", t, tiny_opr(fid, result, curr_reg)));
						curr_reg = curr_reg + 1;
				}
				else // storing a register
				{
					assembly.push_back(tinyNode("move", output_reg, tiny_opr(fid, result, curr_reg)));
					while (!regs.empty())
						regs.pop();
				}
			}
			else // storing into a register
			{
				assembly.push_back(tinyNode("move", op1, tiny_opr(fid, result, curr_reg)));
				output_reg = tiny_opr(fid, result, curr_reg);
				regs.push(output_reg);
				curr_reg++;
			}
		}
		// Plus
		else if (code == "ADDI")
		{
			assemble_addop("addi", op1, op2, &curr_reg, &addop_temp, &mulop_temp, &output_reg, fid);
		}
		else if (code == "ADDF")
		{
			assemble_addop("addr", op1, op2, &curr_reg, &addop_temp, &mulop_temp, &output_reg, fid);
		}
		// Sub
		else if (code == "SUBI")
		{
			assemble_addop("subi", op1, op2, &curr_reg, &addop_temp, &mulop_temp, &output_reg, fid);
		}
		else if (code == "SUBF")
		{
			assemble_addop("subr", op1, op2, &curr_reg, &addop_temp, &mulop_temp, &output_reg, fid);
		}
		// Mult
		else if (code == "MULTI")
		{
			assemble_mulop("muli", op1, op2, &curr_reg, &mulop_temp, &output_reg, fid);
		}
		else if (code == "MULTF")
		{
			assemble_mulop("mulr", op1, op2, &curr_reg, &mulop_temp, &output_reg, fid);
		}
		// Div
		else if (code == "DIVI")
		{
			assemble_mulop("divi", op1, op2, &curr_reg, &mulop_temp, &output_reg, fid);
		}
		else if (code == "DIVF")
		{
			assemble_mulop("divr", op1, op2, &curr_reg, &mulop_temp, &output_reg, fid);
		}
	}
}

// takes a function name and a register/stack value from the IR and returns a string with the tiny register/stack value
string tiny_opr(string func_name, string opr, int reg_num)
{
	if (opr[0] == '$') // the opr is a register or stack value
	{
		if (opr[1] == 'T') // the opr is a register
		{
			ss.str("");
			ss << "r" << reg_num;
			string t = ss.str();
			ss.str("");
			
			return t;
		}
		else if (opr[1] == 'L') // the opr is a local variable
		{
			string t = "$-" + opr.substr(2, string::npos);
			return t;
		}
		else if (opr[1] == 'R') //  the opr is a return value
		{
			ss.str("");
			ss << "$" << func_info[func_name].P_cnt + 6;
			string t  = ss.str();
			ss.str("");	

			return t;
		}
		else // the opr is a parameter
		{
			string t = opr.substr(2, string::npos);
			ss.str("");
			ss << "$" << atoi(t.c_str()) + 5; 
			t = ss.str();
			ss.str("");
		
			return t;
		}
	}
	else
		return opr; // the opr is a global variable
}

// Takes the IR for an addop and turns it into assembly code.
// This function has several pointers/temp variables and a stack to keep track of registers. These things are shared with assemble_mulop
void assemble_addop(string opcode, string op1, string op2, int * curr_reg, string * addop_temp, string * mulop_temp, string * output_reg, string func_name)
{
	if (op1[0] != '$' || op1[1] != 'T') // op1 is a variable or a stack value
	{
		ss << "r" << *curr_reg;
		string t = ss.str();
		ss.str("");
		assembly.push_back(tinyNode("move", tiny_opr(func_name, op1, *curr_reg), t));
		
		ss << "r" << *curr_reg - 1;
		*addop_temp = ss.str();
		ss.str("");

		*curr_reg = *curr_reg + 1;

		if (op2[0] != '$' || op2[1] != 'T') // op2 is a variable or stack value
		{
			assembly.push_back(tinyNode(opcode, tiny_opr(func_name, op2, *curr_reg - 1), t));
		}
		else // op2 is a register
		{
			assembly.push_back(tinyNode(opcode, *addop_temp, t));
			if (!regs.empty()) 
			{
				regs.pop();
			}
		}
		regs.push(t);
		*output_reg = t;
		*addop_temp = t;
	}
	else // op1 is a register
	{
		if (op2[0] != '$' || op2[1] != 'T') // op2 is a variable or a stack value
		{
			ss << "r" << *curr_reg - 1; 
			string t = ss.str();
			ss.str("");
			assembly.push_back(tinyNode(opcode, tiny_opr(func_name, op2, *curr_reg - 1), t));
			*output_reg = t;
		}
		else // op2 is a register
		{
			while (!regs.empty())
			{
				*addop_temp = regs.top();
				regs.pop();
			}
			assembly.push_back(tinyNode(opcode, tiny_opr(func_name, op1, *curr_reg - 1), *addop_temp));
			*output_reg = *addop_temp;
			regs.push(*addop_temp);
		}
	}
	*mulop_temp = *addop_temp;
}

// Takes the IR for a mulop and turns it into assembly code.
// This function has several pointers/temp variables and a stack to keep track of registers. These things are shared with assemble_addop.
void assemble_mulop(string opcode, string op1, string op2, int * curr_reg, string * temp, string * output_reg, string func_name)
{
	if (op1[0] != '$' || op1[1] != 'T') // op1 is a variable or a stack value
	{
		ss << "r" << *curr_reg;
		string t = ss.str();
		ss.str("");
		assembly.push_back(tinyNode("move", tiny_opr(func_name, op1, *curr_reg), t));

		ss << "r" << *curr_reg - 1;
		*temp = ss.str();
		ss.str("");

		*curr_reg = *curr_reg + 1;

		if (op2[0] != '$' || op2[1] != 'T') // op2 is a variable or a stack value
		{
			assembly.push_back(tinyNode(opcode, tiny_opr(func_name, op2, *curr_reg - 1), t));
		}
		else // op2 is a register
		{
			assembly.push_back(tinyNode(opcode, *temp, t));
			if (!regs.empty()) 
			{
				regs.pop();
			}
		}
		regs.push(t);
		*output_reg = t;
		*temp = t;
	}
	else // op1 is a register
	{
		if (op2[0] != '$' || op1[1] != 'T') // op2 is a variable or a stack value
		{
			ss << "r" << *curr_reg - 1;
			string t  = ss.str();
			ss.str("");
			assembly.push_back(tinyNode(opcode, tiny_opr(func_name, op2, *curr_reg - 1), t));
			*output_reg = t;
		}
		else // op2 is a register
		{
			while (!regs.empty())
			{
				*temp = regs.top();
				regs.pop();
			}
			assembly.push_back(tinyNode(opcode, tiny_opr(func_name, op1, *curr_reg - 1), *temp));
			*output_reg = *temp;
			regs.push(*temp);
		}
	}
}

// Takes the IR for an integer compare and generates assembly code.
void assemble_cmpi(string op1, string op2, string saved_reg, string output_reg, int * curr_reg, string func_name)
{
	if (op1[0] != '$' && op2[0] != '$' || (op1[1] != 'T' && op2[1] != 'T')) // op1 and op2 are variables or stack values
	{
		ss << "r" << *curr_reg;
		string t = ss.str();
		ss.str("");
		assembly.push_back(tinyNode("move", tiny_opr(func_name, op2, *curr_reg), t));
		output_reg = t;
		*curr_reg = *curr_reg + 1;
		assembly.push_back(tinyNode("cmpi", tiny_opr(func_name, op1, *curr_reg), output_reg));
	}
	else if (op1[0] != '$' || op1[1] != 'T') // only op1 is a variable or astack value
	{
		assembly.push_back(tinyNode("cmpi", tiny_opr(func_name, op1, *curr_reg), output_reg));
	}
	else if (op2[0] != '$' || op2[1] != 'T') // only op2 is variable or stack value
	{
		assembly.push_back(tinyNode("cmpi", output_reg, tiny_opr(func_name, op2, *curr_reg)));
	}
	else // both ops are registers
	{
		assembly.push_back(tinyNode("cmpi", saved_reg, output_reg));
	}
}

// Takes the IR for a float compare and generates assembly code.
void assemble_cmpr(string op1, string op2, string saved_reg, string output_reg, int * curr_reg, string func_name)
{
	if (op1[0] != '$' && op2[0] != '$' || (op1[1] != 'T' && op2[1] != 'T')) // op1 and op2 are variables or stack values
	{
		ss << "r" << *curr_reg;
		string t = ss.str();
		ss.str("");
		assembly.push_back(tinyNode("move", tiny_opr(func_name, op2, *curr_reg), t));
		output_reg = t;
		*curr_reg = *curr_reg + 1;
		assembly.push_back(tinyNode("cmpr", tiny_opr(func_name, op1, *curr_reg), output_reg));
	}
	else if (op1[0] != '$' || op1[1] != 'T') // only op1 is a variable or astack value
	{
		assembly.push_back(tinyNode("cmpr", tiny_opr(func_name, op1, *curr_reg), output_reg));
	}
	else if (op2[0] != '$' || op2[1] != 'T') // only op2 is variable or stack value
	{
		assembly.push_back(tinyNode("cmpr", output_reg, tiny_opr(func_name, op2, *curr_reg)));
	}
	else // both ops are registers
	{
		assembly.push_back(tinyNode("cmpr", saved_reg, output_reg));
	}
}
*/
