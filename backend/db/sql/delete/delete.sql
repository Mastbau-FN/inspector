DELETE FROM "Events"
WHERE WHERE "PjNr" = $1 
AND "E1" = $? /*neuer Parameter*/
AND "E2" = $? /*neuer Parameter*/
AND "E3" = $? /*neuer Parameter*/
; 
