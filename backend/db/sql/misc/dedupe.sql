-- Active: 1715682165743@@10.46.26.9@5436@insp_3
-- Query 1 : select all duplicate categories
SELECT e.* FROM "Events" e 
JOIN (
    SELECT "PjNr", "LangText", "KurzText", "E2", "E3", COUNT(*) , "Zusatz_Info"
    FROM "Events"
    WHERE ("E2" = 0 AND "E3" = 0)
    GROUP BY "PjNr","LangText", "KurzText", "E2", "E3" , "Zusatz_Info"
    HAVING COUNT(*) > 1
    ORDER BY COUNT(*) DESC
) d
ON d."PjNr" = e."PjNr" AND d."LangText" = e."LangText" AND d."KurzText" = e."KurzText" AND d."Zusatz_Info" = e."Zusatz_Info"
-- AND (d."E1" != e."E1" AND d."E2" = 0 AND d."E3" = 0)
;
-- there are none

-- Query 2 : select all duplicate checkpoints
SELECT e.* FROM "Events" e 
JOIN (
    SELECT "PjNr", "LangText", "KurzText", "E1",  "E3", COUNT(*) , "Zusatz_Info"
    FROM "Events"
    WHERE ("E3" = 0)
    GROUP BY "PjNr","LangText", "KurzText", "E1",  "E3" , "Zusatz_Info"
    HAVING COUNT(*) > 1
    ORDER BY COUNT(*) DESC
) d
ON d."PjNr" = e."PjNr" AND d."LangText" = e."LangText" AND d."KurzText" = e."KurzText" AND d."Zusatz_Info" = e."Zusatz_Info"
AND (d."E1" = e."E1")
;
-- there are none

-- how often do duplicates occur?
SELECT "PjNr", "LangText", "KurzText", "E1",  "E2", COUNT(*) , "Zusatz_Info"
FROM "Events"
-- WHERE ("E3" = 0)
GROUP BY "PjNr","LangText", "KurzText", "E1",  "E2" , "Zusatz_Info"
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
;

-- Query 3 : select all duplicate (including orig) mangel
SELECT e.* FROM "Events" e 
JOIN (
    SELECT "PjNr", "LangText", "KurzText", "E1",  "E2", COUNT(*) , "Zusatz_Info"
    FROM "Events"
    -- WHERE ("E3" = 0)
    GROUP BY "PjNr","LangText", "KurzText", "E1",  "E2" , "Zusatz_Info"
    HAVING COUNT(*) > 1
    ORDER BY COUNT(*) DESC
) d
ON d."PjNr" = e."PjNr" AND d."LangText" = e."LangText" AND d."KurzText" = e."KurzText" AND d."Zusatz_Info" = e."Zusatz_Info"
AND (d."E1" = e."E1" AND d."E2" = e."E2")
;

-- Query 4 : select all duplicate (excl orig) mangel
SELECT ev.* FROM "Events" ev
WHERE ev."Index" NOT IN (SELECT DISTINCT ON ("PjNr","LangText", "KurzText", "E1",  "E2" , "Zusatz_Info", "E1", "E2") e."Index" FROM "Events" e ) -- all non-duplicates
;

-- YEEEET
DELETE FROM "Events" ev
WHERE ev."Index" NOT IN (SELECT DISTINCT ON ("PjNr","LangText", "KurzText", "E1",  "E2" , "Zusatz_Info", "E1", "E2") e."Index" FROM "Events" e ) -- all non-duplicates
;