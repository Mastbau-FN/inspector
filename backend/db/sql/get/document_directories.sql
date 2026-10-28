SELECT "PjNr", "E1", "E2", "E3", "Link", "LinkOrdner"
FROM "Events"
WHERE "PjNr" = ANY($1::integer[])
  AND "EREArt" IN (5100, 5200, 5201, 5202, 5203, 5204);
