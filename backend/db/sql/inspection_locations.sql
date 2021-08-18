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
("MGAUFTR"."Bauleitung" = $1) -- Monteur -- $1 oder immer 'NL' für monteur
AND "MGAUFTR"."PjTypID" = 2000 -- Projekttyp Inspektion, als Variable ablegen --for future proofing?
AND ("Events"."EventID" = 6097) -- Standardereignis_ID Übersichtsfoto zum Standort, als Variable ablegen  --???
)
ORDER BY "MGAUFTR"."AuDatum";