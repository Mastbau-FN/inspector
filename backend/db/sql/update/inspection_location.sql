UPDATE "Insp_STANDORT_Infos" SET
	"Eigentuemer"=$?, 
	"Bauwerkhoehe"=$?, 
	"Baujahr"=$?, 
	"Ansprechpartner"=$?, 
	"Steigwegtyp"=$?, 
	"Schluessel"=$?, 
	"Abschaltungen"=$?, 
	"Steckdosen"=$?, 
	"WC"=$?, 
	"Lagerraeume"=$?, 
	"Steigschutzschluessel"=$?
WHERE "Insp_STANDORT_Infos"."PjNr" = $1;
