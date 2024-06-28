;
; Copyright 2024 NXP
;
; RUN: llc -mtriple=riscv32 -mattr=+experimental-zilsd -verify-machineinstrs -O0 -mattr=+fast-unaligned-access < %s \
; RUN:   | FileCheck %s -check-prefix=RV32ZILSD

define i32 @raw_hazard(i32* %a, i32 %b) {
  %1 = getelementptr i32, i32* %a, i32 4
  %2 = load i32, i32* %1, align 4
  %3 = getelementptr i32, i32* %a, i32 5
  store i32 %b, i32* %3, align 4
  %4 = load i32, i32* %3, align 4
  %5 = add i32 %2, %4
  ret i32 %5
}
; RV32ZILSD-LABEL:    raw_hazard: 
; RV32ZILSD:            lw	a0, 16(a1)
; RV32ZILSD:            sw	a2, 20(a1)
; RV32ZILSD:            lw	a1, 20(a1)

define i32 @war_hazard(i32 %b, i32 %c, i32* %a) {
  %1 = getelementptr i32, i32* %a, i64 4
  store i32 %b, i32* %1, align 4
  %2 = getelementptr i32, i32* %a, i64 5
  %3 = load i32, i32* %1, align 4
  store i32 %c, i32* %2, align 4
  ret i32 %3
}
; RV32ZILSD-LABEL:    war_hazard: 
; RV32ZILSD:            sw	a0, 16(a2)
; RV32ZILSD:            lw	a0, 16(a2)
; RV32ZILSD:            sw	a1, 20(a2)

define i32 @raw_hazard_inoffensive_write(i32* %a, i32 %b) {
  %1 = getelementptr i32, i32* %a, i32 4
  %2 = load i32, i32* %1, align 4
  %3 = getelementptr i32, i32* %a, i32 6
  store i32 %b, i32* %3, align 4
  %4 = getelementptr i32, i32* %a, i32 5
  %5 = load i32, i32* %4, align 4
  %6 = add i32 %2, %5
  ret i32 %6
}
; RV32ZILSD-LABEL:    raw_hazard_inoffensive_write:
; RV32ZILSD:            ld	a4, 16(a3)
; RV32ZILSD:            sw	a2, 24(a3)

define i32 @war_hazard_inoffensive_read(i32 %b, i32 %c, i32* %a) {
  %1 = getelementptr i32, i32* %a, i64 4
  store i32 %b, i32* %1, align 4
  %2 = getelementptr i32, i32* %a, i64 6
  %3 = load i32, i32* %2, align 4
  %4 = getelementptr i32, i32* %a, i64 5
  store i32 %c, i32* %4, align 4
  ret i32 %3
}
; RV32ZILSD-LABEL:   war_hazard_inoffensive_read:
; RV32ZILSD:            lw	a0, 24(a1)
; RV32ZILSD:            sd	a2, 16(a1)

define i32 @raw_hazard_more_writes(i32* %a, i32 %b) {
  %1 = getelementptr i32, i32* %a, i32 4
  %2 = load i32, i32* %1, align 4
  %3 = getelementptr i32, i32* %a, i32 5
  store i32 %b, i32* %3, align 4
  %4 = getelementptr i32, i32* %a, i32 6
  store i32 %b, i32* %4, align 4
  %5 = load i32, i32* %3, align 4
  %6 = add i32 %2, %5
  ret i32 %6
}
; RV32ZILSD-LABEL:   raw_hazard_more_writes:
; RV32ZILSD:            lw	a0, 16(a1)
; RV32ZILSD:            sd	a2, 20(a1)
; RV32ZILSD:            lw	a1, 20(a1)

define i32 @war_hazard_more_reads(i32 %b, i32 %c, i32* %a) {
  %1 = getelementptr i32, i32* %a, i64 4
  store i32 %b, i32* %1, align 4
  %2 = getelementptr i32, i32* %a, i64 6
  %3 = load i32, i32* %2, align 4
  %4 = getelementptr i32, i32* %a, i64 5
  %5 = load i32, i32* %4, align 4
  store i32 %c, i32* %4, align 4
  %6 = add i32 %3, %5
  ret i32 %6
}
; RV32ZILSD-LABEL:   war_hazard_more_reads:
; RV32ZILSD:            ld	a2, 20(a4)
; RV32ZILSD:            sd	a2, 16(a4)