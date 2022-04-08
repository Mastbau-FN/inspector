-- update Prüfpunkt (04_Auswahl_Prüfpunkte)
UPDATE "Events"  
SET 
"KurzText" = $4,
"LangText" =$5,
"Link" = COALESCE($6,"Link"),
"LinkOrdner" = COALESCE($7,"LinkOrdner"),
"Zusatz_Info" = $8, /*ggf. neuer Parameter?*/
"ErDat" = $9 /*aktuelles Datum*/ 
WHERE
"EREArt" = 5200 /*Prüfpunkt*/
AND ("E1" = $2 /*neuer Parameter*/
AND "E2" = $3 /*neuer Parameter*/
AND ("E3" = 0 OR "E3" is null))
AND "PjNr" = $1
;
