//===-------- RISCVMIPeephole.cpp - RISCV MI Peephole optimization --------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains a pass that performs the merging of two eligible LW/SW 
// instructions in a ZILSD_LD/ZILSD_SD instuction under the presence of 
// the ZILSD extension. This pass is run before register allocation.
//
//===----------------------------------------------------------------------===//
/*
 * Copyright 2024 NXP
 */


#include "RISCV.h"
#include "RISCVTargetMachine.h"
#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/Support/Debug.h"
#include "llvm/ADT/SmallSet.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-mi-peephole"

static cl::opt<bool> RISCVZilsdMerge(
    "riscv-merge-lwsw-to-ldsd", cl::Hidden, cl::init(true),
    cl::desc("Merge eligible two 32bit lw-sw instructions to 64bit ld-sd"));

namespace {

struct RISCVMIPeephole : public MachineFunctionPass {
  const RISCVSubtarget *ST;
  const RISCVInstrInfo *TII;
  MachineRegisterInfo *MRI;
  AliasAnalysis *AA;
  MachineFrameInfo *MFI;

  static char ID;
  RISCVMIPeephole() : MachineFunctionPass(ID) {
    initializeRISCVMIPeepholePass(*PassRegistry::getPassRegistry());
  }

public:
  StringRef getPassName() const override {
    return "RISCV MI Peephole Optimization - ZILSD";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<AAResultsWrapperPass>();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  bool runOnMachineFunction(MachineFunction &MF) override;
  bool CombineLDSTtoPair(MachineBasicBlock::iterator &MBBI);
  bool ChangeZdinxLDSDtoPair(MachineBasicBlock::iterator &MBBI);
};

// Merge two 32bit load or store into 64bit load or store.
// Return true on success. This is available only on ZILSD extension.
bool RISCVMIPeephole::CombineLDSTtoPair(MachineBasicBlock::iterator &MBBI) {
  MachineBasicBlock::iterator NextI = MBBI;

  MachineInstr &MI = *MBBI;

  if ((!MI.getOperand(2).isImm() && !MI.getOperand(2).isGlobal()) ||
      (!MI.getOperand(1).isReg() && 
      !MI.getOperand(1).isFI()))
    return false;

  bool IsStore = (MI.getOpcode() == RISCV::SW);
  bool IsReg = MI.getOperand(1).isReg();
  int Base = IsReg ? (int) MI.getOperand(1).getReg() : 
                           MI.getOperand(1).getIndex();
  bool IsImm = MI.getOperand(2).isImm();

  int OffsetMI = IsImm ? MI.getOperand(2).getImm() : MI.getOperand(2).getOffset();

  const GlobalValue *GV = !IsImm ? MI.getOperand(2).getGlobal() : nullptr;
  const int TF = !IsImm ? MI.getOperand(2).getTargetFlags() : -1;

  int OffsetLo, OffsetHi;
  SmallSet<MachineInstr *, 10> PossibleInterferences = {};
  MachineInstr *LoInst = nullptr, *HiInst = nullptr;
  bool LocalVariables = false;

  // Get the next valid instruction.
  do {
    NextI++;

    if (NextI == MBBI->getParent()->end() || NextI->isBarrier() || NextI->isCall())
      break;

    if (NextI->isMetaInstruction())
      continue;

    if (NextI->isBarrier() || NextI->isCall())
      break;

    if (!IsStore) {
      if (NextI->getOpcode() != RISCV::LW) {
        // For a store between two loads, we need to check that there is no interference.
        if (NextI->mayStore()) 
            PossibleInterferences.insert(&*NextI);
        continue;
      }
    } else {
      if (NextI->getOpcode() != RISCV::SW) {
        // For a load between two stores, we need to check that there is no
        // interference.
        if (NextI->mayLoad())
            PossibleInterferences.insert(&*NextI);
        continue;
      }
    }

    // Some times we can have two consecutive un-related instructions.
    // We are looking only at those with the same format.
    if ((IsImm && !NextI->getOperand(2).isImm()) ||
        (!IsImm && !NextI->getOperand(2).isGlobal()) ||
        (IsReg && !NextI->getOperand(1).isReg()) ||
        (!IsReg && !NextI->getOperand(1).isFI()))
      continue;

    // Make sure that the instructions are related (for global variables).
    if (IsReg && Base != NextI->getOperand(1).getReg())
      continue;

    // Also for local variables (same pointer base or neighbouring locations).
    if (!IsReg && 
        Base != NextI->getOperand(1).getIndex() &&
        Base != NextI->getOperand(1).getIndex() + 1 &&
        Base != NextI->getOperand(1).getIndex() - 1)
      continue;

    LocalVariables = (!IsReg && (Base != NextI->getOperand(1).getIndex()));

    // Check for globals with target flags, that these are the same.
    if (!IsImm && (GV != NextI->getOperand(2).getGlobal() || TF != NextI->getOperand(2).getTargetFlags()))
      continue;

    // If the instructions can be merged into ZILSD_LD or ZILSD_SD, the subregs
    // should be accessed such that lower numbered register is at a lower
    // address and four bytes away from the higher subreg. We already know the
    // low subreg. Check for the address also.
    // In addition, the offset of the higher part needs to be zero to avoid combining
    // in situations like this one:
    // e.g. SW %0:gpr, %stack.0.x, 0 :: (store (s32) into %ir.x)
    //      SW %2:gpr, %stack.1.y, 80 :: (store (s32) into %ir.y)
    int OffsetNext =
        IsImm ? NextI->getOperand(2).getImm() : NextI->getOperand(2).getOffset();
    if ((!LocalVariables && ((OffsetMI + 4) == OffsetNext)) ||
        (LocalVariables && (NextI->getOperand(1).getIndex() + 1) == Base) &&
         OffsetNext == 0) {
      LoInst = &MI;
      HiInst = &*NextI;
      OffsetLo = OffsetMI;
      OffsetHi = OffsetNext;
      break;
    } else if ((!LocalVariables && ((OffsetNext + 4) == OffsetMI)) ||
               (LocalVariables && (Base + 1) == NextI->getOperand(1).getIndex()) &&
                OffsetMI == 0) {
      LoInst = &*NextI;
      HiInst = &MI;
      OffsetLo = OffsetNext;
      OffsetHi = OffsetMI;
      break;
    }

  } while (NextI != MBBI->getParent()->end());
 
  if (LoInst && HiInst) {

    // Do not combine if the two memory locations can alias.
    for (auto Inst : PossibleInterferences) 
      if ((IsStore && MI.mayAlias(AA, *Inst, /*UseTBAA*/ false)) ||
          (!IsStore && NextI->mayAlias(AA, *Inst, /*UseTBAA*/ false)))
        return false;
    

    // Do not combine if the memory locations are volatile.
    if (LoInst->memoperands()[0]->isVolatile() ||
        HiInst->memoperands()[0]->isVolatile())
      return false;

    // Take the alignment for global frames and for stack locations.
    Align LoAlignment, HiAlignment;
    if (IsReg) {
      LoAlignment = LoInst->memoperands()[0]->getAlign();
      HiAlignment = HiInst->memoperands()[0]->getAlign();
    }
    else if (!IsReg && LocalVariables) {
      LoAlignment = MFI->getObjectAlign(LoInst->getOperand(1).getIndex());
      HiAlignment = MFI->getObjectAlign(HiInst->getOperand(1).getIndex());
    }

    // Do not combine if the unaligned memory is not allowed and 
    // the alignment of the memory is not a multiple of 8 or if 
    // the offset is not a multiple of 8.
    if (((IsReg || (!IsReg && LocalVariables)) && 
        !ST->hasFastUnalignedAccess() &&
        LoAlignment < 8) ||
        (!IsReg && !LocalVariables && OffsetLo % 8 != 0))
      return false;
     
    // If the high and low parts both have an alignment greater than 4
    // they should not be grouped, because this leaves a byte gap.
    if ((IsReg || (!IsReg && LocalVariables)) && HiAlignment > 4)
      return false;

    // If the lo instruction is a pointer to a value larger than 4 bytes
    // or an array, the two stack locations are not situated at the right distance.
    if (LocalVariables && LoInst->memoperands()[0]->getValue()) 
      if (const AllocaInst *AI =
              dyn_cast<AllocaInst>(LoInst->memoperands()[0]->getValue()))
        if (AI->getAllocationSize(LoInst->getParent()->getParent()->getDataLayout()) > 4)
            return false;
      
    LLVM_DEBUG(
        dbgs() << "Creating load/store pair. Replacing instructions:\n    ");
    LLVM_DEBUG(MI.dump());
    LLVM_DEBUG(dbgs() << "    ");
    LLVM_DEBUG(NextI->dump());
    LLVM_DEBUG(dbgs() << "  with instruction:\n    ");

    Register SuperReg = MRI->createVirtualRegister(&RISCV::GPRPRegClass);

    MachineInstrBuilder NewMI;
    if (IsStore) {
      Register Reg0 = MRI->createVirtualRegister(&RISCV::GPRPRegClass),
               Reg1 = MRI->createVirtualRegister(&RISCV::GPRPRegClass);

      BuildMI(*NextI->getParent(), NextI, NextI->getDebugLoc(),
              TII->get(RISCV::IMPLICIT_DEF), Reg0);

      BuildMI(*NextI->getParent(), NextI, NextI->getDebugLoc(),
              TII->get(RISCV::INSERT_SUBREG), Reg1)
          .addReg(Reg0)
          .addReg(LoInst->getOperand(0).getReg())
          .addImm(RISCV::sub_gpr_even);
      BuildMI(*NextI->getParent(), NextI, NextI->getDebugLoc(),
              TII->get(RISCV::INSERT_SUBREG), SuperReg)
          .addReg(Reg1)
          .addReg(HiInst->getOperand(0).getReg())
          .addImm(RISCV::sub_gpr_odd);
      NewMI = BuildMI(*NextI->getParent(), NextI, NextI->getDebugLoc(),
                      TII->get(RISCV::ZILSD_SD))
                  .addReg(SuperReg);
      if (IsReg)
        NewMI.addReg(Base);
      else
        NewMI.addFrameIndex(LoInst->getOperand(1).getIndex());

      if (IsImm)
        NewMI.addImm(OffsetLo);
      else {
        NewMI.addGlobalAddress(GV, OffsetLo, TF);
      }

    } else {
      NewMI = BuildMI(*MI.getParent(), &MI, MI.getDebugLoc(),
                      TII->get(RISCV::ZILSD_LD), SuperReg);
      if (IsReg)
        NewMI.addReg(Base);
      else
        NewMI.addFrameIndex(LoInst->getOperand(1).getIndex());

      if(IsImm) 
        NewMI.addImm(OffsetLo);
      else {
        NewMI.addGlobalAddress(GV, OffsetLo, TF);
      }

      BuildMI(*MI.getParent(), &MI, MI.getDebugLoc(), TII->get(RISCV::COPY),
              LoInst->getOperand(0).getReg())
          .addReg(SuperReg, 0, RISCV::sub_gpr_even);
      BuildMI(*MI.getParent(), &MI, MI.getDebugLoc(), TII->get(RISCV::COPY),
              HiInst->getOperand(0).getReg())
          .addReg(SuperReg, 0, RISCV::sub_gpr_odd);
    }

    // Update the iterator before removing the instructions.
    if (IsStore) 
      MBBI = std::next(MBBI);
    else 
      MBBI = std::next(NextI);

    LLVM_DEBUG(NewMI->dump());
    LLVM_DEBUG(dbgs() << "\n");

    MI.eraseFromParent();
    NextI->eraseFromParent();
    return true;
  }

  return false;
}

bool RISCVMIPeephole::ChangeZdinxLDSDtoPair(MachineBasicBlock::iterator &MBBI) {
  MachineInstr &MI = *MBBI;

  if ((!MI.getOperand(2).isImm() && !MI.getOperand(2).isGlobal() &&
       !MI.getOperand(2).isCPI()) ||
      (!MI.getOperand(1).isReg() && (!MI.getOperand(1).isFI()))) 
      return false;

  bool IsStore = (MI.getOpcode() == RISCV::PseudoRV32ZdinxSD);
  bool IsReg = MI.getOperand(1).isReg();
  bool IsImm = MI.getOperand(2).isImm();
  int OffsetMI =
      IsImm ? MI.getOperand(2).getImm() : MI.getOperand(2).getOffset();
  
  // Do not replace if the unaligned memory is not allowed and
  // the alignment of the memory is not a multiple of 8 or if
  // the offset is not a multiple of 8.
  if ((IsReg && !ST->hasFastUnalignedAccess() &&
         MI.memoperands()[0]->getAlign() < 8) ||
        (!IsReg && OffsetMI % 8 != 0)) 
      return false;
  
  MachineInstrBuilder NewMI;
  // Generate ZILSD_SD/ZILSD_LD instead of PseudoRV32ZdinxSD/PseudoRV32ZdinxLD.
  if (IsStore) 
    NewMI =
      BuildMI(*MI.getParent(), &MI, MI.getDebugLoc(),
              TII->get(RISCV::ZILSD_SD)) 
          .addReg(MI.getOperand(0).getReg()) 
          .add(MI.getOperand(1)) 
          .add(MI.getOperand(2));
  else 
   NewMI =
      BuildMI(*MI.getParent(), &MI, MI.getDebugLoc(),
              TII->get(RISCV::ZILSD_LD)) 
          .addReg(MI.getOperand(0).getReg(), 
              (getRegState(MI.getOperand(0)) & !RegState::Kill | RegState::Define)) 
          .add(MI.getOperand(1)) 
          .add(MI.getOperand(2));

  LLVM_DEBUG(
      dbgs() << "Creating load/store pair. Replacing instruction:\n    ");
  LLVM_DEBUG(MI.dump());
  LLVM_DEBUG(dbgs() << "  with instruction:\n    ");
  LLVM_DEBUG(NewMI->dump());
  LLVM_DEBUG(dbgs() << "\n");

  MI.eraseFromParent();
  MBBI = NewMI;
  return true;
}

bool RISCVMIPeephole::runOnMachineFunction(MachineFunction &MF) {

  ST = &MF.getSubtarget<RISCVSubtarget>();


  if (!ST->hasStdExtZilsd())
    return false;

  LLVM_DEBUG({
    dbgs() << "********** Before RISCV Peephole **********\n"
           << "********** Function: " << MF.getName() << '\n';
  });
  
  LLVM_DEBUG(MF.print(dbgs()));

  TII = ST->getInstrInfo();
  MRI = &MF.getRegInfo();
  MFI = &MF.getFrameInfo();
  AA = &getAnalysis<AAResultsWrapperPass>().getAAResults();

  bool Changed = false;

  // Loop over all of the basic blocks.
  for (auto &MBB : MF) {
    // Traverse the basic block.
    auto BlockIter = MBB.begin();
    while (BlockIter != MBB.end()) {
      MachineInstr &MI = *BlockIter;
      switch (MI.getOpcode()) {
      case RISCV::LW:
      case RISCV::SW:
        // Try to merge the LW/SW instructions (if enabled).
        if (RISCVZilsdMerge)
          if (CombineLDSTtoPair(BlockIter))
            Changed = true;
          else 
            ++BlockIter;
        break;
      case RISCV::PseudoRV32ZdinxSD:
      case RISCV::PseudoRV32ZdinxLD: 
        // Try to convert the PseudoRV32ZdinxSD/PseudoRV32ZdinxLD instruction (if enabled).
        if (RISCVZilsdMerge) 
            Changed |= ChangeZdinxLDSDtoPair(BlockIter);
      default:
        ++BlockIter;
        break;
      }
    }
  }

  LLVM_DEBUG({
    dbgs() << "********** After RISCV Peephole **********\n"
           << "********** Function: " << MF.getName() << '\n';
  });

  LLVM_DEBUG(MF.print(dbgs()));

  return Changed;
}

} // namespace

INITIALIZE_PASS(RISCVMIPeephole, "riscv-mi-peephole", "RISCV MI Peephole",
                false, false)

char RISCVMIPeephole::ID = 0;
FunctionPass *llvm::createRISCVMIPeepholePass() {
  return new RISCVMIPeephole();
}
