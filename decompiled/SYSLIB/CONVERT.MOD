(* perfect decompilation of CONVERT module, needs better naming in RealToStr  *)
IMPLEMENTATION MODULE Convert;
FROM SYSTEM IMPORT OVERFLOW, REALOVERFLOW, FILL, ADR;
(* EXCEPTION TooLarge; *)
TYPE Union = RECORD
              CASE : CARDINAL OF
              | 1 : long: LONGINT;
              | 2 : lsw, msw: CARDINAL;
              END;
             END;
(* $[+ *)

PROCEDURE Ten(exp: CARDINAL): REAL;
VAR n: CARDINAL;
    result: REAL;
BEGIN
  n := 0;
  result := 1.0;
  REPEAT
    IF ODD(exp) THEN
      CASE n OF 
      | 0 : result := result * 1.0E1
      | 1 : result := result * 1.0E2
      | 2 : result := result * 1.0E4
      | 3 : result := result * 1.0E8
      | 4 : result := result * 1.0E16
      | 5 : result := result * 1.0E32
      ELSE RAISE REALOVERFLOW
      END;
    END;
    exp := exp DIV 2;
    INC(n);
  UNTIL exp = 0;
  RETURN result
END Ten;

PROCEDURE StrToReal(VAR s: ARRAY OF CHAR; VAR r: REAL) : BOOLEAN;
CONST LIMIT = 3355443L; (* Strange.... in hex it's 00333333H *)
VAR expNumber, index, digit: CARDINAL;
VAR exponent: INTEGER;
VAR char: CHAR;
VAR negative, negativeExp: BOOLEAN;
VAR result: LONGINT;

  PROCEDURE NextDigit;
  BEGIN
    IF index <= HIGH(s)
    THEN char := s[index]; index := index + 1
    ELSE char := 0C
    END;
    digit := ORD(char) - ORD('0');
  END NextDigit;

(* $[- *)
BEGIN
  index := 0;
  NextDigit;
  negative := (char = '-');
  IF negative OR (char = '+') THEN NextDigit END;
  IF digit > 9 THEN RETURN FALSE END;
  result := 0L;
  exponent := 0;
  REPEAT
    IF result < LIMIT
    THEN result := result * LONG(10) + LONG(digit);
    ELSE INC(exponent)
    END;
    NextDigit;
  UNTIL digit > 9;
  IF char = '.' THEN
    NextDigit;
    WHILE digit <= 9 DO
      IF result < LIMIT THEN
        result := result * LONG(10) + LONG(digit);
        DEC(exponent)
      END;
      NextDigit;
    END;
  END;
  IF CAP(char) = 'E' THEN
    expNumber := 0;
    NextDigit;
    negativeExp := (char = '-');
    IF negativeExp OR (char = '+') THEN NextDigit END;
    IF digit > 9 THEN RETURN FALSE END;
    REPEAT
      IF expNumber < 255 THEN expNumber := expNumber * 10 + digit END;
      NextDigit;
    UNTIL digit > 9;
    IF negativeExp THEN DEC(exponent,expNumber) ELSE INC(exponent,expNumber) END;
  END;
  IF char # 0C THEN RETURN FALSE END;
  IF result >= 16777216L
  THEN r := FLOAT((result + LONG(1)) DIV LONG(2)) * 2.0
  ELSE r := FLOAT(result)
  END;
  IF negative THEN r := -r END;
  IF exponent < 0 THEN
    IF exponent < -38 THEN
      r := r / Ten(CARDINAL(-38-exponent));
      exponent := -38;
    END;
    r := r / Ten(CARDINAL(-exponent))
  ELSIF exponent # 0 THEN
    r := r * Ten(CARDINAL(exponent))
  END; 
  RETURN TRUE
EXCEPTION
| REALOVERFLOW: r := 0.0; RETURN exponent <= 0
END StrToReal;

PROCEDURE RealToStr (r: REAL; VAR s: ARRAY OF CHAR; digits: INTEGER);
(* TODO: give better names to local variables *)
VAR scientificNotation : BOOLEAN;
VAR local3 : CARDINAL;
VAR local4 : CARDINAL;
VAR index : CARDINAL;
VAR decimals : CARDINAL;
VAR local7 : CARDINAL;
VAR exponent : INTEGER;
VAR negative: BOOLEAN;
VAR local11: LONGINT;
VAR local13: LONGINT;
VAR value: Union;
BEGIN
  FILL(ADR(s), HIGH(s)+1, ' ');
  exponent := 0;
  local11 := LONG(0);
  local4 := 0;
  local3 := 1;
  scientificNotation := (digits < 0);
  decimals := ABS(digits);
  negative := r < 0.0;
  r := ABS(r);
  value.long := LONGINT(r);
  exponent  := INTEGER(value.msw DIV 128) - 127;
  IF exponent = -127 THEN (* i.e. exponent bits were 0 *)
    IF scientificNotation THEN s[HIGH(s)]:='0'; RETURN END;
    local4 := digits + 1;
  ELSE
    IF exponent >= 0 THEN
      (* convert binary exponent to exponent in base 10 : log(2) ~ 77/256 *)
      exponent := exponent * 77 DIV 256 + 1;
      IF exponent = 39
      THEN r := r / 1.0E37 / 100.0  (* can't do Ten(309) *)
      ELSE r := r / Ten(exponent)
      END;
      IF r >= 1.0 THEN r := r / 10.0; INC(exponent) END;
    ELSE
      (* convert binary exponent to exponent in base 10 : log(2) ~ 77/256 *)
      exponent := (exponent+1)*77 DIV 256;
      r := r * Ten(-exponent);
      IF r < 0.1 THEN r := r * 10.0; DEC(exponent) END;
    END;
    index := decimals + 1 + (CARDINAL(exponent - 1) * ORD(NOT scientificNotation));
    IF INTEGER(index) >= 0 THEN
      IF index > 7 THEN index := 7 END;
      r := r + 0.5 / Ten(index);  (* add 0.5 to next decimal for rounding *)
    END;
    IF r >= 1.0 THEN r := r / 10.0; INC(exponent) END;
    IF NOT scientificNotation THEN
      IF exponent >= 1 THEN local3 := CARDINAL(exponent)
      ELSE local4 := 1 - CARDINAL(exponent)
      END;
    END;
    value.long := LONGINT(r);
    INC(value.msw, 0C00H);
    local11 := LONG(REAL(value.long)) * LONG(10);
    IF local11 < 16777216L THEN local11 := 16777216L END;
  END;
  index := CARDINAL(decimals) + local3;
  decimals := 7;
  local7 := HIGH(s);
  IF scientificNotation THEN local7 := local7 - 4
  ELSIF digits = 0 THEN DEC(index)
  END;
  IF index >= local7 THEN RAISE TooLarge END;
  index := local7 - index;
  IF negative THEN s[index-1] := '-' END;
  REPEAT
    IF local4 # 0 THEN s[index] := '0'; DEC(local4)
    ELSIF decimals # 0 THEN
      local13 := local11 DIV 16777216L;
      s[index] := CHR(CARD(local13) + ORD('0'));
      local11 := (local11 - local13 * 16777216L) * LONG(10);
      DEC(decimals);
    ELSE
      s[index] := '0'
    END;
    INC(index);
    IF local3 # 0 THEN
      DEC(local3);
      IF (local3 = 0) AND (digits # 0) THEN
        s[index] := '.';
        INC(index)
      END;
    END;
  UNTIL index > local7;
  IF scientificNotation THEN
    s[index]   := 'E';
    s[index+1] := CHR( ORD('+') + ORD(exponent <= 0)*2 );
    exponent   := ABS(exponent - 1);
    s[index+2] := CHR(CARDINAL(exponent) DIV 10 + ORD('0'));
    s[index+3] := CHR(CARDINAL(exponent) MOD 10 + ORD('0'));
  END;
END RealToStr;

PROCEDURE StrToInt  (VAR s: ARRAY OF CHAR; VAR i: INTEGER)  : BOOLEAN;
VAR index: CARDINAL;
VAR digit: CARDINAL;
VAR negative: BOOLEAN;
BEGIN
  i := 0;
  index := 0;
  negative := (s[0] = '-');
  IF negative OR (s[0] = '+') THEN INC(index) END;
  REPEAT
    digit := ORD(s[index]) - ORD('0');
    IF digit > 9 THEN RETURN FALSE END;
(* $O+ *)
    i := i * 10 + INTEGER(digit) + 0;
(* $O- *)
    INC(index);
  UNTIL (index > HIGH(s)) OR (s[index] = 0C);
  IF negative THEN i := -i END;
  RETURN TRUE;
EXCEPTION
| OVERFLOW: RETURN FALSE;
END StrToInt;

PROCEDURE IntToStr  (i: INTEGER;  VAR s: ARRAY OF CHAR);
VAR index, tmp: CARDINAL;
    negative: BOOLEAN;
BEGIN
  FILL(ADR(s), HIGH(s)+1, " ");
  index    := HIGH(s);
  tmp      := ABS(i);
  negative :=  i < 0;
  REPEAT
    IF index = 0 THEN RAISE TooLarge END;
    s[index] := CHR(tmp MOD 10 + ORD('0'));
    tmp := tmp DIV 10;
    DEC(index);
  UNTIL tmp = 0;
  IF negative THEN s[index] := '-' END;
END IntToStr;

PROCEDURE StrToCard (VAR s: ARRAY OF CHAR; VAR c: CARDINAL) : BOOLEAN;
VAR index, digit: CARDINAL;
BEGIN
  c := 0;
  index := 0;
  REPEAT
    digit := ORD(s[index]) - ORD('0');
    IF digit > 9 THEN RETURN FALSE END;
(* $O+ *)
    c := c * 10 + digit;
(* $O- *)
    INC(index);
  UNTIL (index > 6) OR (s[index] = 0C);
  RETURN TRUE
EXCEPTION
| OVERFLOW: RETURN FALSE
END StrToCard;

PROCEDURE CardToStr (c: CARDINAL; VAR s: ARRAY OF CHAR);
VAR index: INTEGER;
BEGIN
  FILL(ADR(s), HIGH(s)+1, " ");
  index    := HIGH(s);
  REPEAT
    IF index < 0 THEN RAISE TooLarge END;
    s[index] := CHR(c MOD 10 + ORD('0'));
    c := c DIV 10;
    DEC(index);
  UNTIL c = 0;
END CardToStr;

PROCEDURE StrToLong (VAR s: ARRAY OF CHAR; VAR l: LONGINT)  : BOOLEAN;
VAR index: CARDINAL;
VAR digit: CARDINAL;
VAR negative: BOOLEAN;
BEGIN
  l := LONG(0);
  index := 0;
  negative := (s[0] = '-');
  IF negative OR (s[0] = '+') THEN INC(index) END;
  REPEAT
    digit := ORD(s[index]) - ORD('0');
    IF digit > 9 THEN RETURN FALSE END;
    l := l * LONG(10) + LONG(digit);
    INC(index);
  UNTIL (index > HIGH(s)) OR (s[index] = 0C);
  IF negative THEN l := -l END;
  RETURN TRUE;
EXCEPTION
| OVERFLOW: RETURN FALSE;
END StrToLong;

PROCEDURE LongToStr (l: LONGINT;  VAR s: ARRAY OF CHAR);
VAR index: CARDINAL;
    negative, overflow: BOOLEAN;
BEGIN
  FILL(ADR(s), HIGH(s)+1, " ");
  index    := HIGH(s);
  negative :=  l < LONG(0);
  l        := ABS(l);
  overflow :=  l < LONG(0);
  IF overflow THEN l := 2147483647L END;
  REPEAT
    IF index = 0 THEN RAISE TooLarge END;
    s[index] := CHR(CARD(l MOD LONG(10)) + ORD('0'));
    l := l DIV LONG(10);
    DEC(index);
  UNTIL l = LONG(0);
  IF overflow THEN s[HIGH(s)] := '8' END; (* Wow... replace the final 7 by a 8 *)
  IF negative THEN s[index] := '-' END;
END LongToStr;

END Convert.

