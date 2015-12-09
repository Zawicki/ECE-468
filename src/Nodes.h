#include <iostream>
#include <set>
#include <sstream>
using namespace std;

class tinyNode
{
	public:
		string opcode;
		string op1;
		string op2;

	tinyNode(string op, string o1, string o2)
	{
			opcode = op;
			op1 = o1;
			op2 = o2;
	}

	void print_Node()
	{
		if (opcode != "")
		{
			cout << opcode;
			if (op1 != "")
				cout << " " << op1;
			if (op2 != "")
				cout << " " << op2;
			cout << endl; 
		}

	}
};

class Register
{
	public:
		bool dirty;
		string data;
		string name;
		int Pcnt;
		int Lcnt;
		
		Register(string s)
		{
			dirty = false;
			data = "";
			name = s;
			Pcnt = 0;
			Lcnt = 0;
		}


		Register(string s, int P, int L)
		{
			dirty = false;
			data = "";
			name = s;
			Pcnt = P;
			Lcnt = L;
		}

		string str()
		{
			stringstream ss;
			if (data[0] == '$')
			{
				if (data[1] == 'T')
				{
					string t = data.substr(2, string::npos);
					ss << "$-" << atoi(t.c_str()) + Lcnt;
					return ss.str();
				}
				else if (data[1] == 'L')
				{
					return "$-" + data.substr(2, string::npos);
				}
				else if (data[1] == 'P')
				{
					string t = data.substr(2, string::npos);
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
				return data;
		}
};

class IRNode
{
	public:
		string opcode;
		string op1;
		string op2;
		string result;
		string cmp_type;
		set <string> gen;
		set <string> kill;
		set <string> in;
		set <string> out;
		set <IRNode *> prev;
		set <IRNode *> next;


		IRNode(string op, string o1, string o2, string r)
		{
			opcode = op;
			op1 = o1;
			op2 = o2;
			result = r;
			cmp_type = "none";
		}	

		IRNode(string op, string o1, string o2, string r, string t)
		{
			opcode = op;
			op1 = o1;
			op2 = o2;
			result = r;
			cmp_type = t;
		}	

		void print_Node()
		{
			if (opcode != "")
			{
				cout << ";" << opcode;
				if (op1 != "")
					cout << " " << op1;
				if (op2 != "")
					cout << " " << op2;
				cout << " " << result;
				//printf(" %x", this);

				/*cout << "\n\tLIVE-IN:";
				for (set <string>::iterator it = in.begin(); it != in.end(); ++it)
				{
					cout << " " << *it;
				}*/

				cout << "\tLIVE VARS:";
				for (set <string>::iterator it2 = out.begin(); it2 != out.end(); ++it2)
				{
					cout << " " << *it2;
				}
				/*cout << "\n\tGEN:";
				for (set <string>::iterator it = gen.begin(); it != gen.end(); ++it)
				{
					cout << " " << *it;
				}
				cout << "\n\tKILL:";
				for (set <string>::iterator it2 = kill.begin(); it2 != kill.end(); ++it2)
				{
					cout << " " << *it2;
				}
				cout << "\n\tPREV:";
				for (set <IRNode *>::iterator it3 = prev.begin(); it3 != prev.end(); ++it3)
				{
					cout << " " << (*it3)->opcode << " " << (*it3)->result;
					printf(" %x", *it3);
				}
				cout << "\n\tNEXT:";
				for (set <IRNode *>::iterator it4 = next.begin(); it4 != next.end(); ++it4)
				{
					cout << " " << (*it4)->opcode << " " << (*it4)->result;
					printf(" %x", *it4);
				}*/

				cout << endl; 
			}
		}
};

class ASTNode 
{
	public:
		string val; // The value of the node
		string data_type; // The data type of the node
		string node_type; // The type of node
		string reg; // The register that the nodes value is stored in
		ASTNode * left; // The left child of the node
		ASTNode * right; // The righ child of the node

		virtual IRNode gen_IR() = 0;
};

class ConstIntNode : public ASTNode
{

	public:
		ConstIntNode(string value)
		{
			val = value;
			data_type = "INT";
			node_type = "CONST";
			this->left = NULL;
			this->right = NULL;
		}

		IRNode gen_IR()
		{
			return IRNode("STOREI", val, "", reg);
		}
};

class ConstFloatNode : public ASTNode
{

	public:
		ConstFloatNode(string value)
		{
			val = value;
			data_type = "FLOAT";
			node_type = "CONST";
			this->left = NULL;
			this->right = NULL;
		}

		IRNode gen_IR()
		{
			return IRNode("STOREF", val, "", reg);
		}

};

class VarNode : public ASTNode
{

	public:
		VarNode(string value, string dt)
		{
			val = value;
			reg = value;
			data_type = dt;
			node_type = "VAR";
			this->left = NULL;
			this->right = NULL;
		}

		IRNode gen_IR()
		{
			return IRNode("","","",reg,"VAR");
		}

};

class FuncNode : public ASTNode
{
	public:
		FuncNode(string r)
		{
			reg = r;
			node_type = "FUNC";
			this->left = NULL;
			this->right = NULL;
		}

		IRNode gen_IR()
		{
			return IRNode("", "", "", reg, "FUNC");
		}
};

class OpNode : public ASTNode
{

	public:
		OpNode(string op)
		{
			node_type = "OP";
			val = op;
			this->left = NULL;
			this->right = NULL;
		}

		OpNode(string op, ASTNode * left, ASTNode * right)
		{
			node_type = "OP";
			val = op;
			this->left = left;
			this->right = right;
		}

		IRNode gen_IR()
		{
			if (val == "+")
			{
				if (data_type == "INT")
					return IRNode("ADDI", this->left->reg, this->right->reg, reg);
				else
					return IRNode("ADDF", this->left->reg, this->right->reg, reg);
			}
			else if (val == "-")
			{
				if (data_type == "INT")
					return IRNode("SUBI", this->left->reg, this->right->reg, reg);
				else
					return IRNode("SUBF", this->left->reg, this->right->reg, reg);

			}
			else if (val == "*")
			{
				if (data_type == "INT")
					return IRNode("MULTI", this->left->reg, this->right->reg, reg);
				else
					return IRNode("MULTF", this->left->reg, this->right->reg, reg);

			}
			else if (val == "/")
			{
				if (data_type == "INT")
					return IRNode("DIVI", this->left->reg, this->right->reg, reg);
				else
					return IRNode("DIVF", this->left->reg, this->right->reg, reg);

			}
			else if (val == "=")
			{
				if (data_type == "INT")
					return IRNode("STOREI", this->right->reg, "", reg);
				else
					return IRNode("STOREF", this->right->reg, "", reg);
			}
		}

};

