UPDATE "MGAUFTR"  
SET 
"Login_ID_Pruefer" =$2
WHERE
"PjNr" = $1
AND "Login_ID_Pruefer" IS DISTINCT FROM $2
RETURNING "PjNr","Login_ID_Pruefer"
;
