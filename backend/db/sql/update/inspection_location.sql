with events_update as (
	UPDATE "Events"  
		SET 
		"PjNr" = $1,
		"KurzText" = $16,
		"LangText" =$17,
		"Link" = COALESCE($18,"Link"),
		"LinkOrdner" = COALESCE($19,"LinkOrdner"),
		"Zusatz_Info" = $20
		WHERE
		"EREArt" = 5100 /*Prüfkategorie*/
		AND ("E1" = 0 OR "E2" is null)
		AND ("E2" = 0 OR "E2" is null)
		AND ("E3" = 0 OR "E3" is null)
	returning "PjNr"
)
UPDATE "Insp_STANDORT_Infos" 
	"Eigentuemer"=$2, 
	"Bauwerkhoehe"=$3, 
	"Baujahr"=$4, 
	"Ansprechpartner"=$5, 
	"Steigwegtyp"=$6, 
	"Schluessel"=$7, 
	"Abschaltungen"=$8, 
	"Steckdosen"=$9, 
	"WC"=$10, 
	"Lagerraeume"=$11, 
	"Steigschutzschluessel"=$12,
	"ASP_required"=$13,
	"Steckdosen_description"=$14,
	"Schlüssel_description"=$15
WHERE ("PjNr") IN (select "PjNr" from events_update);