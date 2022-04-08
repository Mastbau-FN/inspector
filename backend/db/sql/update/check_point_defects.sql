-- update Mangel (05_Prüfpunkt_Mängel)
UPDATE "Events"  
SET 
"KurzText" = $5,
"LangText" =$6,
"Link" = $8,
"LinkOrdner" = $9,
"Zusatz_Info" = $10, /*ggf. neuer Parameter*/
"ErDat" = $??? /*aktuelles Datum*/ 
WHERE
"EREArt" = $7 /*5201 Mangel leicht, 5202 Mangel mittel, 5203 Mangel schwer, 5204 ohne Mangel*/
AND ("E1" = $2 /*neuer Parameter*/
AND "E2" = $3 /*neuer Parameter*/
AND "E3" = $4) /*neuer Parameter*/
AND "PjNr" = $1
;
