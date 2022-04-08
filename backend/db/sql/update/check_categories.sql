-- update Categorie (03_Auswahl_Prüfkategorie)
UPDATE "Events"  
SET 
"KurzText" = $3,
"LangText" =$4,
"Link" = $5,
"LinkOrdner" = $6,
"Zusatz_Info" = $7, /*ggf. neuer Parameter?*/
"ErDat" = $??? /*aktuelles Datum*/  
WHERE
"EREArt" = 5100 /*Prüfkategorie*/
AND ("E1" = $2 /*neuer Parameter*/
AND ("E2" = 0 OR "E2" is null)
AND ("E3" = 0 OR "E3" is null))
AND "PjNr" = $1
;
