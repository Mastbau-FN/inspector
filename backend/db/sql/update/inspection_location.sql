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
	"Steigschutzschluessel"=$12
WHERE "Insp_STANDORT_Infos"."PjNr" = $1;

UPDATE "Events"  
SET 
"KurzText" = $13,
"LangText" =$14,
"Link" = $15,
"LinkOrdner" = $16,
"Zusatz_Info" = $17
WHERE
-- "EREArt" -- @MbgBn hier: was wär hier die nummer um sicherzustellen dass es ein inspektionsort ist?
-- AND 
("E1" = 0 OR "E1" is null)
AND ("E2" = 0 OR "E2" is null)
AND ("E3" = 0 OR "E3" is null)
AND "PjNr" = $1
;