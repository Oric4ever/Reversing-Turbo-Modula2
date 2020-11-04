IMPLEMENTATION MODULE Local;
FROM SYSTEM IMPORT ADR, ADDRESS;
IMPORT Stack;

TYPE WordPointer = POINTER TO ARRAY [0..0FFFFH] OF CARDINAL;

(* $O- don't check overflows except when explicitly required *)
(* $T- don't test array indices *)

PROCEDURE LoadParam(n: CARDINAL);
BEGIN
  Stack.Push( framePointer^[n] )
END LoadParam;

PROCEDURE StoreParam(n: CARDINAL);
BEGIN
  framePointer^[n] := Stack.Pop()
END StoreParam;

PROCEDURE Load(n: INTEGER); (* n is negative for local variables *)
BEGIN
  Stack.Push( framePointer^[CARDINAL(n)] )
END Load;

PROCEDURE LoadDouble(n: INTEGER); (* n is negative for local variables *)
BEGIN
  Stack.Push( framePointer^[CARDINAL(n+1)] );
  Stack.Push( framePointer^[CARDINAL(n)] );
END LoadDouble;

PROCEDURE LoadQuad(n: INTEGER); (* n is negative for local variables *)
BEGIN
  Stack.Push( framePointer^[CARDINAL(n+3)] );
  Stack.Push( framePointer^[CARDINAL(n+2)] );
  Stack.Push( framePointer^[CARDINAL(n+1)] );
  Stack.Push( framePointer^[CARDINAL(n+0)] );
END LoadQuad;

PROCEDURE Store(n: INTEGER);
BEGIN
  framePointer^[CARDINAL(n)] := Stack.Pop()
END Store;

PROCEDURE StoreDouble(n: INTEGER);
BEGIN
  framePointer^[CARDINAL(n)]   := Stack.Pop();
  framePointer^[CARDINAL(n+1)] := Stack.Pop()
END StoreDouble;

PROCEDURE StoreQuad(n: INTEGER);
BEGIN
  framePointer^[CARDINAL(n+0)] := Stack.Pop();
  framePointer^[CARDINAL(n+1)] := Stack.Pop();
  framePointer^[CARDINAL(n+2)] := Stack.Pop();
  framePointer^[CARDINAL(n+3)] := Stack.Pop();
END StoreQuad;

PROCEDURE LoadAddr(n: INTEGER); (* n is negative for local variables *)
BEGIN
  Stack.Push( ADR(framePointer^[CARDINAL(n)]) )
END LoadAddr;

PROCEDURE LoadUpperFrame(nbFramesUp: CARDINAL);
VAR ptr : ADDRESS;
BEGIN
  ptr := framePointer;
  WHILE nbFramesUp > 0 DO ptr := ADDRESS(ptr^); DEC(nbFramesUp) END;
  Stack.Push( ptr )
END LoadUpperFrame;

END Local.
