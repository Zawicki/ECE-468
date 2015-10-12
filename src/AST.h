using namespace std;

class ASTNode 
{
	public:
		virtual string value() = 0;
		virtual string type() = 0;
};

class ConstNode : public ASTNode
{
	string val;
	string typ;
	public:
		ConstNode(string value, string type)
		{
			val = value;
			typ = type;
		}

		string value()
		{
			return val;
		}

		string type()
		{
			return typ;
		}
};

class VarNode : public ASTNode
{
	string val;
	string typ;
	
	public:
		VarNode(string value, string type)
		{
			val = value;
			typ = type;	
		}

		string value()
		{
			return val;
		}

		string type()
		{
			return typ;
		}
};

class OpNode : public ASTNode
{
	string op;

	public:
		ASTNode * left;
		ASTNode * right;

		OpNode(string opr)
		{
			op = opr;
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
		
		string type()
		{
			return "";
		}
};

