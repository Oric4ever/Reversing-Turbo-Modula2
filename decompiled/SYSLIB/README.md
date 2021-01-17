Decompilation of the system library is now 100% complete.

The quality of the decompiled sources is now acceptable IMHO.
I called them 'perfect decompiled modules' when compiling them produces 
exactly (byte-to-byte identically) the MCode files provided in the original Turbo Modula-2 distribution.

So now this is the case of all these files of the system library (with a small minor exception for the Strings module).
In order to achieve this binary equality, it means that I also provide a few .COM files containing Z80 code,
because some of the original modules had a few procedures written in Z80 assembly.

The system library of Turbo Modula-2 is composed of the following modules:

- ComLine: command line access
- Convert: conversion of numeric types (except LONGREAL) to/from strings
- Doubles: conversion of LONGREAL type to/from string (and hidden LONGREAL arithmetic)
- Files: Files operations
- InOut: classic Wirth's input/output module
- Loader: dynamic loader of modules
- LongMath: same as MathLib but for LONGREAL type
- MathLib: mathematic library
- Processes: synchronisation of processes with signals
- Strings: string manipulation
- Terminal: terminal output
- Texts: TEXT files operations
