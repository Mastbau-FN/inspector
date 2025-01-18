CREATE DATABASE "insp_4" WITH TEMPLATE "insp_doubled" OWNER postgres;

SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity 
WHERE pg_stat_activity.datname = 'insp_doubled' AND pid <> pg_backend_pid();

SELECT * FROM "Events"
WHERE "PjNr" = 20236546 

-- replace all 3453 with 1 in all Link and LinkOrdner of PjNr 20236546
UPDATE "Events"
SET 
    "Link" = REPLACE("Link", '3453', '1'),
    "LinkOrdner" = REPLACE("LinkOrdner", '3453', '1')
WHERE "PjNr" = 20236546