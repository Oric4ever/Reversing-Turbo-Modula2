MODULE RushHour;
IMPORT ComLine;
FROM Terminal IMPORT ClearScreen, GotoXY;
FROM XTerm    IMPORT CursorOn, CursorOff;
FROM DrawCars IMPORT Color, DrawBorder, DrawCar,
                     MoveVertical, MoveHorizontal;

(*******************************************************************)
(* Internal Queue module                                           *)
(*******************************************************************)
  MODULE CardQueue;
  EXPORT Queue, InitQueue, IsEmpty, Enqueue, Dequeue;
  
  CONST Size = 256;
  TYPE Queue = RECORD
                 getIndx, putIndx : CARDINAL;
                 buffer : ARRAY [0..Size-1] OF CARDINAL;
               END;
  EXCEPTION QueueOverflow, QueueEmpty;
  
  PROCEDURE InitQueue(VAR queue: Queue);
  BEGIN
    WITH queue DO
      getIndx := 0; putIndx := 0;
    END
  END InitQueue;
  
  PROCEDURE IsEmpty(VAR queue: Queue): BOOLEAN;
  BEGIN
    WITH queue DO RETURN getIndx=putIndx END
  END IsEmpty;
  
  PROCEDURE Enqueue(VAR queue: Queue; value: CARDINAL);
  BEGIN
    WITH queue DO
      buffer[putIndx] := value;
      INC(putIndx); IF putIndx=Size THEN putIndx:=0 END;
      IF putIndx=getIndx THEN RAISE QueueOverflow END;
    END
  END Enqueue;
      
  PROCEDURE Dequeue(VAR queue: Queue): CARDINAL;
  VAR value: CARDINAL;
  BEGIN
    WITH queue DO
      IF getIndx=putIndx THEN RAISE QueueEmpty END;
      value := buffer[getIndx];
      INC(getIndx); IF getIndx=Size THEN getIndx:=0 END;
    END;
    RETURN value
  END Dequeue;
  
  END CardQueue;

(*******************************************************************)

  TYPE
    Hash  = RECORD
              first, second : CARDINAL;
            END;
    Move  = RECORD
              car : CARDINAL;
              pos : CARDINAL;
            END;
    Path  = ARRAY [0..50] OF Move;
    Car   = RECORD
              name     : CHAR;
              vertical : BOOLEAN;
              size     : CARDINAL;
              lineCol  : CARDINAL;
            END;
VAR
    cars   : ARRAY [0..15] OF Car;
    nbCars : CARDINAL;
    carPos : ARRAY [0..15] OF CARDINAL;
    redCar : CARDINAL;
    moves  : ARRAY [0..63] OF Move;

PROCEDURE InputBoard;
VAR line : ARRAY [0..5],[0..5] OF CHAR;
    x,y  : CARDINAL;
    name : CHAR;
BEGIN
  WRITELN("Enter board to solve :");
(*  FOR y:=0 TO 5 DO READLN(line[y]) END; *)
  line[0] := "AAOBCC";
  line[1] := "..OB..";
  line[2] := "XXO...";
  line[3] := "DEEFFP";
  line[4] := "D..K.P";
  line[5] := "HH.K.P";
  nbCars := 0;
  FOR y:=0 TO 5 DO FOR x:=0 TO 5 DO
    name := line[y][x];
    IF  (name<>'.')
    AND ((x=0) OR (line[y][x-1]<>name))
    AND ((y=0) OR (line[y-1][x]<>name))
    THEN
      IF CAP(name)='X' THEN redCar:=nbCars END;
      cars[nbCars].name := name;
      IF (y<5) AND (line[y+1][x] = name) THEN
        cars[nbCars].vertical := TRUE;
        cars[nbCars].lineCol := x; carPos[nbCars] := y
      ELSE
        cars[nbCars].vertical := FALSE;
        cars[nbCars].lineCol := y; carPos[nbCars] := x
      END;
      IF (y<4) AND (line[y+2][x] = name) OR
         (x<4) AND (line[y][x+2] = name)
      THEN cars[nbCars].size := 3
      ELSE cars[nbCars].size := 2;
      END;
      INC(nbCars);
    END
  END END;
  WRITELN;
END InputBoard;


PROCEDURE PositionIsOK(forCar: CARDINAL; VAR carsPos : ARRAY OF CARDINAL):BOOLEAN;
VAR car, lineCol, colLine, size, position : CARDINAL;
    vertical : BOOLEAN;
BEGIN
  vertical := cars[forCar].vertical;
  lineCol  := cars[forCar].lineCol;
  size     := cars[forCar].size;
  position := carsPos[forCar];
  FOR car:=0 TO nbCars-1 DO
    IF vertical = cars[car].vertical THEN (* same direction *)
      IF (car<>forCar) AND (lineCol = cars[car].lineCol) (* same line or column *)
      AND (position+size>carsPos[car]) AND (carsPos[car]+cars[car].size>position)
      THEN RETURN FALSE
      END
    ELSE (* orthogonal directions *)
      FOR colLine:=position TO position+size-1 DO
        IF (colLine = cars[car].lineCol)
        AND (lineCol >= carsPos[car]) AND (lineCol < carsPos[car]+cars[car].size)
        THEN RETURN FALSE
        END
      END
    END
  END;
  RETURN TRUE
END PositionIsOK;

PROCEDURE FindPossibleMoves(VAR carsPos: ARRAY OF CARDINAL;
                            VAR moves:ARRAY OF Move): CARDINAL;
VAR car, nbMoves, oldPos: CARDINAL;
BEGIN
  nbMoves := 0;
  FOR car:=0 TO nbCars-1 DO
    oldPos := carsPos[car];
    LOOP
      IF carsPos[car]=0 THEN EXIT END;
      DEC(carsPos[car]);
      IF NOT PositionIsOK(car, carsPos) THEN EXIT END;
      moves[nbMoves].car := car;
      moves[nbMoves].pos := carsPos[car];
      INC(nbMoves);
    END;
    carsPos[car] := oldPos+1;
    WHILE (carsPos[car]+cars[car].size <= 6) AND PositionIsOK(car, carsPos) DO
      moves[nbMoves].car := car;
      moves[nbMoves].pos := carsPos[car];
      INC(nbMoves);
      INC(carsPos[car])
    END;
    carsPos[car] := oldPos
  END;
  RETURN nbMoves
END FindPossibleMoves;

(*******************************************************************)
(* Implements a Store for compressed configurations,
   with parent link information
********************************************************************)
CONST STORESIZE = 600;
VAR store : ARRAY [0..STORESIZE-1] OF Hash;
    parent : ARRAY [0..STORESIZE-1] OF INTEGER;
    parentMove : ARRAY [0..STORESIZE-1] OF Move;
    storeId : INTEGER;

PROCEDURE InitStore;
BEGIN
  storeId := -1
END InitStore;

PROCEDURE Compress(VAR carsPos : ARRAY OF CARDINAL; VAR hash: Hash);
VAR car  : CARDINAL;
BEGIN
  hash.first := 0; hash.second := 0;
  FOR car:=0 TO 5 DO hash.first := hash.first*5 + carsPos[car]; END;
  FOR car:=6 TO nbCars-1 DO hash.second := hash.second*5 + carsPos[car]; END;
END Compress;

PROCEDURE UnCompress(hash: Hash; VAR carsPos: ARRAY OF CARDINAL);
VAR car : CARDINAL;
BEGIN
  FOR car:=5 TO 0 BY -1 DO
    carsPos[car] := hash.first MOD 5;
    hash.first := hash.first DIV 5;
  END;
  FOR car:=nbCars-1 TO 6 BY -1 DO
    carsPos[car] := hash.second MOD 5;
    hash.second := hash.second DIV 5;
  END
END UnCompress;

PROCEDURE IsInStore(VAR carPos: ARRAY OF CARDINAL): BOOLEAN;
VAR indx : INTEGER;
    hash : Hash;
BEGIN
  Compress(carPos,hash);
  FOR indx := storeId TO 0 BY -1 DO
    IF (hash.first = store[indx].first) AND (hash.second = store[indx].second)
    THEN RETURN TRUE END
  END;
  RETURN FALSE
END IsInStore;

PROCEDURE Store(VAR carPos: ARRAY OF CARDINAL;
                parentId  : INTEGER;
                move      : Move): INTEGER;
BEGIN
  INC(storeId);
  Compress(carPos, store[storeId]);
  parent[storeId]     := parentId;
  parentMove[storeId] := move;
  RETURN storeId
END Store;

PROCEDURE Extract(id: INTEGER;
                  VAR carPos  : ARRAY OF CARDINAL;
                  VAR parentId: INTEGER;
                  VAR move    : Move);
VAR hash : Hash;
BEGIN
  hash := store[id];
  UnCompress(hash, carPos);
  parentId := parent[id];
  move := parentMove[id];
END Extract;

PROCEDURE LastStore(): INTEGER;
BEGIN
  RETURN storeId
END LastStore;

(*******************************************************************)


PROCEDURE BFSearch(carsPos: ARRAY OF CARDINAL): BOOLEAN;
VAR car, i, oldPos, nbMoves : CARDINAL;
    id, parentId : INTEGER;
    hash : Hash;
    unexplored : Queue;
BEGIN
  InitQueue(unexplored);
  InitStore;
  id := Store(carsPos, 0, moves[1]); (* dummy move *)
  Enqueue(unexplored, id);
  WHILE NOT IsEmpty(unexplored) DO
    parentId := Dequeue(unexplored);
    Extract(parentId, carsPos, id, moves[1]); (* id and moves not used *)
    nbMoves := FindPossibleMoves(carsPos, moves);
    FOR i:=0 TO nbMoves-1 DO
      car := moves[i].car;
      oldPos := carsPos[car];         (* save current car position *)
      carsPos[car] := moves[i].pos;   (* do the move *)
      IF NOT IsInStore(carsPos) THEN
        id := Store(carsPos, parentId, moves[i]);
        Enqueue(unexplored, id);
        IF (car=redCar) AND (carsPos[car]=4) THEN RETURN TRUE END; (* success *)
      END;
      carsPos[car] := oldPos; (* undo move: restore old car position *)
    END
  END;
  RETURN FALSE (* no solution found *)
END BFSearch;

PROCEDURE PrintBoard;
VAR x,y,car : CARDINAL;
    truck, vertical : BOOLEAN;
    name : CHAR;
    color : Color;
BEGIN
  DrawBorder;
  FOR car:=0 TO nbCars-1 DO
    vertical := cars[car].vertical;
    truck    := cars[car].size = 3;
    name     := cars[car].name;
    IF vertical THEN
      x := cars[car].lineCol; y := carPos[car];
    ELSE
      x := carPos[car]; y := cars[car].lineCol;
    END;
    IF name = 'X' 
    THEN color := RED 
    ELSE color := Color( ORD(name) MOD 6 + 2 )
    END;
    DrawCar(x, y, color, name, truck, vertical);
  END;
END PrintBoard;

PROCEDURE GetSolutionMoves(VAR moves:ARRAY OF Move): CARDINAL;
VAR id, parentId : INTEGER;
    i, nbMoves : CARDINAL;
    tmp : Move;
BEGIN
  nbMoves := 0;
  id := LastStore();
  WHILE id<>0 DO
    Extract(id, carPos, parentId, moves[nbMoves]);
    INC(nbMoves);
    id := parentId
  END;
  RETURN nbMoves
END GetSolutionMoves;

PROCEDURE PrintSolution(nbMoves: CARDINAL; VAR moves:ARRAY OF Move);
VAR car, i, dest, dist : CARDINAL;
    parentId : INTEGER;
    move, dummy : Move;
BEGIN
  Extract(0, carPos, parentId, dummy);
  FOR i:=nbMoves-1 TO 0 BY -1 DO
    car := moves[i].car;
    dest:= moves[i].pos;
    WRITE(cars[car].name);
    IF dest>carPos[car] THEN
      dist := dest-carPos[car];
      IF cars[car].vertical THEN WRITE('d') ELSE WRITE('r') END
    ELSE
      dist := carPos[car]-dest;
      IF cars[car].vertical THEN WRITE('u') ELSE WRITE('l') END
    END;
    WRITE(CHR(ORD('0')+dist),' ');
    carPos[car] := dest;  (* do the move *)
  END
END PrintSolution;

PROCEDURE AnimateSolution(nbMoves: CARDINAL; VAR moves:ARRAY OF Move);
  PROCEDURE Sleep(n : CARDINAL);
  BEGIN
    WHILE n<>0 DO DEC(n) END
  END Sleep;
VAR i, car, dest  : CARDINAL;
    x,y,steps,step: CARDINAL;
    parentId      : INTEGER;
    dummy         : Move;
    name          : CHAR;
    color         : Color;
    toLeftOrUp    : BOOLEAN;
    truck         : BOOLEAN;
BEGIN
  Extract(0, carPos, parentId, dummy);
  PrintBoard;
  FOR i:=nbMoves-1 TO 0 BY -1 DO
    Sleep(30000);
    car  := moves[i].car;
    dest := moves[i].pos;
    name := cars[car].name;
    toLeftOrUp := carPos[car] > dest;
    IF toLeftOrUp 
    THEN steps := carPos[car] - dest
    ELSE steps := dest - carPos[car] 
    END;
    IF name = 'X' 
    THEN color := RED 
    ELSE color := Color( ORD(name) MOD 6 + 2 )
    END;
    truck := cars[car].size = 3;
    IF cars[car].vertical THEN
      x := cars[car].lineCol; y := carPos[car];
      FOR step := 1 TO steps DO
        MoveVertical(x, y, color, name, truck, toLeftOrUp);
        IF toLeftOrUp THEN DEC(y) ELSE INC(y) END;
      END;
    ELSE
      x := carPos[car]; y := cars[car].lineCol;
      FOR step := 1 TO steps DO
        MoveHorizontal(x, y, color, name, truck, toLeftOrUp);
        IF toLeftOrUp THEN DEC(x) ELSE INC(x) END;
      END;
    END;
    carPos[car] := dest; (* do the move *)
  END
END AnimateSolution;

VAR indx, nbMoves: CARDINAL;
    hash : Hash;
BEGIN
(*  ComLine.RedirectInput; *)
  InputBoard;
  ClearScreen; CursorOff;
  PrintBoard;
  IF BFSearch(carPos) THEN
    nbMoves := GetSolutionMoves(moves);
    AnimateSolution(nbMoves, moves);
  ELSE WRITELN('No solution found')
  END;
  GotoXY(0,24); CursorOn;
END RushHour.
