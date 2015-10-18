#include <iostream>
using namespace std;

class IRNode
{
	public:
		string opcode;
		string op1;
		string op2;
		string result;

		IRNode(string op, string o1, string o2, string r)
		{
			opcode = op;
			op1 = o1;
			op2 = o2;
			result = r;
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
				cout << " " << result << endl; 
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
			return IRNode("","","","");
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

