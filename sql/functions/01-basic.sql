/*
    Stored Proc: dropFunctions()
*/
CREATE OR REPLACE FUNCTION dropFunctions() returns integer AS $$
    DECLARE
        _f varchar;
    BEGIN
        -- Logging
        raise notice 'dropFunctions()';

        FOR _f IN 
                SELECT 'DROP FUNCTION ' || ns.nspname || '.' || proname 
                       || '(' || oidvectortypes(proargtypes) || ');'
                FROM pg_proc INNER JOIN pg_namespace ns ON (pg_proc.pronamespace = ns.oid)
                WHERE ns.nspname = 'scoreboard'  order by proname
        LOOP
            EXECUTE _f;
        END LOOP;

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;
SELECT dropFunctions();

/*
    Stored Proc: emptyTables()
*/
CREATE OR REPLACE FUNCTION emptyTables() 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'emptyTables()';

        TRUNCATE team,
                 flagStatus,
                 host,
                 flagCategory,
                 flagAuthor,
                 flag,
                 kingFlag,
                 team_flag,
                 team_kingFlag,
                 news,
                 submit_history,
                 flagStatus_history,
                 settings
            RESTART IDENTITY
            CASCADE;
        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    sha256()
*/
CREATE OR REPLACE FUNCTION sha256(text) returns text AS $$
    SELECT encode(pgcrypto.digest($1, 'sha256'), 'hex');
$$ LANGUAGE sql STRICT IMMUTABLE;

/*
    random_64()
*/
CREATE OR REPLACE FUNCTION random_64() returns text AS $$
    SELECT encode(pgcrypto.digest(random()::text, 'sha256'), 'hex');
    --SELECT encode(pgcrypto.digest(to_char(random(),'9.999999999999999'), 'sha256'), 'hex')
$$ LANGUAGE sql;

/*
    random_32()
*/
CREATE OR REPLACE FUNCTION random_32() returns text AS $$
    SELECT encode(pgcrypto.digest(random()::text, 'md5'), 'hex');
    --SELECT encode(pgcrypto.digest(to_char(random(),'9.999999999999999'), 'md5'), 'hex')
$$ LANGUAGE sql;

/*
    idx: Used in some ORDER BY
*/
CREATE OR REPLACE FUNCTION idx(anyarray, anyelement)
  RETURNS integer AS 
$$
  SELECT i FROM (
     SELECT generate_series(array_lower($1,1),array_upper($1,1))
  ) g(i)
  WHERE $1[i] = $2
  LIMIT 1;
$$ LANGUAGE sql IMMUTABLE;

/*
    formatCash()
*/
CREATE OR REPLACE FUNCTION formatCash(cash NUMERIC(9,2)) returns NUMERIC(9,2) AS $$
    SELECT cash::NUMERIC(9,2);
$$ LANGUAGE sql STRICT IMMUTABLE;

/*
    raise_p()
    Error code T3GA0 is used for scoreboard as errors printable to users.
*/
CREATE OR REPLACE FUNCTION raise_p(msg text) 
RETURNS integer AS 
$$
    BEGIN
        raise exception USING MESSAGE = msg, ERRCODE = 'T3GA0';
    END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

