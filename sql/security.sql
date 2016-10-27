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
--REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA scoreboard FROM hfflagupdater;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA scoreboard FROM hfscore;

--REVOKE CREATE ON SCHEMA public FROM PUBLIC;             -- From internet
--REVOKE ALL PRIVILEGES ON SCHEMA scoreboard FROM PUBLIC;    -- 
--REVOKE ALL PRIVILEGES ON SCHEMA pgcrypto FROM PUBLIC;   -- 
--REVOKE ALL PRIVILEGES ON SCHEMA public FROM PUBLIC;     -- Why not...

-- Grant privileges
GRANT CONNECT ON DATABASE scoreboard TO owner,hfadmins,hfplayers,hfscore;

--GRANT ALL PRIVILEGES ON SCHEMA scoreboard TO owner;
--GRANT ALL PRIVILEGES ON SCHEMA pgcrypto TO owner;

GRANT USAGE ON SCHEMA scoreboard TO hfadmins,hfplayers,hfscore;
GRANT USAGE ON SCHEMA pgcrypto TO hfadmins,hfplayers,hfscore;
GRANT USAGE ON SCHEMA tablefunc TO hfadmins,hfplayers,hfscore;

-- Grants for admins only
GRANT EXECUTE ON FUNCTION scoreboard.getGameStats() TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.addTeam(integer,varchar,varchar,varchar,integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.modTeam(integer,varchar,varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.listTeams(varchar,integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.rewardTeam(integer,text,integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.addNews(text,varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.modNews(integer,text,varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getScoreProgress(integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getSubmitHistory(integer,integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.setSetting(text,text,varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getSettings() TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.startGame() TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getFlagsSubmitCount(varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getTeamProgress(team.id%TYPE) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getFlagProgress(flag.name%TYPE) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.checkFlag(varchar) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getFlagList(integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getEvents(timestamp,varchar,varchar,varchar,integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.launderMoneyFromTeamId(integer,numeric) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.listTeamSecrets(varchar,integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.addBMItem(varchar,varchar,integer,integer,numeric,integer,varchar,text,varchar,bytea,text) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getBMItemInfo(integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getBMItemList(integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.reviewBMItem(integer,boolean,integer,text) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getBMItemLink(integer) TO hfadmins;
--GRANT EXECUTE ON FUNCTION scoreboard.getLotoHistory(integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getTransactionHistory(integer) TO hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.addTeamLocation(varchar) TO hfadmins;

-- Grants for web
GRANT EXECUTE ON FUNCTION scoreboard.getCatProgress(integer) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.getCatProgressFromIp(varchar) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.getFlagProgress(integer) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.getFlagProgressFromIp(varchar) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.logSubmit(varchar,integer,flag.value%TYPE) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.submitFlagFromIp(varchar,flag.value%TYPE) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.getTeamInfoFromIp(varchar) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.getScoreProgress(integer) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.getBMItemDataFromIp(varchar,varchar) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.registerTeam(varchar,varchar,varchar,integer) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.loginTeam(varchar,varchar) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.getTeamInfo(integer) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.getTeamSecrets(integer) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.getTeamSecretsFromIp(varchar) TO hfscore;
GRANT EXECUTE ON FUNCTION scoreboard.submitFlag(varchar,integer,varchar) TO hfscore;

-- Grants for flagUpdater
--GRANT EXECUTE ON FUNCTION scoreboard.getAllKingFlags() TO hfflagupdater;
--GRANT EXECUTE ON FUNCTION scoreboard.getKingFlagsFromHost(varchar) TO hfflagupdater;
--GRANT EXECUTE ON FUNCTION scoreboard.getKingFlagsFromName(varchar) TO hfflagupdater;
--GRANT EXECUTE ON FUNCTION scoreboard.addRandomKingFlagFromId(integer,integer) TO hfflagupdater;

-- Grants for bmUpdater
--GRANT EXECUTE ON FUNCTION scoreboard.getBMItemListUpdater(integer) TO hfbmupdater;
--GRANT EXECUTE ON FUNCTION scoreboard.getBMItemData(integer) TO hfbmupdater;
--GRANT EXECUTE ON FUNCTION scoreboard.addEvent(text,varchar,varchar) TO hfbmupdater;
--GRANT EXECUTE ON FUNCTION scoreboard.setBMItemStatus(integer,integer) TO hfbmupdater;

-- Grants for lotoUpdater
--GRANT EXECUTE ON FUNCTION scoreboard.getLotoCurrentList(integer) TO hflotoupdater;
--GRANT EXECUTE ON FUNCTION scoreboard.processLotoWinner(integer) TO hflotoupdater;

-- Grants for rpi
--GRANT EXECUTE ON FUNCTION scoreboard.getModelCountDown() TO hfrpi;
--GRANT EXECUTE ON FUNCTION scoreboard.getModelNews(integer) TO hfrpi;
--GRANT EXECUTE ON FUNCTION scoreboard.getModelTeamsTop(integer) TO hfrpi;

-- Grants for players only
GRANT EXECUTE ON FUNCTION scoreboard.logSubmit(varchar,integer,flag.value%TYPE) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.submitFlagFromIp(varchar,flag.value%TYPE) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.buyBMItemFromIp(integer,varchar) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.sellBMItemFromIp(varchar,numeric,integer,text,bytea,varchar)TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.getBMItemInfoFromIp(integer,varchar) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.getBMItemDataFromIp(integer,varchar) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.getBMItemListFromIp(integer,varchar) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.getBMItemLinkFromIp(integer,varchar) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.getCatProgressFromIp(varchar) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.getFlagProgressFromIp(varchar) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.getTeamInfoFromIp(varchar) TO hfplayers;
GRANT EXECUTE ON FUNCTION scoreboard.getTeamSecretsFromIp(varchar) TO hfplayers;
--GRANT EXECUTE ON FUNCTION scoreboard.getEventsFromIp(timestamp,varchar,varchar,varchar,integer,varchar) TO hfplayers;
--GRANT EXECUTE ON FUNCTION scoreboard.buyLotoFromIp(varchar) TO hfplayers;
--GRANT EXECUTE ON FUNCTION scoreboard.getLotoCurrentList(integer) TO hfplayers;
--GRANT EXECUTE ON FUNCTION scoreboard.getLotoInfo() TO hfplayers;

-- Grants for multiple groups
GRANT EXECUTE ON FUNCTION scoreboard.getScore(integer,varchar,flagCategory.name%TYPE) TO hfplayers,hfscore,hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getNewsList() TO hfplayers,hfscore,hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getBMItemCategoryList() TO hfplayers,hfscore,hfadmins;
GRANT EXECUTE ON FUNCTION scoreboard.getBMItemStatusList() TO hfplayers,hfscore,hfadmins;

