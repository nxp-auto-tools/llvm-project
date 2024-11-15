========================
RISCV LLVM Release Notes
========================

RISCV LLVM Release 12-November-2024
===================================
Update based on clang 18.1.6

**Compiler**
	- Changed zcmlsd extension to zclsd and updated version to 0.10.
	
RISCV LLVM Release 01-July-2024
===================================
Build based on clang 18.1.6

**Compiler**
    - Migrated the Zilsd changes to LLVM release 18.
    - Added the Zcmlsd extension (without checking the constraints yet).
    - Configured the toolchain for the internal unaligned libraries.
    - Optimized for the generation of the zilsd instructions for consecutive local variables.
    - Added support for the generation of the zilsd instructions for Zdinx extension.
    - Implemented an additional pass which generates the zilsd instructions instead of the consecutive loads/stores generated through spilling or passing arguments.
    - Marked the Zilsd and Zcmlsd extensions as experimental.

RISCV LLVM Release 20-May-2024
===================================
Build based on clang 17.0.6

**Compiler**
    - The generation was moved before register allocation - more situations covered.
    - Added an implementation which does not neccessary implies that loads/stores should be consecutive.
    - Improved the generation for the callee-saved registers.
    - Treated the unalignment cases (added a "-munaligned_access" flag)
    - Deactivate the generation of loads/stores in the prolog/epilog when the extension Zcmp is activated.


RISCV LLVM Release 23-February-2024
===================================
Build based on clang 17.0.5

**Compiler**
    - Added an initial implementation for the RISCV ZILSD extension.
