IMPLEMENTATION MODULE ComLine;
FROM Texts IMPORT OpenText, CreateText, ReadString, input, output,
                  haltOnControlC, ConnectDriver, Init;
FROM SYSTEM IMPORT BDOS, IORESULT;
IMPORT Loader;
FROM Terminal IMPORT WriteString, WriteLn, ReadLine, ReadChar;
IMPORT EDITOR, SCANNER;

(* $[+ remove procedure names *)

EXCEPTION NoInputFile;

CONST DRVGET = 25;

VAR buffer [0081H]: ARRAY [0..126] OF CHAR;
(* 8 *) index: CARDINAL;
(* 9 *) key: CHAR;

PROCEDURE GetCommandLine(text: TEXT; VAR ch: CHAR);
CONST EOF = 032C;
BEGIN
  IF (ORD(buffer[index]) - ORD('<')) IN {0,2} THEN
    REPEAT INC(index) UNTIL buffer[index]<=' '
  END;
  ch := buffer[index];
  IF ch = 0C THEN ch := EOF ELSE INC(index) END
END GetCommandLine;

(* $[- *)

PROCEDURE RedirectInput;
BEGIN
  IF NOT OpenText(input, inName) THEN
    RAISE NoInputFile
  END;
END RedirectInput;

PROCEDURE RedirectOutput;
BEGIN
  CreateText(output, outName)
END RedirectOutput;

PROCEDURE PromptFor(prompt:ARRAY OF CHAR; VAR s:ARRAY OF CHAR);
VAR i: CARDINAL;
BEGIN
  ReadString(commandLine, s);
  IF s[0] = 0C THEN
    WriteString(prompt); ReadLine(s);
    i := 0; REPEAT s[i] := CAP(s[i]); INC(i) UNTIL i = HIGH(s);
  END
END PromptFor;

PROCEDURE CallShell(): BOOLEAN;
BEGIN
  Loader.Call("SHELL");
  RETURN TRUE
EXCEPTION
| Loader.LoadError : RETURN FALSE
END CallShell;

(* $[+ *)

BEGIN
  LOOP
    BDOS(DRVGET, 0);
    Loader.firstDrive := IORESULT;
    Init;
    haltOnControlC := FALSE;
    index := 0;

    ConnectDriver(commandLine, GetCommandLine);
    IF NOT CallShell() THEN
      WriteLn;
      WriteString("Insert Disk with SHELL.MCD, press any key");
      ReadChar(key);
      WriteLn;
      IF NOT CallShell() THEN HALT END;
    END;
    haltOnControlC := TRUE;
    CASE execute OF
    | 1 : Loader.Call(progName)
    | 2 : EDITOR.editPosition := 0; EDITOR.Edit
    | 3
    , 4 : SCANNER.proc30
    | 5 : SCANNER.proc30;
          IF execute = 4 THEN SCANNER.proc30 END
    ELSE EXIT
    END
  END
END ComLine.
