%{
#include <cstdio>
#include <cstdlib>
#include <string>
#include "y.tab.h"
#include "ResWordMap.h"
#include "IdTable.h"
//#include "node.h"

using namespace std;

ReservedWordMap reservedWordMap;
IdTable idTable;

//NBlock* programBlock; /* the top level root node of our final AST */

extern int yylex();
void yyerror(const char* s)
{
	printf("Error: %s\n", s);
	exit(1);
}
%}

/* Represents the many different ways we can access our data */
%union {
//	Node* node;
//	NBlock* block;
//	NExpression* expression;
//	NStatement* statement;
//	NIdentifier* identifier;
//	NVariableDeclaration* variable_declaration;
//	std::vector<NVariableDeclaration*> *variable_vector;
//	std::vector<NExpression*> *expression_vector;
	std::string* str;
	int value;
};

%token <str> ID INTEGER BUSINT REAL SYS_CALL DEFINED
%token <value> SL SR OR AND GE LE EQ NE ZEQ ZNE NXOR NAND NOR

%token <value> RES_INPUT
%token <value> RES_OUTPUT
%token <value> RES_INOUT
%token <value> RES_ALWAYS
%token <value> RES_OR
%token <value> RES_INITIAL
%token <value> RES_IF
%token <value> RES_ELSE
%token <value> RES_CASE
%token <value> RES_CASEX
%token <value> RES_CASEZ
%token <value> RES_FOR
%token <value> RES_BEGIN
%token <value> RES_END
%token <value> RES_FORK
%token <value> RES_JOIN
%token <value> RES_WIRE
%token <value> RES_ASSIGN
%token <value> RES_REG
%token <value> RES_INTEGER
%token <value> RES_MODULE
%token <value> RES_FUNCTION
%token <value> RES_TASK
%token <value> RES_PARAMETER
%token <value> RES_DEFAULT
%token <value> RES_ENDCASE
%token <value> RES_ENDMODULE
%token <value> RES_ENDFUNCTION
%token <value> RES_ENDTASK
%token <value> RES_NEGEDGE
%token <value> RES_POSEDGE
%token <value> RES_INCLUDE_
%token <value> RES_DEFINE_

%nonassoc IFX
%nonassoc RES_ELSE
%nonassoc '=' ASSIGN
%right CONDITIONAL
%left OR
%left AND
%left '|' NOR
%left '^' NXOR
%left '&' NAND
%left EQ NE ZEQ ZNE
%left GE LE '>' '<'
%nonassoc SL SR
%left '+' '-'
%left '*' '/' '%'
%nonassoc '!' '~' UNARY
%start program

// 格式: %type <union的某个成员> 某个非终结符
//%type <ident> ident
//%type <expr> numeric expr
//%type <varvec> func_decl_args
//%type <exprvec> call_args
//%type <block> program stmts block
//%type <stmt> stmt var_decl func_decl
//%type <value> comparison

%%
program:
preprocess module_dec { exit(0);}       //暂时先简化成这个模型, 假设module里边没有预处理语句. 毕竟要保留预处理语句进行整理代码还是非常困难的.
;

preprocess:
RES_INCLUDE_ "\""       {}      // TO-DO 没写完, 在verilog.l放弃过滤预处理语句之前, 永远不会搜索到这个节点. 如果真的要支持, 应该在l文件里识别字符串.
|RES_DEFINE_ ID expression  {}
|
;

module_dec:
RES_MODULE ID '(' port_list ')' ';' module_body RES_ENDMODULE  {}
;

port_list:
directioned_port_list     {}
|undirectioned_port_list  {}
|               {}
;

undirectioned_port_list:
ID      {}
|undirectioned_port_list ',' ID   {}
;

directioned_port_list:
directioned_port                       {}
|directioned_port_list ',' directioned_port {}
;

directioned_port:
port_direction port_width ID   {}
;

port_dec_block:
port_dec_block directioned_port ';'    {}
|           {}
;

port_direction:
RES_INPUT       {}
|RES_INOUT      {}
|RES_OUTPUT      {}
;

port_width:
'[' expression ':' expression ']' {}
|                           {}
;

module_body:
module_body parameter_dec       {}
|module_body port_dec           {}
|module_body variable_dec       {}
|module_body wire_dec           {}
|module_body reg_dec            {}
|module_body instance           {}
|module_body fun_dec            {}
|module_body task_dec           {}
|module_body assign_stmt        {}
|module_body always_block       {}
|                               {}
;

port_dec:
directioned_port ';'        {}
;

wire_dec:
RES_WIRE port_width signal_list ';'   {}
;

//wire_dec_block:
//wire_dec                {}
//|wire_dec_block wire_dec     {}
//;

reg_dec:
RES_REG port_width ID port_width ';'    {}
|RES_REG port_width signal_list ';'       {}
;

//reg_dec_block:
//reg_dec             {}
//|reg_dec_block reg_dec   {}
//;

signal_list:
ID                      {}
| signal_list ',' ID    {}
;

parameter_dec:
RES_PARAMETER ID '=' bus_int ';'        {}
;

//parameter_dec_block:
//parameter_dec_block parameter_dec   {}
//|parameter_dec                      {}
//;

bus_int:
BUSINT    {}
| INTEGER                    {}
;

assign_stmt:
RES_ASSIGN ID '=' expression ';'     {}
;

//assign_stmt_block:
//assign_stmt_block assign_stmt   {}
//|assign_stmt                    {}
//;

always_block:
RES_ALWAYS trigger_list reg_assign_stmt    {}
;

wait:
'#' INTEGER     {}
|
;

trigger_list:
'@''(' trigger_list_ ')'  {}
|wait                   {}
;

trigger_list_:
combinatory_trigger_list   {}
|sequential_trigger_list    {}
;

combinatory_trigger_list:
'*'                         {}
|combinatory_trigger_list_    {}
;

combinatory_trigger_list_:
combinatory_trigger                         {}
combinatory_trigger_list_ or combinatory_trigger    {}
;

or:
RES_OR      {}
| ','        {}
;

combinatory_trigger:
ID                  {}
;

sequential_trigger_list:
sequential_trigger                                   {}
|sequential_trigger_list or sequential_trigger      {}
;

sequential_trigger:
edge ID                     {}
;

edge:
RES_POSEDGE         {}
|RES_NEGEDGE         {}
;

reg_assign_stmt:
RES_BEGIN reg_assign_stmt_list RES_END  {}
|RES_FORK reg_assign_stmt_list RES_JOIN {}
|case_stmt          {}
|if_stmt            {}
|for_stmt           {}
|reg_assign              {}      //为了和assign语句区分, 并且突出reg信号才可以在always块里赋值的特点
;

reg_assign_stmt_list:
reg_assign_stmt        {}
|reg_assign_stmt_list reg_assign_stmt {}
;

reg_assign:
wait lval assign_op wait expression ';'        {}
;

lval:
lval_       {}
|'{' lval_list '}'       {}
;

lval_list:
lval_list ',' lval_     {}
|lval_                  {}
;

lval_:
ID '[' expression ']'    {}
|ID port_width        {}
;

assign_op:
'='         {}
|LE         {}
;

case_stmt:
case_type '(' expression ')' branch_list RES_ENDCASE  {}
;

case_type:
RES_CASE    {}
|RES_CASEX   {}
|RES_CASEZ  {}
;

branch_list:
branch_list_entry   {}
|branch_list branch_list_entry  {}
;

branch_list_entry:
branch_lable ':' reg_assign_stmt   {cout<<"entry\n\n"}
;

branch_lable:
branch_lable_                   {}
|branch_lable ',' branch_lable_ {}
;

branch_lable_:
parameter            {}      // 虽然就是ID, 但是可以在语义部分增加检测
|DEFINED          {}      // 为了字处理而编写的编译器就是尴尬, 其实不会有id这一项的, 只是为了允许parameter
|bus_int         {}
|RES_DEFAULT     {}
;

parameter:
ID      {}
;

if_stmt:
RES_IF '(' expression ')' reg_assign_stmt %prec IFX     {}
|RES_IF '(' expression ')' reg_assign_stmt RES_ELSE reg_assign_stmt {}
;

expression:
expression_             {}
|'{' expression_list '}'  {}
|'{'INTEGER'{'expression '}''}'   {}
;

expression_list:
expression_list ',' expression {}
|expression            {}
;

expression_:
bus_int     {}
|DEFINED    {}
|fun_call   {}
|unary expression %prec UNARY    {}
|expression binary expression    {}
|'(' expression ')'             {}
|lval       {}
|condition      {}
|
;

condition:
expression '?' expression ':' expression  %prec CONDITIONAL      {}
;

unary:
'+'
|'-'
|'!'
|'~'
|'|'
;

binary:
'+'     {}
|'-'    {}
|'*'    {}
|'/'    {}
|'%'    {}
|SL     {}
|SR     {}
|OR     {}
|AND    {}
|'|'    {}
|NOR    {}
|'^'    {}
|NXOR   {}
|'&'    {}
|NAND   {}
|EQ     {}
|NE     {}
|ZEQ    {}
|ZNE    {}
|GE     {}
|LE     {}
|'>'    {}
|'<'    {}
;

fun_dec:
RES_FUNCTION port_width ID ';' port_and_reg_dec_block reg_assign_stmt RES_ENDFUNCTION  {}
;

port_and_reg_dec_block:
port_and_reg_dec_block port_dec       {}
|port_and_reg_dec_block reg_dec         {}
|port_dec                               {}
|reg_dec                                  {}
;

instance:
ID ID '(' connect_list ')'';'  {}
;

connect_list:
connect_entry  {}
|connect_list ',' connect_entry   {}
;

connect_entry:
'.' ID '(' expression ')'    {}
;

variable_dec:
variable_type ID ';'    {}
;

variable_type:
RES_INTEGER         {}
;

for_assign:     // for语句的语法规范比较粗糙. 毕竟只是语法分析阶段. 语义分析才能更好地解决这个.
ID '=' INTEGER   {}
|
;

for_condition:
expression   {}
;

for_acc:
ID '=' expression       {}
;

for_stmt:
RES_FOR '(' for_assign ';' for_condition ';' for_acc ')' reg_assign_stmt       {}
;

task_dec:
;

fun_call:
fun_name '(' expression_list ')'   {}
;

fun_name:
ID      {}
|SYS_CALL       {}
;

%%

int main(void)
{
	yyparse();
	return 0;
}
