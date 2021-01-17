(*
    Perfect decompilation of original Processes module.
*)
IMPLEMENTATION MODULE Processes[1];
FROM SYSTEM IMPORT PROCESS, NEWPROCESS, TRANSFER, ADDRESS, ADR, TSIZE;
FROM STORAGE IMPORT ALLOCATE;
TYPE SignalDesc = RECORD
                    next, nextWaiting: SIGNAL;
                    process: PROCESS;
                    running: BOOLEAN;
                  END;
     SIGNAL = POINTER TO SignalDesc;

VAR processes, thisProcess: SIGNAL;

PROCEDURE StartProcess(P: PROC; n: CARDINAL);
VAR callingProcess: SIGNAL;
VAR wrkArea: ADDRESS;
BEGIN
  callingProcess := processes;
  ALLOCATE(wrkArea, n);
  ALLOCATE(processes, TSIZE(SignalDesc));
  WITH processes^ DO
    next := callingProcess^.next;
    callingProcess^.next := processes;
    running := TRUE;
    nextWaiting := NIL;
  END;
  NEWPROCESS(P, wrkArea, n, processes^.process);
  TRANSFER(callingProcess^.process, processes^.process);
END StartProcess;


PROCEDURE SEND(VAR s: SIGNAL);
VAR senderProcess: SIGNAL;
BEGIN
  IF s # NIL THEN
    senderProcess := processes;
    processes := s;
    WITH processes^ DO
      s           := nextWaiting;
      running       := TRUE;
      nextWaiting := NIL;
    END;
    TRANSFER(senderProcess^.process, processes^.process);
  END; 
END SEND;

PROCEDURE WAIT(VAR s: SIGNAL);
VAR last, nextWaiting: SIGNAL;
BEGIN
  IF s = NIL
  THEN s := processes    (* first of the list is the caller process *)
  ELSE  (* put the caller after the last process of the waiting queue *)
    last := s;
    nextWaiting := last^.nextWaiting;
    WHILE nextWaiting # NIL DO
      last     := nextWaiting;
      nextWaiting := last^.nextWaiting 
    END;
    last^.nextWaiting := processes;
  END;
  last := processes; (* last means last running process, ie. caller of WAIT *)
  REPEAT processes := processes^.next UNTIL processes^.running;
  IF processes = last THEN RAISE DeadLock END;
  last^.running := FALSE;
  TRANSFER(last^.process, processes^.process);
END WAIT;

PROCEDURE Awaited(s: SIGNAL): BOOLEAN;
BEGIN
  RETURN s # NIL
END Awaited;

PROCEDURE Init(VAR s: SIGNAL);
BEGIN
  s := NIL
END Init; 

BEGIN
  ALLOCATE(processes, TSIZE(SignalDesc));
  thisProcess := processes;
  thisProcess^.next        := processes;
  thisProcess^.running     := TRUE;
  thisProcess^.nextWaiting := NIL;
END Processes.

