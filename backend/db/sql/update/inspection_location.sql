UPDATE "Insp_STANDORT_Infos" SET
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
	"Schlüssel_description"=$15,
	"Temperatur"=$16,
	"Wetter"=$17,
	"Wind"=$18,
	"Windrichtung"=$19
WHERE "Insp_STANDORT_Infos"."PjNr" = $1;
