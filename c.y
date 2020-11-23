%{
#include <cstdio>
#include <iostream>
#include <cstring>
#include <stdio.h>
#include "c.ast.hpp"

using namespace std;

// stuff from flex that bison needs to know about:
extern "C" int yylex();
int yyparse(vector<FunctionDefinition*> *ast);
extern "C" FILE *yyin;
 
void yyerror(vector<FunctionDefinition*> *ast, const char *s);

#define TRACE printf("reduce at line %d\n", __LINE__);
%}
%token	IDENTIFIER I_CONSTANT F_CONSTANT STRING_LITERAL FUNC_NAME SIZEOF
%token	PTR_OP INC_OP DEC_OP LEFT_OP RIGHT_OP LE_OP GE_OP EQ_OP NE_OP
%token	AND_OP OR_OP MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN ADD_ASSIGN
%token	SUB_ASSIGN LEFT_ASSIGN RIGHT_ASSIGN AND_ASSIGN
%token	XOR_ASSIGN OR_ASSIGN
%token	TYPEDEF_NAME ENUMERATION_CONSTANT

%token	TYPEDEF EXTERN STATIC AUTO REGISTER INLINE
%token	CONST RESTRICT VOLATILE
%token	BOOL CHAR SHORT INT LONG SIGNED UNSIGNED FLOAT DOUBLE VOID
%token	COMPLEX IMAGINARY 
%token	STRUCT UNION ENUM ELLIPSIS

%token	CASE DEFAULT IF ELSE SWITCH WHILE DO FOR GOTO CONTINUE BREAK RETURN

%token	ALIGNAS ALIGNOF ATOMIC GENERIC NORETURN STATIC_ASSERT THREAD_LOCAL

%start translation_unit
%parse-param {vector<FunctionDefinition*> *ast}

%union {
    string *str;
    int num;
    TypeSpecifier typespec;
    FunctionDefinition *func;
    vector<FunctionDefinition*> *root;
    Declaration *decl;
    vector<Declaration*> *decls;
    Signature *sig;
    Literal *lit;
    Expression *expr;
	Assignment *assign;
	Statement *stmt;
	BlockItem *block;
	vector<BlockItem*> *blocks;
}

%type<typespec> type_specifier declaration_specifiers
%type<str> IDENTIFIER
%type<num> I_CONSTANT constant
%type<func> external_declaration function_definition
%type<root> translation_unit
%type<decl> parameter_declaration
%type<decls> parameter_list parameter_type_list
%type<sig> declarator direct_declarator
%type<lit> cast_expression unary_expression
%type<expr> multiplicative_expression shift_expression additive_expression relational_expression equality_expression inclusive_or_expression exclusive_or_expression and_expression logical_or_expression logical_and_expression primary_expression conditional_expression expression expression_statement
%type<assign> assignment_expression
%type<stmt> statement
%type<block> block_item
%type<blocks> block_item_list compound_statement
%%

primary_expression
	: IDENTIFIER {
        auto *var = new Variable(*$1);
        $$ = var;
    }
	| constant {
        auto *num = new IntLiteral($1);
        $$ = num;
    }
	| string
	| '(' expression ')' { $$ = $2; }
	| generic_selection
	;

constant
	: I_CONSTANT
	| F_CONSTANT
	| ENUMERATION_CONSTANT	/* after it has been defined as such */
	;

enumeration_constant		/* before it has been defined as such */
	: IDENTIFIER
	;

string
	: STRING_LITERAL
	| FUNC_NAME
	;

generic_selection
	: GENERIC '(' assignment_expression ',' generic_assoc_list ')'
	;

generic_assoc_list
	: generic_association
	| generic_assoc_list ',' generic_association
	;

generic_association
	: type_name ':' assignment_expression
	| DEFAULT ':' assignment_expression
	;

postfix_expression
	: primary_expression
	| postfix_expression '[' expression ']'
	| postfix_expression '(' ')'
	| postfix_expression '(' argument_expression_list ')'
	| postfix_expression '.' IDENTIFIER
	| postfix_expression PTR_OP IDENTIFIER
	| postfix_expression INC_OP
	| postfix_expression DEC_OP
	| '(' type_name ')' '{' initializer_list '}'
	| '(' type_name ')' '{' initializer_list ',' '}'
	;

argument_expression_list
	: assignment_expression
	| argument_expression_list ',' assignment_expression
	;

unary_expression
	: postfix_expression
	| INC_OP unary_expression
	| DEC_OP unary_expression
	| unary_operator cast_expression
	| SIZEOF unary_expression
	| SIZEOF '(' type_name ')'
	| ALIGNOF '(' type_name ')'
	;

unary_operator
	: '&'
	| '*'
	| '+'
	| '-'
	| '~'
	| '!'
	;

cast_expression
	: unary_expression
	| '(' type_name ')' cast_expression
	;

multiplicative_expression
	: cast_expression
	| multiplicative_expression '*' cast_expression {
		auto *expr = new UnaryExpression(UnaryOperator::Multiply, $1, $3);
        $$ = expr;
    }
	| multiplicative_expression '/' cast_expression {
		auto *expr = new UnaryExpression(UnaryOperator::Divide, $1, $3);
        $$ = expr;
    }
	| multiplicative_expression '%' cast_expression
	;

additive_expression 
	: multiplicative_expression
	| additive_expression '+' multiplicative_expression {
		auto *expr = new UnaryExpression(UnaryOperator::Plus, $1, $3);
        $$ = expr;
    }
	| additive_expression '-' multiplicative_expression {
		auto *expr = new UnaryExpression(UnaryOperator::Minus, $1, $3);
        $$ = expr;
    }
	;

shift_expression
	: additive_expression
	| shift_expression LEFT_OP additive_expression {
		auto *expr = new UnaryExpression(UnaryOperator::Left, $1, $3);
        $$ = expr;
    }
	| shift_expression RIGHT_OP additive_expression {
		auto *expr = new UnaryExpression(UnaryOperator::Right, $1, $3);
        $$ = expr;
    }
	;

relational_expression
	: shift_expression
	| relational_expression '<' shift_expression {
		auto *expr = new UnaryExpression(UnaryOperator::Less, $1, $3);
        $$ = expr;
    }
	| relational_expression '>' shift_expression {
		auto *expr = new UnaryExpression(UnaryOperator::Greater, $1, $3);
        $$ = expr;
    }
	| relational_expression LE_OP shift_expression {
		auto *expr = new UnaryExpression(UnaryOperator::LessEqual, $1, $3);
        $$ = expr;
    }
	| relational_expression GE_OP shift_expression {
		auto *expr = new UnaryExpression(UnaryOperator::GreaterEqual, $1, $3);
        $$ = expr;
    }
	;

equality_expression
	: relational_expression
	| equality_expression EQ_OP relational_expression {
		auto *expr = new UnaryExpression(UnaryOperator::Equal, $1, $3);
        $$ = expr;
    }
	| equality_expression NE_OP relational_expression {
		auto *expr = new UnaryExpression(UnaryOperator::NotEqual, $1, $3);
        $$ = expr;
    }
	;

and_expression
	: equality_expression
	| and_expression '&' equality_expression {
        auto *expr = new UnaryExpression(UnaryOperator::BitwiseAnd, $1, $3);
        $$ = expr;
    }
	;

exclusive_or_expression
	: and_expression
	| exclusive_or_expression '^' and_expression {
		auto *expr = new UnaryExpression(UnaryOperator::BitwiseXor, $1, $3);
        $$ = expr;
    }
	;

inclusive_or_expression
	: exclusive_or_expression
	| inclusive_or_expression '|' exclusive_or_expression {
		auto *expr = new UnaryExpression(UnaryOperator::BitwiseOr, $1, $3);
        $$ = expr;
    }
	;

logical_and_expression
	: inclusive_or_expression
	| logical_and_expression AND_OP inclusive_or_expression {
		auto *expr = new UnaryExpression(UnaryOperator::And, $1, $3);
        $$ = expr;
    }
	;

logical_or_expression
	: logical_and_expression
	| logical_or_expression OR_OP logical_and_expression {
		auto *expr = new UnaryExpression(UnaryOperator::Or, $1, $3);
        $$ = expr;
    }
	;

conditional_expression
	: logical_or_expression
	| logical_or_expression '?' expression ':' conditional_expression
	;

assignment_expression
	: conditional_expression {
		Assignment *assign = new Assignment($1);
		$$ = assign;
	}
	| unary_expression assignment_operator assignment_expression {
		auto *var = dynamic_cast<Variable*>($1);
		Assignment *assign = new Assignment(var, $3->expr);
		$$ = assign;
	}
	;

assignment_operator
	: '='
	| MUL_ASSIGN
	| DIV_ASSIGN
	| MOD_ASSIGN
	| ADD_ASSIGN
	| SUB_ASSIGN
	| LEFT_ASSIGN
	| RIGHT_ASSIGN
	| AND_ASSIGN
	| XOR_ASSIGN
	| OR_ASSIGN
	;

expression
	: assignment_expression
	| expression ',' assignment_expression
	;

constant_expression
	: conditional_expression	/* with constraints */
	;

declaration
	: declaration_specifiers ';'
	| declaration_specifiers init_declarator_list ';'
	| static_assert_declaration
	;

declaration_specifiers
	: storage_class_specifier declaration_specifiers
	| storage_class_specifier
	| type_specifier declaration_specifiers
	| type_specifier
	| type_qualifier declaration_specifiers
	| type_qualifier
	| function_specifier declaration_specifiers
	| function_specifier
	| alignment_specifier declaration_specifiers
	| alignment_specifier
	;

init_declarator_list
	: init_declarator
	| init_declarator_list ',' init_declarator
	;

init_declarator
	: declarator '=' initializer
	| declarator
	;

storage_class_specifier
	: TYPEDEF	/* identifiers must be flagged as TYPEDEF_NAME */
	| EXTERN
	| STATIC
	| THREAD_LOCAL
	| AUTO
	| REGISTER
	;

type_specifier
	: VOID { $$ = TypeSpecifier::Void; }
	| CHAR { $$ = TypeSpecifier::Char; }
	| SHORT
	| INT { $$ = TypeSpecifier::Int; }
	| LONG
	| FLOAT
	| DOUBLE
	| SIGNED
	| UNSIGNED
	| BOOL
	| COMPLEX
	| IMAGINARY	  	/* non-mandated extension */
	| atomic_type_specifier
	| struct_or_union_specifier
	| enum_specifier
	| TYPEDEF_NAME		/* after it has been defined as such */
	;

struct_or_union_specifier
	: struct_or_union '{' struct_declaration_list '}'
	| struct_or_union IDENTIFIER '{' struct_declaration_list '}'
	| struct_or_union IDENTIFIER
	;

struct_or_union
	: STRUCT
	| UNION
	;

struct_declaration_list
	: struct_declaration
	| struct_declaration_list struct_declaration
	;

struct_declaration
	: specifier_qualifier_list ';'	/* for anonymous struct/union */
	| specifier_qualifier_list struct_declarator_list ';'
	| static_assert_declaration
	;

specifier_qualifier_list
	: type_specifier specifier_qualifier_list
	| type_specifier
	| type_qualifier specifier_qualifier_list
	| type_qualifier
	;

struct_declarator_list
	: struct_declarator
	| struct_declarator_list ',' struct_declarator
	;

struct_declarator
	: ':' constant_expression
	| declarator ':' constant_expression
	| declarator
	;

enum_specifier
	: ENUM '{' enumerator_list '}'
	| ENUM '{' enumerator_list ',' '}'
	| ENUM IDENTIFIER '{' enumerator_list '}'
	| ENUM IDENTIFIER '{' enumerator_list ',' '}'
	| ENUM IDENTIFIER
	;

enumerator_list
	: enumerator
	| enumerator_list ',' enumerator
	;

enumerator	/* identifiers must be flagged as ENUMERATION_CONSTANT */
	: enumeration_constant '=' constant_expression
	| enumeration_constant
	;

atomic_type_specifier
	: ATOMIC '(' type_name ')'
	;

type_qualifier
	: CONST
	| RESTRICT
	| VOLATILE
	| ATOMIC
	;

function_specifier
	: INLINE
	| NORETURN
	;

alignment_specifier
	: ALIGNAS '(' type_name ')'
	| ALIGNAS '(' constant_expression ')'
	;

declarator
	: pointer direct_declarator
	| direct_declarator
	;

direct_declarator
	: IDENTIFIER {
        auto *sig = new Signature();
        sig->name = *$1;
        $$ = sig;
    }
	| '(' declarator ')'
	| direct_declarator '[' ']'
	| direct_declarator '[' '*' ']'
	| direct_declarator '[' STATIC type_qualifier_list assignment_expression ']'
	| direct_declarator '[' STATIC assignment_expression ']'
	| direct_declarator '[' type_qualifier_list '*' ']'
	| direct_declarator '[' type_qualifier_list STATIC assignment_expression ']'
	| direct_declarator '[' type_qualifier_list assignment_expression ']'
	| direct_declarator '[' type_qualifier_list ']'
	| direct_declarator '[' assignment_expression ']'
	| direct_declarator '(' parameter_type_list ')' {
        $1->arguments = $3;
        $$ = $1;
    }
	| direct_declarator '(' ')'
	| direct_declarator '(' identifier_list ')'
	;

pointer
	: '*' type_qualifier_list pointer
	| '*' type_qualifier_list
	| '*' pointer
	| '*'
	;

type_qualifier_list
	: type_qualifier
	| type_qualifier_list type_qualifier
	;


parameter_type_list
	: parameter_list ',' ELLIPSIS
	| parameter_list
	;

parameter_list
	: parameter_declaration {
        auto *params = new vector<Declaration*>;
        params->push_back($1);
        $$ = params;
    }
	| parameter_list ',' parameter_declaration {
		$1->push_back($3);
		$$ = $1;
	}
	;

parameter_declaration
	: declaration_specifiers declarator {
        auto *decl = new Declaration();
        decl->type = $1;
        decl->name = $2->name;
        $$ = decl;
    }
	| declaration_specifiers abstract_declarator
	| declaration_specifiers
	;

identifier_list
	: IDENTIFIER
	| identifier_list ',' IDENTIFIER
	;

type_name
	: specifier_qualifier_list abstract_declarator
	| specifier_qualifier_list
	;

abstract_declarator
	: pointer direct_abstract_declarator
	| pointer
	| direct_abstract_declarator
	;

direct_abstract_declarator
	: '(' abstract_declarator ')'
	| '[' ']'
	| '[' '*' ']'
	| '[' STATIC type_qualifier_list assignment_expression ']'
	| '[' STATIC assignment_expression ']'
	| '[' type_qualifier_list STATIC assignment_expression ']'
	| '[' type_qualifier_list assignment_expression ']'
	| '[' type_qualifier_list ']'
	| '[' assignment_expression ']'
	| direct_abstract_declarator '[' ']'
	| direct_abstract_declarator '[' '*' ']'
	| direct_abstract_declarator '[' STATIC type_qualifier_list assignment_expression ']'
	| direct_abstract_declarator '[' STATIC assignment_expression ']'
	| direct_abstract_declarator '[' type_qualifier_list assignment_expression ']'
	| direct_abstract_declarator '[' type_qualifier_list STATIC assignment_expression ']'
	| direct_abstract_declarator '[' type_qualifier_list ']'
	| direct_abstract_declarator '[' assignment_expression ']'
	| '(' ')'
	| '(' parameter_type_list ')'
	| direct_abstract_declarator '(' ')'
	| direct_abstract_declarator '(' parameter_type_list ')'
	;

initializer
	: '{' initializer_list '}'
	| '{' initializer_list ',' '}'
	| assignment_expression
	;

initializer_list
	: designation initializer
	| initializer
	| initializer_list ',' designation initializer
	| initializer_list ',' initializer
	;

designation
	: designator_list '='
	;

designator_list
	: designator
	| designator_list designator
	;

designator
	: '[' constant_expression ']'
	| '.' IDENTIFIER
	;

static_assert_declaration
	: STATIC_ASSERT '(' constant_expression ',' STRING_LITERAL ')' ';'
	;

statement
	: labeled_statement
	| compound_statement
	| expression_statement
	| selection_statement
	| iteration_statement
	| jump_statement
	;

labeled_statement
	: IDENTIFIER ':' statement
	| CASE constant_expression ':' statement
	| DEFAULT ':' statement
	;

compound_statement
	: '{' '}' {
		auto *blocks = new vector<BlockItem*>();
		$$ = blocks;
	}
	| '{'  block_item_list '}' { $$ = $2; }
	;

block_item_list
	: block_item {
		auto *blocks = new vector<BlockItem*>();
		blocks->push_back($1);
		$$ = blocks;
	}
	| block_item_list block_item
	;

block_item
	: declaration
	| statement
	;

expression_statement
	: ';'
	| expression ';'
	;

selection_statement
	: IF '(' expression ')' statement ELSE statement
	| IF '(' expression ')' statement
	| SWITCH '(' expression ')' statement
	;

iteration_statement
	: WHILE '(' expression ')' statement
	| DO statement WHILE '(' expression ')' ';'
	| FOR '(' expression_statement expression_statement ')' statement
	| FOR '(' expression_statement expression_statement expression ')' statement
	| FOR '(' declaration expression_statement ')' statement
	| FOR '(' declaration expression_statement expression ')' statement
	;

jump_statement
	: GOTO IDENTIFIER ';'
	| CONTINUE ';'
	| BREAK ';'
	| RETURN ';'
	| RETURN expression ';'
	;

translation_unit
    : external_declaration {
		ast->push_back($1);
	}
    | translation_unit external_declaration {
		ast->push_back($2);
	}
	;

external_declaration
	: function_definition
	| declaration
	;

function_definition
	: declaration_specifiers declarator declaration_list compound_statement
	| declaration_specifiers declarator compound_statement {
        auto *fn = new FunctionDefinition($1, $2->name, $2->arguments, $3);
        $$ = fn;
    }
	;

declaration_list
	: declaration
	| declaration_list declaration
	;

%%
#include <stdio.h>

void yyerror(vector<FunctionDefinition*> *ast, const char *s)
{
    fflush(stdout);
    fprintf(stderr, "*** %s\n", s);
}