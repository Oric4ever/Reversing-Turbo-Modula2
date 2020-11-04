IMPLEMENTATION MODULE Extended;
FROM SYSTEM IMPORT ADDRESS, MOVE, FILL, TRANSFER, PROCESS, BIOS;
FROM STORAGE IMPORT ALLOCATE, DEALLOCATE, FREEMEM, MARK, RELEASE;
IMPORT Stack;

(* $O- don't check overflows except when explicitly required *)
(* $T- don't test array indices *)

EXCEPTION IllegalOpcode, Unimplemented;
PROCEDURE EnterMonitor; BEGIN (* silently unimplemented *) END EnterMonitor;
PROCEDURE LeaveMonitor; BEGIN (* silently unimplemented *) END LeaveMonitor;

PROCEDURE LongNegate;
BEGIN
  Stack.DPush( - Stack.DPop() )
END LongNegate;

PROCEDURE FieldMask;
VAR op1, op2: BITSET;
BEGIN
  op2 := {}; INCL(op2, Stack.Pop());
  op1 := {}; INCL(op1, Stack.Pop());
  Stack.Push( CARDINAL(op1) - CARDINAL(op2) )
END FieldMask;

PROCEDURE Allocate;
VAR varPtr, blockPtr : ADDRESS;
    size   : CARDINAL;
BEGIN
  size    := Stack.Pop();
  varPtr  := Stack.Pop();
  ALLOCATE(blockPtr, size);
  varPtr^ := blockPtr;
END Allocate;

PROCEDURE DeAllocate;
VAR varPtr, blockPtr : ADDRESS;
    size : CARDINAL;
BEGIN
  size     := Stack.Pop();
  varPtr   := Stack.Pop();
  blockPtr := ADDRESS( varPtr^ );
  DEALLOCATE(blockPtr, size);
  varPtr^  := NIL;
END DeAllocate;

PROCEDURE Mark;
VAR varPtr, markPtr : ADDRESS;
BEGIN
  varPtr  := Stack.Pop();
  MARK(markPtr);
  varPtr^ := markPtr;
END Mark;

PROCEDURE Release;
VAR varPtr, markPtr : ADDRESS;
BEGIN
  varPtr  := Stack.Pop();
  markPtr := ADDRESS( varPtr^ );
  RELEASE(markPtr);
  varPtr  := NIL;
END Release;

PROCEDURE FreeMem;
BEGIN
  Stack.Push( FREEMEM() )  (* TODO: check this *)
END FreeMem;

PROCEDURE Transfer;   BEGIN RAISE Unimplemented END Transfer;
PROCEDURE IOtransfer; BEGIN RAISE Unimplemented END IOtransfer;
PROCEDURE NewProcess; BEGIN RAISE Unimplemented END NewProcess;

PROCEDURE Bios;
VAR fct, param: CARDINAL;
BEGIN
  param := Stack.Pop();
  fct   := Stack.Pop();
  BIOS(fct, param);
END Bios;

PROCEDURE Move;
VAR size: CARDINAL;
    src, dst: ADDRESS;
BEGIN
  size := Stack.Pop();
  dst  := ADDRESS( Stack.Pop() );
  src  := ADDRESS( Stack.Pop() );
  MOVE(src, dst, size);
END Move;

PROCEDURE Fill;
VAR value, size: CARDINAL;
    addr : ADDRESS;
BEGIN
  value := Stack.Pop();
  size  := Stack.Pop();
  addr  := Stack.Pop();
  FILL(addr, size, value)
END Fill;

PROCEDURE Opcode(opcode: CARDINAL);
BEGIN
  CASE opcode OF
  | 00H : Stack.Drop
  | 01H : EnterMonitor
  | 02H : LeaveMonitor
  | 03H : LongNegate
  | 04H : FieldMask
  | 05H : Allocate
  | 06H : DeAllocate
  | 07H : Mark
  | 08H : Release
  | 09H : FreeMem
  | 0AH : Transfer
  | 0BH : IOtransfer
  | 0CH : NewProcess
  | 0DH : Bios
  | 0EH : Move
  | 0FH : Fill
  | 10H,
    11H : RAISE Unimplemented, "INP/OUT not implemented"
  | 12H : Stack.ReserveString
  ELSE RAISE IllegalOpcode
  END;
END Opcode;

END Extended.
