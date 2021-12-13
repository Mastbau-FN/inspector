-- update Prüfpunkt (04_Auswahl_Prüfpunkte)
UPDATE "Events"  
SET 
"PjNr" = $1,
"KurzText" = §4,
"LangText" =$5,
"Link" = $8,
"LinkOrdner" = $9,
"Insp_Stelle" = $? /*ggf. neuer Parameter?*/
WHERE
"EREArt" = 5200 /*Prüfpunkt*/
AND ("E1" = $? /*neuer Parameter*/
AND "E2" = $? /*neuer Parameter*/
AND "E3" = 0)
;
