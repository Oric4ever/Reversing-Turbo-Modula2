(*
    "perfect" decompilation of LongMath module
    (just two differences on the least significant bit of mantissa
    of two LONGREAL constants: that depends on how roundings are
    done in double-precision calculations).
*)
IMPLEMENTATION MODULE LongMath;
FROM SYSTEM IMPORT BYTE;
CONST PI = 3.141592653589793999D0;
TYPE Union = RECORD
               CASE : CARDINAL OF
               | 1: d: LONGREAL;
               | 2: b: ARRAY [0..7] OF BYTE;
               | 3: w0, w1, w2, w3: CARDINAL;
               | 4: lsd, msd: LONGINT;
               END;
             END;
VAR zero, half, one: LONGREAL;

(* $[+ remove procedure names *)
  
PROCEDURE positive(param1: LONGREAL): BOOLEAN;
VAR union: Union;
BEGIN
  union.d := param1;
  RETURN INTEGER(union.w3) >= 0
END positive;

PROCEDURE exponent(param1: LONGREAL): INTEGER;
VAR unsigned: Union;
BEGIN
  unsigned.d := ABS(param1);
  RETURN INTEGER(unsigned.w3 DIV 16 - 1022)
END exponent;

PROCEDURE addExponent(VAR x: LONGREAL; exponent: INTEGER);
VAR union: Union;
BEGIN
  union.d := x;
  union.w3 := union.w3 + CARDINAL(exponent) * 16;
  x := union.d;
END addExponent;

(* $[- keep procedure names *)

PROCEDURE Entier(x: LONGREAL): LONGINT;
BEGIN
  IF positive(x)
  THEN RETURN LONG(x)
  ELSE RETURN LONG(x - one)
  END;
END Entier;

PROCEDURE Sqrt(x: LONGREAL): LONGREAL;
VAR r : LONGREAL; 
    i: CARDINAL;
    exp: INTEGER;
BEGIN
  IF positive(x) THEN
    IF x = zero THEN RETURN x END;
    exp := exponent(x);
    addExponent(x, -exp);
    r := 0.41731D0 + 0.59016D0 * x;
    IF ODD(exp) THEN
      r := r * 0.7071067811865475D0;
      INC(exp);
      addExponent(x, -1);
    END;
    i := 0;
    REPEAT
      r := r + x / r;
      addExponent(r, -1);
      INC(i);
    UNTIL i > 2;
    addExponent(r, exp DIV 2);
    RETURN r
  END;
  RAISE ArgumentError, "Negative argument for Sqrt"
END Sqrt;

PROCEDURE Exp(x: LONGREAL): LONGREAL;
CONST k1 =  1.4426950408889634D0;
      k2 = 0.693359375D0;
      k3 = -2.121944400546905D-04;
      k4 =  1.6520330026827911D-05;
      k5 =  6.943600015117928D-03;
      k6 =  0.2499999999999999D0;
      k7 =  4.958628849054411D-04;
      k8 =  5.555386669690011D-02;
VAR tmp1 : INTEGER;
    tmp2, tmp3, tmp4, tmp5, tmp6 : LONGREAL;
BEGIN
  IF x < 710.475859D0 THEN
    IF x <= -710.475859D0 THEN RETURN zero END;
    IF ABS(x) < 5.551115123125783D-17 THEN RETURN one END;
    tmp1 := INT(Entier(x * k1 + half));
    tmp2 := DOUBLE(LONG(tmp1));
    tmp3 := x - tmp2 * k2 - tmp2 * k3;
    tmp4 := tmp3 * tmp3;
    tmp5 := tmp3 * ((k4 * tmp4 + k5) * tmp4 + k6);
    tmp6 := half + tmp5 / ((k7 * tmp4 + k8) * tmp4 + half - tmp5);
    addExponent(tmp6, tmp1+1);
    RETURN tmp6
  END;
  RAISE ArgumentError, "Argument for Exp too big"
END Exp;

PROCEDURE Ln(x: LONGREAL): LONGREAL;
CONST k1 = -2.121944400546905D-04;
      k2 = -0.7895611288749125D0;
      k3 = 16.383943563021537D0;
      k4 = -64.12494342374558D0;
      k5 = -35.66797773903464D0;
      k6 = 312.0322209192453D0;
      k7 = -769.4993210849487D0;
      k8 = 0.693359375D0;
VAR y, z, t, u : LONGREAL;
    exp : INTEGER; (* local10 *)
BEGIN
  IF x > zero THEN
    exp := exponent(x);
    addExponent(x, -exp);
    IF x > 0.7071067811865475D0
    THEN y := (x - half - half) / (x * half + half);
    ELSE z := x - half;
         y := z / (z * half + half);
         DEC(exp);
    END;
    t := y * y;
    u := DOUBLE(LONG(exp));
    RETURN (u * k1 + y)
        + y * (t * ((t * k2 + k3) * t + k4) / (((t + k5) * t + k6) * t + k7))
        + u * k8
  END;
  RAISE ArgumentError, "Negative argument for Ln"
END Ln;

(* $[+ remove procedure names *)

PROCEDURE Sin(x: LONGREAL): LONGREAL;
CONST k1 = 0.3183098861837906D0;
      k2 = 3.1416015625D0;
      k3 = -8.908910206761536D-06;
      k4 =  2.720479095788884D-15;
      k5 = -7.642917806891046D-13;
      k6 =  1.605893649037159D-10;
      k7 = -2.50521067982745799D-08;
      k8 =  2.755731921015275D-06;
      k9 = -1.984126984120184D-04;
      k10=  8.333333333333165D-03;
      k11= -1.6666666666666666D-01;
VAR tmp1 : CARDINAL;
    r, y, tmp4 : LONGREAL;
    negative: BOOLEAN; (* local9 *)
BEGIN
  negative := NOT positive(x);
  x := ABS(x);
  IF x >= 65535.0D0 THEN RETURN zero END;
  tmp1 := CARD(LONG(x * k1 + half));
  tmp4 := DOUBLE(LONG(tmp1));
  IF ODD(tmp1) THEN negative := NOT negative END;
  r := x - tmp4 * k2 - tmp4 * k3;
  IF ABS(r) >= 1.4901161193847657D-08 THEN
    y := r * r;
    r:=r + r*((((((((k4*y +k5)*y +k6)*y +k7)*y +k8)*y +k9)*y +k10)*y +k11)*y);
  END;
  IF negative THEN RETURN -r END;
  RETURN r
END Sin;

PROCEDURE Cos(x: LONGREAL): LONGREAL;
BEGIN
  RETURN Sin(ABS(x) + PI/2.0D0)
END Cos;

PROCEDURE Arctan(x: LONGREAL): LONGREAL;
CONST two26 = 64.0D0 * 1024.0D0 * 1024.0D0;
CONST k1 =  0.7320508075688773D0;
      k2 =  1.7320508075688774D0;
      k3 = -0.8375829936815006D0;
      k4 = -8.494624035132068D0;
      k5 = -2.050585519586165D1;
      k6 = -1.368876889419193D1;
      k7 =  1.502400116002858D1;
      k8 =  5.957843614259734D1;
      k9 =  8.615734959713023D1;
      k10=  4.106630668257578D1;
VAR y, z: LONGREAL;
    sector: CARDINAL;
BEGIN
  y := ABS(x);
  sector := 0;
  IF y > one THEN y := one / y; sector := 2 END;
  IF y > 0.2679491924311227D0 THEN
    y := (-half + k1 * y - half + y) / (k2 + y);
    INC(sector)
  END;
  IF ABS(y) >= (1.0D0 / two26) THEN
    z := y * y;
    y := y + y * ( (((k3*z+k4)*z+k5)*z+k6)*z / ((((z+k7)*z+k8)*z+k9)*z+k10) );
  END;
  CASE sector OF
  | 1 : y := PI/6.0D0 + y
  | 2 : y := PI/2.0D0 - y
  | 3 : y := PI/3.0D0 - y 
  END;
  IF positive(x) THEN RETURN y END;
  RETURN -y
END Arctan;

BEGIN
  zero := 0.0D0;
  half := 0.5D0;
  one  := 1.0D0;
END LongMath.

