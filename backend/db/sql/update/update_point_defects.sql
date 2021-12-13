-- update Mangel (05_Prüfpunkt_Mängel)
UPDATE "Events"  
SET 
"PjNr" = $1,
"KurzText" = §4,
"LangText" =$5,
"Link" = $8,
"LinkOrdner" = $9,
"Insp_Stelle" = $? /*ggf. neuer Parameter*/
WHERE
"EREArt" = $7 , /*5201 Mangel leicht, 5202 Mangel mittel, 5203 Mangel schwer, 5204 ohne Mangel*/
AND "E1" = $? /*neuer Parameter*/
AND "E2" = $? /*neuer Parameter*/
AND "E3" = $? /*neuer Parameter*/
;
