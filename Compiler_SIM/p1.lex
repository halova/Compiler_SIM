%{
#include <stdio.h>
#include <math.h>
#include <cstdio>
#include <list>
#include <iostream>
#include <string>
#include <memory>
#include <stdexcept>

#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Type.h"
#include "llvm/IR/IRBuilder.h"

#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/Support/SystemUtils.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/Support/FileSystem.h"

using namespace std;
using namespace llvm;

#include "p1.y.hpp"

%}

%option debug

%%

[\t \n]         //ignore

return       { return RETURN; }
det          { return DET; }
transpose    { return TRANSPOSE; }
invert       { return INVERT; }
matrix       { return MATRIX; }
reduce       { return REDUCE; }
x            { return X; }

[a-zA-Z_][a-zA-Z_0-9]*    {    yylval.ID_name = strdup(yytext);
                                    return ID; }

[0-9]+                    { yylval.int_numb = atoi(yytext) ; return INT; }

[0-9]+"."[0-9]*           { yylval.numb = atof(yytext); return FLOAT; }

"["           { return LBRACKET; }
"]"           { return RBRACKET; }
"{"           { return LBRACE; }
"}"           { return RBRACE; }
"("           { return LPAREN; }
")"           { return RPAREN; }

"="           { return ASSIGN; }
"*"           { return MUL; }
"/"           { return DIV; }
"+"           { return PLUS; }
"-"           { return MINUS; }

","           { return COMMA; }
";"           { return SEMI; }

"//".*\n      { }

.             { printf("Syntax Error \n"); return ERROR; }
%%

int yywrap()
{
  return 1;
}
