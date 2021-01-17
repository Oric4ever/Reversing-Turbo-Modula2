IMPLEMENTATION MODULE Scanner;
IMPORT Compiler, Files, Texts, ComLine, Loader, Doubles, Errors, SymTab, CodeGen;
IMPORT VarAddr;
FROM SYSTEM IMPORT ADR, MOVE, CODE, TSIZE, BYTE, OVERFLOW, REALOVERFLOW;
FROM STORAGE IMPORT ALLOCATE,MARK,RELEASE;

VAR global29: RecordPtr;
    global30: CARDINAL;

CONST FREEMARKER = 3AE3H;
CONST EOT = 032C; DEL = 177C;
CONST LINEFEED = 012C; TAB = 011C; CR = 015C;

VAR stackLimit [0316H]: ADDRESS;
VAR buffer  [0080H]: ARRAY [0..127] OF CHAR;
VAR bufIndex[006CH]: CARDINAL;
VAR filePos [006EH]: CARDINAL;
VAR column  [0070H]: CARDINAL;
VAR flag    [0072H]: CARDINAL;

CONST EXPECTED = " expected, but ";

(* $[+ remove procedure names *)

PROCEDURE proc26(param1: CARDINAL);
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
  WHILE (i < SymTab.global3) AND (SymTab.global6^[i].name <> param3) DO
    INC(i)
  END; 
  ptr := ADR(SymTab.global6^[i]);
  IF i < SymTab.global3 THEN
    IF ptr^.word <> param1 THEN Errors.proc2(12, ptr^.name) END;
  ELSE
    IF i > 15 THEN proc26(84) END;
    ptr^.name := param3;
    ptr^.word := param1;
    INC(SymTab.global3);
  END;
  RETURN i
END proc27;

PROCEDURE Allocate(VAR a:ADDRESS; n:CARDINAL); (* was in Z80 code *)
BEGIN
  ALLOCATE(a, n);
  RETURN;

(* padding to compensate for length difference *)
  n := n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n+n;
  RETURN; RETURN;

END Allocate;

PROCEDURE proc5(VAR param1: ADDRESS);
BEGIN
  param1 := stackLimit - 60;
END proc5;

PROCEDURE proc6(param1: ADDRESS);
BEGIN 
  stackLimit := param1 + 60;
  param1^ := FREEMARKER;
END proc6;

(* proc 22: find identifier in keyword list *)
PROCEDURE FindIdent(list: List; identifier: ADDRESS; caseInsensitive: BOOLEAN): RecordPtr;
(* original was in Z80 code *)
VAR current: T1;
BEGIN
  current := list^.first;
  WHILE current <> NIL DO
    IF StrCmp(identifier, current^.link1, caseInsensitive) THEN 
      RETURN ADDRESS(current)
    END;
    current := current^.link0;
  END;
  RETURN NIL;

(* padding to compensate for different length *)
  caseInsensitive := NOT NOT NOT NOT NOT NOT NOT NOT NOT NOT NOT NOT NOT NOT NOT
    NOT NOT NOT NOT NOT NOT NOT NOT NOT NOT NOT caseInsensitive
END FindIdent;

(* proc 23: original was in Z80 code, removed caseInsensitive comparison *)
PROCEDURE StrCmp(ptr1, ptr2: StringPtr; caseInsensitive: BOOLEAN):BOOLEAN;
BEGIN
  WHILE ptr1^[0] = ptr2^[0] DO
    IF ptr1^[0] = 0C THEN RETURN TRUE END;
    ptr1 := ADDRESS(ptr1)+1;
    ptr2 := ADDRESS(ptr2)+1;
  END;
  RETURN FALSE;
END StrCmp;

(* proc24: original was in Z80 code *)
PROCEDURE StrLen(VAR s: ARRAY OF CHAR): CARDINAL;
VAR i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i < HIGH(s)) AND (s[i] # 0C) DO INC(i) END;
  IF i # 0 THEN RETURN i END;
  RETURN 1;  (* never return a zero length *)
END StrLen;

PROCEDURE proc16(VAR a: ADDRESS; VAR s: ARRAY OF CHAR);
VAR length: CARDINAL;
BEGIN
  length := StrLen(s);
  Allocate(a, length+1);
  MOVE(ADR(s), a, length);
END proc16;

PROCEDURE proc15(n:CARDINAL):ADDRESS;
VAR ptr: Compiler.RecordPtr;
BEGIN
  Allocate(ptr, 14);
  ptr^.word4 := n;
  RETURN ptr
END proc15;

PROCEDURE proc14(n:CARDINAL):ADDRESS;
VAR ptr: Compiler.RecordPtr;
BEGIN
  IF    n <=  1 THEN Allocate(ptr, 14)
  ELSIF n <=  6 THEN Allocate(ptr, 10)
  ELSIF n <= 11 THEN Allocate(ptr, 12)
  ELSE               Allocate(ptr, 16)
  END;
  ptr^.word4 := n;
  RETURN ptr
END proc14;

PROCEDURE proc18(param1: CARDINAL): ADDRESS;
VAR ptr : Compiler.RecordPtr;
BEGIN
  proc12;
  IF ADDRESS(global13) = SymTab.global9 THEN Errors.proc2(1, global11) END;
  ptr := proc15(param1);
  proc16(ptr^.word1, global11);
  proc1;
  RETURN ptr
END proc18;

PROCEDURE proc20(param1: SymTab.T1);
BEGIN
  IF FindIdent(ADR(SymTab.global9^.link1), param1^.link1, 9 IN global2) # NIL THEN
    Errors.proc2(1, param1^.link1^)
  END;
  param1^.link0 := SymTab.global9^.link1;
  SymTab.global9^.link1 := param1;
END proc20;

PROCEDURE proc19(param1: CARDINAL): ADDRESS;
VAR ptr: SymTab.T1;
BEGIN
  ptr := proc18(param1);
  ptr^.link0 := SymTab.global9^.link1;
  SymTab.global9^.link1 := ptr;
  RETURN ptr;
END proc19;

PROCEDURE proc17(a:ADDRESS; next: ADDRESS);
BEGIN
  Allocate(SymTab.global9, 14);
  SymTab.global9^.w0 := a;
  SymTab.global9^.link1 := next;
END proc17;

PROCEDURE proc32;
VAR PipeChar[034EH]: CHAR;
BEGIN
  Texts.WriteLn(2);
  IF global23 
  THEN Texts.WriteCard(2, CodeGen.global2 - global22, 4)
  ELSE Texts.SetCol(2, 4)
  END;
  Texts.WriteChar(2, PipeChar);
  Texts.WriteChar(2, ' ')
END proc32;

PROCEDURE proc33;
BEGIN
  IF (ORD(global3) + 1) MOD 256 > 32 THEN Texts.WriteChar(2, global3); RETURN END;
  IF global3 = LINEFEED THEN column := 0; proc32; RETURN END;
  IF global3 = TAB      THEN 
    REPEAT Texts.WriteChar(2," "); INC(column) UNTIL column MOD 8 = 0;
  ELSIF (global3 < " ") AND (global3 # CR) THEN
    Texts.WriteChar(2, "^");
    Texts.WriteChar(2, CHR(ORD(global3)+40H))
  END;
END proc33;

PROCEDURE proc34;
VAR nbRead: CARDINAL;
BEGIN
  nbRead := Files.ReadBytes(global16, ADR(buffer), 128);
  IF nbRead < 128 THEN buffer[nbRead] := EOT END;
  bufIndex := 0;
  proc2
END proc34;

PROCEDURE proc28;
BEGIN
  global3  := ' ';
  column   := 0;
  bufIndex := 128;
  IF 0 IN global2 THEN proc32 END;
  Files.NoTrailer(global16)
END proc28;

PROCEDURE proc29;
VAR nbRead: CARDINAL;
BEGIN
  IF NOT Files.Open(global16, ComLine.inName) THEN HALT END;
  proc28;
  Files.SetPos(global16, LONG((global25 DIV 128) * 128));
  nbRead   := Files.ReadBytes(global16, ADR(buffer), 128);
  bufIndex := global25 MOD 128;
  filePos  := global25;
  proc1
END proc29;

PROCEDURE proc2; (* original was in Z80 code *)
VAR ch: CHAR;
BEGIN
  IF bufIndex = 128 THEN proc34
  ELSE
    ch := buffer[bufIndex];
    INC(bufIndex);
    IF ch = EOT THEN global3 := 377C ELSE global3 := ch END;
    INC(filePos);
    IF 0 IN global2 THEN
      IF ch >= ' ' THEN
        INC(column);
        IF flag # 0 THEN
          Texts.WriteChar(3, ch);
          RETURN; RETURN; (* padding *)
        END;
      END;
      proc33
    END;
  END;
  RETURN;
(* padding to compensate for smaller length *)
  INC(ch); INC(ch); INC(ch); INC(ch); INC(ch); INC(ch);
  INC(ch); INC(ch); INC(ch); INC(ch); RETURN; RETURN; RETURN; RETURN;
END proc2;

PROCEDURE proc1;
(* $[- keep procedure names *)

  (* proc 35 *)
  PROCEDURE Number;
  VAR local2: CARDINAL;
  VAR local3: CARDINAL;
  VAR local4: CARDINAL;
  VAR local5: CARDINAL;
  VAR local6: CARDINAL;
  VAR local7: INTEGER;
  VAR local8: BOOLEAN;
  VAR local9 : BOOLEAN;
  VAR local10: BOOLEAN;
  VAR local12: LONGINT;
  VAR local14: LONGINT;
  VAR local16: LONGINT;
  VAR local18: LONGINT;
  
  (* $[+ remove procedure names *)
  
    (* proc 36 *)
    PROCEDURE Ten(exp: CARDINAL): REAL;
    VAR n: CARDINAL;
    VAR r: REAL;
    BEGIN
      n := 0;
      r := 1.0;
      REPEAT
        IF ODD(exp) THEN
          CASE n OF
          | 0 : r := r * 1.0E01
          | 1 : r := r * 1.0E02
          | 2 : r := r * 1.0E04
          | 3 : r := r * 1.0E08
          | 4 : r := r * 1.0E16
          | 5 : r := r * 1.0E32
          ELSE RAISE REALOVERFLOW
          END;
        END;
        exp := exp DIV 2;
        INC(n);
      UNTIL exp = 0;
      RETURN r
    END Ten;
  
    PROCEDURE proc37;
    VAR digit: CARDINAL;
    BEGIN
      IF global30 < 128 THEN global11[global30] := global3; INC(global30) END;
      proc2;
      digit := ORD(global3) - ORD('0');
      IF digit > 9 THEN
        IF digit >= 17 THEN digit := digit - 7 ELSE digit := 16 END;
      END; (* 043C *)
      local4 := digit
    END proc37;
  
  (* $[- keep procedure names *)
  BEGIN (* Number *)
    local2  := 0;
    local12 := LONG(0);
    local7  := 0;
    local18 := local12;
    local16 := local12;
    local14 := local12;
    global30:= 0;
    local4  := ORD(global3) - ORD('0');
    local5  := local4;
    local10 := TRUE;
    local9  := TRUE;
    REPEAT
      IF local5 > 7 THEN
        local10 := FALSE;
        IF local5 > 9 THEN local9 := FALSE END;
      END;
      IF local4 <= 9 THEN
        local14 := local14 * LONG(10) + LONG(local4);
        IF local14 < 3355443L THEN local12 := local14 ELSE INC(local7) END;
        IF local4 <= 7 THEN local16 := local16 * LONG(8) + LONG(local4) END;
      END; (* 04b1 *)
      IF local18 <= LONG(65535) THEN local18 := local18 * LONG(16) + LONG(local4) END;
      local5 := local4;
      proc37;
    UNTIL local4 > 15;
    global12 := Compiler.CardType;
    IF global3 = '.' THEN
      proc37;
      IF    global3 = '.' THEN global3 := DEL; DEC(global30)
      ELSIF global3 = ')' THEN global3 := ']'; DEC(global30)
      ELSE
        IF NOT local9 THEN proc26(30) END;
        global12 := Compiler.RealType;
        WHILE local4 <= 9 DO
          IF local12 < 3355443L THEN
            local12 := local12 * LONG(10) + LONG(local4);
            DEC(local7)
          END; (* 0527 *)
          proc37;
        END; (* 052B *)
        IF local4 IN {13, 14} THEN
          IF local4 = 13 THEN global12 := Compiler.LongrealType END;
          local3 := 0;
          proc37;
          local8 := (global3 = '-');
          IF local8 OR (global3 = '+') THEN proc37 END;
          IF local4 > 9 THEN proc26(30) END;
          REPEAT
            IF local3 < 255 THEN local3 := local3 * 10 + local4 END;
            proc37;
          UNTIL local4 > 9;
          IF local8
          THEN DEC(local7, local3)
          ELSE INC(local7, local3)
          END;
        END; (* 0577 *)
        IF global12 = Compiler.RealType THEN
          IF local12 >= 16777216L
          THEN global14 := FLOAT((local12 + LONG(1)) DIV LONG(2)) * 2.0
          ELSE global14 := FLOAT(local12)
          END;
          IF    local7 < 0 THEN global14 := global14 / Ten(-local7)
          ELSIF local7 # 0 THEN global14 := global14 * Ten(local7)
          END;
        ELSE
          global11[global30] := 0C;
          IF NOT Doubles.StrToDouble(global11, global17) THEN proc26(74) END;
        END;
      END;
    END; (* 05D4 *)
    IF global12^.word4 # 8 THEN
      IF global3 = 'L' THEN
        proc37;
        global14 := REAL(local14);
        global12 := Compiler.LongintType;
      ELSE
        local6 := 65535;
        IF global3 = 'H' THEN proc37; local12 := local18
        ELSE
          IF local5 IN {11, 12} THEN
            IF NOT local10 THEN proc26(30) END;
            local12 := local16;
            IF local5 = 12 THEN global12 := Compiler.CharType; local6 := 255 END;
          ELSE
            IF NOT local9 OR (local5 > 9) THEN proc26(30) END;
            local12 := local14;
          END;
        END; (* 062e *)
        IF local12 > LONG(local6) THEN proc26(73) END;
        global7 := CARD(local12);
      END;
    END; (* 063f *)
    IF global24^[ORD(global3)] = 10 THEN proc26(30) END;
  EXCEPTION
  | OVERFLOW: proc26(73)
  | REALOVERFLOW: 
      IF local7 >= 0 THEN proc26(74) END;
      global14 := REAL(0L);
  END Number;
  
(* $[+ remove procedure names *)
  PROCEDURE proc38;
  VAR local2: CARDINAL;
  BEGIN
    REPEAT
      REPEAT
        IF global3 = CHR(255) THEN proc26(29) END;
        proc2;
        IF global3 = '(' THEN
          REPEAT proc2 UNTIL global3 # '(';
          IF global3 = '*' THEN proc38 END; (* recursive call *)
        END;
        IF global3 = '$' THEN
          proc2;
          local2 := CARDINAL(BITSET(global3) * {0,1,2,3,4,6}) - ORD('L');
          IF local2 <= 15 THEN
            proc2;
            IF    global3 = '-' THEN EXCL(global2, local2)
            ELSIF global3 = '+' THEN INCL(global2, local2)
            END;
            IF local2 = 0 THEN Texts.WriteLn(2) END;
          END;
        END; (* 06c6 *)
      UNTIL global3 = '*';
      REPEAT proc2 UNTIL global3 # '*';
    UNTIL global3 = ')';
  END proc38;

  PROCEDURE scanNextToken():BOOLEAN; (* original was in Z80 code *)
  VAR i: CARDINAL;
  VAR local3: CARDINAL;
  BEGIN
    global6 := FALSE;
    global9 := 7;
    WHILE global3 <= ' ' DO proc2 END;
    global25 := filePos - 1;
    global26 := column;
    IF global3 < CHR(128)
    THEN global5 := global24^[ORD(global3)]
    ELSE global5 := 0
    END;
    IF global5 = 10 THEN
      i := 0;
      REPEAT
        IF i # 128 THEN global11[i] := global3; INC(i) END;
        proc2;
        local3 := global24^[ORD(global3)];
      UNTIL (local3 # 10) AND (local3 # 11);
      global11[i] := 0C;
      RETURN TRUE
    END; (* 0730 *)
    RETURN FALSE;
    (* padding to compensate for smaller code *)
    i := i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i+i
  END scanNextToken;

VAR local2: BOOLEAN;
    local3: CARDINAL;
    local4: BOOLEAN;
    local5: CHAR;
BEGIN
  REPEAT
    IF scanNextToken() THEN
      local4 := 9 IN global2;
      global5 := procPtr27(ADR(global11), local4);
      IF global5 # 0 THEN
        global9 := 7;
        IF ((global5 = 14) OR (global5 = 39)) AND NOT (12 IN global2) THEN
          Errors.proc3(2)
        END;
        RETURN
      END; (* 0797 *)
      global13 := ADDRESS(SymTab.global9);
      REPEAT
        global8  := FindIdent(ADR(global13^.link1), ADR(global11), local4);
        IF global8 # NIL THEN
          global12 := ADDRESS(global8^.word2);
          global9  := global8^.word4;
          global10 := global8^.word3;
          RETURN
        END;
        global13 := global13^.link0;
      UNTIL global13 = NIL;
      global9 := 0;
      RETURN
    END; (* 07BA *)
    local2 := TRUE;
    CASE global5 OF
    | 0 : proc26(31 - ORD(global3 = CHR(255)) * 2)
    | 2 : proc2;
          IF    global3 = '=' THEN global5 := 27; proc2
          ELSIF global3 = ')' THEN global5 := 7; proc2
          END;
    | 3 : proc2;
          IF    global3 = '.' THEN global5 := 4; proc2
          ELSIF global3 = ')' THEN global5 := 6; proc2
          END;
    |11 : global6 := TRUE;
          global9 := 1;
          global5 := 0;
          Number;
          global11[global30] := 0C
    |12 : local3  := 0;
          global6 := TRUE;
          global9 := 1;
          global5 := 0;
          local5  := global3;
          proc2;
          WHILE global3 # local5 DO
            IF global3 = LINEFEED THEN proc26(28) END;
            IF global3 = CHR(255) THEN proc26(29) END;
            IF local3 < 128 THEN
              global11[local3] := global3;
              INC(local3);
            END;
            proc2;
          END; (* 0839 *)
          global11[local3] := 0C;
          proc2;
          global12 := Compiler.global12;
          IF local3 = 1 THEN
            global12 := Compiler.CharType;
            global7  := ORD(global11[0]);
          END;
    ELSE
          proc2;
          CASE global5 OF
          | 43:  IF global3 = '*' THEN proc38; proc2; local2 := FALSE
              ELSIF global3 = '.' THEN global5 := 44; proc2
              ELSIF global3 = ':' THEN global5 := 45; proc2
              END;
          | 54:  IF global3 = '=' THEN global5 := 56; proc2 
              ELSIF global3 = '>' THEN global5 := 53; proc2
              END;
          | 55:  IF global3 = '=' THEN global5 := 57; proc2 END;
          END;
    END;
  UNTIL local2;
END proc1;

PROCEDURE proc4(param1: CARDINAL): BOOLEAN;
BEGIN
  IF global5 = param1 THEN proc1; RETURN TRUE END;
  RETURN FALSE
END proc4;

PROCEDURE proc3;
BEGIN
  IF global9 = 6 THEN
    global29^.word1 := ADDRESS(global8^.high);
    global29^.word0 := ADDRESS(SymTab.global9);
    SymTab.global9  := ADDRESS(global29);
    proc1;
    proc8(3);
    proc12;
    IF global13 # ADDRESS(global29) THEN Errors.proc2(3, global11) END;
    SymTab.global9  := SymTab.global9^.w0;
  END;
END proc3;

PROCEDURE proc8(param1:CARDINAL);
VAR local2: BITSET;
VAR local3: CARDINAL;
BEGIN
  IF global5 = param1 THEN proc1; RETURN END;
  local3 := 0;
  local2 := {};
  IF    param1 >= 51 THEN local3 := 51
  ELSIF param1 >= 40 THEN local3 := 40
  ELSIF param1 >= 27 THEN local3 := 27
  ELSIF param1 >= 13 THEN local3 := 13
  END;
  local2 := local2 + {param1 - local3};
  Errors.proc16(local2, local3)
END proc8;

PROCEDURE proc9(param1: BITSET);
BEGIN
  IF NOT (global5 IN param1) THEN Errors.proc16(param1, 0) END;
END proc9;

PROCEDURE proc10(param1: BITSET);
BEGIN
  IF NOT ((global5-40) IN param1) THEN Errors.proc16(param1, 40) END;
END proc10;

PROCEDURE proc11(param1: BITSET);
BEGIN
  IF NOT ((global5-13) IN param1) THEN Errors.proc16(param1, 13) END;
END proc11;

PROCEDURE proc12;
BEGIN
  IF (global9 = 7) OR global6 THEN
    Errors.proc8('A');
    Texts.WriteString(3, "Identifier");
    Texts.WriteString(3, EXPECTED);
    Errors.Allocate;
    Errors.proc9;
  END;
END proc12;

PROCEDURE proc21(VAR param2: ARRAY OF CHAR);
BEGIN
  proc12;
  IF StrCmp(ADR(global11), ADR(param2), 9 IN global2) THEN proc1; RETURN END;
  Errors.proc2(9, param2);
END proc21;

PROCEDURE proc13(param1: CARDINAL);
BEGIN
  IF global9 # param1 THEN
    proc12;
    IF global9 = 0 THEN Errors.proc2(0, global11) END;
    Errors.proc8('B');
    Errors.proc6(param1);
    Texts.WriteString(3, EXPECTED);
    Errors.proc6(global9);
    Texts.WriteString(3, " found");
    Errors.proc9;
  END;
END proc13;

PROCEDURE Compile;

  (* Z80 proc 40 removed, replaced by a MCode one in module VarAddr *)
  (*
  PROCEDURE VarAddress(VAR v: WORD):ADDRESS;
  CODE("Z80RET")
  END VarAddress;
  *)

VAR addr: ADDRESS;
    ptr       [006EH]: CARDINAL;
    console   [0072H]: BOOLEAN;
    jmpOpcode [0074H]: CARDINAL;
    jmpAddress[0075H]: CARDINAL;

(* $[- keep procedure names *)

BEGIN
  jmpOpcode := 0C3H;
  addr      := VarAddr.ADR(global2)-6;
  addr      := ADDRESS(addr^) - 4;
  jmpAddress:= addr + CARDINAL(addr^) + 3;
  MARK(addr);
  ptr       := 0;
  console   := (ComLine.outName = "CON:");
  global23  := FALSE;
  global25  := 0;
  Allocate(global29, 14);
  Compiler.proc2;
  IF global16 <> NIL THEN
    Allocate(global21, 4096);
    Loader.Call("COMPILE");
    IF Compiler.global25 THEN
      proc6(global21 + CodeGen.global2);
      IF CodeGen.global3 <> 0 THEN
        MOVE(global21, global21 + CodeGen.global3, CodeGen.global2 - CodeGen.global3);
        Files.SetPos(global4, LONG(0));
        IF Files.ReadBytes(global4, global21, CodeGen.global3) <> CodeGen.global3 THEN
          RAISE Files.EndError
        END;
      END;
      Files.SetPos(global4, LONG(0));
      Loader.Call("GENZ80");
    END;
  END;
  Texts.CloseText(Texts.output);
  RELEASE(addr);

EXCEPTION Loader.LoadError:
  Texts.WriteLn(3); (* console *)
  Texts.WriteString(3,"ERROR: CANNOT LOAD OVERLAY");
  Texts.WriteLn(3);
  Files.Delete(global4);
  RELEASE(addr)
END Compile;

(* $[+ remove procedure names *)
END Scanner.

