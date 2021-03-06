(*
    Perfect decompilation of original Terminal module.
    Uses BUSYREAD.COM and TERMCHAR.COM for Z80 implementation
    of BusyRead and WriteChar.
    Annoying bug in GotoXY.
*)
IMPLEMENTATION MODULE Terminal;
FROM SYSTEM IMPORT BDOS,BYTE,IORESULT,CODE;
CONST BACKSP=010C; TAB=011C; CR=015C; LF=012C;
      RECORDSEP=030C; UNITSEP=037C; DEL=177C;

VAR lastReadChar: CHAR;
    nbReadChars : CARDINAL;

(* $[+ remove procedure names *)

PROCEDURE ReadChar(VAR ch: CHAR);
BEGIN
  REPEAT BusyRead(ch) UNTIL ch <> 0C;
END ReadChar;

PROCEDURE BusyRead(VAR ch: CHAR);
CODE("BUSYREAD");
(* equivalent of :
VAR c: CHAR;
BEGIN
  c := lastReadChar;
  IF nbReadChars = 0 THEN BDOS(6,255); c := CHR(IORESULT) END;
  nbReadChars := 0;
  IF c <> 0C THEN lastReadChar := c END;
  ch := c
*)
END BusyRead;
  
PROCEDURE ReadAgain;
BEGIN
  nbReadChars := 1
END ReadAgain;

PROCEDURE ReadLine(VAR s: ARRAY OF CHAR);
VAR ch: CHAR;
    i : CARDINAL;
BEGIN
  i := 0;
  REPEAT
    ReadChar(ch);
    IF ch = TAB THEN ch := ' ' END;
    IF (ch = BACKSP) OR (ch = UNITSEP) OR (ch = DEL) THEN
      IF i <> 0 THEN
        WriteChar(BACKSP); WriteChar(' '); WriteChar(BACKSP);
        DEC(i)
      END;
    ELSIF ch = RECORDSEP THEN
      WHILE i <> 0 DO
        WriteChar(BACKSP); WriteChar(' '); WriteChar(BACKSP);
        DEC(i)
      END;
    ELSIF (ch < DEL) AND (ch <> CR) THEN
      s[i] := ch;
      IF ch < ' ' THEN Highlight; WriteChar(CHR(ORD(ch)+64)); Normal
      ELSE WriteChar(ch)
      END;
      INC(i)
    END;
  UNTIL (ch = CR) OR (i > HIGH(s));
  IF i <= HIGH(s) THEN s[i] := 0C END;
  WriteLn
END ReadLine;

PROCEDURE WriteChar(ch: CHAR);
CODE("TERMCHAR");
(* equivalent of
BEGIN
  BDOS(6, ch)
*)
END WriteChar;

PROCEDURE WriteLn;
BEGIN
  WriteChar(CR); WriteChar(LF)
END WriteLn;

PROCEDURE WriteString(s: ARRAY OF CHAR);
VAR i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i <= HIGH(s)) AND (s[i] <> 0C) DO
    WriteChar(s[i]);
    INC(i);
  END;
END WriteString;


TYPE 
  SystemParams = RECORD
       (*   0 *)   CompilerOptions: BITSET;
       (*   1 *)   searchDrives   : BITSET;
       (*   2 *)   ScannerOptions : BITSET;
       (*   3 *)   PipeCharacter  : CHAR;
       (*   4 *)   unknown        : CARDINAL;
       (*   5 *)   TerminalType   : ARRAY [0..21] OF CHAR;
       (*  16 *)   ColsAndRowsNums: ARRAY [0.. 1] OF BYTE;
       (*  17 *)   InitScreenSeq  : ARRAY [0..15] OF CHAR;
       (*  25 *)   ResetScreenSeq : ARRAY [0..15] OF CHAR;
       (*  33 *)   GotoXYseq      : ARRAY [0..15] OF CHAR;
       (*  41 *)   binaryXYparams : BOOLEAN;
       (*  42 *)   ColsAndRowsBase: ARRAY [0.. 1] OF BYTE;
       (*  43 *)   ColsAndRowsOffs: ARRAY [0.. 1] OF BYTE;
       (*  44 *)   GotoXYtempo    : CARDINAL;
       (*  45 *)   ClearScreenSeq : ARRAY [0..5] OF CHAR;
       (*  48 *)   HomeSeq        : ARRAY [0..5] OF CHAR;
       (*  51 *)   InsertLineSeq  : ARRAY [0..9] OF CHAR;
       (*  56 *)   DeleteLineSeq  : ARRAY [0..5] OF CHAR;
       (*  59 *)   InsDelHomeTempo: CARDINAL;
       (*  60 *)   ClearToEOLseq  : ARRAY [0..5] OF CHAR;
       (*  63 *)   NormalAttrSeq  : ARRAY [0..7] OF CHAR;
       (*  67 *)   HighlightSeq   : ARRAY [0..7] OF CHAR;
       (*  71 *)   OtherTempo     : CARDINAL;
       (*  72 *)   unknown2       : CARDINAL;
                 END;


VAR params   [0348H]: SystemParams;

PROCEDURE WriteEscSeq(VAR s: ARRAY OF CHAR; tempo: CARDINAL);
VAR i, length: CARDINAL;
BEGIN
  i := 1;  length := ORD(s[0]); WHILE i <= length DO WriteChar(s[i]); INC(i) END;
  i := 1;  length := tempo * 4; WHILE i <= length DO INC(i) END;
END WriteEscSeq;


PROCEDURE ClearScreen;
BEGIN
  WriteEscSeq(params.ClearScreenSeq, 0);
  WriteEscSeq(params.HomeSeq, params.InsDelHomeTempo); 
END ClearScreen;

PROCEDURE GotoXY(col,row: CARDINAL);
VAR coordNum, value: CARDINAL;
    divisor: CARDINAL;
    base   : CARDINAL;
    index  : CARDINAL;
BEGIN
  IF (col < numCols) AND (row < numRows) THEN
    divisor := 10; base := ORD('0');
    IF params.binaryXYparams THEN divisor := 256; base := 0 END;
    value    := col;
    coordNum := 0;
    REPEAT
      value    := value + ORD(params.ColsAndRowsBase[coordNum]);
      index    := ORD(params.ColsAndRowsOffs[coordNum]);
      REPEAT
        params.GotoXYseq[index] := CHR(value MOD divisor + base);
        value := value DIV divisor;
        DEC(index);
      UNTIL value = 0; (* Bug: this loop does not write the most 
                          significant bytes of the coordinates when
                          the coordinates are lower than the divisor,
                          very annoying for ANSI types Terminals. *)
      value := row;
      INC(coordNum)
    UNTIL coordNum > 1;
    WriteEscSeq(params.GotoXYseq, params.GotoXYtempo);
  END;
END GotoXY;

PROCEDURE ClearToEOL;
BEGIN
  WriteEscSeq(params.ClearToEOLseq, params.OtherTempo)
END ClearToEOL;
  
PROCEDURE InsertLine;
BEGIN
  WriteEscSeq(params.InsertLineSeq, params.InsDelHomeTempo)
END InsertLine;

PROCEDURE DeleteLine;
BEGIN
  WriteEscSeq(params.DeleteLineSeq, params.InsDelHomeTempo)
END DeleteLine;

PROCEDURE Highlight;
BEGIN
  WriteEscSeq(params.HighlightSeq, params.OtherTempo)
END Highlight;

PROCEDURE Normal;
BEGIN
  WriteEscSeq(params.NormalAttrSeq, params.OtherTempo)
END Normal;

PROCEDURE InitScreen;
BEGIN
  WriteEscSeq(params.InitScreenSeq, 0)
END InitScreen;

PROCEDURE ExitScreen;
BEGIN
  WriteEscSeq(params.ResetScreenSeq, 0);
END ExitScreen;

BEGIN
  numCols := ORD(params.ColsAndRowsNums[0]);
  numRows := ORD(params.ColsAndRowsNums[1]);
  IF params.ClearToEOLseq[0] <> 0C THEN INCL(available, clearEol) END;
  IF params.InsertLineSeq[0] <> 0C THEN INCL(available, insertDelete) END;
  IF params.HighlightSeq [0] <> 0C THEN INCL(available, highlightNormal) END;
END Terminal.
                
