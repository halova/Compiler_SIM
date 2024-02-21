#include <fstream>
#include <memory>
#include <algorithm>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "llvm-c/Core.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Verifier.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/LinkAllPasses.h"
#include "llvm/Support/ManagedStatic.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Analysis/InstructionSimplify.h"

using namespace llvm;
using namespace std;
static void CommonSubexpressionElimination(Module *M);
static void summarize(Module *M);
static void print_csv_file(std::string outputfile);

static cl::opt<std::string>
        InputFilename(cl::Positional, cl::desc("<input bitcode>"), cl::Required, cl::init("-"));

static cl::opt<std::string>
        OutputFilename(cl::Positional, cl::desc("<output bitcode>"), cl::Required, cl::init("out.bc"));

static cl::opt<bool>
        Mem2Reg("mem2reg",
                cl::desc("Perform memory to register promotion before CSE."),
                cl::init(false));

static cl::opt<bool>
        NoCSE("no-cse",
              cl::desc("Do not perform CSE Optimization."),
              cl::init(false));

static cl::opt<bool>
        Verbose("verbose",
                    cl::desc("Verbose stats."),
                    cl::init(false));

static cl::opt<bool>
        NoCheck("no",
                cl::desc("Do not check for valid IR."),
                cl::init(false));

int main(int argc, char **argv) {
    // Parse command line arguments
    cl::ParseCommandLineOptions(argc, argv, "llvm system compiler\n");

    // Handle creating output files and shutting down properly
    llvm_shutdown_obj Y;  // Call llvm_shutdown() on exit.
    LLVMContext Context;

    // LLVM idiom for constructing output file.
    std::unique_ptr<ToolOutputFile> Out;
    std::string ErrorInfo;
    std::error_code EC;
    Out.reset(new ToolOutputFile(OutputFilename.c_str(), EC,
                                 sys::fs::OF_None));

    EnableStatistics();

    // Read in module
    SMDiagnostic Err;
    std::unique_ptr<Module> M;
    M = parseIRFile(InputFilename, Err, Context);

    // If errors, fail
    if (M.get() == 0)
    {
        Err.print(argv[0], errs());
        return 1;
    }

    // If requested, do some early optimizations
    if (Mem2Reg)
    {
        legacy::PassManager Passes;
        Passes.add(createPromoteMemoryToRegisterPass());
        Passes.run(*M.get());
    }

    if (!NoCSE) {
        CommonSubexpressionElimination(M.get());
    }

    // Collect statistics on Module
    summarize(M.get());
    print_csv_file(OutputFilename);

    if (Verbose)
        PrintStatistics(errs());

    // Verify integrity of Module, do this by default
    if (!NoCheck)
    {
        legacy::PassManager Passes;
        Passes.add(createVerifierPass());
        Passes.run(*M.get());
    }

    // Write final bitcode
    WriteBitcodeToFile(*M.get(), Out->os());
    Out->keep();

    return 0;
}

static llvm::Statistic nFunctions = {"", "Functions", "number of functions"};
static llvm::Statistic nInstructions = {"", "Instructions", "number of instructions"};
static llvm::Statistic nLoads = {"", "Loads", "number of loads"};
static llvm::Statistic nStores = {"", "Stores", "number of stores"};

static void summarize(Module *M) {
    for (auto i = M->begin(); i != M->end(); i++) {
        if (i->begin() != i->end()) {
            nFunctions++;
        }
        for (auto j = i->begin(); j != i->end(); j++) {
            for (auto k = j->begin(); k != j->end(); k++) {
                Instruction &I = *k;
                nInstructions++;
                if (isa<LoadInst>(&I)) {
                    nLoads++;
                } else if (isa<StoreInst>(&I)) {
                    nStores++;
                }
            }
        }
    }
}

static void print_csv_file(std::string outputfile)
{
    std::ofstream stats(outputfile + ".stats");
    auto a = GetStatistics();
    for (auto p : a) {
        stats << p.first.str() << "," << p.second << std::endl;
    }
    stats.close();
}

static llvm::Statistic CSEDead = {"", "CSEDead", "CSE found dead instructions"};
static llvm::Statistic CSEElim = {"", "CSEElim", "CSE redundant instructions"};
static llvm::Statistic CSESimplify = {"", "CSESimplify", "CSE simplified instructions"};
// As 466 I dont use those //
//static llvm::Statistic CSELdElim = {"", "CSELdElim", "CSE redundant loads"};
//static llvm::Statistic CSEStore2Load = {"", "CSEStore2Load", "CSE forwarded store to load"};
//static llvm::Statistic CSEStElim = {"", "CSEStElim", "CSE redundant stores"};
//static llvm::Statistic WorkList = {"", "WorkList", "Added to work list"};

// This function is the same as the one we did in tutorials 3 //

bool isDead(Instruction &I) {
    int opcode = I.getOpcode();
    switch(opcode) {
        case Instruction::Add:
        case Instruction::FNeg:
        case Instruction::FAdd:
        case Instruction::Sub:
        case Instruction::FSub:
        case Instruction::Mul:
        case Instruction::FMul:
        case Instruction::UDiv:
        case Instruction::SDiv:
        case Instruction::FDiv:
        case Instruction::URem:
        case Instruction::SRem:
        case Instruction::FRem:
        case Instruction::Shl:
        case Instruction::LShr:
        case Instruction::AShr:
        case Instruction::And:
        case Instruction::Or:
        case Instruction::Xor:
        case Instruction::Alloca:
        case Instruction::GetElementPtr:
        case Instruction::Trunc:
        case Instruction::ZExt:
        case Instruction::SExt:
        case Instruction::FPToUI:
        case Instruction::FPToSI:
        case Instruction::UIToFP:
        case Instruction::SIToFP:
        case Instruction::FPTrunc:
        case Instruction::FPExt:
        case Instruction::PtrToInt:
        case Instruction::IntToPtr:
        case Instruction::BitCast:
        case Instruction::AddrSpaceCast:
        case Instruction::ICmp:
        case Instruction::FCmp:
        case Instruction::PHI:
        case Instruction::Select:
        case Instruction::ExtractElement:
        case Instruction::InsertElement:
        case Instruction::ShuffleVector:
        case Instruction::ExtractValue:
        case Instruction::InsertValue:
        {
            if (I.use_begin() == I.use_end()) {
                return true;
            }
            break;
        }
        case Instruction::Load:
        {
            LoadInst *li = dyn_cast<LoadInst>(&I);
            if (li && li->isVolatile())
                return false;
            if (I.use_begin() == I.use_end())
                return true;
            break;

        }
        default:
            // any other opcode fails
            return false;
    }
    return false;
}
// Same function as above to check if we can perform CSE on the Inst //
bool canCSE(Instruction &I) {
    int opcode = I.getOpcode();
    switch(opcode) {
        case Instruction::Add:
        case Instruction::FNeg:
        case Instruction::FAdd:
        case Instruction::Sub:
        case Instruction::FSub:
        case Instruction::Mul:
        case Instruction::FMul:
        case Instruction::UDiv:
        case Instruction::SDiv:
        case Instruction::FDiv:
        case Instruction::URem:
        case Instruction::SRem:
        case Instruction::FRem:
        case Instruction::Shl:
        case Instruction::LShr:
        case Instruction::AShr:
        case Instruction::And:
        case Instruction::Or:
        case Instruction::Xor:
        case Instruction::ZExt:
        case Instruction::SExt:
        case Instruction::FPToUI:
        case Instruction::FPToSI:
        case Instruction::UIToFP:
        case Instruction::SIToFP:
        case Instruction::FPTrunc:
        case Instruction::FPExt:
            return true;
        default:
            // any other opcode fails
            return false;
    }

}

static void CommonSubexpressionElimination(Module *M) {
    // Implement this function
    for(auto f = M->begin(); f!=M->end(); f++)
    {
        // loop over functions
        for(auto bb= f->begin(); bb!=f->end(); bb++)
        {
            // loop over basic blocks
            // Create an iterator to loop over all instruction
            // Has to use while since we can destroy the iterator while doing for loop and it causes seg fault
            auto i = bb->begin();
            while( i != bb->end())
            {
                //loop over instructions and find the dead ones
                if (isDead(*i)) {
                    // Check if is dead Ins and remove the instruction
                    Instruction *j = &*i;
                    CSEDead++;
                    // remove j from the basic block
                    // j->eraseFromParent() return a pointer point to next instruction, so we can let i = that
                    i = j->eraseFromParent();
                }
                // If not dead then check if we can use GVN to opt the Inst
                else if ( SimplifyInstruction(&*i,M->getDataLayout()) != nullptr){
                    Value *val = SimplifyInstruction(&*i,M->getDataLayout());
                    i->replaceAllUsesWith(val);
                    Instruction *j = &*i;
                    CSESimplify++;
                    // remove j from the basic block
                    // this also return a pointer point to next instruction so we can let i = that //
                    i = j->eraseFromParent();
                }
                else if (canCSE(*i)){
                    // Check is the opcode is OK to use CSE on it
                    auto j = i;
                    j++;
                    // We then take the i as parent Inst and go over all other Inst in that Basic block
                    // Since all Inst after i is dominance by i //
                    while( j != bb->end()) {
                        // Check if it's the same type, same opcode and same numb of operands
                        if (i->getType() == j->getType() && i->getOpcode() == j->getOpcode() &&
                            i->getNumOperands() == j->getNumOperands()) {
                            CSEElim++;
                            Instruction *k = &*j;
                            auto *val1 = dyn_cast<Value>(&*i);
                            j->replaceAllUsesWith(val1);
                            // Erase it and let j point to next Inst //
                            j = k->eraseFromParent();
                        }
                        // If can't CSE just go to the next Inst
                        j++;
                    }
                    i++;
                }
                else
                    i++;

            }
        }
    }
}

