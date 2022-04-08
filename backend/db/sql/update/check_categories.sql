-- update Categorie (03_Auswahl_Prüfkategorie)
UPDATE "Events"  
SET 
"KurzText" = $3,
"LangText" =$4,
"Link" = COALESCE($5,"Link"),
"LinkOrdner" = COALESCE($6,"LinkOrdner"),
"Zusatz_Info" = $7, /*ggf. neuer Parameter?*/
"ErDat" = $8 /*aktuelles Datum*/  
WHERE
"EREArt" = 5100 /*Prüfkategorie*/
AND ("E1" = $2 /*neuer Parameter*/
AND ("E2" = 0 OR "E2" is null)
AND ("E3" = 0 OR "E3" is null))
AND "PjNr" = $1
;
