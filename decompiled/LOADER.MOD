IMPLEMENTATION MODULE Loader;
(* DEFINITION :
FROM SYSTEM IMPORT ADDRESS;
VAR firstDrive: CARDINAL;

TYPE FCB = ARRAY [0..35] OF CHAR;
     LibFile = RECORD
                bp : CARDINAL; (* byte position in buffer *)
                pos: CARDINAL;  (* current record number *)
                fcbs : ARRAY [0..7] OF FCB;
               END;
     Extension = ARRAY [0..2] OF CHAR;


EXCEPTION LoadErrror;
*)
FROM TERMINAL IMPORT WriteLn, WriteString;
FROM SYSTEM IMPORT BDOS, IORESULT, MOVE, FILL, ADR, BYTE, WORD, TSIZE,
                   PROCESS, OUTOFMEMORY, NEWPROCESS, TRANSFER;
FROM STORAGE IMPORT MARK, RELEASE;

CONST MAXLIB = 8;
CONST FOPEN = 15; DRVGET = 25; FUSERNUM = 32; FREADRAND = 33; FSIZE = 35;

TYPE Name = ARRAY [0..7] OF CHAR;
     LibFilePtr = POINTER TO LibFile;
     FLAGS = (OVERLAY, Z80, TOINIT, RECURSEFLAG);
     FlagSet = SET OF FLAGS;
     FlagSetPtr = POINTER TO FlagSet;
     ModDescPtr  = POINTER TO ModuleDesc;
     ModuleDesc = RECORD
                    procs: ARRAY [0..31] OF ADDRESS;
                    link : ModDescPtr;
                    name : Name;
                    loadAddr,checksum,procsAddr: ADDRESS;
                    CASE : BOOLEAN OF
                    | TRUE : flags : FlagSet;
                    | FALSE: bytes : ARRAY [0..3] OF BYTE;
                        (* byte 0: flags
                           byte 1: nb of vars
                           byte 2: ?
                           byte 3: nb of dependencies
                        *)
                    END;
                  END;
    Dependency = RECORD
                   name: Name;
                   version: CARDINAL;
                   location: ADDRESS;
                 END;


VAR libraries[03DAH]: ARRAY [0..MAXLIB-1] OF Name;
    drives   [034AH]: BITSET;
    module1  [030CH]: ADDRESS;

(*  3 *) nbLibs : CARDINAL;
(*  4 *) presentLibs : BITSET;
(*  5 *) global5 : BITSET;
(*  6 *) libFilesPtr : POINTER TO ARRAY [0..7] OF LibFilePtr;
(*  7 *) catalogsPtr : POINTER TO ARRAY [0..7] OF ADDRESS;
(*  8 *) buffer : POINTER TO ARRAY [0..127] OF CHAR;
(*  9 *) userNum : CARDINAL;
(* 10 *) workspaceEnd: CARDINAL;
(* 11 *) allocAddr: ADDRESS;
(* 12 *) errorMsg: ARRAY [0..25] OF CHAR;
(* 13 *) global13: ModDescPtr;
(* 14 *) global14: LibFilePtr;
(* 15 *) global15: BOOLEAN;
(* 16 *) global16: BOOLEAN;
(* 17 *) global17: ADDRESS;
(* 18 *) global18: ADDRESS;

(* $[+ : remove procedure names *)

(* NLibs: count the number of declared libraries *)
(*  5 *) PROCEDURE NLibs(): CARDINAL;
VAR n: CARDINAL;
BEGIN
  n := 0;
  WHILE (n <= HIGH(libraries)) AND (libraries[n][0] <> 0C) DO
    INC(n)
  END;
  RETURN n
END NLibs;

(* InitFCB : init the provided FCB with a filename and an extension *)
(*  8 *) PROCEDURE InitFCB(VAR fcb : FCB;
                VAR fname: ARRAY OF CHAR;
                ext: Extension);
VAR n: CARDINAL;
BEGIN
  fcb := '         ';
  n := 0;
  REPEAT
    fcb[n+1] := CAP(fname[n]);
    INC(n);
  UNTIL (n = 8) OR (n > HIGH(fname)) OR (fname[n] = 0C) OR (fname[n] = '.');
  MOVE(ADR(ext), ADR(fcb[9]), 3)
END InitFCB;

(* Initialise les FCBs d'une bibliothèque :
   en entrée : drive et nom de la bibliothèque dans fcb
   en sortie : structure LibFile initialisée
*)

(*  9 *) PROCEDURE InitLibFile(VAR f : LibFile;
                VAR fcb : FCB;
                drive : CARDINAL): BOOLEAN;
VAR nbExtents: CARDINAL;
    nbRecords: INTEGER;
    recordPtr: POINTER TO INTEGER;
BEGIN
  fcb[0] := CHR(drive+1);
  BDOS(FOPEN, ADR(fcb));
  IF IORESULT = 255 THEN RETURN FALSE END;
  BDOS(FSIZE, ADR(fcb));
  recordPtr := ADR(fcb[33]);
  nbRecords := recordPtr^;
  nbExtents := 0;
  WHILE (nbRecords > 0) AND (nbExtents <= HIGH(f.fcbs)) DO
    f.fcbs[nbExtents] := fcb;
    INC(nbExtents);
    fcb[12] := CHR(nbExtents);
    BDOS(FOPEN, ADR(fcb));
    nbRecords := nbRecords - 128;
  END;
  f.bp  := 128;
  f.pos := 0;
  RETURN TRUE
END InitLibFile;

(* lit l octets depuis la position courante de la bibliothèque f,
   vers l'adresse a
*)
(*  4 *) PROCEDURE LibRead(VAR f: LibFile; a: ADDRESS; l: CARDINAL): BOOLEAN;
VAR n : CARDINAL;
    lastChunkSize: CARDINAL;
    recordNumPtr: POINTER TO CARDINAL;
    fcbAddr: POINTER TO FCB;
BEGIN
  n := 128 - f.bp; (* nombre d'octets restants dans le buffer *)
  IF l <= n THEN (* tous les octets à lire sont déjà dans le buffer *)
    MOVE( ADR(buffer^[f.bp]), a, l);
    INC(f.bp, l);
    RETURN TRUE
  END;
  MOVE( ADR(buffer^[f.bp]), a, n); (* transfère le reste du buffer *)
  a := a + n;
  l := l - n;
  BDOS(26, buffer);
  lastChunkSize := 128;
  REPEAT    (* continue à lire par buffers de 128 octets *)
    n := f.pos DIV 128; (* calcule l'extent *)
    IF n > 7 THEN n := 7 END; (* limite à 8 extents = 128 K ? *)
    fcbAddr := ADR(f.fcbs[n]);
    recordNumPtr := ADR(fcbAddr^[33]);
    recordNumPtr^ := f.pos;
    BDOS(FREADRAND, fcbAddr);
    INC(f.pos);
    IF IORESULT <> 0 THEN RETURN FALSE END;
    IF l < 128 THEN lastChunkSize := l END;
    MOVE(buffer, a, lastChunkSize);
    a := a + lastChunkSize;
    l := l - lastChunkSize;
  UNTIL l = 0;
  f.bp := lastChunkSize;
  RETURN TRUE
END LibRead;

(* Cherche les bibliothèques déclarées et les initialise (lit le catalogue) *)
(*  1 *) PROCEDURE InitLibs(wsp: ADDRESS; wsize: CARDINAL);

    PROCEDURE Reserve(VAR ptr: ADDRESS; size: CARDINAL);
    BEGIN
      workspaceEnd := workspaceEnd - size;
      IF workspaceEnd < wsp THEN RAISE OUTOFMEMORY END;
      ptr := workspaceEnd
    END Reserve;

VAR n : CARDINAL;
    i : CARDINAL;
    drive : CARDINAL;
    curDrive : CARDINAL;
    oneLibMissing : BOOLEAN;
    buf : ARRAY [0 .. 7] OF FCB;
    libFile: LibFile;
BEGIN
  workspaceEnd := wsp + wsize;
  Reserve(libFilesPtr, 8*2);
  Reserve(catalogsPtr, 8*2);
  Reserve(buffer, 128);
  nbLibs := NLibs();
  n := 0;
  WHILE n < nbLibs DO
    InitFCB(buf[n], libraries[n], "LIB");
    catalogsPtr^[n] := NIL;
    libFilesPtr^[n] := NIL;
    INC(n);
  END;
  presentLibs := {};
  global5 := {};
  BDOS(DRVGET, 0); curDrive := IORESULT;
  drive := curDrive;
  REPEAT
    n := 0;
    WHILE n < nbLibs DO
      IF NOT (n IN presentLibs) THEN
        IF InitLibFile(libFile, buf[n], drive) THEN
          Reserve(libFilesPtr^[n], SIZE(libFile));
          libFilesPtr^[n]^ := libFile;
          Reserve(catalogsPtr^[n], 498);
          INCL(presentLibs, n);
        END;
      END;
      INC(n);
    END;
    REPEAT
      drive := (drive + 1) MOD 16;
    UNTIL (drive = curDrive ) OR (drive IN drives);
  UNTIL drive = curDrive;
  oneLibMissing := FALSE;
  i := 0;
  WHILE i < nbLibs DO
    IF NOT (i IN presentLibs) THEN
      IF NOT oneLibMissing THEN WriteLn; oneLibMissing := TRUE END;
      WriteString("Warning: Library ");
      WriteString(libraries[i]);
      WriteString(" not found.");
      WriteLn;
    END;
    INC(i);
  END;  
END InitLibs;

(* cherche le module fname.ext sur les drives ouverts, 
   et initialise f comme si c'était une bibliothèque ne contenant que ce module 
*)
(*  3 *) PROCEDURE DirOpen(VAR f: LibFile; fname: ARRAY OF CHAR; ext: Extension): BOOLEAN;
VAR fcb: FCB;
    drive : CARDINAL;
BEGIN
  InitFCB(fcb, fname, ext);
  drive := firstDrive;
  WHILE NOT InitLibFile(f, fcb, firstDrive) DO
    REPEAT
      firstDrive := (firstDrive + 1) MOD 16;
      IF firstDrive = drive THEN
        BDOS(FUSERNUM, userNum);
        RETURN FALSE
      END;
    UNTIL firstDrive IN drives;
  END;
  BDOS(FUSERNUM, userNum);
  RETURN TRUE
END DirOpen;

(* Cherche dans les bibliothèques le module fname,
   symfile = TRUE pour un .SYM, symfile = FALSE pour un .MCD
   Initialise f et se positionne sur le début du module.
   Si le module n'est pas trouvé dans les bibliothèques,
   tente d'ouvrir le module depuis un disque connecté.
*)
(*  2 *) PROCEDURE LibOpen(VAR f: LibFile; VAR fname: ARRAY OF CHAR; symfile: BOOLEAN): BOOLEAN;
CONST LASTENTRY = 31;
TYPE LibEntry = RECORD
                  name: Name;
                  firstSect, nbSect: ARRAY BOOLEAN OF CARDINAL;
                END;
     Directory = RECORD
                    entries : ARRAY [0..LASTENTRY-1] OF LibEntry;
                    CASE : BOOLEAN OF
                    | TRUE : lastEntry: LibEntry;
                    | FALSE: continue: CARDINAL;
                    END;
                END;
    CardArrayPtr = POINTER TO ARRAY [0..255] OF CARDINAL;
VAR n,i: CARDINAL;
    name: Name;
    ext : Extension;
    local6 : BOOLEAN;
    local7 : LibFilePtr;
    local8 : POINTER TO Directory;
    local9 : POINTER TO LibEntry;
BEGIN
  i := 0; 
  REPEAT 
    name[i] := CAP(fname[i]); 
    INC(i) ;
  UNTIL (i > 7) OR (i > HIGH(fname)) OR (fname[i] = '.');
  n := 0;
  WHILE n < nbLibs DO 
    IF n IN presentLibs THEN
      local7 := libFilesPtr^[n];
      local6 := n IN global5;
      IF NOT local6 THEN
        local7^.pos := 0;
        local7^.bp  := 128;
        (* lit le catalogue de la bibliothèque *)
        IF LibRead(libFilesPtr^[n]^, catalogsPtr^[n], 498) THEN
          INCL(global5, n);
          local6 := TRUE;
        END;
      END;
      local8 := catalogsPtr^[n];
      WHILE local6 DO
        i := 0;
        REPEAT
          local9 := ADR(local8^.entries[i]);
          IF (local9^.nbSect[symfile] <> 0) AND (local9^.name = name) THEN
            f := libFilesPtr^[n]^;
            f.bp  := 128;
            (* se positionne sur le début du module *)
            f.pos := local9^.firstSect[symfile] * 4;
            RETURN TRUE
          END;
          INC(i)
        UNTIL i >= LASTENTRY;
        local6 := local8^.continue <> 0;
        IF local6 THEN
          local7^.pos := local8^.continue * 4;
          local7^.bp  := 128;
          EXCL(global5, n);
          local6 := LibRead(libFilesPtr^[n]^, catalogsPtr^[n], 498);
        END;
      END;
    END;
    INC(n);
  END;
  IF symfile THEN ext := "SYM" ELSE ext := "MCD" END;
  RETURN DirOpen(f, name, ext);
END LibOpen;

MODULE Helpers;
IMPORT BDOS, IORESULT, FCB, MOVE, ADR, ADDRESS;
IMPORT LibFile, Extension, userNum;

CONST FUSERNUM = 32;

BEGIN (* Internal module's INIT *)
  BDOS(FUSERNUM,255);
  userNum := IORESULT;
END Helpers;

(* 11 *) PROCEDURE Reserve(VAR ptr: ADDRESS; size: CARDINAL);
BEGIN
    global18 := global18 - size;
    IF global18 < global17 THEN RAISE OUTOFMEMORY END;
    ptr := global18
END Reserve;

(* 12 *) PROCEDURE Error(errorNum: CARDINAL; name: ARRAY OF CHAR);
BEGIN
  IF    errorNum = 0 THEN errorMsg := "Read Error      : ";
  ELSIF errorNum = 1 THEN errorMsg := "File not found  : ";
  ELSE                    errorMsg := "Out of memory";
  END;
  (* concatenate name to errorMsg *)
  MOVE(ADR(name), ADR(errorMsg[18]), HIGH(name)+1 );
  RAISE LoadError
END Error;


(* 13 *) PROCEDURE DisplayConflict(VAR param2, param1: Name);
(* 14 *) CONST ConflictMsg = "Version conflict";
BEGIN
  WriteLn;
  WriteString(ConflictMsg);
  WriteString(' between ');
  WriteString(param2);
  WriteString(' and ');
  WriteString(param1);
  global15 := FALSE;
  errorMsg := ConflictMsg;
END DisplayConflict;

(* 15 *) PROCEDURE AlreadyLoadedModule(
                    VAR moduleName: Name;
                    VAR referencingModule: Name;
                    referencedChecksum: CARDINAL;
                    VAR moduleAddr: ADDRESS): BOOLEAN;
VAR module: ModDescPtr;
BEGIN
  module := module1;
  WHILE module <> NIL DO
    IF module^.name = moduleName THEN
      IF (referencedChecksum <> 0) AND (module^.checksum <> referencedChecksum) THEN
        DisplayConflict(referencingModule, moduleName)
      END;
      moduleAddr := ADDRESS(module) + 80;
      RETURN TRUE;
    END;
    module := ADDRESS(module^.link);
  END;
  RETURN FALSE
END AlreadyLoadedModule;

(* 16 *) PROCEDURE proc16(param2, param1: ADDRESS);
VAR local2: ADDRESS;
BEGIN
  REPEAT
    local2 := ADDRESS(param1^);
    param1^:= param2;
    param1 := local2
  UNTIL local2 = NIL;
END proc16;

(* 17 *) PROCEDURE proc17(param2: CARDINAL; param1: ADDRESS); 
VAR module : ModDescPtr;
    local3 : POINTER TO ADDRESS;
    local4 : ADDRESS;
    local5 : ADDRESS;
    local6 : ADDRESS;
    local7 : CARDINAL;
    local8 : ADDRESS;
BEGIN
  WHILE param2 <> 0 DO
    module := allocAddr + CARDINAL(param1^) - 80;
    INC(param1, 2);
    local7 := CARDINAL(param1^);
    INC(param1, 2);
    IF module <> allocAddr - 80 THEN
      local8 := module^.loadAddr;
      local5 := param1 + (ORD(module^.bytes[1]) + 42) * 2;
      local6 := module;
      REPEAT
        local3 := local8 + CARDINAL(param1^);
        INC(param1, 2);
        WHILE local3 <> local8 DO
          local4 := local8 + CARDINAL(local3^);
          local3^:= local6;
          local3 := local4;
        END;
        local6 := local6 + 2;
      UNTIL param1 = local5;
      IF local7 <> 0 THEN
        local5 := param1 + local7 * 2;
        REPEAT
          local3 := local8 + CARDINAL(param1^);
          INC(param1, 2);
          INC(local3^, CARDINAL(local8));
        UNTIL param1 = local5;
      END;
    END;
    DEC(param2)
  END
END proc17;

(* 18 *) PROCEDURE proc18(VAR modName, referencer: Name;
                          checksum : CARDINAL; (* checksum *)
                          VAR param1: FlagSetPtr (* flags ou ptr to flags *)
                         );

(* 19 *)   PROCEDURE Read(param2: ADDRESS; param1: CARDINAL);
  BEGIN
    IF NOT LibRead(global14^, param2, param1) THEN Error(0, modName) END;
  END Read;

TYPE Record = RECORD
                fileSize,
                moduleStart,
                dependencies,
                nbDependencies,
                word4,
                word5,
                word6,
                word7: CARDINAL;
              END;
VAR modDescPtr: ModDescPtr;
    aModDescPtr: ModDescPtr;
    header: Record;
    i: INTEGER;
    moduleStart: ADDRESS;
    dependencySize: CARDINAL;
    local8: INTEGER;
    dependencies: POINTER TO ARRAY [0..31] OF Dependency;
    local10:ADDRESS;
    local11:ADDRESS;
    local12:INTEGER;
    local13: BOOLEAN;
BEGIN
  IF global16 THEN
    local13 := DirOpen(global14^, modName, 'MCD');
  ELSE
    local13 := LibOpen(global14^, modName, FALSE);
  END;
  IF NOT local13 THEN Error(1, modName) END;
  moduleStart := allocAddr;

  (* first read the 16 bytes header, it contains the filesize *)
  Read(ADR(header), SIZE(header));
  (* $O+ *)
  IF allocAddr + header.fileSize + 100 > ADR(header) THEN Error(2, '') END;
  (* $O- *)

  (* then read the rest of the file *)
  Read(allocAddr, header.fileSize);
  dependencySize := header.nbDependencies * 12;
  (* but move the dependencies elsewhere *)
  Reserve(dependencies, dependencySize);
  MOVE(allocAddr + header.dependencies, dependencies, dependencySize);

  (* update the references *)
  modDescPtr := allocAddr + header.moduleStart;
  aModDescPtr := modDescPtr;
  local8 := 0;
  LOOP
    INC(local8);
    FOR i := 0 TO 1 - INTEGER(CARD(INTEGER(aModDescPtr^.bytes[3]))) BY -1 DO
      IF aModDescPtr^.procs[i+31] <> 0 THEN
        INC(aModDescPtr^.procs[i+31], moduleStart)
      END;
    END;
    INC(aModDescPtr^.loadAddr, moduleStart);
    INC(aModDescPtr^.procsAddr, moduleStart);
    INCL(aModDescPtr^.flags, RECURSEFLAG);
    IF aModDescPtr^.link = NIL THEN EXIT END;
    aModDescPtr^.link := ADDRESS(aModDescPtr^.link) + moduleStart;
    aModDescPtr := aModDescPtr^.link;
  END;

  IF (checksum <> 0) AND (aModDescPtr^.checksum <> checksum) THEN
    DisplayConflict(referencer, aModDescPtr^.name)
  END;

  IF NOT AlreadyLoadedModule(aModDescPtr^.name, referencer, aModDescPtr^.checksum, param1) THEN
    proc17(local8, allocAddr + header.dependencies + dependencySize);
    aModDescPtr^.link := module1;
    module1 := modDescPtr;
    param1  := ADR(aModDescPtr^.flags);
    allocAddr := allocAddr + header.dependencies;
    i := 0;
    WHILE i < INTEGER(CARD(INTEGER(header.nbDependencies))) DO
      WITH dependencies^[i] DO
        IF NOT AlreadyLoadedModule(name, aModDescPtr^.name, version, local10) THEN
          IF global16 THEN
            local12 := NLibs() * (TSIZE(LibFile) + 512) + 200;
            Reserve(local11, local12);
            InitLibs(local11, local12);
            global16 := FALSE;
          END;
        (* recursive call *)
          proc18(name, aModDescPtr^.name, version, local10);
        END;
        proc16(local10, location + moduleStart);
      END;
      INC(i);
    END;
  END;
END proc18;

(* 20 *) PROCEDURE proc20(module: ModDescPtr);
VAR local2 : INTEGER;
    dependencyModule : ADDRESS;
    local4 : INTEGER;
BEGIN
  EXCL(module^.flags, RECURSEFLAG);
  local2 := 0;
  local4 := 1 - CARD(INTEGER(module^.bytes[3]));
  WHILE local2 >= local4 DO
    dependencyModule := module^.procs[local2+31];
    IF (dependencyModule <> NIL)
    AND (RECURSEFLAG IN FlagSet(dependencyModule^)) THEN
      proc20(dependencyModule - 80)  (* recursive ! *)
    END;
    DEC(local2);
  END;
  IF global13 = NIL THEN module1 := module 
  ELSE global13^.link := module 
  END;
  global13 := module;
END proc20;

(* $[- : retain procedure name because of exception handler *)

(* 21 *) PROCEDURE LoadTh(name: Name; block: ARRAY OF CHAR);
VAR oldFirstModule: ADDRESS;
    moduleAddr: ADDRESS;
    local4 : ARRAY [0..127] OF CHAR;
BEGIN
  global17 := ADR(block);
  global18 := global17 + SIZE(block);
  Reserve(global14, SIZE(global14^));
  buffer   := ADR(local4);
  oldFirstModule   := module1;
  global16 := TRUE;
  global15 := TRUE;
  proc18(name, name, 0, moduleAddr);
  IF global15 THEN
    IF module1 <> oldFirstModule THEN
      global13 := NIL;
      proc20(moduleAddr - 80);
    END;
  END;
EXCEPTION
| LoadError : global15 := FALSE
END LoadTh;

(*  6 *) PROCEDURE Call(modName: ARRAY OF CHAR);
TYPE Procedure  = RECORD
                    CASE : BOOLEAN OF
                    | FALSE: proc : PROC;
                    | TRUE : module,procAddr: CARDINAL;
                    END
                  END;
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
     MemPtr     = RECORD
                    CASE : CARDINAL OF
                    | 0: blockPtr: ADDRESS;
                    | 1: smallBlockPtr: POINTER TO ARRAY [0..4711] OF CHAR;
                    | 2: bigBlockPtr: POINTER TO ARRAY [0..8731] OF CHAR;
                    END
                  END;

VAR
    callerTask [0308H]: ContextPtr;
    calledTask [030AH]: ContextPtr;
    modulePtr : ModDescPtr;
    oldFirstModule : ModDescPtr;
    saveCallerTask : PROCESS;
    saveCalledTask : PROCESS;
    saveHeapAddr : ADDRESS;
    varCount : CARDINAL;
    varSize : CARDINAL;
    globalVarsPtr : POINTER TO ARRAY [0..255] OF CARDINAL;
    local10: MemPtr;
    proc: Procedure;
    name: Name;
    context: ContextPtr;
BEGIN
  IF HIGH(modName) > 7 THEN modName[8] := 0C END;
  name := modName;
  oldFirstModule  := module1; 
  saveCallerTask  := callerTask;
  saveCalledTask  := calledTask;
  MARK(saveHeapAddr);
  allocAddr := saveHeapAddr + 4;
  local10.blockPtr := 1; (* TODO: replace by 0500H *)
  IF NLibs() <= 4
  THEN LoadTh(name, local10.smallBlockPtr^);
  ELSE LoadTh(name, local10.bigBlockPtr^);
  END;

  (* allocate memory for global arrays and records *)
  modulePtr := module1;
  WHILE global15 AND (modulePtr <> oldFirstModule) DO
    varCount := ORD(modulePtr^.bytes[1]);
    globalVarsPtr := ADDRESS(modulePtr) + TSIZE(ModuleDesc);
    WHILE global15 AND (varCount <> 0) DO
      DEC(varCount);
      varSize := globalVarsPtr^[varCount];
      IF varSize <> 0 THEN
        (* $O+ *)
        IF allocAddr + varSize + 100 > ADR(proc) THEN
        (* $O- *)
          errorMsg := "Out of memory";
          global15 := FALSE
        ELSE
          FILL(allocAddr, varSize, 0);
          globalVarsPtr^[varCount] := CARDINAL(allocAddr);
          allocAddr := allocAddr + varSize;
        END;
      END;
    END;
    modulePtr := modulePtr^.link;
  END;

  (* initializes the modules that requires it.
     The called module will be the last one initialized, thus run...
  *)
  
  IF global15 THEN
    modulePtr := module1;
    WHILE modulePtr <> oldFirstModule DO
      IF TOINIT IN modulePtr^.flags THEN
        proc.module   := ADDRESS(modulePtr) + 80;
        proc.procAddr := 0; (* procnum of INIT is 0 *)
        (* create a process, giving it all memory from current alloc addr *)
        NEWPROCESS(proc.proc, allocAddr, ADR(proc)-50-ADDRESS(allocAddr), calledTask);
        TRANSFER(callerTask, calledTask);
        (* once the init is finished (opcode 50), get the new heap ptr by peeking it
           directly in the context of the finished process *)
        context   := calledTask;
        allocAddr := context^.StackLimit - 60;
      END;
      modulePtr := modulePtr^.link;
    END;
  END;
  RELEASE(saveHeapAddr);
  callerTask := saveCallerTask;
  calledTask := saveCalledTask;
  module1 := oldFirstModule;
  IF NOT global15 THEN RAISE LoadError, errorMsg END
END Call;

(* $[+ : remove procedure names *)

BEGIN
  BDOS(DRVGET, 0);
  firstDrive := IORESULT
END Loader.

