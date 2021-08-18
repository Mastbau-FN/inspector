-- 05_Prüfpunkt_Mängel
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
("MGAUFTR"."PjNr" = 6006259) --$1?
AND ("MGAUFTR"."Bauleitung" LIKE 'NL')
AND (
"Events"."EREArt" = 5201 -- leichte Mängel
OR "Events"."EREArt" = 5202 -- mittlere Mängel
OR "Events"."EREArt" = 5203 -- schwere Mängel
OR "Events"."EREArt" = 5204 -- ohne Mängel
)
AND ("Events"."E2" = 2) -- alle Mängel zum zweiten Prüfpunkt
)
ORDER BY "Events"."E1",
"Events"."E2",
"Events"."E3"
