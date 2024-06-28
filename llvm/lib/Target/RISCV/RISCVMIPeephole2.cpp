//===-------- RISCVMIPeephole2.cpp - RISCV MI Peephole 2 optimization --------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains a pass that performs the merging of two eligible LW/SW 
// instructions in a ZILSD_LD/ZILSD_SD instuction under the presence of 
// the ZILSD extension. This pass is run after register allocation.
//
//===----------------------------------------------------------------------===//
/*
 * Copyright 2024 NXP
 */

#include "RISCV.h"
#include "RISCVTargetMachine.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/Support/Debug.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-mi-peephole"

static cl::opt<bool> RISCVZilsdMerge2(
    "riscv-merge-lwsw-to-ldsd2", cl::Hidden, cl::init(true),
    cl::desc("Merge eligible two 32bit lw-sw instructions to 64bit ld-sd after register allocation"));

namespace {

struct RISCVMIPeephole2 : public MachineFunctionPass {
  const RISCVSubtarget *ST;
  const RISCVInstrInfo *TII;
  const TargetRegisterInfo *TRI;

  static char ID;
  RISCVMIPeephole2() : MachineFunctionPass(ID) {
    initializeRISCVMIPeephole2Pass(*PassRegistry::getPassRegistry());
  }

public:
  StringRef getPassName() const override {
    return "RISCV MI Peephole 2 Optimization - ZILSD";
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  bool runOnMachineFunction(MachineFunction &MF) override;
  bool CombineLDSTtoPair(MachineBasicBlock::iterator &MBBI);
  bool ChangeZdinxLDSDtoPair(MachineBasicBlock::iterator &MBBI);
};

// Merge two consecutive 32bit load or store into 64bit load or store.
// Return true on success. This is available only on ZILSD extension.
bool RISCVMIPeephole2::CombineLDSTtoPair(MachineBasicBlock::iterator &MBBI) {
  MachineBasicBlock::iterator NextI = MBBI;

  MachineInstr &MI = *MBBI;

  bool IsStore = (MI.getOpcode() == RISCV::SW);
  unsigned SuperReg = 0;
  bool FirstInstruction = false;
  unsigned int BaseReg = MI.getOperand(1).getReg();
  Align Alignment = Align(1);

  // Do not combine if the memory location is volatile.
  if (MI.memoperands().size() && MI.memoperands()[0]->isVolatile())
    return false;

  do {
    NextI++;
    if (NextI == MBBI->getParent()->end())
      return false;
  } while (NextI->isMetaInstruction());

  MachineInstr &NextMI = *NextI;

  // Peephole at this stage is valid only for consecutive load or store.
  if (IsStore && NextMI.getOpcode() != RISCV::SW)
    return false;

  if (!IsStore && NextMI.getOpcode() != RISCV::LW)
    return false;

  // Do not combine if the memory location is volatile.
  if (NextMI.memoperands().size() && NextMI.memoperands()[0]->isVolatile())
    return false;

  // Sometimes we can have two consecutive un-related instructions
  // that might be accessing using symbols. We are looking at only
  // those that have immediate offsets.
  bool IsGlobal = false;
  if (!MI.getOperand(2).isImm() || !NextMI.getOperand(2).isImm())
    if (MI.getOperand(2).isGlobal() && NextMI.getOperand(2).isGlobal() &&
        MI.getOperand(2).getGlobal() == NextMI.getOperand(2).getGlobal())
      IsGlobal = true;
    else
      return false;

  // Make sure that the instructions are related.
  if (BaseReg != NextMI.getOperand(1).getReg())
    return false;

  int OffsetMI = IsGlobal ? MI.getOperand(2).getOffset() : MI.getOperand(2).getImm();
  int OffsetNext = IsGlobal ? NextMI.getOperand(2).getOffset()
                            : NextMI.getOperand(2).getImm();
  unsigned RegMI = MI.getOperand(0).getReg();
  unsigned RegNext = NextMI.getOperand(0).getReg();

  // For a load instruction, make sure that the second load doesn't
  // use the result of the first one.
  if (!IsStore && BaseReg == RegNext)
    return false;

  if (OffsetMI + 4 == OffsetNext) {
    SuperReg = TRI->getMatchingSuperReg(RegMI, RISCV::sub_gpr_even,
                                          &RISCV::GPRPRegClass);
    if (!SuperReg || TRI->getSubRegIndex(SuperReg, RegNext) != RISCV::sub_gpr_odd)
      return false;
    FirstInstruction = true;
    Alignment = MI.memoperands().size() ? MI.memoperands()[0]->getAlign() 
                                        : Align(1);
  } else if (OffsetMI == OffsetNext + 4) {
    SuperReg = TRI->getMatchingSuperReg(RegNext, RISCV::sub_gpr_even,
                                          &RISCV::GPRPRegClass);
    if (!SuperReg || TRI->getSubRegIndex(SuperReg, RegMI) != RISCV::sub_gpr_odd)
      return false;
    Alignment = NextMI.memoperands().size() ? NextMI.memoperands()[0]->getAlign()
                                            : Align(1);
  } else
    return false;
  // Do not combine if the unaligned memory is not allowed and
  // the alignment of the memory is not a multiple of 8.
  if (!ST->hasFastUnalignedAccess() && Alignment < 8)
    return false;

  MachineOperand &Offset =
      FirstInstruction ? MI.getOperand(2) : NextMI.getOperand(2);

  LLVM_DEBUG(
        dbgs() << "Creating load/store pair. Replacing instructions:\n    ");
  LLVM_DEBUG(MI.dump());
  LLVM_DEBUG(dbgs() << "    ");
  LLVM_DEBUG(NextMI.dump());
  LLVM_DEBUG(dbgs() << "  with instruction:\n    ");

  MachineInstr *NewMI;
  if (IsStore) {
    NewMI = BuildMI(*MI.getParent(), &MI, MI.getDebugLoc(),
                      TII->get(RISCV::ZILSD_SD))
                  .addReg(SuperReg)
                  .addReg(BaseReg)
                  .add(Offset);
  } else {
    NewMI = BuildMI(*MI.getParent(), &MI, MI.getDebugLoc(),
                      TII->get(RISCV::ZILSD_LD), SuperReg)
                  .addReg(BaseReg)
                  .add(Offset);
  }

  LLVM_DEBUG(NewMI->dump());
  LLVM_DEBUG(dbgs() << "\n");

  // Update the iterator before removing the instructions.
  MBBI = ++NextI;
  MI.eraseFromParent();
  NextMI.eraseFromParent();
  return true;
}

bool RISCVMIPeephole2::ChangeZdinxLDSDtoPair(MachineBasicBlock::iterator &MBBI) {
  MachineInstr &MI = *MBBI;

  Align Alignment =
      MI.memoperands().size() ? MI.memoperands()[0]->getAlign() : Align(1);

  if (!ST->hasFastUnalignedAccess() && Alignment < 8)
    return false;

  bool IsStore = (MI.getOpcode() == RISCV::PseudoRV32ZdinxSD);
 
  MachineInstrBuilder NewMI;
  if (IsStore)
    NewMI = BuildMI(*MI.getParent(), &MI, MI.getDebugLoc(),
                    TII->get(RISCV::ZILSD_SD))
                .add(MI.getOperand(0))
                .add(MI.getOperand(1))
                .add(MI.getOperand(2));
  else
    NewMI = BuildMI(*MI.getParent(), &MI, MI.getDebugLoc(),
                    TII->get(RISCV::ZILSD_LD))
                .add(MI.getOperand(0))
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

bool RISCVMIPeephole2::runOnMachineFunction(MachineFunction &MF) {

  ST = &MF.getSubtarget<RISCVSubtarget>();
  
  if (!ST->hasStdExtZilsd())
    return false;

  LLVM_DEBUG({
    dbgs() << "********** Before RISCV Peephole 2 **********\n"
           << "********** Function: " << MF.getName() << '\n';
  });

  LLVM_DEBUG(MF.print(dbgs()));

  TII = ST->getInstrInfo();
  TRI = ST->getRegisterInfo();
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
        // Try to merge the remaining LW/SW instructions (if enabled).
        if (RISCVZilsdMerge2)
          if (CombineLDSTtoPair(BlockIter))
            Changed = true;
          else
            ++BlockIter;
        break;
      case RISCV::PseudoRV32ZdinxSD:
      case RISCV::PseudoRV32ZdinxLD:
        // Try to convert the remaining PseudoRV32ZdinxSD/PseudoRV32ZdinxLD instruction
        // (if enabled).
        if (RISCVZilsdMerge2)
          Changed |= ChangeZdinxLDSDtoPair(BlockIter);
      default:
        ++BlockIter;
        break;
      }
    }
  }

  LLVM_DEBUG({
    dbgs() << "********** After RISCV Peephole 2**********\n"
           << "********** Function: " << MF.getName() << '\n';
  });

  LLVM_DEBUG(MF.print(dbgs()));

  return Changed;
}

} // namespace

INITIALIZE_PASS(RISCVMIPeephole2, "riscv-mi-peephole2", "RISCV MI Peephole 2",
                false, false)

char RISCVMIPeephole2::ID = 0;
FunctionPass *llvm::createRISCVMIPeephole2Pass() {
  return new RISCVMIPeephole2();
}