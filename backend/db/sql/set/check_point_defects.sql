-- add Mangel (05_Prüfpunkt_Mängel)
INSERT INTO "Events" ("PjNr", "KurzText", "LangText", "Link", "LinkOrdner", "EventID", "EREArt", "E1", "E2", "E3", "Zusatz_Info", "Autor", "ErDat") 
VALUES (
$1, /*Projektnummer*/
$4, /*name (required)*/
$5, /*description (optional)*/
$8, /*Link*/
$9, /*linkOrdner*/
0, /*erstmal 0, später mehr*/
$7 , /*5201 Mangel leicht, 5202 Mangel mittel, 5203 Mangel schwer, 5204 ohne Mangel*/
$2, /*required: Wert der Ebene 1*/
$3, /*required: Wert der Ebene 2*/
(SELECT COALESCE("E3",0) + 1 AS "E3" FROM "Events" WHERE "PjNr" = $1 /*Projektnummer*/ AND "E1" = $2 /*Wert für Ebene 1*/ AND "E2" = $3 /*Wert für Ebene 2*/ ORDER BY COALESCE("E3",0) DESC LIMIT 1),
$6, /*Höhenangabe*/
$10, /*Autor/KZL (ersteller des neuen Datenpunktes)*/
$??? /*ErDat, aktuelles Datum*/  
)
RETURNING "E3"
;
