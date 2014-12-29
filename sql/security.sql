/*
    Set default schema
*/
SET search_path TO scoreboard;

/*
    Database security
*/
-- Drop privileges as much as possible
--REVOKE ALL PRIVILEGES ON DATABASE scoreboard FROM PUBLIC;    -- 
--REVOKE ALL PRIVILEGES ON SCHEMA scoreboard FROM PUBLIC;    -- 
--REVOKE ALL PRIVILEGES ON SCHEMA pgcrypto FROM PUBLIC;   -- 
--REVOKE ALL PRIVILEGES ON SCHEMA public FROM PUBLIC;     -- Why not...

REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA scoreboard FROM PUBLIC;
--REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA pgcrypto FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA scoreboard FROM hfadmins;
--REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA pgcrypto FROM hfadmins;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA scoreboard FROM hfplayers;
--REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA pgcrypto FROM hfplayers;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA scoreboard FROM hfflagupdater;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA scoreboard FROM hfscore;

--REVOKE CREATE ON SCHEMA public FROM PUBLIC;             -- From internet
--REVOKE ALL PRIVILEGES ON SCHEMA scoreboard FROM PUBLIC;    -- 
--REVOKE ALL PRIVILEGES ON SCHEMA pgcrypto FROM PUBLIC;   -- 
--REVOKE ALL PRIVILEGES ON SCHEMA public FROM PUBLIC;     -- Why not...

-- Grant privileges
GRANT CONNECT ON DATABASE scoreboard TO owner,hfadmins,hfplayers,hfscore,hfflagupdater;

--GRANT ALL PRIVILEGES ON SCHEMA scoreboard TO owner;
--GRANT ALL PRIVILEGES ON SCHEMA pgcrypto TO owner;

GRANT USAGE ON SCHEMA scoreboard TO hfadmins,hfplayers,hfscore,hfflagupdater;
GRANT USAGE ON SCHEMA pgcrypto TO hfadmins,hfplayers,hfscore;
GRANT USAGE ON SCHEMA tablefunc TO hfadmins,hfplayers,hfscore;

-- Grants for admins only
GRANT EXECUTE ON FUNCTION scoreboard.getGameStats() TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.addTeam(varchar,varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.modTeam(integer,varchar,varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.listTeams(integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.rewardTeam(integer,varchar,integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.addNews(varchar,varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.modNews(integer,varchar,varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getScoreProgress(integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getSubmitHistory(integer,integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.setSetting(text,text,varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getSettings() TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.startGame() TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getFlagsSubmitCount(varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getTeamProgress(team.id%TYPE) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getFlagProgress(flag.name%TYPE) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.listFlags(integer) TO hfadmins;

-- Grants for scoreboard
GRANT EXECUTE ON FUNCTION scoreboard.getCatProgressFromIp(varchar) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.getFlagProgressFromIp(varchar) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.logSubmit(varchar,flag.value%TYPE) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.submitFlagFromIp(varchar,flag.value%TYPE) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.getTeamInfoFromIp(varchar) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.getScoreProgress(integer) TO hfscore;

-- Grants for flagUpdater
GRANT EXECUTE ON FUNCTION scoreboard.getAllKingFlags() TO hfflagupdater;
GRANT EXECUTE ON FUNCTION scoreboard.getKingFlagsFromHost(varchar) TO hfflagupdater;
GRANT EXECUTE ON FUNCTION scoreboard.getKingFlagsFromName(varchar) TO hfflagupdater;
GRANT EXECUTE ON FUNCTION scoreboard.addRandomKingFlagFromId(integer,integer) TO hfflagupdater;

-- Grants for players only
GRANT EXECUTE ON FUNCTION scoreboard.logSubmit(varchar,flag.value%TYPE) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.submitFlagFromIp(varchar,flag.value%TYPE) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.getCatProgressFromIp(varchar) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.getFlagProgressFromIp(varchar) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.getTeamInfoFromIp(varchar) TO hfplayers;

-- Grants for multiple groups
GRANT EXECUTE ON FUNCTION scoreboard.getScore(integer,varchar,category.name%TYPE) TO hfplayers,hfscore,hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getNews() TO hfplayers,hfscore,hfadmins;
