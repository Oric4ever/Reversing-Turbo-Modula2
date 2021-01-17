Decompilation of the system library is now 100% complete.

The quality of the decompiled sources are now acceptable IMHO.
I called them 'perfect decompiled' files when compiling them produces 
exactly (byte-to-byte identically) the MCode files provided in the original Turbo Modula-2 distribution.

So now this is the case of all these files of the system library (with a small minor exception for the Strings module).
In order to achieve this binary equality, it means that I also provide a few .COM files containing Z80 code,
because some of the original modules had a few procedures written in Z80 assembly.
