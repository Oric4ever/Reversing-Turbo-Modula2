(*
    Perfect decompilation of original MathLib module
*)
IMPLEMENTATION MODULE MathLib;
CONST PI = 3.14159265;
TYPE Union =  RECORD
                CASE : CARDINAL OF
                | 1: long: LONGINT;
                | 2: lsw, msw: CARDINAL;
                END;
              END;
(* $[+ remove procedure names *)
  
PROCEDURE exponent(param1: REAL): INTEGER;
VAR unsigned: Union;
BEGIN
  unsigned.long := LONGINT(ABS(param1));
  RETURN INTEGER(unsigned.msw DIV 128 - 126)
END exponent;

PROCEDURE addExponent(VAR x: REAL; exponent: INTEGER);
VAR union: Union;
BEGIN
  union.long := LONGINT(x);
  IF exponent >= 0 
  THEN INC(union.msw, CARDINAL(exponent) * 128)
  ELSE DEC(union.msw, CARDINAL(ABS(exponent)) * 128)
  END;
  x := REAL(union.long)
END addExponent;

(* $[- keep procedure names *)

PROCEDURE Entier(x: REAL): INTEGER;
BEGIN
  IF x >= 0.0 
  THEN RETURN INT(LONG(x))
  ELSE RETURN INT(LONG(x - 1.0))
  END;
END Entier;

PROCEDURE Sqrt     (x: REAL): REAL;
VAR r : REAL;
    exp: INTEGER;
BEGIN
  IF x > 0.0 THEN
    exp := exponent(x);
    addExponent(x, -exp);
    r := 0.41731 + 0.59016 * x;
    IF ODD(exp) THEN
      r := r * 0.70710675; (* r * sqrt(0.5) *)
      INC(exp);
      addExponent(x, -1);
    END; (* 00b9 *)
    r := r + x / r;
    r := 0.25 * r + x / r;
    addExponent(r, exp DIV 2);
    RETURN r
  END;
  IF x = 0.0 THEN RETURN x END;
  RAISE ArgumentError, "Negative argument for Sqrt"
END Sqrt;

PROCEDURE Exp(x: REAL): REAL;
VAR tmp1 : INTEGER;
    tmp2, tmp3, tmp4, tmp5, tmp6 : REAL;
BEGIN
  IF x < 87.4 THEN
    IF x <= -87.4 THEN RETURN 0.0 END;
    IF ABS(x) < 2.9802322E-8 THEN RETURN 1.0 END;
    tmp1 := Entier(x * 1.442695 + 0.5);
    tmp2 := FLOAT(LONG(tmp1));
    tmp3 := x - tmp2 * 0.6933594 - tmp2 * (-0.00021219444);
    tmp4 := tmp3 * tmp3;
    tmp5 := tmp3 * (0.004160288 * tmp4 + 0.25);
    tmp6 := 0.5 + tmp5 / (0.049987171 * tmp4 + 0.5 - tmp5);
    addExponent(tmp6, tmp1+1);
    RETURN tmp6
  END;
  RAISE ArgumentError, "Argument for Exp too big"
END Exp;

PROCEDURE Ln(x: REAL): REAL;
VAR tmp1, tmp2, tmp3, tmp4 : REAL;
    exp : INTEGER; (* local10 *)
BEGIN
  IF x > 0.0 THEN
    exp := exponent(x);
    addExponent(x, -exp);
    IF x > 0.70710671 
    THEN tmp1 := (-0.5 + x - 0.5) / (x * 0.5 + 0.5);
    ELSE tmp2 := x - 0.5;
         tmp1 := tmp2 / (tmp2 * 0.5 + 0.5);
         DEC(exp);
    END;
    tmp3 := tmp1 * tmp1;
    tmp4 := FLOAT(LONG(exp));
    RETURN tmp4 * (-0.00021219444)
       + (tmp1 + tmp1 * (tmp3 * (-0.5527074) / (tmp3 + (-6.6327181))))
       + tmp4 * 0.6933594;
  END;
  RAISE ArgumentError, "Negative argument for Ln"
END Ln;

(* $[+ remove procedure names *)

PROCEDURE Sin      (x: REAL): REAL;
VAR tmp1 : CARDINAL;
    tmp2, tmp3, tmp4 : REAL;
    negative: BOOLEAN; (* local9 *)
BEGIN
  negative := x < 0.0;
  x := ABS(x);
  IF x >= 12867.963 THEN RETURN 0.0 END;
  tmp1 := CARD(LONG(x * 0.31830987 + 0.5));
  tmp4 := FLOAT(LONG(tmp1));
  IF ODD(tmp1) THEN negative := NOT negative END;
  tmp2 := x - tmp4 * 3.140625 - tmp4 * 0.00096765353;
  IF ABS(tmp2) >= 0.00024414062 THEN
    tmp3 := tmp2 * tmp2;
    tmp2 := tmp2 + tmp2 * ((((2.6019031E-06 * tmp3 + (-0.00019807418)) * tmp3 + 0.008333025) * tmp3 + (-0.16666656)) * tmp3);
  END;
  IF negative THEN RETURN -tmp2 END;
  RETURN tmp2
END Sin;

PROCEDURE Cos(x: REAL): REAL;
BEGIN
  RETURN Sin(ABS(x) + PI/2.0)
END Cos;

PROCEDURE Arctan   (x: REAL): REAL;
VAR tmp1, tmp2: REAL;
    sector: CARDINAL;
BEGIN
  tmp1 := ABS(x);
  sector := 0;
  IF tmp1 > 1.0 THEN tmp1 := 1.0 / tmp1; sector := 2 END;
  IF tmp1 > 0.26794919 THEN
    tmp1 := (-0.5 + 0.7320508 * tmp1 - 0.5 + tmp1) / (1.7320508 + tmp1);
    INC(sector)
  END;
  IF ABS(tmp1) >= 0.00024414062 THEN
    tmp2 := tmp1 * tmp1;
    tmp1 := tmp1 + tmp1 * (((-0.05090958) * tmp2 + (-0.4708325)) * tmp2 / (tmp2 + 1.4125007));
  END;
  CASE sector OF
  | 1 : tmp1 := PI/6.000001 + tmp1
  | 2 : tmp1 := PI/2.0 - tmp1
  | 3 : tmp1 := PI/3.0 - tmp1
  END;
  IF x >= 0.0 THEN RETURN tmp1 END;
  RETURN -tmp1
END Arctan;

MODULE RNG;
 EXPORT Random, Randomize;
 VAR seed: CARDINAL;

  PROCEDURE Randomize(n: CARDINAL);
  BEGIN
    seed := n
  END Randomize;

  PROCEDURE Random(): REAL;
  BEGIN
    seed := seed * 256 + seed + 41;
    RETURN FLOAT(LONG(seed)) / FLOAT(LONG(65535));
  END Random;

 BEGIN
  seed := 23579
END RNG;

END MathLib.

