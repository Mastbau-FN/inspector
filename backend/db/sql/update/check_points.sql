-- update Prüfpunkt (04_Auswahl_Prüfpunkte)
UPDATE "Events"  
SET 
"PjNr" = $1,
"KurzText" = $4,
"LangText" =$5,
"Link" = $6,
"LinkOrdner" = $7,
"Insp_Stelle" = $8 /*ggf. neuer Parameter?*/
WHERE
"EREArt" = 5200 /*Prüfpunkt*/
AND ("E1" = $2 /*neuer Parameter*/
AND "E2" = $3 /*neuer Parameter*/
AND "E3" = 0)
;
