(*
    100%-complete decompilation of the MCode procedures of DOUBLES module,
    however the original contained a number of "hidden" Z80 procedures for the
    LONGREAL arithmetics. These arithmetics procedures have been moved to
    new longreal bytecodes in the virtual machine, and the code generator has
    been modified to use the new bytecodes instead of calls to the arithmetic
    procedures. However when compiling READ and WRITE calls, the compiler still
    generates calls to these arithmetic procedures (notably qcp), so we need to
    keep them until the transformation of the READ and WRITE calls is modified 
    to use the new longreal bytecodes
*)
   
IMPLEMENTATION MODULE Doubles;
FROM Texts IMPORT ReadString, WriteChar;
FROM SYSTEM IMPORT ADR,CODE,FILL,REALOVERFLOW,BYTE;
FROM Convert IMPORT TooLarge, StrToCard;
(* $T+ *)

CONST LIMIT  = 1801439850948198.5D0;

TYPE Union = RECORD
               CASE : CARDINAL OF
               | 1: d: LONGREAL;
               | 2: b: ARRAY [0..7] OF BYTE;
               | 3: w0, w1, w2, w3: CARDINAL;
               | 4: lsd, msd: LONGINT;
               END;
             END;

PROCEDURE qtod(r: LONGREAL): LONGINT;  BEGIN RETURN LONG(r)  END qtod;
PROCEDURE qtof(r: LONGREAL): REAL;     BEGIN RETURN FLOAT(r) END qtof;
PROCEDURE dtoq(l: LONGINT) : LONGREAL; BEGIN RETURN DOUBLE(l)END dtoq;
PROCEDURE ftoq(r: REAL)    : LONGREAL; BEGIN RETURN DOUBLE(r)END ftoq;
PROCEDURE qcp(r1: LONGREAL; r2: LONGREAL): LONGINT; BEGIN RETURN LONG(ORD(r1<r2)) END qcp;
PROCEDURE qadd(r1,r2: LONGREAL): LONGREAL; BEGIN RETURN r1+r2 END qadd;
PROCEDURE qsub(r1,r2: LONGREAL): LONGREAL; BEGIN RETURN r1-r2 END qsub;
PROCEDURE qmul(r1,r2: LONGREAL): LONGREAL; BEGIN RETURN r1*r2 END qmul;
PROCEDURE qdiv(r1,r2: LONGREAL): LONGREAL; BEGIN RETURN r1/r2 END qdiv;
PROCEDURE qneg(r: LONGREAL): LONGREAL;     BEGIN RETURN -r    END qneg;
PROCEDURE qabs(r: LONGREAL): LONGREAL;     BEGIN RETURN ABS(r)END qabs;

PROCEDURE Ten(exponent: CARDINAL): LONGREAL;
VAR n: CARDINAL;
VAR result: LONGREAL;
VAR power10: LONGREAL;
BEGIN
  n := 0;
  result := ftoq(1.0);
  REPEAT
    IF ODD(exponent) THEN
      CASE n OF
      | 0: power10 := 1.0D1
      | 1: power10 := 1.0D2
      | 2: power10 := 1.0D4
      | 3: power10 := 1.0D8
      | 4: power10 := 1.0D16
      | 5: power10 := 1.0000000000000001D32  (* compensates for different rounding *)
      | 6: power10 := 1.0D64
      | 7: power10 := 1.0D128
      | 8: power10 := 1.0000000000000002D256 (* compensates for different rounding *)
      ELSE RAISE REALOVERFLOW
      END;
      result := qmul(result, power10);
    END;
    exponent := exponent DIV 2;
    INC(n);
  UNTIL exponent = 0;
  RETURN result;
END Ten;

PROCEDURE StrToDouble (VAR s: ARRAY OF CHAR; VAR r: LONGREAL) : BOOLEAN;
VAR expNumber, index, digit: CARDINAL;
VAR exponent: INTEGER;
VAR char: CHAR;
VAR negative, negativeExp: BOOLEAN;
VAR result: LONGREAL;
  PROCEDURE NextDigit;
  BEGIN
    IF index <= HIGH(s)
    THEN char := s[index]; index := index + 1
    ELSE char := 0C
    END;
    digit := ORD(char) - ORD('0');
  END NextDigit;
BEGIN
  index := 0;
  NextDigit;
  negative := (char = '-');
  IF negative OR (char = '+') THEN NextDigit END;
  IF digit > 9 THEN RETURN FALSE END;
  result := 0.0D0;
  exponent := 0;
  REPEAT
    IF qcp(result, LIMIT) = LONG(1) THEN
      result := qadd(qmul(result,10.0D0), dtoq(LONG(digit)))
    ELSE INC(exponent)
    END;
    NextDigit;
  UNTIL digit > 9;
  IF char = '.' THEN
    NextDigit;
    WHILE digit <= 9 DO
      IF qcp(result, LIMIT) = LONG(1) THEN
        result := qadd(qmul(result,10.0D0), dtoq(LONG(digit)));
        DEC(exponent)
      END;
      NextDigit;
    END;
  END;
  IF ORD(CAP(char)) - ORD('D') <= 1 THEN
    expNumber := 0;
    NextDigit;
    negativeExp := (char = '-');
    IF negativeExp OR (char = '+') THEN NextDigit END;
    IF digit > 9 THEN RETURN FALSE END;
    REPEAT
      IF expNumber < 512 THEN expNumber := expNumber * 10 + digit END;
      NextDigit;
    UNTIL digit > 9;
    IF negativeExp THEN DEC(exponent,expNumber) ELSE INC(exponent,expNumber) END;
  END;
  IF char # 0C THEN RETURN FALSE END;
  IF negative THEN result := qneg(result) END;
  IF exponent < 0 THEN
    IF exponent < -308 THEN
      result := qdiv(result, Ten(CARDINAL(-308-exponent)));
      exponent := -308;
    END;
    result := qdiv(result, Ten(CARDINAL(-exponent)))
  ELSIF exponent # 0 THEN
    result := qmul(result, Ten(CARDINAL(exponent)))
  END; (* 0746 *)
  r := result;
  RETURN TRUE  
EXCEPTION
| REALOVERFLOW: r := dtoq(LONG(0)); RETURN exponent <= 0
END StrToDouble;

PROCEDURE qmul10(u: Union): LONGREAL;
(* Original in Z80
CODE("QMUL10")
*)
VAR i,carry,tmp: CARDINAL;
BEGIN
  carry := 0;
  FOR i:=0 TO 6 DO
    tmp    := ORD(u.b[i]) * 10 + carry;
    u.b[i] := tmp MOD 256;
    carry  := tmp DIV 256;
  END;
  RETURN u.d
END qmul10;

PROCEDURE DoubleToStr (r: LONGREAL; VAR s: ARRAY OF CHAR; digits: INTEGER);
VAR scientificNotation : BOOLEAN;
VAR local3 : CARDINAL;
VAR local4 : CARDINAL;
VAR index : CARDINAL;
VAR decimals : CARDINAL;
VAR local7 : CARDINAL;
VAR local8 : CARDINAL;
VAR exponent : INTEGER;
VAR value: Union;
VAR negative: BOOLEAN;
VAR local12: CARDINAL;
BEGIN
  FILL(ADR(s), HIGH(s)+1, ' ');
  exponent := 0;
  local4 := 0;
  local3 := 1;
  scientificNotation := (digits < 0);
  decimals := ABS(digits);
  value.d := r;
  negative := 15 IN BITSET(value.w3);
  exponent  := INTEGER(value.w3 MOD 32768 DIV 16) - 1023;
  r := qabs(r);
  IF exponent = -1023 THEN (* representation of Zero *)
    IF scientificNotation THEN s[HIGH(s)]:='0'; RETURN END;
    local4 := digits + 1;
  ELSE
    IF exponent >= 0 THEN
      (* convert binary exponent to exponent in base 10 : log(2) ~ 77/256 *)
      exponent := INT(LONG(exponent)*LONG(77) DIV LONG(256)) + 1;
      IF exponent = 309
      THEN r := qdiv( qdiv(r, Ten(308)), dtoq(LONG(10)) )  (* can't do Ten(309) *)
      ELSE r := qdiv(r, Ten(exponent))
      END;
      IF qcp(r, dtoq(LONG(1))) # LONG(1) THEN
        r := qdiv(r, dtoq(LONG(10)));
        INC(exponent)
      END;
    ELSE
      (* convert binary exponent to exponent in base 10 : log(2) ~ 77/256 *)
      exponent := INT(LONG(exponent+1)*LONG(77) DIV LONG(256));
      r := qmul(r, Ten(-exponent));
      IF qcp(r, ftoq(0.1)) = LONG(1) THEN
        r := qmul(r, dtoq(LONG(10)));
        DEC(exponent);
      END;
    END;
    index := decimals + 1 + (CARDINAL(exponent - 1) * ORD(NOT scientificNotation));
    IF INTEGER(index) >= 0 THEN
      IF index > 15 THEN index := 15 END;
      r := qadd(r, qdiv(ftoq(0.5), Ten(index)));  (* add 0.5 to next decimal for rounding *)
    END;
    IF qcp(r, dtoq(LONG(1))) # LONG(1) THEN
      r := qdiv(r, dtoq(LONG(10)));
      INC(exponent)
    END;
    IF NOT scientificNotation THEN
      IF exponent >= 1 THEN local3 := CARDINAL(exponent)
      ELSE local4 := 1 - CARDINAL(exponent)
      END;
    END;
    value.d := r;
    IF qcp(r, ftoq(0.5)) = LONG(1) THEN
      value.d := qadd(r, ftoq(0.5))
    END;
    (* keep mantissa only in value *)
    value.w3 := CARDINAL(BITSET(value.w3) * BITSET(0FH));
    IF qcp(r, ftoq(0.5)) # LONG(1) THEN INC(value.w3, 16) END;
    value.d := qmul10(value);
    IF value.w3 < 32 THEN
      value.msd := 2097152L; (* 200000H *)
      value.lsd := LONG(0);
    END;
  END;
  index := CARDINAL(decimals) + local3;
  decimals := 15;
  local7 := HIGH(s);
  IF scientificNotation THEN local7 := local7 - 5
  ELSIF digits = 0 THEN DEC(index)
  END;
  IF index >= local7 THEN
    scientificNotation := StrToCard(s, index);
    RAISE TooLarge
  END;
  index := local7 - index;
  IF negative THEN s[index-1] := '-' END;
  REPEAT
    IF local4 # 0 THEN s[index] := '0'; DEC(local4)
    ELSIF decimals # 0 THEN
      local8 := value.w3 DIV 32;
      s[index] := CHR(local8 + ORD('0'));
      value.w3 := CARDINAL(BITSET(value.w3) * BITSET(1FH));
      value.d := qmul10(value);
      DEC(decimals);
    ELSE (* 09C2 *)
      s[index] := '0'
    END; (* 09c9 *)
    INC(index);
    IF local3 # 0 THEN
      DEC(local3);
      IF (local3 = 0) AND (digits # 0) THEN
        s[index] := '.';
        INC(index)
      END;
    END; (* 09E5 *)
  UNTIL index > local7;
  IF scientificNotation THEN
    s[index]   := 'D';
    s[index+1] := CHR( ORD('+') + ORD(exponent <= 0)*2 );
    exponent := ABS(exponent - 1);
    decimals := 4;
    local12:= 2;
    INC(decimals);
    WHILE decimals >= local12 + 1 DO
      DEC(decimals);
      s[index+decimals] := CHR(exponent MOD 10 + 48);
      exponent := INTEGER(CARDINAL(exponent) DIV 10);
    END;
  END; (* 0a2a *)
END DoubleToStr;

PROCEDURE ReadDouble (t: TEXT; VAR r: LONGREAL);
VAR str: ARRAY [0..39] OF CHAR;
BEGIN
  r := dtoq(LONG(0));
  ReadString(t, str);
  legal := StrToDouble(str, r);
END ReadDouble;

PROCEDURE WriteDouble(t: TEXT; r: LONGREAL; n: CARDINAL; digits: INTEGER);
VAR str: ARRAY [0..79] OF CHAR;
BEGIN
  DoubleToStr(r, str, digits);
  WHILE n > 80 DO WriteChar(t, ' '); DEC(n) END;
  n := 80 - n;
  WHILE (n # 0) AND (str[n-1] # ' ') DO DEC(n) END;
  WHILE n <= 79 DO WriteChar(t, str[n]); INC(n) END;
END WriteDouble;

END Doubles.
                                        
