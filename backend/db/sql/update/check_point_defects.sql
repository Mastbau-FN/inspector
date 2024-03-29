-- update Mangel (05_Prüfpunkt_Mängel)
UPDATE "Events"  
SET 
"KurzText" = $5,
"LangText" =$6,
"Link" = COALESCE($8,"Link"),
"LinkOrdner" = COALESCE($9,"LinkOrdner"),
"Zusatz_Info" = $10, /*ggf. neuer Parameter*/
"ErDat" = $11, /*aktuelles Datum*/ 
"EREArt" = $7 /*5201 Mangel leicht, 5202 Mangel mittel, 5203 Mangel schwer, 5204 ohne Mangel*/

WHERE
("E1" = $2 /*neuer Parameter*/
AND "E2" = $3 /*neuer Parameter*/
AND "E3" = $4) /*neuer Parameter*/
AND "PjNr" = $1
;
