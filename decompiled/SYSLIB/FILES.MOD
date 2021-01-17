(*
    Perfect decompilation of original FILES module.
    Uses READBYTE.COM for the Z80 implementation of ReadByte
    Uses BDOS functions for access to the CP/M filesystem.
*)
IMPLEMENTATION MODULE Files;
 FROM SYSTEM IMPORT ADR, BDOS, IORESULT, HLRESULT, MOVE, FILL, CODE;
 FROM STORAGE IMPORT ALLOCATE, DEALLOCATE;

 (* BDOS functions *)
 CONST DRVRESET = 13; DRVSET = 14; DRVGET = 25; DRVROVEC = 29;
       FOPEN = 15; FCLOSE = 16; FDELETE = 19; FMAKE = 22; FRENAME = 23;
       DMAOFFSET = 26; FUSERNUM = 32;
       READRAND = 33; WRITERAND = 34; FSIZE = 35;

 CONST FILEMARKER = 7A39H; 
       RECORDNUM = 33;     (* offset of random record number in FCB *)

 TYPE FCB = ARRAY [0..35] OF CHAR;
 TYPE FCBADDR = POINTER TO FCB;

 TYPE TRAILER = (NOTRAILER, UNKNOWNTRAILER, PADDING, PADDING128); 
 (* NB: PADDING128 occurs when file size is a multiple of 128 and last
    byte is non-ASCII (> 127) *)

 TYPE FileDesc = RECORD
                   marker: CARDINAL;
                   posPtr: ADDRESS;
                   dataEnd: ADDRESS;
                   buffer: ADDRESS;
                   bufferEnd: CARDINAL;
                   bufferDirty: BOOLEAN;
                   currentRec: CARDINAL;
                   nbRecords: CARDINAL;
                   padding: CARDINAL;
                   trailer: TRAILER;
                   fcb: FCB;
                   user   : CARDINAL;
                 END;
 TYPE FILE = POINTER TO FileDesc;
 TYPE ERROR = (Unknown0, Unknown1, ENDERROR, DEVICEERROR, DISKFULL);

 VAR userSave: CARDINAL;

 (* $[+ remove procedure names *)

 PROCEDURE Error(f: FILE; error: ERROR);
 VAR msgBuffer: ARRAY [0..37] OF CHAR;
     ptr: POINTER TO ARRAY [0..15] OF CHAR;
 BEGIN 
   msgBuffer := "While processing file ";
   ptr := ADR(msgBuffer[22]);
   GetName(f, ptr^);
   CASE error OF
   | ENDERROR    : RAISE EndError, msgBuffer
   | DEVICEERROR : RAISE DeviceError, msgBuffer
   | DISKFULL    : RAISE DiskFull, msgBuffer
   END;
 END Error;

 PROCEDURE CheckFile(f: FILE);
 BEGIN
   IF (f = NIL) OR (f^.marker <> FILEMARKER) THEN
     RAISE StatusError, "Processing unopened file"
   END;
 END CheckFile;

 PROCEDURE GetDriveAndUser(VAR filename: ARRAY OF CHAR; VAR drive: CARDINAL; VAR user: CARDINAL);
 VAR i: CARDINAL;
 VAR n: CARDINAL;
 VAR userNum: CARDINAL;
 VAR driveSpecified: BOOLEAN;
 VAR currentDrive: CARDINAL;
 VAR currentUser: CARDINAL;
 VAR unused: ARRAY [0..7] OF CHAR;
 BEGIN
   BDOS(DRVGET, 0);      currentDrive := IORESULT + 1;
   BDOS(FUSERNUM, 255);  currentUser  := IORESULT;
   driveSpecified := FALSE;
   i := 0;
   IF (CAP(filename[0]) >= 'A') AND (CAP(filename[0]) <= 'P') THEN
     drive := ORD(CAP(filename[0])) - 64;
     driveSpecified := TRUE;
     i := 1;
   ELSE
     drive := currentDrive;
   END;
   n := 0;
   userNum := currentUser;
   WHILE (i <= 3) AND (filename[i]>='0') AND (filename[i]<='9') DO
     driveSpecified := TRUE;
     n :=  n * 10 + (ORD(filename[i]) - ORD('0'));
     INC(i);
     userNum := n;
   END;
   driveSpecified := (filename[i] = ':') AND driveSpecified AND (userNum < 32);
   IF driveSpecified THEN
     MOVE(ADR(filename[i+1]), ADR(filename), HIGH(filename) - i);
     filename[HIGH(filename) - i] := 0C;
     user := userNum;
   ELSE
     drive := currentDrive;
     user  := currentUser;
   END;
 END GetDriveAndUser;

 PROCEDURE BuildFCB(VAR fcb: FCB; VAR filename: ARRAY OF CHAR; VAR user: CARDINAL);
 VAR i,j : CARDINAL;
 VAR drive: CARDINAL;
 BEGIN
   fcb := "            ";
   GetDriveAndUser(filename, drive, user);
   fcb[0] := CHR(drive);
   i := 0; j := 1;
   WHILE (i <= HIGH(filename)) AND (filename[i] <> 0C) DO
     IF filename[i] = '.' THEN
       INC(i);
       j := 9;
       WHILE (i <= HIGH(filename)) AND (filename[i] <> 0C) DO
         IF j <= 11 THEN fcb[j] := CAP(filename[i]); INC(j) END;
         INC(i);
       END;
     END;
     IF j <= 8 THEN fcb[j] := CAP(filename[i]); INC(j) END;
     INC(i);
   END;
 END BuildFCB;

 (* $[- keep procedure names *)

 PROCEDURE GetName(f: FILE; VAR name: ARRAY OF CHAR);
 VAR filename: ARRAY [0..16] OF CHAR;
 VAR i: CARDINAL;
 VAR n: CARDINAL;
 VAR char: CHAR;
 BEGIN
   CheckFile(f);
   filename[0] := CHR(ORD(f^.fcb[0]) + 64);
   n := f^.user;
   filename[1] := CHR(n DIV 10 + ORD('0'));
   filename[2] := CHR(n MOD 10 + ORD('0'));
   filename[3] := ':';
   n := 4;
   i := 1;
   REPEAT
     IF i = 9 THEN filename[n] := '.'; INC(n) END;
     char := CHR(ORD(f^.fcb[i]) MOD 128);
     IF char <> ' ' THEN filename[n] := char; INC(n) END;
     INC(i);
   UNTIL i > 11;
   name := filename;
 END GetName;

 (* proc 31 *)
 PROCEDURE GoToUser(user: CARDINAL);
 BEGIN
   BDOS(FUSERNUM, 255); userSave := IORESULT;
   BDOS(FUSERNUM, user);
 END GoToUser;
 
 (* proc 32 *)
 PROCEDURE ReturnToUser;
 BEGIN
   BDOS(FUSERNUM, userSave)
 END ReturnToUser;

 (* $[+ remove procedure names *)

 (* proc 17 *)
 PROCEDURE Flush(f: FILE);
 VAR ptrRecordNum: POINTER TO CARDINAL;
 VAR ptrDataEnd: POINTER TO ARRAY [0..127] OF CHAR;
 VAR ptrRecord: ADDRESS;
 VAR ptrFileEnd: ADDRESS;
 VAR padding: CARDINAL;
 VAR file: FILE;
 BEGIN
   file := f;
   IF file^.bufferDirty THEN
     file^.bufferDirty := FALSE;
     GoToUser(file^.user);

     (* consolidate file end *)
     IF file^.dataEnd < file^.posPtr THEN file^.dataEnd := file^.posPtr END;
     ptrDataEnd := file^.dataEnd;
     padding := (file^.buffer + 512 - ADDRESS(ptrDataEnd)) MOD 128;
     ptrFileEnd := ADDRESS(ptrDataEnd) + padding;
     IF padding <> 0 THEN
       FILL(ptrDataEnd, padding, 0);
       IF file^.trailer <> NOTRAILER THEN
         ptrDataEnd^[padding-1] := CHR(256 - padding);
         file^.trailer := PADDING;
       END;
     END;

     (* write the needed 128-bytes record *)
     ptrRecord := file^.buffer;
     ptrRecordNum := ADR(file^.fcb[RECORDNUM]);
     ptrRecordNum^ := file^.currentRec;
     WHILE ptrRecord <> ptrFileEnd DO
       BDOS(DMAOFFSET, ptrRecord);
       BDOS(WRITERAND, ADR(file^.fcb));
       IF IORESULT <> 0 THEN
         ReturnToUser;
         Error(f, DISKFULL);
       END;
       INC(ptrRecord, 128);
       INC(ptrRecordNum^);
     END;

     (* what if the old number of records has been reached *)
     IF ptrRecordNum^ >= file^.nbRecords THEN
       file^.nbRecords := ptrRecordNum^;
       IF file^.trailer <> NOTRAILER THEN
         IF padding = 0 THEN
           ptrDataEnd := ADDRESS(ptrDataEnd) - 1;
           file^.trailer := TRAILER(ORD(PADDING) + ORD(ORD(ptrDataEnd^[0]) >= 128));
         END;
         file^.padding := padding;
       END;
     END;
     ReturnToUser;
   END;
 END Flush;

 (* fill the file buffer with the next 4 records read from disk,
    return the size of real data (less than 512 if end of file reached) *)
 PROCEDURE ReadBuffer(f: FILE): CARDINAL;
 VAR ptrRecordNum: POINTER TO CARDINAL;
 VAR ptrLastByte: POINTER TO ARRAY [0..127] OF BYTE;
 VAR file: FILE;
 BEGIN
   file := f;
   GoToUser(file^.user);
   file^.dataEnd := file^.buffer;    (* means buffer is empty *)
   IF file^.currentRec < file^.nbRecords THEN
     ptrRecordNum := ADR(file^.fcb[RECORDNUM]);
     ptrRecordNum^ := file^.currentRec; (* ready to read current record *)
     LOOP
       BDOS(DMAOFFSET, f^.dataEnd);
       BDOS(READRAND, ADR(file^.fcb));
       IF IORESULT <> 0 THEN
         ReturnToUser;
         Error(f, DEVICEERROR);
       END;
       INC(file^.dataEnd, 128);
       INC(ptrRecordNum^);
       IF ptrRecordNum^ = file^.nbRecords THEN (* last record was read *)
         IF file^.trailer = UNKNOWNTRAILER THEN
           ptrLastByte := file^.dataEnd - 1;
           file^.padding := 256 - ORD(ptrLastByte^[0]);
           IF file^.padding > 128 THEN file^.padding := 0 END;
           file^.trailer := PADDING;
         END;
         file^.dataEnd := file^.dataEnd - file^.padding;
         EXIT;
       END;
       IF file^.dataEnd = file^.bufferEnd THEN EXIT END;
     END;
   END;
   ReturnToUser;
   RETURN file^.dataEnd - file^.buffer
 END ReadBuffer;

 PROCEDURE CheckWriteProtect(VAR fcb: FCB);
 VAR msg : ARRAY [0..19] OF CHAR;
 BEGIN
   BDOS(DRVROVEC, 0);
   IF ORD(fcb[0])-1 IN BITSET(HLRESULT) THEN
     msg := "Drive @ is Read-Only";
     msg[6] := CHR(ORD(fcb[0]) + ORD('@'));
     RAISE UseError, msg
   END;
 END CheckWriteProtect;

 (* proc 35 *)
 PROCEDURE InitFile(VAR f: FILE; VAR fcb: FCB; user: CARDINAL);
 VAR ptr: POINTER TO CARDINAL;
 VAR file: FILE;
 BEGIN
   NEW(f);
   file := f;
   file^.marker := FILEMARKER;
   ALLOCATE(file^.buffer, 512);
   file^.posPtr := file^.buffer;
   file^.dataEnd := file^.buffer;
   file^.bufferEnd := file^.buffer;
   GoToUser(user);
   BDOS(FSIZE, ADR(fcb));
   ReturnToUser;
   ptr := ADR(fcb[RECORDNUM]);
   file^.nbRecords := ptr^;
   file^.trailer := UNKNOWNTRAILER;
   file^.user := user;
   file^.fcb := fcb;
 END InitFile;

 (* $[- keep procedure names *)

 PROCEDURE Open(VAR f: FILE; name: ARRAY OF CHAR): BOOLEAN;
 VAR fcb: FCB;
 VAR user: CARDINAL;
 VAR success: BOOLEAN;
 BEGIN
   BuildFCB(fcb, name, user);
   GoToUser(user);
   BDOS(FOPEN, ADR(fcb));
   success := IORESULT <> 255;
   ReturnToUser;
   IF success THEN InitFile(f, fcb, user) END;
   RETURN success
 END Open;

 PROCEDURE Create(VAR f: FILE; name: ARRAY OF CHAR);
 VAR fcb: FCB;
 VAR success, failure: BOOLEAN;
 VAR user: CARDINAL;
 BEGIN
   BuildFCB(fcb, name, user);
   GoToUser(user);
   BDOS(FOPEN, ADR(fcb));
   success := IORESULT <> 255;
   ReturnToUser;
   CheckWriteProtect(fcb);
   GoToUser(user);
   IF success THEN BDOS(FDELETE, ADR(fcb)) END;
   BDOS(FMAKE, ADR(fcb));
   failure := IORESULT = 255;
   ReturnToUser;
   IF failure THEN RAISE DiskFull, "Directory Overflow" END;
   InitFile(f, fcb, user);
 END Create;

 PROCEDURE Close(VAR f: FILE);
 VAR buf: ARRAY [0..127] OF BYTE;
 VAR failure: BOOLEAN;
 VAR file: FILE;
 BEGIN
   IF (f <> NIL) AND (f^.marker = FILEMARKER) THEN
     Flush(f);
     file := f;
     IF file^.trailer = PADDING128 THEN (* append a full padding record *)
       buf[127] := 128;
       SetPos(f, FileSize(f));
       WriteRec(f, buf);
       Flush(f);
     END;
     GoToUser(f^.user);
     BDOS(FCLOSE, ADR(file^.fcb));
     failure := IORESULT = 255;
     ReturnToUser;
     IF failure THEN Error(f, DEVICEERROR) END;
     DEALLOCATE(file^.buffer, 512);
     DISPOSE(f);
   END;
 END Close;

 PROCEDURE Delete(VAR f: FILE);
 VAR file: FILE;
 BEGIN
   IF (f <> NIL) AND (f^.marker = FILEMARKER) THEN
     file := f;
     CheckWriteProtect(file^.fcb);
     GoToUser(f^.user);
     BDOS(FCLOSE, ADR(file^.fcb));
     BDOS(FDELETE, ADR(file^.fcb));
     ReturnToUser;
     DEALLOCATE(file^.buffer, 512);
     DISPOSE(f);
   END;
 END Delete;

 PROCEDURE Rename(VAR f: FILE; name: ARRAY OF CHAR);
 VAR fcb1, fcb2: FCB;
 VAR i: CARDINAL;
 VAR user: CARDINAL;
 BEGIN
   IF (f <> NIL) AND (f^.marker = FILEMARKER) THEN
     fcb1 := f^.fcb;
     BuildFCB(fcb2, name, user);
     fcb2[0] := fcb1[0];
     i := 1;
     WHILE fcb2[i] = fcb1[i] DO
       INC(i);
       IF i = 12 THEN RETURN END;
     END;
     CheckWriteProtect(fcb1);
     user := f^.user;
     Close(f);
     GoToUser(user);
     BDOS(FDELETE, ADR(fcb2));
     MOVE(ADR(fcb2), ADR(fcb1)+16, 16);
     BDOS(FRENAME, ADR(fcb1));
     ReturnToUser;
  END;
 END Rename;

 PROCEDURE NoTrailer(f: FILE);
 BEGIN
   CheckFile(f);
   f^.trailer := NOTRAILER;
   f^.padding := 0;
 END NoTrailer;

 PROCEDURE FileSize(f: FILE): LONGINT;
 VAR buf: ARRAY [0..127] OF BYTE;
 VAR ptrRecordNum: POINTER TO CARDINAL;
 VAR file: FILE;
 BEGIN
   CheckFile(f);
   file := f;
   IF file^.dataEnd < file^.posPtr THEN file^.dataEnd := file^.posPtr END;
   IF file^.currentRec + ORD(file^.bufferEnd <> file^.buffer) * 4 >= file^.nbRecords THEN
     RETURN LONG(file^.currentRec) * LONG(128) + LONG(file^.dataEnd - file^.buffer)
   END;
   IF file^.trailer = UNKNOWNTRAILER THEN (* read last record *)
     ptrRecordNum := ADR(file^.fcb[RECORDNUM]);
     ptrRecordNum^ := file^.nbRecords - 1; 
     GoToUser(file^.user);
     BDOS(DMAOFFSET, ADR(buf));
     BDOS(READRAND, ADR(file^.fcb));
     ReturnToUser;
     file^.padding := 256 - ORD(buf[127]);
     IF file^.padding > 128 THEN file^.padding := 0 END;
     file^.trailer := PADDING;
   END;
   RETURN LONG(file^.nbRecords) * LONG(128) - LONG(file^.padding)
 END FileSize;

 PROCEDURE EOF(f: FILE): BOOLEAN;
 BEGIN
   CheckFile(f);
   RETURN (f^.posPtr >= f^.dataEnd) 
      AND (f^.currentRec + ORD(f^.bufferEnd <> f^.buffer) * 4 >= f^.nbRecords)
 END EOF;

 PROCEDURE ReadBytes(f: FILE; buf: ADDRESS; nbytes: CARDINAL): CARDINAL;
 VAR n: CARDINAL;
 VAR size: CARDINAL;
 VAR file: FILE;
 BEGIN
   CheckFile(f);
   file := f;
   n := 0;
   IF file^.dataEnd > file^.posPtr THEN (* buffer still has unread bytes *)
     n := file^.dataEnd - file^.posPtr;  (* number of unread bytes *)
     IF n >= nbytes THEN                (* enough bytes in buffer *)
       MOVE(file^.posPtr, buf, nbytes);
       INC(file^.posPtr, nbytes);
       RETURN nbytes;
     END;
                                        (* else *)
     MOVE(file^.posPtr, buf, n);        (* start with the buffer bytes *)
     INC(buf, n);
     INC(file^.posPtr, n);
   END;
   IF file^.dataEnd <> file^.bufferEnd THEN RETURN n END; (* incomplete buffer *)
   IF file^.bufferEnd = file^.buffer
   THEN INC(file^.bufferEnd, 512)       (* buffer was empty: no need to update *)
   ELSE Flush(f);                       (* update file contents if buffer modified *)
        INC(file^.currentRec, 4)
   END;
   WHILE n + 512 < nbytes DO
     size := ReadBuffer(f);
     MOVE(file^.buffer, buf, size);
     INC(buf, size);
     INC(n, size);
     IF size < 512 THEN file^.posPtr := file^.dataEnd; RETURN n END;
     INC(file^.currentRec, 4);
   END;
   size := ReadBuffer(f);
   IF size > nbytes - n THEN size := nbytes - n END;
   MOVE(file^.buffer, buf, size);
   file^.posPtr := file^.buffer + size;
   RETURN n + size
 END ReadBytes;

 PROCEDURE ReadByte(f: FILE; VAR ch: BYTE);
   CODE("READBYTE");
(*
 (* Equivalent to following code *)
 VAR ptr: POINTER TO ARRAY [0..1] OF BYTE;
 VAR buf: ARRAY [0..1] OF BYTE;
 BEGIN
   IF (f <> NIL) AND (f^.marker = FILEMARKER) THEN
     ptr := f^.posPtr;
     IF ADDRESS(ptr) < f^.dataEnd THEN
       ch := ptr^[0];
       f^.posPtr := ADDRESS(ptr) + 1;
       RETURN
     END;
   END;
   IF ReadBytes(f, ADR(buf), 1) <> 1 THEN Error(f, ENDERROR) END;
   ch := buf[0];
*)
 END ReadByte;

 PROCEDURE ReadWord(f: FILE; VAR w : WORD);
 BEGIN
   CheckFile(f);
   IF f^.posPtr + 1 < f^.dataEnd THEN
     w := f^.posPtr^;
     INC(f^.posPtr, 2);
     RETURN
   END;
   ReadRec(f, w);
 END ReadWord;

 PROCEDURE ReadRec(f: FILE; VAR rec: ARRAY OF WORD);
 BEGIN
   IF ReadBytes(f, ADR(rec), (HIGH(rec)+1)*2 ) <> (HIGH(rec)+1)*2 THEN
     Error(f, ENDERROR)
   END;
 END ReadRec;

 PROCEDURE WriteBytes(f: FILE; buf: ADDRESS; nbytes: CARDINAL);
 VAR n: CARDINAL;
 VAR dummy: CARDINAL;
 VAR file: FILE;
 BEGIN
   CheckFile(f);
   file := f;
   n := file^.bufferEnd - file^.posPtr;
   IF n <> 0 THEN
     file^.bufferDirty := TRUE;
     IF n >= nbytes THEN
       MOVE(buf, file^.posPtr, nbytes);
       INC(file^.posPtr, nbytes);
       RETURN
     END; (* 0821 *)
     MOVE(buf, file^.posPtr, n);
     DEC(nbytes, n); INC(buf, n);
   END; (* 082f *)
   IF file^.bufferEnd = file^.buffer THEN
     INC(file^.bufferEnd, 512);
     file^.posPtr := file^.bufferEnd;
   ELSE
     file^.posPtr := file^.bufferEnd;
     Flush(f);
     INC(file^.currentRec, 4);
   END; (* 0851 *)
   WHILE nbytes > 512 DO
     MOVE(buf, file^.buffer, 512);
     DEC(nbytes, 512); INC(buf, 512);
     file^.bufferDirty := TRUE;
     Flush(f);
     INC(file^.currentRec, 4);
   END; (* 087a *)
   (* if last buffer write is not a full 512-byte,
     then the buffer needs to be read before being partially modified *)
   IF nbytes <> 512 THEN dummy := ReadBuffer(f) END;
   MOVE(buf, file^.buffer, nbytes);
   file^.bufferDirty := TRUE;
   file^.posPtr := file^.buffer + nbytes;
 END WriteBytes;


 PROCEDURE WriteByte(f: FILE; ch: BYTE);
   CODE("WRITEBYT")
(*
 (* Equivalent to following code *)
 VAR ptr: POINTER TO ARRAY [0..1] OF BYTE;
 VAR buf: ARRAY [0..1] OF BYTE;
 BEGIN
   IF (f <> NIL) AND (f^.marker = FILEMARKER) THEN
     ptr := f^.posPtr;
     IF ADDRESS(ptr) < f^.bufferEnd THEN
       f^.bufferDirty := TRUE;
       ptr^[0] := ch;
       f^.posPtr := ADDRESS(ptr) + 1;
       RETURN
     END;
   END;
   buf[0] := ch;
   WriteBytes(f, ADR(buf), 1);
*)
 END WriteByte;

 PROCEDURE WriteWord(f: FILE;  w: WORD);
 BEGIN
   CheckFile(f);
   IF f^.posPtr < f^.bufferEnd - 1 THEN
     f^.posPtr^ := w;
     INC(f^.posPtr, 2);
     f^.bufferDirty := TRUE;
     RETURN
   END;
   WriteRec(f, w);
 END WriteWord;

 PROCEDURE WriteRec(f: FILE; VAR rec: ARRAY OF WORD);
 BEGIN
   WriteBytes(f, ADR(rec), (HIGH(rec)+1)*2 );
 END WriteRec;

 PROCEDURE NextPos(f: FILE): LONGINT;
 BEGIN
   CheckFile(f);
   RETURN LONG(f^.currentRec) * LONG(128) + LONG(f^.posPtr-f^.buffer)
 END NextPos;

 PROCEDURE SetPos(f: FILE; pos: LONGINT);
 VAR recordNum: CARDINAL;
 VAR bufOffset: CARDINAL;
 VAR dummy: CARDINAL;
 VAR changeBuffer: BOOLEAN;
 VAR file: FILE;
 BEGIN
   CheckFile(f);
   IF pos > FileSize(f) THEN Error(f, ENDERROR) END;
   bufOffset := CARD(pos MOD LONG(512));
   recordNum := CARD((pos - LONG(bufOffset)) DIV LONG(128));
   file := f;
   IF file^.bufferEnd = file^.buffer THEN
     INC(file^.bufferEnd, 512);
     changeBuffer := TRUE;
   ELSE
     changeBuffer := (recordNum <> file^.currentRec);
     IF changeBuffer THEN Flush(f) END;
   END;
   IF changeBuffer THEN
     file^.currentRec := recordNum;
     IF bufOffset = 0 THEN
       file^.dataEnd := file^.buffer;
       file^.bufferEnd := file^.buffer;
     ELSE
       dummy := ReadBuffer(f)
     END;
   END;
   file^.posPtr := file^.buffer + bufOffset;
 END SetPos;

 (* $[+ remove procedure names *)

 PROCEDURE ResetSys( );
 VAR drive: CARDINAL;
 BEGIN
   BDOS(DRVGET, 0);
   drive := IORESULT;
   GoToUser(0);
   BDOS(DRVRESET, 0);
   BDOS(DRVSET, drive);
   ReturnToUser;
 END ResetSys;

END Files.

