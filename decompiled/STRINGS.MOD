IMPLEMENTATION MODULE Strings;
FROM SYSTEM IMPORT ADR, CODE, ADDRESS;
FROM STORAGE IMPORT ALLOCATE;

(* $[+ remove procedure names *)

PROCEDURE SearchChar(str: ADDRESS; size: CARDINAL; char: CHAR): ADDRESS;
CODE("CharIndx");
END SearchChar;

PROCEDURE Length (VAR str: ARRAY OF CHAR): CARDINAL;
VAR addr: ADDRESS;
BEGIN
  addr := SearchChar(ADR(str), HIGH(str)+1, 0C);
  IF addr = NIL THEN RETURN HIGH(str)+1 END;
  RETURN addr - ADR(str)
END Length;

PROCEDURE Pos    (substr,str: ARRAY OF CHAR): CARDINAL;
(* TODO: find a way to generate D3 opcode instead of 40 12 *)
VAR local2 : ADDRESS;
    local3 : POINTER TO ARRAY [0..0FFFFH] OF CHAR;
    subStrLen, strLen : CARDINAL;
    i : CARDINAL;
BEGIN
  subStrLen := Length(substr);
  strLen := Length(str);
  IF (subStrLen <> 0) AND (subStrLen <= strLen) THEN
    local3 := ADR(str) - 1;
    local2 := ADR(str) + (strLen - subStrLen);
    LOOP
      local3 := SearchChar(ADDRESS(local3)+1, local2-ADDRESS(local3), substr[0]);
      IF local3 = NIL THEN EXIT END;
      i := 0;
      WHILE local3^[i] = substr[i] DO
        INC(i);
        IF i = subStrLen THEN RETURN ADDRESS(local3) - ADR(str) END;
      END;
      IF local3 = local2 THEN EXIT END;
    END; (* 0095 *)
  END; (* 0095 *)
  RETURN HIGH(str) + 1
END Pos;

PROCEDURE Insert (substr : ARRAY OF CHAR; VAR str: ARRAY OF CHAR;
                     inx : CARDINAL);
(* TODO: find a way to generate D3 opcode instead of 40 12 *)
BEGIN
END Insert;

PROCEDURE Delete (VAR str: ARRAY OF CHAR; inx,len: CARDINAL);
BEGIN
END Delete;

PROCEDURE Append (substr : ARRAY OF CHAR; VAR str: ARRAY OF CHAR);
(* TODO: find a way to generate D3 opcode instead of 40 12 *)
BEGIN
END Append;

PROCEDURE Copy   (VAR str: ARRAY OF CHAR; inx,len: CARDINAL;
                  VAR result: ARRAY OF CHAR);
BEGIN
END Copy;

PROCEDURE CAPS   (VAR str: ARRAY OF CHAR);
VAR i: CARDINAL;
BEGIN
  i := 0; REPEAT str[i] := CAP(str[i]); INC(i) UNTIL i > HIGH(str)
END CAPS;

END Strings.

