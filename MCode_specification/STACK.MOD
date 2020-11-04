IMPLEMENTATION MODULE Stack;

TYPE Union = RECORD
               CASE : CARDINAL OF
               | 1 : w1,w2,w3,w4: WORD;
               | 2 : long : LONGINT;
               | 3 : real : REAL;
               | 4 : double : LONGREAL;
               END;
             END;

VAR sp : ADDRESS;
    stackLimit [0316H]: ADDRESS;

EXCEPTION StackOverflow;

PROCEDURE Top(): CARDINAL;
BEGIN
  RETURN CARDINAL(sp^)
END Top;

PROCEDURE Push(w: WORD);
BEGIN
  DEC(sp,2);  sp^ := w
END Push;

PROCEDURE Load(w: WORD); (* same as push *)
BEGIN
  DEC(sp,2);  sp^ := w
END Load;

PROCEDURE DPush(l: LONGINT);
VAR union: Union;
BEGIN
  union.long := l;  Push(union.w2); Push(union.w1)
END DPush;

PROCEDURE FPush(f: REAL);
VAR union: Union;
BEGIN
  union.real := f; Push(union.w2); Push(union.w1)
END FPush;

PROCEDURE QPush(g: LONGREAL);
VAR u: Union;
BEGIN
  u.double := g; Push(u.w4); Push(u.w3); Push(u.w2); Push(u.w1)
END QPush;

PROCEDURE Pop(): CARDINAL;
VAR i: CARDINAL;
BEGIN
  i := CARDINAL(sp^); INC(sp,2); RETURN i
END Pop;

PROCEDURE BPop(): BOOLEAN;
VAR b: BOOLEAN;
BEGIN
  b := BOOLEAN(sp^); INC(sp,2); RETURN b
END BPop;

PROCEDURE IPop(): INTEGER;
VAR i: INTEGER;
BEGIN
  i := INTEGER(sp^); INC(sp,2); RETURN i
END IPop;

PROCEDURE DPop(): LONGINT;
VAR union: Union;
BEGIN
  union.w1 := sp^; INC(sp,2);
  union.w2 := sp^; INC(sp,2);
  RETURN union.long
END DPop;

PROCEDURE FPop(): REAL;
VAR union: Union;
BEGIN
  union.w1 := sp^; INC(sp,2);
  union.w2 := sp^; INC(sp,2);
  RETURN union.real
END FPop;

PROCEDURE QPop(): LONGREAL;
VAR u: Union;
BEGIN
  u.w1 := sp^; INC(sp,2);
  u.w2 := sp^; INC(sp,2);
  u.w3 := sp^; INC(sp,2);
  u.w4 := sp^; INC(sp,2);
END QPop;

PROCEDURE PointerPop(): ADDRESS;
VAR p: ADDRESS;
BEGIN
  p := ADDRESS(sp^); INC(sp,2); RETURN p
END PointerPop;

PROCEDURE Dup;
BEGIN
  Push( sp^ )
END Dup;

PROCEDURE Swap;
VAR top, newTop: WORD;
BEGIN
  top    := Pop();
  newTop := sp^;
  sp^    := top;
  Push( newTop )
END Swap;

PROCEDURE NewFrame(oldFramePointer, outerFramePointer: ADDRESS): ADDRESS;
BEGIN
  Push(oldFramePointer);
  Push(outerFramePointer);
  RETURN sp
END NewFrame;

PROCEDURE ResetFrame(framePointer: ADDRESS);
BEGIN
  sp := framePointer
END ResetFrame;

PROCEDURE Drop;
BEGIN
  INC(sp, 2)
END Drop;

PROCEDURE DropN(nbWords: CARDINAL);
BEGIN
  INC(sp, nbWords*2)
END DropN;

PROCEDURE Reserve(size: CARDINAL): ADDRESS;
BEGIN
  IF sp - size < stackLimit THEN RAISE StackOverflow END;
  DEC(sp, size);
  RETURN sp
END Reserve;

PROCEDURE ReserveString;
VAR src : POINTER TO ARRAY [0..0FFFFH] OF WORD;
    nbWords : CARDINAL;
BEGIN
  src     := ADDRESS(Pop());
  nbWords := (Pop() + 1) DIV 2;
  IF sp - nbWords*2 < stackLimit THEN RAISE StackOverflow END;
  WHILE nbWords > 0 DO
    DEC(nbWords);
    Push( src^[nbWords] )
  END;
  Push( sp )
END ReserveString;

END Stack.
