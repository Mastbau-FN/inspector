-- update Categorie (03_Auswahl_Prüfkategorie)
UPDATE "Events"  
SET 
"PjNr" = $1,
"KurzText" = §4,
"LangText" =$5,
"Link" = $8,
"LinkOrdner" = $9,
"Insp_Stelle" = $? /*ggf. neuer Parameter?*/
WHERE
"EREArt" = 5100 /*Prüfkategorie*/
AND "E1" = $? /*neuer Parameter*/
;
