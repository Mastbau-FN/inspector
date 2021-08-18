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
"Events"."E3"
FROM "MGAUFTR"
INNER JOIN "Events" ON "MGAUFTR"."PjNr" = "Events"."PjNr"
WHERE (
("MGAUFTR"."PjNr" = 6006259) -- $1 ?
AND ("MGAUFTR"."Bauleitung" LIKE 'NL')
AND ("Events"."EREArt" = 5200) -- Prüfpunkte
AND ("Events"."E1" = 2) -- alle Prüfpunkte zur zweiten Kategorie
)
ORDER BY "Events"."E1",
"Events"."E2",
"Events"."E3";