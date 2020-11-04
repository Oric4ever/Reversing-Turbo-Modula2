MODULE MCode;
FROM Loader2 IMPORT Call;
FROM ComLine IMPORT PromptFor;
VAR modName: ARRAY [0..9] OF CHAR;
BEGIN
  PromptFor("Module to interpret: ",modName);
  Call(modName)
END MCode.
  