IMPLEMENTATION MODULE COMPILER;
IMPORT SCANNER, Files, SYMTAB, ERRORS, Texts, Terminal, ComLine;
FROM SYSTEM IMPORT ADDRESS, ADR, WORD, BDOS, IORESULT;
FROM STORAGE IMPORT FREEMEM;

(* $[+ remove procedure names *)

VAR 
    global27: RecordPtr;
    global28: RecordPtr;
    global29: RecordPtr;
    global30: RecordPtr;
    global31: RecordPtr;
    global32: RecordPtr;
    global33: RecordPtr;
    global34: RecordPtr;
    global35: ArrayPtr;

PROCEDURE PROC1; FORWARD;
PROCEDURE GETINP; FORWARD;

PROCEDURE PROC3(keyword: ARRAY OF CHAR; n: CARDINAL):ADDRESS;
VAR ptr : RecordPtr;
BEGIN
  ptr := SCANNER.proc15(n);
  SCANNER.proc16(ptr^.word1, keyword);
  ptr^.word0 := global31;
  ptr^.word3 := 64;
  global31 := ptr;
  RETURN ptr
END PROC3;

PROCEDURE PROC4(keyword: ARRAY OF CHAR; param3: RecordPtr;
                param2: WORD; n:CARDINAL);
VAR ptr: RecordPtr;
BEGIN 
  ptr := PROC3(keyword, n);
  ptr^.word2 := param3;
  ptr^.word5 := param2;
END PROC4;


PROCEDURE PROC5(keyword: ARRAY OF CHAR; param2,param1: WORD);
VAR ptr: RecordPtr;
BEGIN
  ptr := PROC3(keyword, 5);
  ptr^.word5 := param2;
  ptr^.high := param1;
END PROC5;

PROCEDURE PROC6(keyword: ARRAY OF CHAR; param1: CARDINAL);
BEGIN 
  PROC5(keyword, param1, 0);
  global31^.word3 := 192;
END PROC6;


PROCEDURE PROC7(keyword: ARRAY OF CHAR; param2: CARDINAL; param1: RecordPtr);
BEGIN 
  PROC6(keyword, param2);
  global31^.word2 := param1;
END PROC7;


PROCEDURE PROC8(param2,param1: CARDINAL): RecordPtr;
VAR ptr : RecordPtr;
BEGIN
  ptr := SCANNER.proc14(param1);
  ptr^.word3 := param2;
  RETURN ptr
END PROC8;


PROCEDURE PROC9(keyword: ARRAY OF CHAR; tsize, id: CARDINAL): ADDRESS;
VAR ptr, ptr2 : RecordPtr;
BEGIN 
  ptr := PROC3(keyword, 3);
  ptr2:= PROC8(tsize, id);
  ptr^.word2 := ptr2;
  ptr2^.word0:= ptr;
  RETURN ptr2
END PROC9;


PROCEDURE PROC10;
  VAR n: CARDINAL;

  PROCEDURE PROC11(char1,char2: CHAR; param1: CARDINAL);
  BEGIN
    ERRORS.global3^[n]   := char1;
    ERRORS.global3^[n+1] := char2;
    ERRORS.global3^[n+2] := CHR(param1);
    INC(n,3);
  END PROC11;
BEGIN 
  SCANNER.proc7(ERRORS.global3, 27);
  n := 0;
  PROC11(':','=',27);
  PROC11('.','.', 4);
  PROC11('<','=',56);
  PROC11('>','=',57);
  PROC11('<','>',53);
  PROC11('(','.',44);
  PROC11('.',')', 6);
  PROC11('(',':',45);
  PROC11(':',')', 7);
END PROC10;

PROCEDURE PROC12;
CONST DEL = 177C;
VAR i: CARDINAL;
    local3: ARRAY [0..64] OF CHAR;
    code : CARDINAL;
BEGIN 
  SCANNER.proc7(SCANNER.global24, 128);
  i := ORD('A');
  REPEAT
    SCANNER.global24^[i]    := CHR(10);
    SCANNER.global24^[i+32] := CHR(10);
    INC(i);
  UNTIL i > ORD('Z');
  i := ORD('0'); REPEAT SCANNER.global24^[i] := CHR(11); INC(i) UNTIL i > ORD('9');
  SCANNER.global24^[ORD('!')] := CHR(8);
  SCANNER.global24^[ORD('~')] := CHR(66);
  SCANNER.global24^[ORD(DEL)] := CHR(4);
  SCANNER.global24^[ORD('"')] := CHR(12);
  local3 := " ,:. )]}|;  '                              ([{^     =#<>  +-*  /&";
  code := 0;
  REPEAT
    IF local3[code] <> ' ' THEN SCANNER.global24^[ORD(local3[code])]:=CHR(code) END;
    INC(code)
  UNTIL code > 64;
END PROC12;

PROCEDURE PROC13; 
VAR p: POINTER TO ARRAY [0..29] OF CARDINAL;
BEGIN 
  SCANNER.proc7(global5, 30*2);
  p := global5;
  p^[ 0] :=  730;
  p^[ 1] :=  731;
  p^[ 2] := 1245;
  p^[ 3] := 1206;
  p^[ 4] :=  999;
  p^[ 5] := 1258;
  p^[ 6] := 1127;
  p^[ 7] :=  708;
  p^[ 8] := 1312;
  p^[ 9] := 1234;
  p^[10] :=  979;
  p^[11] :=  990;
  p^[12] :=  991;
  p^[13] :=  747;
  p^[14] :=  257;
  p^[15] := 1248;
  p^[16] :=  993;
  p^[17] :=  304;
  p^[18] :=   49;
  p^[19] := 1229;
  p^[20] := 1230;
  p^[21] := 1231;
  p^[22] := 1236;
  p^[23] := 1024;
  p^[24] := 1281;
  p^[25] :=  770;
  p^[26] :=  772;
  p^[27] :=    0;
  p^[28] :=  195;
  p^[29] :=   80;
END PROC13;


PROCEDURE PROC14; 
VAR p : RecordPtr;
BEGIN 
  global31 := global33;
  IntType  := PROC9("INTEGER" ,2,2);
  CharType := PROC9("CHAR"    ,1,0); CharType^.high := 255;
  BooleanType := PROC9("BOOLEAN" ,1,0); BooleanType^.high := 1;
  CardType  := PROC9("CARDINAL",2,2);
  RealType  := PROC9("REAL"    ,4,8);
  LongrealType := PROC9("LONGREAL",8,8);
  BitsetType := PROC9("BITSET"  ,2,4);

  global34 := PROC8(1,1); global34^.word2 := CardType; global34^.high := 15;
  BitsetType^.word2 := global34;

  ProcType := PROC9("PROC"    ,4,9);
  LongintType := PROC9("LONGINT" ,4,7);

  global33 := global31;
  global31 := global32;
  WordType := PROC9("WORD"    ,2,3);
  AddressType  := PROC9("ADDRESS" ,2,2);
  ByteType := PROC9("BYTE"    ,1,1); ByteType^.word2 := WordType;
  ByteType^.high := 255;

  p := PROC3("PROCESS",3);
  p^.word2 := AddressType;
  global17 := AddressType;
  global32 := global31;

  global12 := PROC8(0,11); global12^.word5 := CharType;
END PROC14;


PROCEDURE PROC15(param3: CARDINAL; param2: CARDINAL; param1: RecordPtr): ADDRESS;
VAR p : ArrayPtr;
BEGIN
  SCANNER.proc7(p, (param3+2)*2);
  p^[0] := param3;
  p^[1] := param2;
  p^[2] := param1;
  global35 := p;
  RETURN p
END PROC15;

PROCEDURE PROC16; 
BEGIN 
  global31 := global33;
  PROC4("TRUE" ,BooleanType,1,1);
  PROC4("FALSE",BooleanType,0,1);
  PROC4("NIL"  ,AddressType ,0,1);

  PROC6("READ"    , 0);
  PROC6("READLN"  , 1);
  PROC6("WRITE"   , 2);
  PROC6("WRITELN" , 3);
  PROC6("NEW"     , 4);
  PROC6("DISPOSE" , 5);
  PROC6("INC"     , 6);
  PROC6("DEC"     , 7);
  PROC6("INCL"    , 8);
  PROC6("EXCL"    , 9);
  PROC7("CARD"    , 0, CardType);
  PROC7("INT"     , 1, IntType);
  PROC7("LONG"    , 2, LongintType);
  PROC7("FLOAT"   , 3, RealType);
  PROC7("ABS"     , 4, CardType);
  PROC7("DOUBLE"  , 5, LongrealType);
  PROC7("ORD"     , 6, CardType);
  PROC7("CHR"     , 7, CharType);
  PROC7("ODD"     , 8, BooleanType);
  PROC7("HIGH"    , 9, CardType);
  PROC7("SIZE"    ,11, CardType);
  PROC7("VAL"     ,13, CardType);
  PROC7("MIN"     ,14, CardType);
  PROC7("MAX"     ,15, CardType);
  PROC5("CAP"     , 6, PROC15(1, 0, CharType));
  global31^.word2 := CharType;
  PROC5("HALT"    , 2, NIL);
  PROC5("TRUNC"   , 8, PROC15(1, 0, RealType));
  global31^.word2 := CardType;
  SCANNER.proc7(global4, 14);
  global4^.word0  := NIL;
  global4^.word1  := global31;
END PROC16;

PROCEDURE PROC17; 
VAR p: RecordPtr;
BEGIN
  global31 := global32;
  PROC4("IORESULT"     , CardType, 0300H, 4); global31^.word3 := 256;
  PROC4("HLRESULT"     , CardType, 0302H, 4); global31^.word3 := 256;
  PROC4("BADOVERLAY"   , NIL    , 1, 2);
  PROC4("OUTOFMEMORY"  , NIL    , 5, 2);
  PROC4("REALOVERFLOW" , NIL    ,11, 2);
  PROC4("OVERFLOW"     , NIL    ,12, 2);

  PROC6("CODE"      ,10);
  PROC7("ADR"       ,10, AddressType);
  PROC7("TSIZE"     ,12, CardType);
  PROC5("BREAK"     , 0, NIL);
  PROC5("TRANSFER"  ,15, PROC15(2, 3, global17)); global35^[3] := global17;
  PROC5("IOTRANSFER",16, PROC15(3, 6, AddressType));
  global35^[3] := global17;
  global35^[4] := global17;
  PROC5("NEWPROCESS",17, PROC15(4, 1, global17));
  global35^[3] := CardType;
  global35^[4] := AddressType;
  global35^[5] := ProcType;
  p := PROC15(2, 0, WordType);
  global35^[3] := WordType;
  PROC5("BDOS"    , 1, p);
  PROC5("BIOS"    ,18, p);
  PROC5("MOVE"    ,19, PROC15(3, 0, CardType));
  global35^[3] := AddressType;
  global35^[4] := AddressType;
  PROC5("FILL"    ,20, PROC15(3, 0, ByteType));
  global35^[3] := CardType;
  global35^[4] := AddressType;
  PROC5("INP"     ,21, PROC15(1, 0, WordType)); global31^.word2 := CardType;
  PROC5("OUT"     ,22, p);

  SCANNER.proc7(global23, 14);
  global23^.word0 := global4;
  global23^.word1 := global31;

  global31 := NIL;
  PROC5("SYSTEM"  , 0, NIL);
  global31^.word4 := 6;
  global31^.word3 := 1089;
  global31^.high := global23^.word1;
  global20 := global31;
END PROC17;



PROCEDURE PROC18; 
VAR p: RecordPtr;
BEGIN 
  global31 := NIL;
  global22 := PROC15(2,2,CardType);
  global35^[3] := AddressType;
  p := PROC15(1,1,AddressType);
  PROC5("ALLOCATE"  , 10, global22);
  PROC5("DEALLOCATE", 11, global22);
  PROC5("MARK"      , 12, p);
  PROC5("RELEASE"   , 13, p);
  PROC5("FREEMEM"   , 14, NIL);
  global31^.word2 := CardType;
  SCANNER.proc7(global24, 14);
  global24^.word0 := global4;
  global24^.word1 := global31;

  global31 := NIL;
  PROC5("STORAGE"   ,  0, NIL);
  global31^.word4 := 6;
  global31^.word3 := 1089;
  global31^.high := global24^.word1;
  global21 := global31;
END PROC18;

(* $[- retain procedure name because of exception handler *)
PROCEDURE GETINP; 
CONST DRVROVEC = 29;
VAR local2 : ARRAY [0..2] OF CHAR;
    char : CHAR;
BEGIN 
  SCANNER.ProcType := NIL;
  SCANNER.global4  := NIL;
  Texts.ReadString(ComLine.commandLine, local2);
  IF NOT Files.Open(SCANNER.ProcType, ComLine.inName) THEN
    Terminal.WriteString(ComLine.inName);
    Terminal.WriteString(" not found.");
    Terminal.WriteLn;
  ELSE
    ComLine.RedirectOutput;
    BDOS(DRVROVEC, 0);
    IF ORD(ComLine.inName[0])-ORD('A') IN BITSET(IORESULT) THEN Files.ResetSys() END;
    ComLine.outName := ComLine.inName;
    SCANNER.proc25(ComLine.outName, "@@@", TRUE);
    Texts.ReadString(ComLine.commandLine, local2);
    IF (local2[1] = ':') AND (local2[2] = 0C) THEN
      char := CAP(local2[0]);
      IF ORD(char)-ORD('A') <= 15 THEN ComLine.outName[0] := char END;
    END;
    Files.Create(SCANNER.global4, ComLine.outName);
    Files.NoTrailer(SCANNER.ProcType);
    Files.ReadByte(SCANNER.ProcType, char);
    Files.SetPos(SCANNER.ProcType, LONG(0));
  END;
EXCEPTION Files.UseError:
  Files.ResetSys();
  Files.Create(SCANNER.global4, ComLine.outName);
END GETINP;

(* $[+ remove procedure names *)

PROCEDURE PROC1; 
VAR local2: ARRAY [0..2] OF CHAR;
    option : CARDINAL;
    compilerOptions[0348H] : BITSET;
BEGIN 
  global25 := FALSE;
  global26 := TRUE;
  global33 := NIL;
  global32 := NIL;
  PROC10;
  PROC12;
  PROC13;
  PROC14;
  PROC16;
  PROC17;
  PROC18;
  SCANNER.global2 := compilerOptions;
  global2 := 2 IN SCANNER.global2;
  Texts.ReadString(ComLine.commandLine, local2);
  IF local2[0] = '%' THEN
    option := ORD(CAP(local2[1])) - ORD('L');
    IF option <= 15 THEN INCL(SCANNER.global2, option) END;
  END;
  ERRORS.global4 := FALSE;
  SCANNER.proc7(SYMTAB.IntType, 170);
  SCANNER.proc7(SYMTAB.CardType, 170);
  SCANNER.proc7(SYMTAB.AddressType,  34);
  SCANNER.proc28;
  SCANNER.proc17(global4, 0);
  IF 5 IN SCANNER.global2 THEN Texts.WriteCard(3, FREEMEM(), 5) END;
END PROC1;
END COMPILER.

