IMPLEMENTATION MODULE DrawCars;
FROM Terminal IMPORT ClearScreen, GotoXY, ReadChar;

VAR OrgX, OrgY: CARDINAL;

PROCEDURE SetInkColor(color: Color);
BEGIN
  WRITE(033C,'[','3',CHR(ORD(color)+ORD('0')),'m')
END SetInkColor;

PROCEDURE Pause(n: CARDINAL);
BEGIN
  WHILE n<>0 DO DEC(n) END;
END Pause;

PROCEDURE DrawBorder;
VAR x,y,n: CARDINAL;
BEGIN
  x := OrgX - 2; y := OrgY - 1;
  GotoXY(x,y); WRITE('█');
  FOR n:=1 TO 37 DO WRITE('▀') END;
  WRITE('█');
  FOR n:=1 TO 18 DO
    GotoXY(x + 0,y+n); WRITE('█');
    GotoXY(x +38,y+n); WRITE('█');
  END;
  FOR n:=7 TO 9 DO
    GotoXY(x +38,y+n); WRITE(' ');
  END;
  GotoXY(x,y+19); WRITE('█');
  FOR n:=1 TO 37 DO WRITE('▄') END;
  WRITE('█');
END DrawBorder;

PROCEDURE DrawHorizontal(x,y: CARDINAL; color: Color; letter: CHAR; truck: BOOLEAN);
BEGIN
  SetInkColor(color);
  DEC(x);   (* added a space to the left *)
  IF truck THEN
    GotoXY(x,y+0); WRITE(" ┌──────────╥──┬─┐ ");
    GotoXY(x,y+1); WRITE(" │          ║  │ │ ");
    GotoXY(x,y+2); WRITE(" └──────────╨──┴─┘ ");
    GotoXY(x+6,y+1);
  ELSE
    GotoXY(x,y+0); WRITE(" ┌─┬───┬───┐ ");
    GotoXY(x,y+1); WRITE(" │ │   │   │ ");
    GotoXY(x,y+2); WRITE(" └─┴───┴───┘ ");
    GotoXY(x+5,y+1);
  END;
  SetInkColor(WHITE);
  WRITE(letter)
END DrawHorizontal;

PROCEDURE MoveHorizontal(x,y: CARDINAL; color: Color; letter: CHAR; truck,left: BOOLEAN);
VAR step: CARDINAL;
BEGIN
  x := OrgX + x * 6;
  y := OrgY + y * 3;
  FOR step:=1 TO 6 DO
    IF left THEN DEC(x) ELSE INC(x) END;
    DrawHorizontal(x,y,color,letter,truck);
    Pause(3000);
  END;
END MoveHorizontal;

PROCEDURE DrawVertical(x,y: CARDINAL; color: Color; letter: CHAR; truck,clearUp,clearBottom: BOOLEAN);
BEGIN
  SetInkColor(color);
  IF clearUp THEN GotoXY(x,y-1); WRITE("      ") END;
  IF truck THEN
    GotoXY(x,y+0); WRITE("┌───┐ ");
    GotoXY(x,y+1); WRITE("│   │ ");
    GotoXY(x,y+2); WRITE("│   │ ");
    GotoXY(x,y+3); WRITE("│   │ ");
    GotoXY(x,y+4); WRITE("│   │ ");
    GotoXY(x,y+5); WRITE("╞═══╡ ");
    GotoXY(x,y+6); WRITE("│   │ ");
    GotoXY(x,y+7); WRITE("├───┤ ");
    GotoXY(x,y+8); WRITE("└───┘ ");
    GotoXY(x,y+9);
  ELSE
    GotoXY(x,y+0); WRITE("┌───┐ ");
    GotoXY(x,y+1); WRITE("├───┤ ");
    GotoXY(x,y+2); WRITE("│   │ ");
    GotoXY(x,y+3); WRITE("├───┤ ");
    GotoXY(x,y+4); WRITE("│   │ ");
    GotoXY(x,y+5); WRITE("└───┘ ");
    GotoXY(x,y+6);
  END;
  IF clearBottom THEN WRITE("      ") END;
  GotoXY(x+2,y+2);
  SetInkColor(WHITE);
  WRITE(letter)
END DrawVertical;

PROCEDURE MoveVertical(x,y: CARDINAL; color: Color; letter: CHAR; truck,up: BOOLEAN);
VAR step: CARDINAL;
    dummy:CHAR;
BEGIN
  x := OrgX + x * 6;
  y := OrgY + y * 3;
  FOR step:=1 TO 3 DO
    IF up THEN DEC(y) ELSE INC(y) END;
    DrawVertical(x,y,color,letter,truck,NOT up,up);
    Pause(6000);
  END;
END MoveVertical;

PROCEDURE DrawCar(x,y: CARDINAL; color: Color; letter: CHAR; truck,vertical: BOOLEAN);
BEGIN
  x := OrgX + x * 6;
  y := OrgY + y * 3;
  IF vertical
  THEN DrawVertical  (x,y,color,letter,truck,FALSE,FALSE)
  ELSE DrawHorizontal(x,y,color,letter,truck)
  END;
END DrawCar;

BEGIN
  ClearScreen; OrgX := 12; OrgY := 12;
END DrawCars.