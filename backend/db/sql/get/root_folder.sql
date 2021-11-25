-- irgendeine designentscheidung hat es geschafft, dass für jedes event hier der root-pfad herkommen muss
SELECT "Link" , "LinkOrdner" -- Ordner für Fotos
FROM "Events"
WHERE (
    "EventID" = $2
    AND "PjNr" = $1
)
;