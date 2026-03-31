SELECT
  "KZL",
  "Vorname",
  "Name"
FROM "Def_Login"
WHERE
  "KZL" IS NOT NULL
  AND btrim("KZL"::text) <> ''
  AND "KZL" <> '??'
ORDER BY
  "Name" ASC,
  "Vorname" ASC,
  "KZL" ASC;
