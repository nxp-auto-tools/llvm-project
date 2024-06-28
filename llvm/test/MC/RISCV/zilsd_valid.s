#
# Copyright 2024 NXP
#
# RUN: llvm-mc %s -triple=riscv32 --mattr=+c,+zilsd,+zcmlsd -riscv-no-aliases -show-encoding \
# RUN:     | FileCheck -check-prefixes=CHECK-ASM,CHECK-ASM-AND-OBJ %s
# RUN: llvm-mc -filetype=obj -triple=riscv32 -mattr=+c,+zilsd,+zcmlsd < %s \
# RUN:     | llvm-objdump --mattr=+zilsd,+zcmlsd -M no-aliases --no-print-imm-hex -d -r - \
# RUN:     | FileCheck --check-prefix=CHECK-ASM-AND-OBJ %s

# CHECK-ASM-AND-OBJ: ld s0, 0(a0)
# CHECK-ASM: encoding: [0x03,0x34,0x05,0x00]
ld x8, 0(x10)

# CHECK-ASM-AND-OBJ: ld zero, 0(a0)
# CHECK-ASM: encoding: [0x03,0x30,0x05,0x00]
ld x0, 0(x10)

# CHECK-ASM-AND-OBJ: ld t5, 0(a0)
# CHECK-ASM: encoding: [0x03,0x3f,0x05,0x00]
ld x30, 0(x10)

# CHECK-ASM-AND-OBJ: ld s0, -2048(a0)
# CHECK-ASM: encoding: [0x03,0x34,0x05,0x80]
ld x8, -2048(x10)

# CHECK-ASM-AND-OBJ: ld s0, 2040(a0)
# CHECK-ASM: encoding: [0x03,0x34,0x85,0x7f]
ld x8, 2040(x10)

# CHECK-ASM-AND-OBJ: ld s0, 0(zero)
# CHECK-ASM: encoding: [0x03,0x34,0x00,0x00]
ld x8, 0(x0)

# CHECK-ASM-AND-OBJ:  ld s0, 0(t6)
# CHECK-ASM: encoding: [0x03,0xb4,0x0f,0x00]
ld x8, 0(x31)


# CHECK-ASM-AND-OBJ: c.ld s0, 0(a0)
# CHECK-ASM: encoding:  [0x00,0x61]
c.ld x8, 0(x10)

# CHECK-ASM-AND-OBJ: c.ld a4, 0(a0)
# CHECK-ASM: encoding: [0x18,0x61]
c.ld x14, 0(x10)

# CHECK-ASM-AND-OBJ: c.ld s0, 0(a0)
# CHECK-ASM: encoding: [0x00,0x61]
c.ld x8, 0(x10)

# CHECK-ASM-AND-OBJ: c.ld s0, 248(a0)
# CHECK-ASM: encoding: [0x60,0x7d]
c.ld x8, 248(x10)

# CHECK-ASM-AND-OBJ: c.ld s0, 0(s0)
# CHECK-ASM: encoding: [0x00,0x60]
c.ld x8, 0(x8)

# CHECK-ASM-AND-OBJ: c.ld s0, 0(a4)
# CHECK-ASM: encoding: [0x00,0x63]
c.ld x8, 0(x14)

# CHECK-ASM-AND-OBJ: c.ldsp  s0, 0(sp)
# CHECK-ASM: encoding: [0x02,0x64]
c.ldsp x8, 0(sp)

# CHECK-ASM-AND-OBJ: c.ldsp  sp, 0(sp)
# CHECK-ASM: encoding: [0x02,0x61]
c.ldsp x2, 0(sp)

# CHECK-ASM-AND-OBJ: c.ldsp  t5, 0(sp)
# CHECK-ASM: encoding: [0x02,0x6f]
c.ldsp x30, 0(sp)

# CHECK-ASM-AND-OBJ: c.ldsp  s0, 504(sp)
# CHECK-ASM: encoding: [0x7e,0x74]
c.ldsp x8, 504(sp)



# CHECK-ASM-AND-OBJ: sd s0, 0(a0)
# CHECK-ASM: encoding: [0x23,0x30,0x85,0x00]
sd x8, 0(x10)

# CHECK-ASM-AND-OBJ: sd zero, 0(a0)
# CHECK-ASM: encoding: [0x23,0x30,0x05,0x00]
sd x0, 0(x10)

# CHECK-ASM-AND-OBJ: sd t5, 0(a0)
# CHECK-ASM: encoding: [0x23,0x30,0xe5,0x01]
sd x30, 0(x10)

# CHECK-ASM-AND-OBJ: sd s0, -2048(a0)
# CHECK-ASM: encoding: [0x23,0x30,0x85,0x80]
sd x8, -2048(x10)

# CHECK-ASM-AND-OBJ: sd s0, 2040(a0)
# CHECK-ASM: encoding: [0x23,0x3c,0x85,0x7e]
sd x8, 2040(x10)

# CHECK-ASM-AND-OBJ: sd s0, 0(zero)
# CHECK-ASM: encoding: [0x23,0x30,0x80,0x00]
sd x8, 0(x0)

# CHECK-ASM-AND-OBJ:  sd s0, 0(t6)
# CHECK-ASM: encoding: [0x23,0xb0,0x8f,0x00]
sd x8, 0(x31)
	

# CHECK-ASM-AND-OBJ: c.sd s0, 0(a0)
# CHECK-ASM: encoding:  [0x00,0xe1]
c.sd x8, 0(x10)

# CHECK-ASM-AND-OBJ: c.sd a4, 0(a0)
# CHECK-ASM: encoding: [0x18,0xe1]
c.sd x14, 0(x10)

# CHECK-ASM-AND-OBJ: c.sd s0, 0(a0)
# CHECK-ASM: encoding: [0x00,0xe1]
c.sd x8, 0(x10)

# CHECK-ASM-AND-OBJ: c.sd s0, 248(a0)
# CHECK-ASM: encoding: [0x60,0xfd]
c.sd x8, 248(x10)

# CHECK-ASM-AND-OBJ: c.sd s0, 0(s0)
# CHECK-ASM: encoding: [0x00,0xe0]
c.sd x8, 0(x8)

# CHECK-ASM-AND-OBJ: c.sd s0, 0(a4)
# CHECK-ASM: encoding: [0x00,0xe3]
c.sd x8, 0(x14)

# CHECK-ASM-AND-OBJ: c.sdsp  s0, 0(sp)
# CHECK-ASM: encoding: [0x22,0xe0]
c.sdsp x8, 0(sp)

# CHECK-ASM-AND-OBJ: c.sdsp  sp, 0(sp)
# CHECK-ASM: encoding: [0x0a,0xe0]
c.sdsp x2, 0(sp)

# CHECK-ASM-AND-OBJ: c.sdsp  t5, 0(sp)
# CHECK-ASM: encoding: [0x7a,0xe0]
c.sdsp x30, 0(sp)

# CHECK-ASM-AND-OBJ: c.sdsp  s0, 504(sp)
# CHECK-ASM: encoding: [0xa2,0xff]
c.sdsp x8, 504(sp)
