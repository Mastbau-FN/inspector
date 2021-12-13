-- update Categorie (03_Auswahl_Prüfkategorie)
UPDATE "Events"  
SET 
"PjNr" = $1,
"KurzText" = §2
"LangText" =$3
"Link" = $3,
"LinkOrdner" = $4
"Insp_Stelle" = $? /*ggf. neuer Parameter*/
WHERE
"EREArt" = 5100 /*Prüfkategorie*/
AND "E1" = $? /*neuer Parameter*/
;
