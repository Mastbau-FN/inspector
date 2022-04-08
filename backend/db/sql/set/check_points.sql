-- add Prüfpunkt (04_Auswahl_Prüfpunkte)
INSERT INTO "Events" ("PjNr", "KurzText", "LangText", "Link", "LinkOrdner", "EventID", "EREArt", "E1", "E2", "E3", "Zusatz_Info", "Autor", "ErDat") 
VALUES (
$1, /*Projektnummer*/
$3, /*name (required)*/
$4, /*description (optional)*/
$5, /*Link*/
$6, /*linkOrdner*/
0, /*erstmal 0, später mehr*/
5200, /*is PrüfPunkt*/
$2, /*required: Wert der Ebene 1*/
(SELECT COALESCE("E2",0) + 1 AS "E2"
FROM "Events"
WHERE "PjNr" = $1 /*required: Projektnummer*/
AND "E1" = $2 /*required: Wert der Ebene 1*/
ORDER BY COALESCE("E2",0) DESC LIMIT 1),
0,
NULL,
$7, /*Autor/KZL (ersteller des neuen Datenpunktes)*/
$8 /*ErDat, aktuelles Datum*/  
)
RETURNING "E2"
;
