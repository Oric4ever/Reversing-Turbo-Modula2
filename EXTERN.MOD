IMPLEMENTATION MODULE Extern;
FROM SYSTEM IMPORT BYTE, WORD, ADR;
IMPORT Stack;
IMPORT Global;

TYPE ByteArrayPointer = POINTER TO ARRAY [0..0FFFFH] OF BYTE;
     WordArrayPointer = POINTER TO ARRAY [0..0FFFFH] OF CARDINAL;

(* $O- don't check overflows except when explicitly required *)
(* $T- don't test array indices *)

PROCEDURE Load(modNum, varNum: CARDINAL);
VAR module: WordArrayPointer;
BEGIN
  module := Global.Module(modNum);
  Stack.Push( module^[varNum] )
END Load;

PROCEDURE Load2(nibbles: CARDINAL);
BEGIN
  Load(nibbles DIV 16, nibbles MOD 16)
END Load2;

PROCEDURE LoadDouble(modNum, varNum: CARDINAL);
VAR module: WordArrayPointer;
BEGIN
  module := Global.Module(modNum);
  Stack.Push( module^[varNum+1] );
  Stack.Push( module^[varNum  ] );
END LoadDouble;

PROCEDURE LoadQuad(modNum, varNum: CARDINAL);
VAR module: WordArrayPointer;
BEGIN
  module := Global.Module(modNum);
  Stack.Push( module^[varNum+3] );
  Stack.Push( module^[varNum+2] );
  Stack.Push( module^[varNum+1] );
  Stack.Push( module^[varNum+0] );
END LoadQuad;

PROCEDURE Store(modNum, varNum: CARDINAL);
VAR module: WordArrayPointer;
BEGIN
  module := Global.Module(modNum);
  module^[varNum] := Stack.Pop()
END Store;

PROCEDURE Store2(nibbles: CARDINAL);
BEGIN
  Store(nibbles DIV 16, nibbles MOD 16)
END Store2;

PROCEDURE StoreDouble(modNum, varNum: CARDINAL);
VAR module: WordArrayPointer;
BEGIN
  module := Global.Module(modNum);
  module^[varNum  ] := Stack.Pop();
  module^[varNum+1] := Stack.Pop();
END StoreDouble;

PROCEDURE StoreQuad(modNum, varNum: CARDINAL);
VAR module: WordArrayPointer;
BEGIN
  module := Global.Module(modNum);
  module^[varNum+0] := Stack.Pop();
  module^[varNum+1] := Stack.Pop();
  module^[varNum+2] := Stack.Pop();
  module^[varNum+3] := Stack.Pop();
END StoreQuad;

PROCEDURE LoadAddr(modNum, varNum: CARDINAL);
VAR module: WordArrayPointer;
BEGIN
  module := Global.Module(modNum);
  Stack.Push( ADR(module^[varNum]) )
END LoadAddr;

END Extern.
