# Reversing-Turbo-Modula2

This is the initial reverse-engineering work that made possible the re-engineering of Turbo Modula-2 (see the companion repository: Turbo Modula-2 Reloaded).

First, there is a disassembly of the Z80 code. The original bytecode (MCode) interpreter of Turbo Modula-2 for CP/M was of course entirely written in Z80 code for speed. A number of procedures in the system library and in the parser of the compiler are also written in Z80 code (again for speed reasons), but apart from these, most of the rest of Turbo Modula-2 System was written in Modula-2, including the "kernel" (which is responsible for the initialization of the system, and the exception propagation system activated when an exception occurs).

After understanding the bytecode interpreter, it was possible to precisely define a compatible specification of the MCode opcodes. To remove ambiguity, this specification is written here in the form of a bytecode interpreter written in Modula-2. Actually, this bytecode interpreter can be run inside Turbo Modula-2 Reloaded, i.e an interpreter inside the interpreter...

Along with this bytecode specification is given here a bytecode disassembler, this was the first step for reversing the Modula-2 code. All modules of the original Turbo Modula-2 system for CP/M have been disassembled with this tool. However, the MCode disassembly is not so much readable, so a decompiling work has then been started. The kernel, the shell, the editor and most of the system library have thus been decompiled, however only a small part of the compiler has been decompiled for now. The resulting sources can be compiled and give a 100% match with the original MCode binaries.

The MCode disassembler is provided as a single source file (unassemble.c, it should compile on all systems). It can disassemble either a .MCD file provided as an argument, or the original Turbo Modula-2 system (M2.COM) if no argument is given.
