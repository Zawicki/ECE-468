#include <iostream>
#include <set>
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
				if (!gen.empty())
				{
					cout << " GEN:";
					for (set <string>::iterator it = gen.begin(); it != gen.end(); ++it)
					{
						cout << " " << *it;
					}
				}
				if (!kill.empty())
				{
					cout << " KILL:";
					for (set <string>::iterator it2 = kill.begin(); it2 != kill.end(); ++it2)
					{
						cout << " " << *it2;
					}
				}
				if (!prev.empty())
				{
					cout << " PREV:";
					for (set <IRNode *>::iterator it3 = prev.begin(); it3 != prev.end(); ++it3)
					{
						cout << " " << (*it3)->opcode << " " << (*it3)->result;
					}
	
				}
				if (!next.empty())
				{
					cout << " NEXT:";
					for (set <IRNode *>::iterator it4 = next.begin(); it4 != next.end(); ++it4)
					{
						cout << " " << (*it4)->opcode << " " << (*it4)->result;
					}

				}
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

