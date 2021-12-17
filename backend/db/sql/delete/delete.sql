DELETE FROM "Events"
WHERE "PjNr" = $1 
AND "E1" = $2 /*neuer Parameter*/
AND "E2" = $3 /*neuer Parameter*/
AND "E3" = $4 /*neuer Parameter*/
AND "Autor" = $5
; 
