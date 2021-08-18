SELECT * 
FROM "Def_Login"
WHERE 
    "KZL" = $1 
    AND 
    "PW" = crypt($2, "PW");