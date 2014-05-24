digit [0-9]
letter [A-Z_a-z]
integer {digit}+
integer_ [0-9_xz]+
real {integer}"."{integer}
busint ([-+]?{integer}"'"[bdh])?{integer_}
%{
#include <cstdlib>
#include <string>
#include "y.tab.h"
#include "ResWordMap.h"
#include "IdTable.h"
void yyerror(const char*);
extern ReservedWordMap reservedWordMap;
extern IdTable idTable;
using namespace std;
%}
%x LINE_COMMENT
%x BLOCK_COMMENT
%x PREPROCESS
%%
[-()<>=+*/;{}.,:&$#~!%@?] return (yylval.value = yytext[0]);
"[" return (yylval.value = yytext[0]);     // �÷�б�ߺ�˫���Ŷ�����
"]" return (yylval.value = yytext[0]);
"^" return (yylval.value = yytext[0]);
"^~" return (yylval.value = NXOR);
"~&" return (yylval.value = NAND);
"~|" return (yylval.value = NOR);
"|" return (yylval.value = yytext[0]);
"||" return (yylval.value = OR);
"&&" return (yylval.value = AND);
"<<" return (yylval.value = SL);
">>" return (yylval.value = SR);
">=" return (yylval.value = GE);
"<=" {return (yylval.value = LE);}
"==" return (yylval.value = EQ);
"!=" return (yylval.value = NE);
"===" return (yylval.value = ZEQ);
"!==" return (yylval.value = ZNE);

"/*" BEGIN BLOCK_COMMENT;
<BLOCK_COMMENT>"*/" BEGIN 0;
<BLOCK_COMMENT>. ;

"//"  BEGIN LINE_COMMENT;
<LINE_COMMENT>\n BEGIN 0;
<LINE_COMMENT>. ;

"`include" BEGIN PREPROCESS;        //��Ԥ�������ֱ�ӹ��˵�
<PREPROCESS>\n BEGIN 0;
<PREPROCESS>. ;
"`timescale" BEGIN PREPROCESS;        //��Ԥ�������ֱ�ӹ��˵�

{integer}			{yylval.str = new string(yytext, yyleng); return INTEGER;}
{busint}          {yylval.str = new string(yytext, yyleng); return BUSINT; }
{real} 			{yylval.str = new string(yytext, yyleng); return REAL; }

[$`]?{letter}({letter}|{digit})* {       // һ��Ҫ���������ʽ��ͬһ��д���, ����дһ��������.
    int i;
    if((i=reservedWordMap.lookUpReservedWord(yytext)) !=-1)
        return i;
    else if(yytext[0] == '$')
    {
        yylval.str = new string(yytext+1, yyleng-1);
        return SYS_CALL;
    }
    else if(yytext[0] == '`')
    {
        yylval.str = new string(yytext+1, yyleng-1);
        return DEFINED;
    }
    else
    {
        yylval.value= idTable.symLookup(yytext);
        return ID;
    }
}

[ \t\n]+ ;

.  cout<<"\n\n\n\n�ַ�"<<yytext<<" û�б�ʶ��!!\n\n\n\n";
%%

int yywrap(void)
{
    return 1;
}