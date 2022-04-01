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
	"Events"."LinkOrdner", -- Ordner für Fotos
	"Insp_STANDORT_Infos"."Eigentuemer",
	"Insp_STANDORT_Infos"."Bauwerkhoehe",
	"Insp_STANDORT_Infos"."Baujahr",
	"Insp_STANDORT_Infos"."Ansprechpartner",
	"Insp_STANDORT_Infos"."Steigwegtyp",
	"Insp_STANDORT_Infos"."Schluessel",
	"Insp_STANDORT_Infos"."Abschaltungen",
	"Insp_STANDORT_Infos"."Steckdosen",
	"Insp_STANDORT_Infos"."WC",
	"Insp_STANDORT_Infos"."Lagerraeume",
	"Insp_STANDORT_Infos"."Steigschutzschluessel",
	"V_StO_Koordinaten"."X",
	"V_StO_Koordinaten"."Y",
	"Insp_STANDORT_Infos"."ASP_required",
	"Insp_STANDORT_Infos"."Steckdosen_description",
	"Insp_STANDORT_Infos"."Schlüssel_description"
FROM (
	"MGAUFTR" INNER JOIN "STANDORT" ON "MGAUFTR"."StONr" = "STANDORT"."StONr"
	)
INNER JOIN "Events" ON "MGAUFTR"."PjNr" = "Events"."PjNr"
INNER JOIN "Insp_STANDORT_Infos" ON "MGAUFTR"."PjNr" = "Insp_STANDORT_Infos"."PjNr"
INNER JOIN "V_StO_Koordinaten" ON "MGAUFTR"."StONr" = "V_StO_Koordinaten"."StONr"
WHERE (
		("MGAUFTR"."Bauleitung" = $1) -- Monteur Kürzel(KZL) -- hauptparameter
		AND "MGAUFTR"."PjTypID" = $2 -- Projekttyp (2000=Inspektion) for future proofing
		AND ("Events"."EventID" = $3) -- Standardereignis_ID 1910 Übersichtsfoto zum Standort (moch nicht 100% durchblickt)
		)
ORDER BY "MGAUFTR"."AuDatum";
