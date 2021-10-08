
-- add Categorie (03_Auswahl_Prüfkategorie)
INSERT INTO "Events" ("PjNr", "KurzText", "LangText", "Link", "LinkOrdner", "EventID", "EREArt", "E1", "E2", "E3", "Insp_Stelle") 
OUTPUT Inserted."E1"
VALUES (
$1, /*Projektnummer*/
$2, /*name (required)*/
$3, /*description (optional)*/
$4, /*Link*/
$5, /*linkOrdner*/
0, /*erstmal 0, später mehr*/
5100, /*is Prüfkategorie*/
(SELECT COALESCE("E1",0) + 1 AS "E1"
FROM "Events"
WHERE "PjNr" = $1 /*Projektnummer*/
ORDER BY COALESCE("E1",0) DESC LIMIT 1),
0,
0,
NULL
);

