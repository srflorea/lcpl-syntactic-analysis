grammar LCPLTreeBuilder;

options {
    language = Java;
    output = AST;
    ASTLabelType = CommonTree;
}

tokens {
    PROGRAM;
    METHOD;
    STATEMENT;
    ID;
    STRING_CONST;
    ATTRIBUTE;
    VARS;
    INTEGER;
    IDENT;
    PARAM;
    RETURN;
    BODY;
    LOCAL_VAR;
    ANTET;
    DISPATCH;
    SCOPE;
    ARG;
    CALL;
    EXPR;
    CAST;  
    UNARY;
    NOT;
    THEN_BODY;
    ELSE_BODY;
    SUBSTRING;
    SUBS;
    S;

    CLASS = 'class';
    INHERITS = 'inherits';
    END = 'end';
    VAR = 'var';
    LOCAL = 'local';
    
    ADD = '+';
    SUB = '-'; 
    MUL = '*';
    DIV = '/';
    NEW = 'new';
    EQUALCOM = '==';
    LD = '<';
    LDE = '<='; 
    UNARY;
    NOT = '!';
    EQUAL = '=';
    
    IF 		= 'if';
    THEN	= 'then';
    ELSE	= 'else';
    WHILE = 'while';
    LOOP	= 'loop';
}

/*
 * The entry point in the grammar. 
*/
program :   classdef+ -> ^(PROGRAM classdef+)
    ;

/*
 * Start of class definition.
*/
classdef :  CLASS name=ID (INHERITS parent=ID)? class_body* END ';' -> 
        ^(CLASS $name $parent? class_body*)
    ;
    
/*
 * Class body can contains methods and varibles declaration.
*/
class_body
	:	method | vars
	;
	
vars
	:	VAR! (attribute)* END! ';'!
	;
	
attribute
	:	type=ID name=ID (EQUAL expression)? ';'
		-> ^(ATTRIBUTE $type $name EQUAL? expression?)
	;    

/*
 * Start of method declaration handle.
*/
method  
	:   name=ID parameters? ('->' return_type=ID)?  ':' body END ';' 
        -> ^(METHOD ^(ANTET $name parameters? ^(RETURN $return_type)?) ^(BODY body?))
    	;
    
parameters
	:	param (','! param)*
	;
	
param
	:	type=ID name=ID -> ^(PARAM $type $name)
	;

/*
 * Rule for a body of a method or an if or while statement.
 * Can contains expressions or local variables.
*/
body
	:	(expression ';'! | local_vars)* 	
	;
	
local_vars
	:	LOCAL local* END ';'
		-> ^(LOCAL (local)*)
	;
    
local
	:	type=ID name=ID (EQUAL expression)? ';'
		-> ^(LOCAL_VAR $type $name EQUAL? expression?)
    ;
    
args
	:	arg (','! arg)*
	;
	
arg
	:	argument=expression	-> ^(ARG $argument)
	;

/*
 * Rule for a method call.
*/
call
	:	'[' dispatch args?  ']'
		-> ^(CALL dispatch args?)
	;
	
/*
 * Rule for an if statement.
*/
if_stat
	: 	IF expression 'then' first=body ('else' second=body)? END
		-> ^(IF expression ^(THEN_BODY $first) ^(ELSE_BODY $second)?)
	;

/*
 * Rule for a while statement.
*/
while_stat
	:	WHILE expression LOOP body END
		-> ^(WHILE expression ^(LOOP body))
	;

/*
 * Rule for a cast expression.
*/
cast
	:	'{' type=ID expression '}'
		->^(CAST $type expression)
	;

/*
 * Rule for a substring expression.
*/
substring
	:	'[' first=expression ',' last=expression ']'
		-> ^(SUBSTRING $first $last)	
	;

term 
	:	ID
	|	'('! expression ')'!
	|	INTEGER
	| 	STR
	| 	call
	|	if_stat
	|	while_stat
	|	cast
	;

subs 
	:	first=substring rest=substring*
		-> ^(S $rest* $first)	
	;

sub
	:	(term subs)=>(term subs)
		-> ^(subs term)
	| 	term
	;
	
dispatch
	:	sub ('.'^ sub)*
	;

/*
 * Start of arithmetics expressions handle.
*/

unary
	:	NOT dispatch -> ^(NOT dispatch)
	|	'-' dispatch -> ^(UNARY dispatch)
	|	NEW^ dispatch
	|	dispatch	
	;
	
mult
	:	unary ((MUL^ | DIV^) unary)*	
	;
    
add
	:	mult ((ADD^ | SUB^) mult)*	
	;
	
relation
	:	add ((LD^ | LDE^ |  EQUALCOM^) add)*	
	;
	
expression
	:	relation (EQUAL^ expression)*
	;

/*
 * End of arithmetics expressions handle.
*/
    
/*
 * Start of lexical rules declaration.
*/

INTEGER 
	:	'0'..'9'+
	;

STR:  '"' ( ESC_SEQ | ~('\\'|'"') )* '"';

fragment
ESC_SEQ:   '\\' (~'x'|'x');

    
ID
	:	('A'..'Z'|'a'..'z') ('a'..'z'|'A'..'Z'|'0'..'9'|'_')*
	;     
 
WS  
	:   (' ' | '\t' | '\n' | '\r') {$channel=HIDDEN;}
    	;
 
 COMMENT_LINE
 	: '#' ~('\n')*  {$channel=HIDDEN;};

/*
 * End of lexical rules declaration.
*/