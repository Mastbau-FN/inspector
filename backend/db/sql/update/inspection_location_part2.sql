UPDATE "Events"  
SET 
"KurzText" = $2,
"LangText" =$3,
"Link" = COALESCE($4,"Link"),
"LinkOrdner" = COALESCE($5,"LinkOrdner"),
"Zusatz_Info" = $6,
"ErDat" = $7 /*aktuelles Datum*/ 
WHERE
-- "EREArt" -- @MbgBn hier: was wär hier die nummer um sicherzustellen dass es ein inspektionsort ist?
-- AND 
("E1" = 0 OR "E1" is null)
AND ("E2" = 0 OR "E2" is null)
AND ("E3" = 0 OR "E3" is null)
AND "PjNr" = $1
;