#
# Copyright 2024 NXP
#
# RUN: not llvm-mc -triple=riscv32 --mattr=+c,+zilsd %s 2>&1 | FileCheck %s

ld x9, 0(x10)       # CHECK: [[@LINE]]:1: error: instruction requires the following: RV64I Base Instruction Set
ld x8, -2049(x10)   # CHECK: [[@LINE]]:8: error: operand must be a symbol with %lo/%pcrel_lo/%tprel_lo modifier or an integer in the range [-2048, 2047]
ld x8, 2048(x10)    # CHECK: [[@LINE]]:8: error: operand must be a symbol with %lo/%pcrel_lo/%tprel_lo modifier or an integer in the range [-2048, 2047]

c.ld x0, 0(x10)     # CHECK: [[@LINE]]:6: error: invalid operand for instruction
c.ld x9, 0(x10)     # CHECK: [[@LINE]]:1: error: instruction requires the following: RV64I Base Instruction Set
c.ld x6, 0(x10)     # CHECK: [[@LINE]]:6: error: invalid operand for instruction
c.ld x14, -1(x10)   # CHECK: [[@LINE]]:11: error: immediate must be a multiple of 8 bytes in the range [0, 248]
c.ld x8, 249(x10)   # CHECK: [[@LINE]]:10: error: immediate must be a multiple of 8 bytes in the range [0, 248]
c.ld x8, 6(x10)     # CHECK: [[@LINE]]:10: error: immediate must be a multiple of 8 bytes in the range [0, 248]
c.ld x8, 0(x6)      # CHECK: [[@LINE]]:12: error: invalid operand for instruction

c.ldsp x9, 0(sp)    # CHECK: [[@LINE]]:1: error: instruction requires the following: RV64I Base Instruction Set
c.ldsp x8, -1(sp)   # CHECK: [[@LINE]]:12: error: immediate must be a multiple of 8 bytes in the range [0, 504]
c.ldsp x8, 6(x10)   # CHECK: [[@LINE]]:12: error: immediate must be a multiple of 8 bytes in the range [0, 504]
c.ldsp x8, 505(sp)  # CHECK: [[@LINE]]:12: error: immediate must be a multiple of 8 bytes in the range [0, 504]

sd x9, 0(x10)       # CHECK: [[@LINE]]:1: error: instruction requires the following: RV64I Base Instruction Set
sd x8, -2049(x10)   # CHECK: [[@LINE]]:8: error: operand must be a symbol with %lo/%pcrel_lo/%tprel_lo modifier or an integer in the range [-2048, 2047]
sd x8, 2048(x10)    # CHECK: [[@LINE]]:8: error: operand must be a symbol with %lo/%pcrel_lo/%tprel_lo modifier or an integer in the range [-2048, 2047]

c.sd x9, 0(x10)     # CHECK: [[@LINE]]:1: error: instruction requires the following: RV64I Base Instruction Set
c.sd x6, 0(x10)     # CHECK: [[@LINE]]:6: error: invalid operand for instruction
c.sd x14, -1(x10)   # CHECK: [[@LINE]]:11: error: immediate must be a multiple of 8 bytes in the range [0, 248]
c.sd x8, 249(x10)   # CHECK: [[@LINE]]:10: error: immediate must be a multiple of 8 bytes in the range [0, 248]
c.sd x8, 6(x10)     # CHECK: [[@LINE]]:10: error: immediate must be a multiple of 8 bytes in the range [0, 248]
c.sd x8, 0(x6)      # CHECK: [[@LINE]]:12: error: invalid operand for instruction

c.sdsp x9, 0(sp)    # CHECK: [[@LINE]]:1: error: instruction requires the following: RV64I Base Instruction Set
c.sdsp x8, -1(sp)   # CHECK: [[@LINE]]:12: error: immediate must be a multiple of 8 bytes in the range [0, 504]
c.sdsp x8, 6(x10)   # CHECK: [[@LINE]]:12: error: immediate must be a multiple of 8 bytes in the range [0, 504]
c.sdsp x8, 505(sp)  # CHECK: [[@LINE]]:12: error: immediate must be a multiple of 8 bytes in the range [0, 504]