using namespace std;

class ASTNode 
{
	public:
		string reg;
		ASTNode * left;
		ASTNode * right;

		virtual string value() = 0;
		virtual string data_type() = 0;
		virtual string node_type() = 0;
};

class Node : public ASTNode
{
	string val;
	string d_type;
	string n_type;
	public:
		Node(string value, string dt, string nt)
		{
			val = value;
			d_type = dt;
			n_type = nt;
			this->left = NULL;
			this->right = NULL;
		}

		string value()
		{
			return val;
		}

		string data_type()
		{
			return d_type;
		}

		string node_type()
		{
			return n_type;
		}
};

class OpNode : public ASTNode
{
	string op;

	public:
		OpNode(string opr)
		{
			op = opr;
			this->left = NULL;
			this->right = NULL;
		}

		OpNode(string opr, ASTNode * left, ASTNode * right)
		{
			op = opr;
			this->left = left;
			this->right = right;
		}

		void setLeft(ASTNode * left)
		{
			this->left = left;
		}

		void setRight(ASTNode * right)
		{
			this->right = right;
		}

		string value()
		{ 
			return op;
		}
		
		string data_type()
		{
			return "";
		}

		string node_type()
		{
			return "op";
		}
};

