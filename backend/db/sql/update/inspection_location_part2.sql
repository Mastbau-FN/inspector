UPDATE "Events"  
SET 
"KurzText" = $2,
"LangText" =$3,
"Link" = $4,
"LinkOrdner" = $5,
"Zusatz_Info" = $6
WHERE
-- "EREArt" -- @MbgBn hier: was wär hier die nummer um sicherzustellen dass es ein inspektionsort ist?
-- AND 
("E1" = 0 OR "E1" is null)
AND ("E2" = 0 OR "E2" is null)
AND ("E3" = 0 OR "E3" is null)
AND "PjNr" = $1
;