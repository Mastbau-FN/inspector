-- 02_Auswahl_Inspektion
SELECT "MGAUFTR"."PjNr", -- Mastbau Projektnummer
"MGAUFTR"."PjName",
"MGAUFTR"."PjInfo",
"MGAUFTR"."Bauleitung", -- Monteur
"STANDORT"."StONr",
"STANDORT"."Straße",
"STANDORT"."PLZ",
"STANDORT"."Ort",
"Events"."Link", -- einzelnes default Foto
"Events"."LinkOrdner" -- Ordner für Fotos
FROM (
"MGAUFTR" INNER JOIN "STANDORT" ON "MGAUFTR"."StONr" = "STANDORT"."StONr"
)
INNER JOIN "Events" ON "MGAUFTR"."PjNr" = "Events"."PjNr"
WHERE (
("MGAUFTR"."Bauleitung" = 'NL') -- Monteur
AND "MGAUFTR"."PjTypID" = 2000 -- Projekttyp Inspektion, als Variable ablegen
AND ("Events"."EventID" = 1910) -- Standardereignis_ID Übersichtsfoto zum Standort, als Variable ablegen
)
ORDER BY "MGAUFTR"."AuDatum";

-- 03_Auswahl_Prüfkategorie
SELECT "MGAUFTR"."PjNr",
"MGAUFTR"."Bauleitung",
"Events"."KurzText",
"Events"."LangText",
"Events"."Link", 
"Events"."LinkOrdner",
"Events"."ErDat",
"Events"."EventID", -- definiert Standard-Ereignisse 
"Events"."EREArt", -- definiert Art des Ereignisses
"Events"."E1", -- Ebenendarstellung, erste Ebene Kategorien
"Events"."E2", -- Ebenendarstellung, zweite Ebene Prüfpunkte
"Events"."E3" -- Ebenendarstellung, dritte Ebene Mängel
FROM "MGAUFTR"
INNER JOIN "Events" ON "MGAUFTR"."PjNr" = "Events"."PjNr"
WHERE (
("MGAUFTR"."PjNr" = 6006259) -- Projektnummer
AND ("MGAUFTR"."Bauleitung" LIKE 'NL') -- Monteur
AND ("Events"."EREArt" = 5100) -- Kategorien
)
ORDER BY "Events"."E1",
"Events"."E2",
"Events"."E3";

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
("MGAUFTR"."PjNr" = 6006259)
AND ("MGAUFTR"."Bauleitung" LIKE 'NL')
AND ("Events"."EREArt" = 5200) -- Prüfpunkte
AND ("Events"."E1" = 2) -- alle Prüfpunkte zur zweiten Kategorie
)
ORDER BY "Events"."E1",
"Events"."E2",
"Events"."E3";

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
("MGAUFTR"."PjNr" = 6006259)
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
