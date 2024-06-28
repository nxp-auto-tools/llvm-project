;
; Copyright 2024 NXP
;
; RUN: llc -mtriple=riscv32 -mattr=+experimental-zilsd -verify-machineinstrs -mattr=+fast-unaligned-access < %s \
; RUN:   | FileCheck %s -check-prefix=RV32ZILSD

define i64 @lwd(i32* %a) {
  %1 = getelementptr i32, i32* %a, i64 4
  %2 = load i32, i32* %1, align 4
  %3 = getelementptr i32, i32* %a, i64 5
  %4 = load i32, i32* %3, align 4
  %5 = sext i32 %2 to i64
  %6 = sext i32 %4 to i64
  %7 = add i64 %5, %6
  ret i64 %7
}
; RV32ZILSD-LABEL:    lwd: 
; RV32ZILSD:        	ld	a2, 16(a0)
; RV32ZILSD-NEXT:    	srai	a1, a2, 31
; RV32ZILSD-NEXT:    	srai	a4, a3, 31
; RV32ZILSD-NEXT:    	add	a0, a2, a3
; RV32ZILSD-NEXT:    	sltu	a2, a0, a2
; RV32ZILSD-NEXT:    	add	a1, a1, a4
; RV32ZILSD-NEXT:    	add	a1, a1, a2
; RV32ZILSD-NEXT:    	ret

define i64 @lwud(i32* %a) {
  %1 = getelementptr i32, i32* %a, i64 4
  %2 = load i32, i32* %1, align 4
  %3 = getelementptr i32, i32* %a, i64 5
  %4 = load i32, i32* %3, align 4
  %5 = zext i32 %2 to i64
  %6 = zext i32 %4 to i64
  %7 = add i64 %5, %6
  ret i64 %7
}
; RV32ZILSD-LABEL:    lwud: 
; RV32ZILSD:      	  ld	a2, 16(a0)
; RV32ZILSD-NEXT:    	add	a0, a2, a3
; RV32ZILSD-NEXT:    	sltu	a1, a0, a2
; RV32ZILSD-NEXT:    	ret


define i64 @ldd(i64* %a) {
  %1 = getelementptr i64, i64* %a, i64 4
  %2 = load i64, i64* %1, align 8
  %3 = getelementptr i64, i64* %a, i64 5
  %4 = load i64, i64* %3, align 8
  %5 = add i64 %2, %4
  ret i64 %5
}
; RV32ZILSD-LABEL:    ldd: 
; RV32ZILSD:      	  ld	a2, 32(a0)
; RV32ZILSD-NEXT:    	ld	a0, 40(a0)
; RV32ZILSD-NEXT:    	add	a1, a3, a1
; RV32ZILSD-NEXT:    	add	a0, a2, a0
; RV32ZILSD-NEXT:    	sltu	a2, a0, a2
; RV32ZILSD-NEXT:    	add	a1, a1, a2
; RV32ZILSD-NEXT:    	ret


define i64 @lwd_0(i32* %a) {
  %1 = getelementptr i32, i32* %a, i64 0
  %2 = load i32, i32* %1, align 4
  %3 = getelementptr i32, i32* %a, i64 1
  %4 = load i32, i32* %3, align 4
  %5 = sext i32 %2 to i64
  %6 = sext i32 %4 to i64
  %7 = add i64 %5, %6
  ret i64 %7
}
; RV32ZILSD-LABEL:    lwd_0: 
; RV32ZILSD:      	  ld a2, 0(a0)
; RV32ZILSD-NEXT:    	srai	a1, a2, 31
; RV32ZILSD-NEXT:    	srai	a4, a3, 31
; RV32ZILSD-NEXT:    	add	a0, a2, a3
; RV32ZILSD-NEXT:    	sltu	a2, a0, a2
; RV32ZILSD-NEXT:    	add	a1, a1, a4
; RV32ZILSD-NEXT:    	add	a1, a1, a2
; RV32ZILSD-NEXT:    	ret


define i64 @lwud_0(i32* %a) {
  %1 = getelementptr i32, i32* %a, i64 0
  %2 = load i32, i32* %1, align 4
  %3 = getelementptr i32, i32* %a, i64 1
  %4 = load i32, i32* %3, align 4
  %5 = zext i32 %2 to i64
  %6 = zext i32 %4 to i64
  %7 = add i64 %5, %6
  ret i64 %7
}
; RV32ZILSD-LABEL:    lwud_0: 
; RV32ZILSD:      	  ld	a2, 0(a0)
; RV32ZILSD-NEXT:    	add	a0, a2, a3
; RV32ZILSD-NEXT:    	sltu	a1, a0, a2
; RV32ZILSD-NEXT:    	ret


define i64 @ldd_0(i64* %a) {
  %1 = getelementptr i64, i64* %a, i64 0
  %2 = load i64, i64* %1, align 8
  %3 = getelementptr i64, i64* %a, i64 1
  %4 = load i64, i64* %3, align 8
  %5 = add i64 %2, %4
  ret i64 %5
}
; RV32ZILSD-LABEL:    ldd_0: 
; RV32ZILSD:      	  ld	a2, 0(a0)
; RV32ZILSD-NEXT:    	ld	a0, 8(a0)
; RV32ZILSD-NEXT:    	add	a1, a3, a1
; RV32ZILSD-NEXT:    	add	a0, a2, a0
; RV32ZILSD-NEXT:    	sltu	a2, a0, a2
; RV32ZILSD-NEXT:    	add	a1, a1, a2
; RV32ZILSD-NEXT:    	ret


define void @swd(i32 %b, i32 %c, i32* %a) {
  %1 = getelementptr i32, i32* %a, i64 4
  store i32 %b, i32* %1, align 4
  %2 = getelementptr i32, i32* %a, i64 5
  store i32 %c, i32* %2, align 4
  ret void
}
; RV32ZILSD-LABEL:    swd: 
; RV32ZILSD:      	  sd	a0, 16(a2)
; RV32ZILSD-NEXT:    	ret


define void @sdd(i64 %b, i64 %c, i64* %a) {
  %1 = getelementptr i64, i64* %a, i64 4
  store i64 %b, i64* %1, align 8
  %2 = getelementptr i64, i64* %a, i64 5
  store i64 %c, i64* %2, align 8
  ret void
}
; RV32ZILSD-LABEL:    sdd: 
; RV32ZILSD:      	  sd	a0, 32(a4)
; RV32ZILSD-NEXT:    	sd	a2, 40(a4)
; RV32ZILSD-NEXT:    	ret


define void @swd_0(i32 %b, i32 %c, i32* %a) {
  %1 = getelementptr i32, i32* %a, i64 0
  store i32 %b, i32* %1, align 4
  %2 = getelementptr i32, i32* %a, i64 1
  store i32 %c, i32* %2, align 4
  ret void
}
; RV32ZILSD-LABEL:    swd_0: 
; RV32ZILSD:      	  sd	a0, 0(a2)
; RV32ZILSD-NEXT:    	ret


define void @sdd_0(i64 %b, i64 %c, i64* %a) {
  %1 = getelementptr i64, i64* %a, i64 0
  store i64 %b, i64* %1, align 8
  %2 = getelementptr i64, i64* %a, i64 1
  store i64 %c, i64* %2, align 8
  ret void
}
; RV32ZILSD-LABEL:    sdd_0: 
; RV32ZILSD:      	  sd	a0, 0(a4)
; RV32ZILSD-NEXT:    	sd	a2, 8(a4)
; RV32ZILSD-NEXT:    	ret


define i64 @ld64(i64* %a) {
  %1 = getelementptr i64, i64* %a, i64 0
  %2 = load i64, i64* %1, align 8
  ret i64 %2
}
; RV32ZILSD-LABEL:    ld64: 
; RV32ZILSD:      	  ld	a0, 0(a0)
; RV32ZILSD-NEXT:    	ret



define i128 @ld128(i128* %a) {
  %1 = getelementptr i128, i128* %a, i64 0
  %2 = load i128, i128* %1, align 8
  ret i128 %2
}
; RV32ZILSD-LABEL:    ld128: 
; RV32ZILSD:      	  ld	a2, 0(a1)
; RV32ZILSD-NEXT:    	ld	a4, 8(a1)
; RV32ZILSD-NEXT:    	sd	a4, 8(a0)
; RV32ZILSD-NEXT:    	sd	a2, 0(a0)
; RV32ZILSD-NEXT:    	ret


define void @sd64(i64* %a, i64 %b) {
  %1 = getelementptr i64, i64* %a, i64 0
  store i64 %b, i64* %1, align 8
  ret void
}
; RV32ZILSD-LABEL:    sd64: 
; RV32ZILSD:      	  mv	a3, a2
; RV32ZILSD-NEXT:    	mv	a2, a1
; RV32ZILSD-NEXT:    	sd	a2, 0(a0)
; RV32ZILSD-NEXT:    	ret


define void @sd128(i128* %a, i128 %b) {
  %1 = getelementptr i128, i128* %a, i64 0
  store i128 %b, i128* %1, align 8
  ret void
}
; RV32ZILSD-LABEL:    sd128: 
; RV32ZILSD:      	  ld	a2, 0(a1)
; RV32ZILSD-NEXT:    	ld	a4, 8(a1)
; RV32ZILSD-NEXT:    	sd	a4, 8(a0)
; RV32ZILSD-NEXT:    	sd	a2, 0(a0)
; RV32ZILSD-NEXT:    	ret


define i32 @lh(i16* %a) {
  %1 = getelementptr i16, i16* %a, i64 0
  %2 = load i16, i16* %1, align 4
  %3 = getelementptr i16, i16* %a, i64 1
  %4 = load i16, i16* %3, align 4
  %5 = sext i16 %2 to i32
  %6 = sext i16 %4 to i32
  %7 = add i32 %5, %6
  ret i32 %7
}
; RV32ZILSD-LABEL:    lh: 
; RV32ZILSD:      	  lh	a1, 0(a0)
; RV32ZILSD-NEXT:    	lh	a0, 2(a0)
; RV32ZILSD-NEXT:    	add	a0, a1, a0
; RV32ZILSD-NEXT:    	ret


define i32 @lb(i8* %a) {
  %1 = getelementptr i8, i8* %a, i64 0
  %2 = load i8, i8* %1, align 4
  %3 = getelementptr i8, i8* %a, i64 1
  %4 = load i8, i8* %3, align 4
  %5 = sext i8 %2 to i32
  %6 = sext i8 %4 to i32
  %7 = add i32 %5, %6
  ret i32 %7
}
; RV32ZILSD-LABEL:    lb: 
; RV32ZILSD:      	  lb	a1, 0(a0)
; RV32ZILSD-NEXT:    	lb	a0, 1(a0)
; RV32ZILSD-NEXT:    	add	a0, a1, a0
; RV32ZILSD-NEXT:    	ret