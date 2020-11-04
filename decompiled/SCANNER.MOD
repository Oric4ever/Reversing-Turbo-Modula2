IMPLEMENTATION MODULE Scanner;
IMPORT COMPILER, Files, Texts, ComLine, Loader, Doubles, Errors, SymTab, Codegen;
FROM SYSTEM IMPORT ADR, MOVE;
FROM STORAGE IMPORT ALLOCATE;
(*
FROM SYSTEM IMPORT ADDRESS, WORD, ;

TYPE Ext = ARRAY [0..2] OF CHAR;
     T = POINTER TO ARRAY [0..6] OF WORD;
VAR
    global2: BITSET;
    global3: CARDINAL;
    global4: Files.FILE;
    global5: CARDINAL;
    global6: CARDINAL;
    global7: CARDINAL;
    global8: CARDINAL;
    global9: CARDINAL;
    global10: CARDINAL;
    global11: CARDINAL;
    global12: CARDINAL;
    global13: CARDINAL;
    global14: CARDINAL;
    global15: CARDINAL;
    global16: Files.FILE;
    global17: CARDINAL;
    global18: CARDINAL;
    global19: CARDINAL;
    global20: CARDINAL;
    global21: CARDINAL;
    global22: CARDINAL;
    global23: CARDINAL;
    global24: POINTER TO Ext;
    global25: CARDINAL;
*)
CONST FREEMARKER = 3AE3H;
VAR stackLimit [0316H]: ADDRESS;

CONST EXPECTED = " expected, but ";
      

(* $[+ remove procedure names *)

PROCEDURE proc26(param1: WORD);
BEGIN
  Errors.proc1(param1);
END proc26;

PROCEDURE proc25(VAR s: ARRAY OF CHAR; ext: Ext; b: BOOLEAN);
VAR i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i < HIGH(s) - 3) AND (s[i] <> 0C) AND (s[i] <> '.') DO
    INC(i)
  END;
  IF b OR (s[i] <> '.') THEN
    s[i] := '.';
    MOVE(ADR(ext), ADR(s[i+1]), 3);
  END;
END proc25;

PROCEDURE proc27(param3: ARRAY OF CHAR; param1: CARDINAL): CARDINAL;
VAR i: CARDINAL;
    ptr : POINTER TO SymTab.Symbol;
BEGIN
  i := 0;
  WHILE (i < SymTab.global3) AND (SymTab.global6[i].name <> param3) DO
    INC(i)
  END; 
  ptr := ADR(SymTab.global6[i]);
  IF i < SymTab.global3 THEN
    IF ptr^.word <> param1 THEN Errors.proc2(12, ptr, 7) END;
  ELSE
    IF i > 15 THEN proc26(84) END;
    ptr^.name := param3;
    ptr^.word := param1;
    INC(SymTab.global3);
  END;
  RETURN i
END proc27;

PROCEDURE proc7(VAR a:ADDRESS; n:CARDINAL);
BEGIN
  ALLOCATE(a, n)  (* was in Z80 code *)
END proc7;

CONST PADDING = "                                                               ";

PROCEDURE proc5(VAR param1: ADDRESS);
BEGIN
  param1 := stackLimit - 60;
END proc5;

PROCEDURE proc6(param1: ADDRESS);
BEGIN 
  stackLimit := param1 + 60;
  param1^ := FREEMARKER;
END proc6;

PROCEDURE proc22(list: List; param2, param1: WORD): List; 
VAR current: List;
BEGIN 
  current := list^.next;
  WHILE current <> NIL DO
    IF proc23(param2, current^.word1, param1) THEN RETURN current END;
    current := current^.next;
  END;
  RETURN NIL
END proc22;

CONST PADDING2 = "                           ";

PROCEDURE proc23(param3, param2: WORD; param1: BOOLEAN):BOOLEAN;
BEGIN
  
END proc23;

PROCEDURE proc1; BEGIN END proc1;
PROCEDURE proc2; BEGIN END proc2;
PROCEDURE proc3; BEGIN END proc3;
PROCEDURE proc4; BEGIN END proc4;
PROCEDURE proc8; BEGIN END proc8;
PROCEDURE proc9; BEGIN END proc9;
PROCEDURE proc10; BEGIN END proc10;
PROCEDURE proc11; BEGIN END proc11;
PROCEDURE proc12; BEGIN END proc12;
PROCEDURE proc13; BEGIN END proc13;
PROCEDURE proc14(n:CARDINAL):ADDRESS; BEGIN END proc14;
PROCEDURE proc15(n:CARDINAL):ADDRESS; BEGIN END proc15;
PROCEDURE proc16(VAR a:WORD; s: ARRAY OF CHAR); BEGIN END proc16;
PROCEDURE proc17(a:ADDRESS; n: CARDINAL); BEGIN END proc17;
PROCEDURE proc18; BEGIN END proc18;
PROCEDURE proc19; BEGIN END proc19;
PROCEDURE proc20; BEGIN END proc20;
PROCEDURE proc21; BEGIN END proc21;
PROCEDURE proc24; BEGIN END proc24;
PROCEDURE proc28; BEGIN END proc28;

(* proc 40 *)
PROCEDURE VarAddress(VAR v: WORD);
CODE("Z80RET")
END VarAddress;

PROCEDURE Compile;
VAR addr: ADDRESS;
    ptr       [006EH]: CARDINAL;
    console   [0072H]: BOOLEAN;
    jmpOpcode [0074H]: CARDINAL;
    jmpAddress[0075H]: CARDINAL;
BEGIN
  jmpOpcode := 0C3H;
  addr      := varAddress(global2)-6;
  addr      := ADDRESS(addr^) - 4;
  jmpAddress:= addr + CARDINAL(addr^) + 3;
  MARK(addr);
  ptr       := 0;
  console   := (ComLine.inName = "CON:");
  global23  := 0;
  global25  := 0;
  proc7(global29, 14);
  Compiler.proc2;
  IF global16 <> 0 THEN
    proc7(global21, 4096);
    Loader.Call("COMPILE");
    IF Compiler.global25 THEN
      proc6(global21 + CodeGen.global2);
      IF CodeGen.global3 <> 0 THEN
        MOVE(global21, global21 + CodeGen.global3, CodeGen.global2 - CodeGen.global3);
        Files.SetPos(global4, LONG(0));
        IF Files.ReadBytes(global4, global21, CodeGen.global3) <> CodeGen.global3 THEN
          RAISE StatusError
        END;
      END; (* 0a98 *)
      Files.SetPos(global4, LONG(0));
      Loader.Call("GENZ80");
    END; (* 0aaa *)
  END; (* 0aaa *)
  Texts.CloseText(Texts.output);
  RELEASE(addr);

EXCEPTION Loader.LoadError:
  Texts.WriteLn(3); (* console *)
  Texts.WriteString(3,"ERROR: CANNOT LOAD OVERLAY");
  Texts.WriteLn(3);
  Files.Delete(global4);
  RELEASE(addr)
END Compile;

END Scanner.

