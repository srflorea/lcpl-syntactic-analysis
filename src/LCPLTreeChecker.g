tree grammar LCPLTreeChecker;

options {
    tokenVocab=LCPLTreeBuilder;
    ASTLabelType=CommonTree;
}

@members {
	/* Some global variables that are helping to insert the correct expression in the tree */
	private int in_local;
	private int local_block_line = -1;

	/* Method that inserts an expression into a block recursively.
	*/
	private Expression put(Expression block, Expression ex) {
		if(block == null) {
			if((ex instanceof LocalDefinition) && (in_local == 1)) {
				block = ex;
			}
			else {
				List<Expression> list = new LinkedList<Expression>();
				list.add(ex);

				int block_line = ex.getLineNumber();
				if(local_block_line != -1) {
					block_line = local_block_line;
					local_block_line = -1;
				}

				block = new Block(block_line, list);
			}
			return block;
		}
		
		if(block instanceof LocalDefinition) {
			Expression scope = ((LocalDefinition)block).getScope();
			((LocalDefinition)block).setScope(put(scope, ex));
		}
		else {
			List<Expression> list = ((Block)block).getExpressions();
			Expression last = list.get(list.size() - 1);

			if(last instanceof LocalDefinition) {
				list.remove(list.size() - 1);
				Expression b = ((LocalDefinition)last).getScope();
				b = put(b, ex);
				((LocalDefinition)last).setScope(b);
				list.add(last);
			}
			else {
				list.add(ex);
			}
			
			((Block)block).setExpressions(list);
		}

		return block;
	}

	/* Method that checks the scope of the last expression of beeing null.
	*/
	Expression checkLastExpression(Expression scope) {
		if(scope == null) {
			return new Block(0, new LinkedList<Expression>());
		}

		if(scope instanceof Block) {
			List<Expression> expressions = ((Block)scope).getExpressions();
			if(expressions.size() == 0)
				return scope;
			Expression last = expressions.get(expressions.size() - 1);
			expressions.remove(expressions.size() - 1);
			last = checkLastExpression(last);
			expressions.add(last);
			((Block)scope).setExpressions(expressions);
		}
		else if(scope instanceof LocalDefinition) {
			Expression next = ((LocalDefinition)scope).getScope();
			((LocalDefinition)scope).setScope(checkLastExpression(next));
		}

		return scope;
	}
}

@header {
    import java.util.LinkedList;
    import ro.pub.cs.lcpl.*;
}

/* The rule for the root of the AST.
*/
program returns [Program result]
scope {
	LinkedList<LCPLClass> classes;
}
@init {
	$program::classes = new LinkedList<LCPLClass>();
}
    : 	^(PROGRAM classdef+)
    	{ 
        	$result=new Program($PROGRAM.line, $program::classes); 
    	}
    ;

/* Rule for a class definition.
*/
classdef returns [LCPLClass result]
	scope {
		List<Feature> features;
	}
	@init {
		$classdef::features = new LinkedList<Feature>();
	}
    :   ^(CLASS name=ID parent=ID? class_body*)
    	{
       	 	LCPLClass new_class = new LCPLClass($CLASS.line, $name.text, $parent.text, $classdef::features);
       	 	$program::classes.add(new_class);
    	}
    ;
    
class_body
	:	(
		var 
			{
				$classdef::features.add($var.result);
			}
	|	method 
			{
				$classdef::features.add($method.result);
			}
		)
	;

/* Rule for a variable from a class.
*/	
var returns [Attribute result]
	: 	^(ATTRIBUTE type=ID name=ID EQUAL? expression?)
		{
			Expression expression;
			if($EQUAL == null) {
				expression = null;
			}
			else {
				expression = $expression.result;
			}
			$result = new Attribute($ATTRIBUTE.line, $name.text, $type.text, expression);
		}
	;
	
/* This rule is a generic one which encapsulates all the types of expressions.
 * In my program everything without declarations of variables are expressions.
 * It returns an Expression object which is the super type of each type of expression. 
*/
expression returns [Expression result]
scope {
	List<Expression> args;
}
@init {
	$expression::args = new LinkedList<Expression>();
}
	:	INTEGER { $result = new IntConstant($INTEGER.line, Integer.parseInt($INTEGER.text)); }
	|	string 	{ $result = new StringConstant($string.line, $string.result); }
	| 	ID		
		{
			if($ID.text.equals("void"))
				$result = new VoidConstant($ID.line);
			else 
				$result = new Symbol($ID.line, $ID.text);
		}
	|   ^(ADD e1=expression e2=expression) { $result = new Addition($ADD.line, e1, e2); }
	|	^(SUB e1=expression e2=expression) { $result = new Subtraction($SUB.line, e1, e2); }
	|   ^(MUL e1=expression e2=expression) { $result = new Multiplication($MUL.line, e1, e2); }
	|	^(DIV e1=expression e2=expression) { $result = new Division($DIV.line, e1, e2); }
	|	^(EQUAL e1=expression e2=expression) { $result = new Assignment($EQUAL.line, ((Symbol)$e1.result).getName(), $e2.result); }
	|	^(NEW e1=expression) { $result = new NewObject($NEW.line, ((Symbol)$e1.result).getName()); }
	|   ^(EQUALCOM e1=expression e2=expression) { $result = new EqualComparison($EQUALCOM.line, e1, e2); }
	|   ^(LD e1=expression e2=expression) { $result = new LessThan($LD.line, e1, e2); }
	|   ^(LDE e1=expression e2=expression) { $result = new LessThanEqual($LDE.line, e1, e2); }
	|   ^(NOT e1=expression) { $result = new LogicalNegation($NOT.line, e1); }
	|   ^(UNARY e1=expression) { $result = new UnaryMinus($UNARY.line, e1); }
	| 	^(CALL e=expression (arg)*)
		{
			if($e.result instanceof Dispatch) {
				((Dispatch)$e.result).setArguments($expression::args);
				$result = $e.result;
			}
			else if($e.result instanceof StaticDispatch) {
				((StaticDispatch)$e.result).setArguments($expression::args);
				$result = $e.result;
			}
			else {
				String name = ((Symbol)$e.result).getName();
				String[] parts = name.split("\\.");
				if(parts.length == 2) {
					Expression obj = new Symbol($CALL.line, parts[0]);
					$result = new Dispatch($CALL.line, obj, parts[1], $expression::args);
				}
				else
					$result = new Dispatch($CALL.line, null, ((Symbol)$e.result).getName(), $expression::args);
			}
				
		}
	/* 	StaticDispatch
		Uses a syntactic predicate to identify what type of Dispatch it has to handle with.
	*/
	|	(^('.' ^('.' expression ID) ID))=> ^('.' ^('.' object=expression type=ID) func=ID)
		{
			List<Expression> args = null;
			$result = new StaticDispatch($type.line, $object.result, $type.text, $func.text, args);
		}
	/* Dispatch */
	|	^('.' object=expression function=expression)
		{
			/* If it is a reference to a member of the self object, 
			then concatenate into a unique Symbol: "self.x" */
			if($object.result instanceof Symbol && ((Symbol)$object.result).getName().equals("self")) {
					String name = ((Symbol)$object.result).getName() + "." + ((Symbol)$function.result).getName();
					$result = new Symbol($object.result.getLineNumber(), name);
			}
			/* Else make a Dispatch object */
			else {
				List<Expression> args = null;
				$result = new Dispatch($object.result.getLineNumber(), $object.result, ((Symbol)$function.result).getName(), args);
			}
		}
	/* If Statement */
	|	^(
			IF 
			cond=expression 
			^(THEN_BODY then_body=body) 
			(^(ELSE_BODY else_body=body))?
		)
		{
			$result = new IfStatement($IF.line, $cond.result, $then_body.result, $else_body.result);
		}
	/* While Statement */
	|	^(WHILE cond=expression ^(LOOP loop_body=body))
		{
			$result = new WhileStatement($WHILE.line, $cond.result, $loop_body.result);
		}
	/* Cast */
	|	^(CAST type=ID expr=expression)
		{
			$result = new Cast($CAST.line, $type.text, $expr.result);
		}
	/* 	For substrings the AST contains some aditional nodes(S) without with I couldn't resolve 
		the problem.
	*/
	|	^(S sub=expression)
		{
			$result = $sub.result;
		}
	|	^(SUBSTRING start=expression end=expression) next=expression
		{
			$result = new SubString($SUBSTRING.line, $next.result, $start.result, $end.result);
		}
	;

/* Rule for strings.
 * It is looking for special characters in order to format the string in the correct form.
*/
string returns [String result, int line]
	: STR
		{
			String str= "";
			String s = $STR.text.substring(1, $STR.text.length() -1);
			char[] chars = s.toCharArray();
			for(int i = 0; i < s.length(); i++) {
				if(chars[i] == '\\') {
					if(chars[i + 1] == '\r') {
						str += "\r\n";
						i += 2;
					}
					else if(chars[i + 1] == 'n') {
						str += "\n";
						i++;
					}
					else if (chars[i + 1] == 'r') {
						str += "\r";
						i++;
					}
					else if (chars[i + 1] == 't') {
						str += "\t";
						i++;
					}
					else {
						str += chars[i + 1];
						i++;
					}
				}
				else {
					str += chars[i];
				}
			}

			$result = str;
			$line   = $STR.line; 
		}
	;

/* Rule for an argument.
 * It adds all the matches to the variable "args" from the scope of expression rule.
*/
arg
	:	^(ARG argument=expression)
		{
			$expression::args.add($argument.result);
		}
	;
    
/* Rule for methods.
*/
method returns [Method result]
	scope {
		List<FormalParam> parameters;
	}
	@init {
		$method::parameters = new LinkedList<FormalParam>();
	}
    :   ^(METHOD ^(ANTET name=ID parameters* (^(RETURN return_type=ID))?) ^(BODY body))
	    {
	    	/* If there is no returning type, the it is "void" */ 
			String ret = $return_type.text;
			if(ret == null)
				ret = "void";

			/* If there is no body, then it is an empty block */
			Expression b = $body.result;
			if(b == null)
				b = new Block(0, new LinkedList<Expression>());

			/*  If the last expression is a LocalVariable, then its scope will be null.
				So, this call checks and modify the block if necessary.
			*/
			b = checkLastExpression(b);

	        $result = new Method($METHOD.line, $name.text, $method::parameters, 
	        					ret, b);
	    }
    ;    

parameters
	:	^(PARAM type=ID name=ID)
		{
			$method::parameters.add(new FormalParam($name.text, $type.text));
		}
	;

/* Rule for body of a method or an if or while statement.
 * It matches a Local Variable or an Expression and then calls the method put to insert the
 * new Node into the body tree.
*/
body returns [ Expression result ]
scope {
	Expression block;
}
@after {
	$result = $body::block;
}
    :   (
    	local_vars
    	| 
    	expression
    		{
	    		$body::block = put($body::block, $expression.result);
    		}
    	)*
    ;

local_vars
	:	^(LOCAL { local_block_line = $LOCAL.line; } local rest*)
		{
			in_local = 0;
			local_block_line = -1;
		}
	;

rest
@init {
	in_local = 1;
}
	:	local
	;

local
	:	^(LOCAL_VAR type=ID name=ID EQUAL? expression?)
		{
			LocalDefinition l = new LocalDefinition($LOCAL_VAR.line, $name.text, $type.text,
													$expression.result, null); 
			$body::block = put($body::block, l);
		}
	;
