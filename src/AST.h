using namespace std;

class ASTNode 
{
	public:
		string reg;
		string val;
		string d_type;
		string n_type;
		ASTNode * left;
		ASTNode * right;

		virtual string value() = 0;
		virtual string data_type() = 0;
		virtual string node_type() = 0;
};

class Node : public ASTNode
{

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

	public:
		OpNode(string op)
		{
			n_type = "op";
			val = op;
			this->left = NULL;
			this->right = NULL;
		}

		OpNode(string op, ASTNode * left, ASTNode * right)
		{
			n_type = "op";
			val = op;
			this->left = left;
			this->right = right;
			if (left->data_type() == "FLOAT")
				d_type = "FLOAT";
			else
				d_type = "INT";
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

