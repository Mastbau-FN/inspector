-- 04_Auswahl_Prüfpunkte
SELECT "MGAUFTR"."PjNr",
"MGAUFTR"."Bauleitung",
"Events"."KurzText",
"Events"."LangText",
"Events"."Link", 
"Events"."LinkOrdner",
"Events"."ErDat",
"Events"."EventID",
"Events"."EREArt",
"Events"."E1",
"Events"."E2",
"Events"."E3",
"Events"."Autor"
FROM "MGAUFTR"
INNER JOIN "Events" ON "MGAUFTR"."PjNr" = "Events"."PjNr"
WHERE (
("MGAUFTR"."PjNr" = $1) -- Primarykey, von welchem projekt wollen wir die Prüfpunkte wissen
AND ("Events"."EREArt" = 5200) -- Prüfpunkte
AND ("Events"."E1" = $2) -- zur wievielten Kategorie wollen wir die Prüfpunkte, 1-indiziert empty wenn nicht-existent
)
ORDER BY "Events"."E1",
"Events"."E2",
"Events"."E3";