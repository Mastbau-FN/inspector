DELETE FROM "Events"
WHERE "Index" = $?; /*über Index den Datensatz identifizieren, dann ist auch egal auf welche Ebene man sich befindet*/
