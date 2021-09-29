-- irgendeine designentscheidung hat es geschafft, dass für jedes event hier der root-pfad herkommen muss
SELECT "Link" -- Ordner für Fotos
FROM "Events"
WHERE (
    "EventID" = 6097
    AND "PjNr" = $1
)
;