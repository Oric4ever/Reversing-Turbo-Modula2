IMPLEMENTATION MODULE Global;
FROM SYSTEM IMPORT ADR;
IMPORT Stack;
(* $O- don't check overflows except when explicitly required *)
(* $T- don't test array indices *)

PROCEDURE Load(n: CARDINAL);
BEGIN
  Stack.Push( globalPointer^[n] )
END Load;

PROCEDURE LoadDouble(n: CARDINAL);
BEGIN
  Stack.Push( globalPointer^[n+1] );
  Stack.Push( globalPointer^[n] )
END LoadDouble;

PROCEDURE LoadQuad(n: CARDINAL);
BEGIN
  Stack.Push( globalPointer^[n+3] );
  Stack.Push( globalPointer^[n+2] );
  Stack.Push( globalPointer^[n+1] );
  Stack.Push( globalPointer^[n+0] );
END LoadQuad;

PROCEDURE Store(n: CARDINAL);
BEGIN
  globalPointer^[n] := Stack.Pop()
END Store;

PROCEDURE StoreDouble(n: CARDINAL);
BEGIN
  globalPointer^[n]   := Stack.Pop();
  globalPointer^[n+1] := Stack.Pop()
END StoreDouble;

PROCEDURE StoreQuad(n: CARDINAL);
BEGIN
  globalPointer^[n+0] := Stack.Pop();
  globalPointer^[n+1] := Stack.Pop();
  globalPointer^[n+2] := Stack.Pop();
  globalPointer^[n+3] := Stack.Pop();
END StoreQuad;

PROCEDURE LoadAddr(n: CARDINAL);
BEGIN
  Stack.Push( ADR(globalPointer^[n]) )
END LoadAddr;

PROCEDURE Module(modNum: CARDINAL): ADDRESS;
BEGIN
  RETURN ADDRESS( globalPointer^[0FFF7H - modNum] )
END Module;

PROCEDURE ProcAddr(moduleBase: WordArrayPointer; procNum: CARDINAL): ADDRESS;
VAR addrLocation: ADDRESS;
BEGIN
  addrLocation := ADDRESS(moduleBase^[0FFFFH]) - procNum * 2;
  RETURN addrLocation + 1 + CARDINAL(addrLocation^)
END ProcAddr;

PROCEDURE LoadProcAddr(procNum: CARDINAL);
BEGIN
  Stack.Push( ProcAddr(globalPointer, procNum) )
END LoadProcAddr;

END Global.
