IMPLEMENTATION MODULE KERNEL;
FROM SYSTEM IMPORT BDOS, WORD, PROCESS, TRANSFER, NEWPROCESS, ADR, MOVE, TSIZE, BYTE,
                   IORESULT, FILL;
FROM STORAGE IMPORT ALLOCATE, MARK;
(* trying to produce a byte-to-byte equivalent of original KERNEL *)

(* BDOS functions *)
CONST RESET = 0;
      CRAWIO = 6;

PROCEDURE WriteChar(c: CHAR);
BEGIN
  BDOS(CRAWIO, c)
END WriteChar;

PROCEDURE WriteString(str: ARRAY OF CHAR);
VAR i: CARDINAL;
BEGIN
  i:=0;
  WHILE (i <= HIGH(str)) AND (str[i] <> 0C) DO
    BDOS(CRAWIO, str[i]);
    INC(i)
  END
END WriteString;

PROCEDURE WriteLn;
CONST CR = 015C; LF = 012C;
BEGIN
  WriteChar(CR); WriteChar(LF)
END WriteLn;

PROCEDURE WriteInt(i: CARDINAL; width: CARDINAL; signed: BOOLEAN);
VAR n: CARDINAL;
    buf: ARRAY [0..6] OF CHAR;
BEGIN
  signed := signed AND (INTEGER(i) < 0);
  IF signed THEN i := -INTEGER(i) END;
  n := 0;
  REPEAT
    buf[n] := CHR( i MOD 10 + ORD('0') );
    i := i DIV 10;
    INC(n);
  UNTIL i = 0;
  IF signed THEN buf[n] := '-'; INC(n) END;
  WHILE width > n DO WriteChar(' '); DEC(width) END;
  REPEAT
    DEC(n); 
    WriteChar(buf[n])
  UNTIL n = 0;
END WriteInt;

PROCEDURE WriteMod38(code: CARDINAL);
VAR i, mod38: CARDINAL;
BEGIN
  i := 1;
  REPEAT
    mod38 := code MOD 38;
    code  := code DIV 38;
    IF    mod38 < 26 THEN WriteChar( CHR(mod38 + ORD('A')) )
    ELSIF mod38 < 36 THEN WriteChar( CHR(mod38 + (ORD('0') - 26)))
    ELSE                  WriteChar(' ')
    END;
    INC(i)
  UNTIL i > 3
END WriteMod38;

PROCEDURE WriteModuleName(modbase: ADDRESS);
VAR name: POINTER TO ARRAY [0..7] OF CHAR;
    i : CARDINAL;
BEGIN
  i := 0;
  name := ADDRESS( CARDINAL(modbase - 78) + 32*2 ); (* TODO: not exactly the same*)
  REPEAT
    IF name^[i] = 0C THEN WriteChar(' ') ELSE WriteChar(name^[i]) END;
    INC(i)
  UNTIL i = 8
END WriteModuleName;

TYPE
     Context    = RECORD
                    HL,HL2 : CARDINAL;
                    GLOBAL : ADDRESS;
                    IntFlag: BOOLEAN;
                    StackLimit, FreeList: ADDRESS;
                    save1, save2: CARDINAL;
                    IY : CARDINAL;
                    LOCAL : ADDRESS;
                    DE2,BC2 : CARDINAL;
                    IP : CARDINAL;
                    BC, AF2, AF: CARDINAL;
                    ReturnAddr : CARDINAL;
                    MsgHigh : CARDINAL;
                    MsgStr : ADDRESS;
                    ExcNum : CARDINAL;
                    Param  : CARDINAL;
                  END;
     ContextPtr = POINTER TO Context;
     ContextSave= ARRAY [0..16] OF WORD;
     ContextSavePtr = POINTER TO ContextSave;
     FCB        = ARRAY [0..35] OF BYTE;
     FramePtr   = POINTER TO Frame;
     Frame      = RECORD
                    outerFrame   : FramePtr;
                    previousFrame: FramePtr;
                    returnAddr   : ADDRESS;
                  END;
     FLAGS      = (OVERLAY, Z80, INIT);
     ModulePtr  = POINTER TO Module;
     Module     = RECORD
                    flags  : SET OF FLAGS;
                    global1: CARDINAL;
                  END;
     ModDescPtr  = POINTER TO ModuleDesc;
     ModuleDesc = RECORD
                    reqModules: ARRAY [0..31] OF ADDRESS;
                    link : ModDescPtr;
                    name : ARRAY [0..7] OF CHAR;
                    loadAddr,checksum,procsAddr: ADDRESS;
                    CASE : BOOLEAN OF
                    | TRUE : flags : SET OF FLAGS;
                    | FALSE: bytes : ARRAY [0..1] OF BYTE;
                    END;
                    global1 : CARDINAL;
                  END;
     ProcDesc = RECORD
                  CASE : BOOLEAN OF
                  | TRUE : modbase, procnum: ADDRESS;
                  | FALSE: proc : PROC;
                  END
                END;

VAR
(*  2 *)    resumeFlag : BOOLEAN;
(*  3 *)    errorMsg : ARRAY [0..59] OF CHAR;
(*  4 *)    msgSize : CARDINAL;
(*  5 *)    exceptNum : CARDINAL;
(*  6 *)    exceptMod : ModulePtr;
(*  7 *)    dbgGlobal : ModulePtr;
(*  8 *)    dbgLocal : FramePtr;
(*  9 *)    returnAddr : CARDINAL;
(* 10 *)    global10: ContextPtr;
(* 11 *)    workTask: PROCESS;
(* 12 *)    mainModuleSave: ModDescPtr;
(* 13 *)    contextSave: ContextSave;
(* 14 *)    lastContextPtr: ContextSavePtr;
(* 15 *)    loadOverlay: BOOLEAN;
(* 16 *)    toLoadFlag: BOOLEAN;
(* 17 *)    ErrorWorkspace: ARRAY [0..99] OF BYTE;
(* 18 *)    DebugWorkspace: ARRAY [0..299] OF BYTE;
(* 19 *)    nbFrames: CARDINAL;
(* 20 *)    versionError: BOOLEAN;
(* 21 *)    global21: CARDINAL;
(* 22 *)    FCBs: POINTER TO ARRAY [0..3] OF FCB;
(* 23 *)    nbExtentsM2OVR: CARDINAL;
(* 24 *)    currentDrive: CARDINAL;
(* 25 *)    drive: CARDINAL;
(* 26 *)    allocAddr: ADDRESS;
(* 27 *)    allocAddr2: ADDRESS;
(* 28 *)    modulePtr: ModDescPtr;
(* 29 *)    varCount: CARDINAL;
(* 30 *)    varSize: CARDINAL;
(* 31 *)    globalVarsPtr: POINTER TO ARRAY [0..255] OF CARDINAL;
(* 32 *)    globalVarsAllocated: BOOLEAN;
(* 33 *)    proc: ProcDesc;
(* 34 *)    contextPtr: ContextPtr;

MODULE Internal[1]; (* procedures with priority 1 *)
IMPORT ADDRESS, WORD, PROCESS, TRANSFER, NEWPROCESS, BDOS, RESET, TSIZE, BYTE, MOVE,
       ADR, IORESULT, ALLOCATE, CRAWIO,
       WriteChar, WriteString, WriteLn, WriteInt, WriteModuleName, WriteMod38,
       FCB, FCBs, nbExtentsM2OVR, currentDrive, drive, toLoadFlag,
       resumeFlag, dbgGlobal, global10, workTask, mainModuleSave, global21,
       contextSave, lastContextPtr, ContextSavePtr, loadOverlay, versionError,
       FLAGS, DebugWorkspace, msgSize, exceptNum, exceptMod, errorMsg,
       dbgLocal, nbFrames, returnAddr, ContextPtr, FramePtr, ModDescPtr, ModulePtr;
EXPORT 
(*
       ExceptionModule,
       proc12,
*)
       DebugProc,
       LoadProc,
       ErrorProc,
       RaisedTask, InterruptedTask, KernelTask0, KernelTask1;

CONST FOPEN     = 15;
      DRVGET    = 25;
      FSIZE     = 35;

VAR
    RaisedTask     [0304H]: PROCESS;
    InterruptedTask[0306H]: PROCESS;
    KernelTask0    [0308H]: PROCESS;
    KernelTask1    [030AH]: PROCESS;
    mainModule     [030CH]: ModDescPtr;

    StartupAddr[0320H]: ADDRESS;
    M2OVRFCB   [0324H]: FCB;
    M2OVRname  [0325H]: ARRAY [0..7] OF CHAR;
    M2OVRext   [032DH]: ARRAY [0..2] OF CHAR;
    RandomAccessRecordNumber [0345H]: CARDINAL;
    drives     [034AH]: BITSET; (* drives that are present *)

  PROCEDURE ExceptionModule(n: CARDINAL): ADDRESS;
  VAR dependency: POINTER TO ADDRESS;
  BEGIN
    IF n = 0 THEN RETURN StartupAddr END;
    IF n = 1 THEN RETURN dbgGlobal END;
    dependency := ADDRESS(dbgGlobal) - (n-2)*2 - 18;
    RETURN dependency^
  END ExceptionModule;

  PROCEDURE DebugProc;
    CONST SPACES5 = "     ";
    TYPE ProcDesc = RECORD
                      name0, name1: CARDINAL;
                      word2: INTEGER;
                    END;
    VAR local2 : ContextPtr;
        ptr    : POINTER TO CARDINAL;
        procPtr: POINTER TO ProcDesc;
        local5 : ADDRESS;
        charPtr: POINTER TO ARRAY [0..19] OF CHAR;
        n      : CARDINAL;
        signed : BOOLEAN;
        local9 : BOOLEAN;
        local10: BOOLEAN;

    PROCEDURE proc10(): BOOLEAN;
    VAR outerFrame   : ADDRESS;
        previousFrame: FramePtr;
        modulePtr    : ModDescPtr;
        ptr          : POINTER TO CARDINAL;
    BEGIN
      IF dbgLocal <> NIL THEN
        outerFrame    := dbgLocal^.outerFrame;
        previousFrame := dbgLocal^.previousFrame;
        IF (outerFrame <> ADDRESS(1)) AND (nbFrames < 5000) THEN
          INC(nbFrames);
          IF outerFrame <> NIL THEN
            IF  (outerFrame <> previousFrame)
            AND (previousFrame    <> NIL)
            AND (outerFrame <> previousFrame^.outerFrame)
            AND ( (previousFrame^.previousFrame = NIL)
               OR (outerFrame <> previousFrame^.previousFrame^.outerFrame) )
            THEN
              modulePtr := mainModule;
              WHILE (modulePtr <> NIL)
              AND   (CARDINAL(modulePtr)+80 <> CARDINAL(outerFrame)) DO
                modulePtr := modulePtr^.link
              END;
              IF modulePtr <> NIL THEN dbgGlobal := outerFrame END;
            END;
          END;
          local2 := ADDRESS(CARDINAL(dbgLocal) - 28);
          returnAddr := dbgLocal^.returnAddr;
          dbgLocal := previousFrame;
          IF dbgGlobal <> NIL THEN
            ptr     := ADDRESS(CARDINAL(dbgLocal) - 2);
            procPtr := ADDRESS(ptr^ - (ORD(Z80 IN dbgGlobal^.flags) + 2) * 4);
            RETURN TRUE;
          END
        END
      END;
      RETURN FALSE
    END proc10;

  BEGIN
    global10   := InterruptedTask;
    local2     := global10;

    dbgLocal   := ADDRESS( global10^.LOCAL );
    dbgGlobal  := ADDRESS( global10^.GLOBAL );
    returnAddr := global10^.IP;
    IF Z80 IN dbgGlobal^.flags THEN returnAddr := global10^.IY END;
    ptr     := ADDRESS(CARDINAL(dbgLocal) - 2);
    procPtr := ADDRESS(ptr^ - (ORD(Z80 IN dbgGlobal^.flags) + 2) * 4);
    local9  := TRUE;
    n       := global10^.ExcNum;
    IF n = 1 THEN   (* Load Overlay Module *)
      loadOverlay := NOT loadOverlay;
      IF loadOverlay THEN TRANSFER(workTask,RaisedTask) END
    END;
    IF n <> 0 THEN
      exceptNum := n MOD 256;
      exceptMod := ExceptionModule(n DIV 256);
      local9    := n <> 10; (* EndOfCoroutine *)
      IF n = 6 THEN (* OutOfMemory *)
        local9 := proc10();
        exceptNum := 5 (* OutOfMemory *)
      END;
      msgSize := global10^.MsgHigh + ORD(global10^.MsgStr <> NIL);
      IF msgSize > 60 THEN msgSize := 60 END;
      MOVE(global10^.MsgStr, ADR(errorMsg), msgSize);
    END;
    global10^.GLOBAL := CARDINAL(dbgGlobal);
    global10^.LOCAL  := CARDINAL(dbgLocal);
    global10^.IP     := returnAddr;

    local5 := procPtr;
    IF local9 THEN (* propagate exception until a handler is found *)
      nbFrames := 0;
      REPEAT
        IF NOT(OVERLAY IN dbgGlobal^.flags) AND (procPtr^.word2 > 0) 
        THEN
          charPtr := ADDRESS( INTEGER(procPtr) + procPtr^.word2 + 5 );
          n := ORD(charPtr^[0]);
          ptr := ADDRESS( CARDINAL(charPtr) + n * 4 - 1 );
          IF CARDINAL(ptr) + ptr^ + 1 >= returnAddr THEN
            charPtr := ADDRESS( CARDINAL(charPtr) + 1 );
            WHILE n <> 0 DO
              IF  (ORD(charPtr^[0]) = 0)
              OR  (ORD(charPtr^[0]) = exceptNum)
              AND (ExceptionModule(ORD(charPtr^[1])) = exceptMod)
              THEN
                MOVE(global10, local2, 17*2);
                local2^.GLOBAL := dbgGlobal;
                local2^.IntFlag:= FALSE;
                local2^.LOCAL  := dbgLocal;
                local2^.IY     := 041AH;
                ptr            := ADDRESS( CARDINAL(charPtr) + 2 );
                local2^.IP     := CARDINAL(ptr) + ptr^ + 1;
                local2^.ReturnAddr := 041AH;
                IF Z80 IN dbgGlobal^.flags THEN
                  local2^.ReturnAddr := local2^.IP
                END;
                (* resume to exception handler *)
                InterruptedTask := local2;
                TRANSFER(workTask, InterruptedTask);
              END;
              charPtr := ADDRESS( CARDINAL(charPtr) + 4 );
              DEC(n);
            END; (* WHILE *)
          END;
        END;
      UNTIL NOT proc10();
    END; (* IF local9 *)

    (* display exception *)
    WriteLn;
    IF (exceptMod <> StartupAddr) AND (OVERLAY IN exceptMod^.flags) THEN
      WriteChar('?')
    ELSE
      ptr := ADDRESS( CARDINAL(exceptMod) - 2 );
      ptr := ADDRESS( CARDINAL(ptr^) - exceptNum * 2 );
      charPtr := ADDRESS( CARDINAL(ptr) + CARDINAL(ptr^) + 1 );
      n := 1;
      WHILE n <= ORD(charPtr^[0]) DO
        WriteChar(charPtr^[n]);
        INC(n)
      END;
    END;
    WriteString(" in module ");
    WriteModuleName(global10^.GLOBAL);
    WriteLn;
    IF exceptMod = StartupAddr THEN
      IF exceptNum = 1 THEN
        WriteString("Missing module: ");
        WriteModuleName(global10^.HL);
      END;
      IF exceptNum IN {2,3,4} THEN (* BoundsError *)
        signed := exceptNum = 3;
        IF exceptNum = 4 THEN
          global10^.BC := 0;
          global10^.HL := 07FFFH;
        END;
        WriteInt(global10^.BC, 0, signed);
        WriteString(" to ");
        WriteInt(global10^.HL, 0, signed);
        WriteString(" is legal range, but ");
        WriteInt(global10^.Param, 0, signed);
        IF exceptNum = 4 THEN
          WriteString(" or ");
          WriteInt(global10^.Param, 0, TRUE);
        END;
        WriteString(" was evaluated");
      END;
      IF exceptNum = 5 THEN (* OutOfMemory *)
        WriteString("Stack=");
        WriteInt(CARDINAL(global10), 5, FALSE);
        WriteString(", heap=");
        WriteInt(global10^.StackLimit, 5, FALSE);
      END;
    ELSE (* exceptMod <> StartupAddr *)
      n := 0;
      WHILE n < msgSize DO
        WriteChar(errorMsg[n]);
        INC(n)
      END;
    END;

    (* display stack trace *)
    IF local9 THEN
      dbgGlobal := global10^.GLOBAL;
      dbgLocal  := global10^.LOCAL;
      returnAddr:= global10^.IP;
      procPtr   := local5;
      n := 0;
      local10 := TRUE;
      LOOP
        IF n MOD 18 = 0 THEN
          WriteLn;
          WriteString('Press "C" ');
          IF local10 
          THEN WriteString("for calling chain >")
          ELSE WriteString("to continue ;")
          END;
          local10 := FALSE;
          REPEAT
            BDOS(CRAWIO, 255); (* input char *)
          UNTIL IORESULT <> 0;
          IF CAP(CHR(IORESULT)) <> 'C' THEN EXIT END;
          WriteLn;
          WriteString("Module      Procedure   Offset     PC");
          WriteLn;
        END;
        IF (OVERLAY IN dbgGlobal^.flags) OR (procPtr^.word2 >= 0) THEN
          WriteModuleName(dbgGlobal);
          WriteString(SPACES5);
          IF OVERLAY IN dbgGlobal^.flags 
          THEN WriteChar('?')
          ELSE
            WriteMod38(procPtr^.name0);
            WriteMod38(procPtr^.name1);
            WriteString(SPACES5);
            IF returnAddr > CARDINAL(procPtr) 
            THEN WriteInt(returnAddr - CARDINAL(procPtr) - 6, 4, FALSE)
            ELSE WriteString("in a submodule")
            END;
            WriteString(SPACES5);
            ptr := ADDRESS( CARDINAL(dbgGlobal) - 6 );
            WriteInt(returnAddr - ptr^ + 16, 4, FALSE);
          END;
          WriteLn;
        END;
        INC(n);
        IF NOT proc10() THEN EXIT END;
      END; (* LOOP *)
    END;
    WriteLn;
    IF resumeFlag
    THEN
      lastContextPtr^ := contextSave;
      mainModule      := mainModuleSave;
      InterruptedTask := lastContextPtr;
      TRANSFER(workTask, InterruptedTask);
    END;
    BDOS(RESET, 0);
  END DebugProc;

  PROCEDURE InitFCBs;
  CONST EXTENT = 12;
        CURREC = 32;
  VAR i: CARDINAL;
  BEGIN
    i := 0;
    IF nbExtentsM2OVR <> 0 THEN
      REPEAT
        FCBs^[i] := M2OVRFCB;
        FCBs^[i][EXTENT] := i;
        FCBs^[i][CURREC] := 0;
        BDOS(FOPEN, ADR(FCBs^[i]));
        INC(i)
      UNTIL i = nbExtentsM2OVR;
    END    
  END InitFCBs;


  (* Read a 128-byte record of M2.OVR, in location set by SETDMA *)
  (* returns TRUE if read is ok *)
  PROCEDURE ReadM2OVR(record: CARDINAL): BOOLEAN;
  CONST FREADRAND = 33;
  VAR recordPtr : POINTER TO CARDINAL;
      fcb : POINTER TO FCB;
  BEGIN
    fcb := ADR(FCBs^[record DIV 128]);
    recordPtr := ADR(fcb^[33]);
    recordPtr^ := record;
    BDOS(FREADRAND, fcb);
    RETURN IORESULT = 0
  END ReadM2OVR;

  PROCEDURE LoadProc;
  CONST SETDMA = 26;
  VAR moduleDesc: ModDescPtr;
      loadedMod : ModDescPtr;
      length    : CARDINAL;
      offset    : CARDINAL;
      local6    : CARDINAL;
      buffer    : ARRAY [0..63] OF CARDINAL;
      destination    : POINTER TO CARDINAL;
      record    : CARDINAL;
      module    : ModulePtr;
  BEGIN
    IF versionError THEN InitFCBs; versionError := FALSE END;
    module      := ADDRESS( global10^.HL );
    moduleDesc  := ADDRESS( module ) - 80 ;
(* eg. module DOUBLES : record = 79 , offset = 48 *)
(*  loadAddr = 259FH *)
(*  checksum = serves as version number = 9567H *)
(*  procsAddr = 306FH *)
    record      := module^.global1 DIV 32;
    offset      := module^.global1 MOD 32 * 2; (* word offset *)
    BDOS(SETDMA, ADR(buffer));
    IF ReadM2OVR(record) THEN
      IF buffer[offset] = moduleDesc^.checksum THEN
        length := buffer[offset+1];     (* mod DOUBLES: 0AD4H *)
        destination := moduleDesc^.loadAddr;   (* overlay addr *)
        (* skip these two words and convert word offset to byte offset *)
        offset := (offset + 2) * 2;     (* => offset := 100 *)
        loadedMod := mainModule;
        REPEAT (* search if a module is currently loaded at this overlay addr *)
          IF loadedMod^.loadAddr = destination THEN
            INCL(loadedMod^.flags, OVERLAY)    (* mark the module absent *)
          END;
          loadedMod := loadedMod^.link;
        UNTIL loadedMod = NIL;
        (* now load the module *)
        REPEAT
          (* move rest of buffer to overlay addr *)
          local6 := 128 - offset;
          IF local6 > length THEN local6 := length END;
          MOVE(ADR(buffer)+offset, destination, local6);

          (* increment destination addr *)
          destination := ADDRESS(destination) + local6;
          length := length - local6;
          IF length = 0 THEN
            destination   := ADDRESS(destination) - 2;
            versionError := destination^ <> moduleDesc^.checksum;
            IF NOT versionError THEN
              EXCL(module^.flags, OVERLAY);
              loadOverlay   := FALSE;
              toLoadFlag := FALSE;
              global21   := 0;
              TRANSFER( workTask, InterruptedTask);
            END;
          END;
          offset := 0;
          INC(record);
        UNTIL versionError OR NOT ReadM2OVR(record);
      END;
    END;
    versionError := TRUE;
    IF toLoadFlag THEN
      INC(global21);
      IF global21 = 2 THEN BDOS(RESET, 0) END;
    END;
    TRANSFER(workTask, RaisedTask);
  END LoadProc;

  PROCEDURE ErrorProc;
  BEGIN
    lastContextPtr := ContextSavePtr(InterruptedTask);
    contextSave    := lastContextPtr^;
    mainModuleSave := mainModule;
    TRANSFER(RaisedTask, InterruptedTask);
    LOOP
      IF InterruptedTask = workTask THEN BDOS(RESET, 0) END;
      NEWPROCESS(DebugProc, ADR(DebugWorkspace), 300, workTask);
      TRANSFER(RaisedTask, workTask);
      IF loadOverlay THEN
        NEWPROCESS(LoadProc, ADR(DebugWorkspace), 300, workTask);
        TRANSFER(RaisedTask, workTask)
      END
    END
  END ErrorProc;

BEGIN (* init of Internal module : locate M2.OVR and open all its extents *)
  IF ORD(M2OVRFCB[1]) <> 0 THEN (* first char of M2.OVR name *)
    BDOS(DRVGET, 0);
    currentDrive := IORESULT;
    drive        := currentDrive;
    LOOP                         (* try to open M2.OVR on one of the drives *)
      M2OVRFCB[0] := CHR(drive + 1);
      BDOS(FOPEN, ADR(M2OVRFCB));
      IF IORESULT <> 255 THEN
        BDOS(FSIZE, ADR(M2OVRFCB));
        nbExtentsM2OVR := (RandomAccessRecordNumber + 127) DIV 128;
        ALLOCATE(FCBs, nbExtentsM2OVR * TSIZE(FCB));
        InitFCBs;
        EXIT
      END;
      REPEAT (* search next present drive *)
        drive := (drive + 1) MOD 16;
        IF drive = currentDrive THEN
          WriteString("Overlay "); WriteString(M2OVRname);
          WriteChar('.'); WriteString(M2OVRext);
          WriteString(" not found."); WriteLn;
          BDOS(RESET, 0)
        END
      UNTIL drive IN drives;
    END
  END
END Internal;

PROCEDURE WriteCopyright;
  TYPE EscSequence = ARRAY [0..5] OF CHAR;

  PROCEDURE WriteSequence(VAR sequence: EscSequence);
  VAR i: CARDINAL;
      length: CARDINAL;
  BEGIN
    i := 1; length := ORD(sequence[0]);
    WHILE i <= length DO WriteChar(sequence[i]); INC(i) END
  END WriteSequence;

  VAR clrScreen[03A2H]: EscSequence;
      home     [03A8H]: EscSequence;
      highlight[03CEH]: EscSequence;
      normal   [03C6H]: EscSequence;
      termType [0352H]: EscSequence;
      i : CARDINAL;
BEGIN
  WriteSequence(clrScreen);
  WriteSequence(home);
  FOR i := 1 TO 39 DO WriteChar('-') END;
  WriteLn;
  WriteString("TURBO Modula System        ");
  WriteSequence(highlight);
  WriteString("Version 1.0 ");
  WriteSequence(normal);
  WriteLn;
  FOR i := 1 TO 27 DO WriteChar(' ') END;
  WriteSequence(highlight);
  WriteString("CP/M-80, Z80");
  WriteLn;
  WriteString("                                       ");
  WriteLn;
  WriteString("Copyright (C) 1985-1986");
  WriteSequence(normal);
  WriteString("    BORLAND Inc.");
  WriteLn;
  FOR i := 1 TO 39 DO WriteChar('-') END;
  WriteLn;
  WriteLn;
  WriteString("Terminal: ");
  WriteSequence(termType);
  WriteLn;
END WriteCopyright;

VAR
    firstModule      [030CH]: ADDRESS; (* FILES module - 80 at boot time *)
    boot             [031EH]: BOOLEAN;
    showCopyrightFlag[0322H]: BOOLEAN;

BEGIN
  resumeFlag := boot;
  IF resumeFlag AND showCopyrightFlag THEN WriteCopyright END;

  (* create a process for all error handling *)
  MARK(allocAddr);
  NEWPROCESS(ErrorProc, ADR(ErrorWorkspace), 100, RaisedTask);
  TRANSFER(InterruptedTask, RaisedTask);

  (* allocate the RECORDs and ARRAYs of all modules.
     List of MODULES (and flags) that are chained together :
        FILES       -
        CONVERT     -
        TERMINAL    INIT
        TEXTS       INIT
        LOADER      INIT
        EDIT2       OVERLAY     360B
        EDITDISK    OVERLAY     51C6
        EDITOR      INIT        259F
        CODEGEN     OVERLAY     360B
        ERRORS      OVERLAY     360B
        SYMTAB      OVERLAY     259F
        COMPILER    OVERLAY     259F
        DOUBLES     OVERLAY     259F
        SCANNER     OVERLAY     51C6
        EXEC        OVERLAY     51C6
        COMLINE     INIT
  *)
        
  IF NOT globalVarsAllocated THEN
    allocAddr := allocAddr + 4;
    modulePtr := firstModule;  (* point to FILES module - 80 initially *)
    WHILE modulePtr <> NIL DO
      varCount := ORD(modulePtr^.bytes[1]);
      globalVarsPtr := ADDRESS(modulePtr) + TSIZE(ModuleDesc);
      WHILE varCount <> 0 DO
        DEC(varCount);
        varSize := globalVarsPtr^[varCount];
        IF varSize <> 0 THEN
          FILL(allocAddr, varSize, 0);
          globalVarsPtr^[varCount] := CARDINAL(allocAddr);
          allocAddr := allocAddr + varSize;
        END
      END;
      modulePtr := modulePtr^.link;
    END;
    globalVarsAllocated := TRUE
  END;

  (* init the modules that requires it. 
     Thus, COMLINE will be the final module to run.
  *)
  modulePtr  := firstModule;
  allocAddr2 := allocAddr;
  WHILE modulePtr <> NIL DO
    IF INIT IN modulePtr^.flags THEN (* init module with a new process *)
      toLoadFlag   := OVERLAY IN modulePtr^.flags;
      proc.modbase := ADR(modulePtr^.flags); (* procnum is 0 *)
      (* create a process, giving it all memory from current alloc addr *)
      NEWPROCESS(proc.proc, allocAddr2,
                 ADDRESS(lastContextPtr)-10-allocAddr2, KernelTask1);
      TRANSFER(KernelTask0, KernelTask1);
      (* once the init is finished (opcode 50), get the new heap ptr by looking
         directly in the context of the finished process *)
      contextPtr := ADDRESS(KernelTask1);
      allocAddr2 := contextPtr^.StackLimit - 60;
    END;
    modulePtr := modulePtr^.link;
  END;
  BDOS(RESET, 0)
END KERNEL.
