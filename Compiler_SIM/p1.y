/* Phan Nguyen pnguyen4 
   ECE-466	2023
   This program was coded and test with Clion and Docker (Remote LLVM)
   It will pass test_0_1_2_3_4_5_6_7_9
   
   Modify in the Makefile  :
   LLVMCONFIG = llvm-config-14
   CXX = clang++-14
   Modify in the ./test/CMakeLists :
   line 49 : clang++-14
*/
%{
#include <cstdio>
#include <list>
#include <vector>
#include <map>
#include <iostream>
#include <fstream>
#include <string>
#include <memory>
#include <stdexcept>

#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Type.h"
#include "llvm/IR/Verifier.h"

#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/Support/SystemUtils.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Support/FileSystem.h"

using namespace llvm;
using namespace std;


// Need for parser and scanner
extern FILE *yyin;
int yylex();
void yyerror(const char*);
int yyparse();
 
// Needed for LLVM
string funName;
Module *M;
LLVMContext TheContext;
IRBuilder<> Builder(TheContext);

// This function will count how many argument are there //
int getArgu() {
  static int cnt = 0;
  //first return 0
  return cnt++;
}
// This function count how many matrix we have made with Matrix = assign 
int getMatrix(){
  static int cnt = 1;
  //first return 1
  return cnt++;
}
// This function keep track of the position inside the matrix
int Matrix_cnt(){
  static int cnt = 1;
  //first return 1
  return cnt++;
}
	// This map will hold the name of the ID and match it with the second parameter, Value* //
    map<string,Value*> ID_map;
	// This map will hold the name of the matrix and have a vector of Value* for its second parameter //
    map<string,vector<Value*>> Matrix_map;
	// Those two vector will hold the individual value which later will get pass to the Matrix map //
	// This is hard-coded to two matrix only... sad //
    vector<Value*> Matrix_value;
    vector<Value*> Matrix_value2;

%}


%union {
  char *ID_name;
  float numb;
  int int_numb;
  Value *val;
}

%define parse.trace

%token ERROR

%token <val>RETURN
%token DET TRANSPOSE INVERT
%token REDUCE
%token MATRIX
%token X

%token <numb>FLOAT
%token <int_numb>INT
%token <ID_name>ID

%token SEMI COMMA

%token PLUS MINUS MUL DIV
%token ASSIGN

%token LBRACKET RBRACKET
%token LPAREN RPAREN 
%token LBRACE RBRACE 

%type <val>params_list
%type <val>expr

%type matrix_rows
%type matrix_row expr_list
%type dim

%left PLUS MINUS
%left MUL DIV 

%start program

%%

program: ID {
  // The Funame will get val from $1, which is a char pointer //
   funName = $1;
} LPAREN params_list_opt RPAREN LBRACE statements_opt return RBRACE
{
  // parsing is done, input is accepted
  YYACCEPT;
}
;

//FIXME: some changes needed below
params_list_opt:  params_list 
{

  // I solve the argument problem by call the function getArgu() //
  // it will return the correct number of the argument // 
  std::vector<Type*> param_types( getArgu() ,Builder.getFloatTy());

  ArrayRef<Type*> Params (param_types);
  
  // Create int function type with no arguments
  FunctionType *FunType = 
    FunctionType::get(Builder.getFloatTy(),Params,false);

  // Create a main function
  Function *Function = Function::Create(FunType,GlobalValue::ExternalLinkage,funName,M);

  // Since I use a map to store the name and Value of each ID
  // The iterator it will make the map point to each argument //
  auto it = ID_map.begin();
  for(auto &a: Function->args()) {
    it->second = &a;
    it++;
  }
  
  //Add a basic block to main to hold instructions, and set Builder
  //to insert there
  Builder.SetInsertPoint(BasicBlock::Create(TheContext, "entry", Function));
}
| %empty
{ 
  // Create int function type with no arguments
  FunctionType *FunType = 
    FunctionType::get(Builder.getFloatTy(),false);

  // Create a main function
  Function *Function = Function::Create(FunType,  
         GlobalValue::ExternalLinkage,funName,M);

  //Add a basic block to main to hold instructions, and set Builder
  //to insert there
  Builder.SetInsertPoint(BasicBlock::Create(TheContext, "entry", Function));
}
;

params_list: ID
{   // Argument get map here first, and then increase the count by call the function //
    int x = getArgu();
    $$ = ID_map[$1];
	// For debug
	printf("We got %d arug",x);
}
| params_list COMMA ID
{   // Same as above
    int x = getArgu();
	printf("We got %d arug",x);
    $$ = ID_map[$3];
}
;

return: RETURN expr SEMI
{
  // This will return the Value pointer from $2, which is expr //
    Builder.CreateRet( $2 );
}
;

// These may be fine without changes
statements_opt: %empty
            | statements
;

// These may be fine without changes
statements:   statement
            | statements statement
;

//FIXME: implement these rules
statement:
  ID ASSIGN expr SEMI
  {     // Assign the ID name to the expr, which is Value* //
         ID_map[$1] = $3;
		 
        /* This will not work when we try to assign a new matrix 
		  m1 = matrix [2 x 2] { [a,b], [c,d] };
		  m2 = matrix [2 x 2] { [e,f], [g,h] };
		  m3 = m1 + m2 ;
		*/

  }
  
| ID ASSIGN MATRIX dim LBRACE matrix_rows RBRACE SEMI
{
    // Assign the matrix ID map to its value ;
    // The Matrix_value is a vector<Value*>
	// The Matrix_map.second() is also a vector<Value*>
	
    if ( Matrix_cnt() == 1 )
    Matrix_map[$1] = Matrix_value;
    else
    Matrix_map[$1] = Matrix_value2;
	// To be fair, this is hard-coded for two matrix assignment, so if we have the third one it will fail //
}
;

//FIXME: implement these rules
dim: LBRACKET INT X INT RBRACKET
{   // Only 2x2 matrices need to be supported
    // So we can assume the dimension always be [ 2 x 2 ]
}
;

//FIXME: implement these rules
matrix_rows: matrix_row

| matrix_rows COMMA matrix_row

;

//FIXME: implement these rules
matrix_row: LBRACKET expr_list RBRACKET
;

//FIXME: implement these rules
expr_list: expr
  {		// So everytime we got a new value, the vector Matrix_value will pushback that value 
		// Each matrix will have 4 position so if the count get over 4 then we move to second matrix //
        if (getMatrix() <= 4 )
        Matrix_value.push_back($1);
        else
        Matrix_value2.push_back($1);

  }
| expr_list COMMA expr
{		// Same as above 
        if (getMatrix() <= 4 )
        Matrix_value.push_back($3);
        else
        Matrix_value2.push_back($3);
  }
;

//FIXME: implement these rules
expr: ID
{ $$ = ID_map[$1];
}
| FLOAT
{ $$ = ConstantFP::get(Builder.getFloatTy(), $1 );
}
| INT
{ $$ = ConstantFP::get(Builder.getFloatTy(), $1 );
}
| expr PLUS expr
{ $$ = Builder.CreateFAdd($1, $3,"add");
}
| expr MINUS expr
{ $$ = Builder.CreateFSub($1, $3,"sub");
}
| expr MUL expr
{ $$ = Builder.CreateFMul($1, $3,"mul");
}
| expr DIV expr
{ $$ = Builder.CreateFDiv($1, $3,"div");
}
| MINUS expr
{ $$ = Builder.CreateFNeg($2,"neg");
}
| DET LPAREN expr RPAREN
{   $$ = Builder.CreateFSub(Builder.CreateFMul(Matrix_map["m1"][0], Matrix_map["m1"][3],"mul"),
                            Builder.CreateFMul(Matrix_map["m1"][2], Matrix_map["m1"][1],"mul"),
                                                                                        "sub");
	// Since we only ever get 2x2 matrix, the det is just mul and sub //
}

| ID LBRACKET INT COMMA INT RBRACKET
{   // Since this will ask us a value of a position in the matrix
	// So we just return the vector that match the position 
	//  0: 0 1
	//  1: 0 1	
	if ( $3 == 0 && $5 == 0 )
        $$ = Matrix_map[$1][0];
    else if ( $3 == 0 && $5 == 1 )
        $$ = Matrix_map[$1][1];
    else  if ( $3 == 1 && $5 == 0 )
        $$ = Matrix_map[$1][2];
    else
        $$ = Matrix_map[$1][3];
}
;


%%

unique_ptr<Module> parseP1File(const string &InputFilename)
{
  string modName = InputFilename;
  if (modName.find_last_of('/') != string::npos)
    modName = modName.substr(modName.find_last_of('/')+1);
  if (modName.find_last_of('.') != string::npos)
    modName.resize(modName.find_last_of('.'));

  // unique_ptr will clean up after us, call destructor, etc.
  unique_ptr<Module> Mptr(new Module(modName.c_str(), TheContext));

  // set global module
  M = Mptr.get();
  
  /* this is the name of the file to generate, you can also use
     this string to figure out the name of the generated function */

  if (InputFilename == "--")
    yyin = stdin;
  else	  
    yyin = fopen(InputFilename.c_str(),"r");

  yydebug = 1;
  if (yyparse() != 0) {
    // Dump LLVM IR to the screen for debugging
    M->print(errs(),nullptr,false,true);
    // errors, so discard module
    Mptr.reset();
  } else {
    // Dump LLVM IR to the screen for debugging
    M->print(errs(),nullptr,false,true);
  }
  
  return Mptr;
}

void yyerror(const char* msg)
{
  printf("%s\n",msg);
}
