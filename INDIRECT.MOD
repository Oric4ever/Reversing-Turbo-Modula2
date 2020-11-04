IMPLEMENTATION MODULE Indirect;
FROM SYSTEM IMPORT BYTE, WORD, ADR;
IMPORT Stack;

TYPE ByteArrayPointer = POINTER TO ARRAY [0..0FFFFH] OF BYTE;
     WordArrayPointer = POINTER TO ARRAY [0..0FFFFH] OF CARDINAL;
     DoubleArrPointer = POINTER TO ARRAY [0..0FFFFH] OF LONGINT;

(* $O- don't check overflows except when explicitly required *)
(* $T- don't test array indices *)

PROCEDURE Load(n: CARDINAL);
VAR indirectPointer : WordArrayPointer;
BEGIN
  indirectPointer := Stack.PointerPop();
  Stack.Push( indirectPointer^[n] )
END Load;

PROCEDURE LoadDouble(n: CARDINAL);
VAR indirectPointer : WordArrayPointer;
BEGIN
  indirectPointer := Stack.PointerPop();
  Stack.Push( indirectPointer^[n+1] );
  Stack.Push( indirectPointer^[n] )
END LoadDouble;

PROCEDURE LoadQuad(n: CARDINAL);
VAR indirectPointer : WordArrayPointer;
BEGIN
  indirectPointer := Stack.PointerPop();
  Stack.Push( indirectPointer^[n+3] );
  Stack.Push( indirectPointer^[n+2] );
  Stack.Push( indirectPointer^[n+1] );
  Stack.Push( indirectPointer^[n+0] );
END LoadQuad;

PROCEDURE Store(n: CARDINAL);
VAR indirectPointer : WordArrayPointer;
    op : CARDINAL;
BEGIN
  op := Stack.Pop();
  indirectPointer := Stack.PointerPop();
  indirectPointer^[n] := op
END Store;

PROCEDURE StoreDouble(n: CARDINAL);
VAR indirectPointer : WordArrayPointer;
    lsw, msw : CARDINAL;
BEGIN
  lsw := Stack.Pop(); msw := Stack.Pop();
  indirectPointer := Stack.PointerPop();
  indirectPointer^[n]   := lsw;
  indirectPointer^[n+1] := msw;
END StoreDouble;

PROCEDURE StoreQuad(n: CARDINAL);
VAR indirectPointer : WordArrayPointer;
    w1, w2, w3, w4 : CARDINAL;
BEGIN
  w1 := Stack.Pop(); w2 := Stack.Pop(); w3 := Stack.Pop(); w4 := Stack.Pop();
  indirectPointer := Stack.PointerPop();
  indirectPointer^[n+0] := w1;
  indirectPointer^[n+1] := w2;
  indirectPointer^[n+2] := w3;
  indirectPointer^[n+3] := w4;
END StoreQuad;

PROCEDURE LoadAddr(n: CARDINAL);
VAR indirectPointer : WordArrayPointer;
BEGIN
  indirectPointer := Stack.PointerPop();
  Stack.Push( ADR(indirectPointer^[n]) )
END LoadAddr;

END Indirect.
