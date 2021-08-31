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
("MGAUFTR"."PjNr" = $1) -- Projektnummer --$1 , ist inspector agnostic
-- AND ("MGAUFTR"."Bauleitung" LIKE 'NL') -- Monteur -- redundant über PjNr
AND ("Events"."EREArt" = 5100) -- Kategorien
)
ORDER BY "Events"."E1",
"Events"."E2",
"Events"."E3";