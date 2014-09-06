/*
    Set default schema
*/
SET search_path TO mon2k14;

/*
    Database security
*/
-- Drop privileges as much as possible
--REVOKE ALL PRIVILEGES ON DATABASE mon2k14 FROM PUBLIC;    -- 
--REVOKE ALL PRIVILEGES ON SCHEMA mon2k14 FROM PUBLIC;    -- 
--REVOKE ALL PRIVILEGES ON SCHEMA pgcrypto FROM PUBLIC;   -- 
--REVOKE ALL PRIVILEGES ON SCHEMA public FROM PUBLIC;     -- Why not...

--REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA mon2k14 FROM PUBLIC;
--REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA pgcrypto FROM PUBLIC;
--REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA mon2k14 FROM hfadmins;
--REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA pgcrypto FROM hfadmins;
--REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA mon2k14 FROM hfplayers;
--REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA pgcrypto FROM hfplayers;
--REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA mon2k14 FROM player;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA mon2k14 FROM player;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA mon2k14 FROM hfplayers;
--REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA pgcrypto FROM player;

--REVOKE CREATE ON SCHEMA public FROM PUBLIC;             -- From internet
--REVOKE ALL PRIVILEGES ON SCHEMA mon2k14 FROM PUBLIC;    -- 
--REVOKE ALL PRIVILEGES ON SCHEMA pgcrypto FROM PUBLIC;   -- 
--REVOKE ALL PRIVILEGES ON SCHEMA public FROM PUBLIC;     -- Why not...

-- Grant privileges
GRANT CONNECT ON DATABASE mon2k14 TO hfowner,hfadmins,hfplayers,hfscore,hfflagupdater;

--GRANT ALL PRIVILEGES ON SCHEMA mon2k14 TO hfowner;
--GRANT ALL PRIVILEGES ON SCHEMA pgcrypto TO hfowner;

GRANT USAGE ON SCHEMA mon2k14 TO hfadmins,hfplayers,hfscore,hfflagupdater;
GRANT USAGE ON SCHEMA pgcrypto TO hfadmins,hfplayers,hfscore;
GRANT USAGE ON SCHEMA tablefunc TO hfadmins,hfplayers,hfscore;

-- Grants for admins only
GRANT EXECUTE ON FUNCTION mon2k14.getGameStats() TO hfadmins;
GRANT EXECUTE ON FUNCTION mon2k14.addTeam(varchar,varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION mon2k14.modTeam(integer,varchar,varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION mon2k14.listTeams(integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION mon2k14.getScoreProgress(integer) TO hfadmins;

-- Grants for scoreboard
GRANT EXECUTE ON FUNCTION mon2k14.getCatProgressFromIp(varchar) TO hfscore;
--GRANT EXECUTE ON FUNCTION mon2k14.getFlagProgressFromIp(varchar) TO hfscore;
GRANT EXECUTE ON FUNCTION mon2k14.submitFlagFromIp(varchar,flag.value%TYPE) TO hfscore;
GRANT EXECUTE ON FUNCTION mon2k14.getTeamInfoFromIp(varchar) TO hfscore;

-- Grants for flagUpdater
GRANT EXECUTE ON FUNCTION mon2k14.getAllKingFlags() TO hfflagupdater;
GRANT EXECUTE ON FUNCTION mon2k14.getKingFlagsFromHost(varchar) TO hfflagupdater;
GRANT EXECUTE ON FUNCTION mon2k14.getKingFlagsFromName(varchar) TO hfflagupdater;
GRANT EXECUTE ON FUNCTION mon2k14.addRandomKingFlagFromId(integer,integer) TO hfflagupdater;

-- Grants for players only
GRANT EXECUTE ON FUNCTION mon2k14.submitFlag(flag.value%TYPE) TO hfplayers;
GRANT EXECUTE ON FUNCTION mon2k14.submitRandomFlag() TO hfplayers;  -- TEMPORARY
GRANT EXECUTE ON FUNCTION mon2k14.getCatProgress() TO hfplayers;
GRANT EXECUTE ON FUNCTION mon2k14.getFlagProgress() TO hfplayers;
GRANT EXECUTE ON FUNCTION mon2k14.getTeamInfo() TO hfplayers;

-- Grants for multiple groups
--GRANT EXECUTE ON FUNCTION pgcrypto.digest(text,text) TO hfowner,hfadmins,hfplayers;
GRANT EXECUTE ON FUNCTION mon2k14.getScore(integer,varchar) TO hfplayers,hfscore,hfadmins;
GRANT EXECUTE ON FUNCTION mon2k14.getValidNews() TO hfplayers,hfscore,hfadmins;

/*
    For other types, the default privileges granted to PUBLIC are as follows: 
        CONNECT 
        CREATE TEMP TABLE for databases; 
        EXECUTE privilege for functions; 
        USAGE privilege for languages. 
*/

