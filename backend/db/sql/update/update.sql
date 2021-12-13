UPDATE "Events"
SET "LangText" = $3
WHERE "Index" = $?; /*über Index den Datensatz identifizieren, dann ist auch egal ob category, point oder point_defect*/
