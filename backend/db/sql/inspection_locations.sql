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
("MGAUFTR"."Bauleitung" = $1) -- Monteur Kürzel(KZL) -- hauptparameter
AND "MGAUFTR"."PjTypID" = $2 -- Projekttyp (2000=Inspektion) for future proofing
AND ("Events"."EventID" = $3) -- Standardereignis_ID 6097 Übersichtsfoto zum Standort (moch nicht 100% durchblickt)
)
ORDER BY "MGAUFTR"."AuDatum";