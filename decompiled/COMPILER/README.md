Some of the modules of the compiler are linked into Turbo Modula-2's system: 
namely the Scanner, Errors, Compiler, SymTab and CodeGen modules.
All these modules are overlaid with other modules so that their code share 
memory with other modules of the system.

But other modules of the compiler are loaded dynamically (with Loader.Call):

- the COMPILE module, which actually is a link of three modules (Pass1, Statement, Express),
- the GENZ80 module, if native code generation is invoked

The current quality of these decompiled modules is very poor: 
I have difficulties trying to guess the data structures because type information has
disappeared during compilation (and of course all identifier names have disappeared too)...
