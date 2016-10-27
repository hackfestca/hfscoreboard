/* 
    Stored Proc: logSubmit(playerip,flagValue)
*/ 
CREATE OR REPLACE FUNCTION logSubmit(_flagValue flag.value%TYPE,
                                     _teamId team.id%TYPE,
                                     _playerIpStr varchar(20))
RETURNS integer AS $$
    DECLARE
        _playerIp inet;
    BEGIN
        -- Logging
        raise notice 'logSubmit(%,%)',$1,$2;

        _playerIp := _playerIpStr::inet;

        -- Get team from userIp 
        if _teamId is Null then
            SELECT id INTO _teamId FROM team WHERE _playerIp << net ORDER BY id DESC LIMIT 1;
            if NOT FOUND then
                raise exception 'Team not found for %',_playerIp;
            end if;
        end if;

        -- Save attempt in submit_history table
        INSERT INTO submit_history(teamId,playerIp,value)
                VALUES(_teamId,_playerIp,_flagValue);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/* 
    Stored Proc: submitFlag(flagValue,teamId)
*/ 
CREATE OR REPLACE FUNCTION submitFlag(_flagValue flag.value%TYPE,
                                      _teamId team.id%TYPE,
                                      _playerIpStr varchar(20)) 
RETURNS text AS $$
    DECLARE
        _teamRec team%ROWTYPE;
        _flagRec RECORD;
        _rowCount smallint;
        _teamAttempts smallint;
        _flagSbtCt integer;
        _playerIp inet;
        _settings settings%ROWTYPE;
        _pts flag.pts%TYPE;
        _ret text := '';
        _retEvent text := '';
        _news text := '';
        _alreadySubmit team_flag.id%TYPE;
        ANTI_BF_INT interval := '20 second';
        ANTI_BF_LIMIT integer := 20;
        STATUS_CODE_OK integer := 1;
        FLAG_MAX_LENGTH integer := 64;
        FLAG_TYPE_STANDARD flagType.code%TYPE := 1;
        FLAG_TYPE_KING flagType.code%TYPE := 11;
    BEGIN
        -- Logging
        raise notice 'submitFlag(%,%,%)',$1,$2,$3;
    
        _playerIp := _playerIpStr::inet;

        -- Get settings
        SELECT * INTO _settings FROM settings ORDER BY ts DESC LIMIT 1;

        -- Check time. Players can submit only if game is started
        if _settings.gameStartTs > current_timestamp then
            PERFORM raise_p(format('Game is not started yet. Game will start at: %',_settings.gameStartTs));
        end if;

        -- Get team from teamId
        SELECT id,name,net INTO _teamRec FROM team where _teamId = id ORDER BY id DESC LIMIT 1;
        if NOT FOUND then
            PERFORM raise_p(format('Team "%" not found',_teamId));
        end if;

        -- Validate flag max length
        if length(_flagValue) > FLAG_MAX_LENGTH then
            PERFORM raise_p(format('Flag too long'));
        end if;

        --Remove because it was rollbacked for invalid flags.
        -- Save attempt in submit_history table
        --PERFORM logSubmit(_teamRec.id,_playerIp,_flagValue);
        --INSERT INTO submit_history(teamId,playerIp,value)
        --        VALUES(_teamRec.id,_playerIp,_flagValue);

        -- Anti-bruteforce
        SELECT count(*)
        INTO _rowCount
        FROM (
            SELECT teamId,ts
            FROM submit_history
            WHERE teamId = _teamRec.id 
                AND ts + ANTI_BF_INT > current_timestamp
            ) as hist;
        if _rowCount > ANTI_BF_LIMIT then
            PERFORM raise_p(format('Anti-Bruteforce: Limit reached! (% attempts per team every %)',ANTI_BF_LIMIT,ANTI_BF_INT::text));
        end if;

        -- Search for the flag in flag and kingFlag tables
        -- Flag statusCode must be equal 1
        -- tableId 1 = flag, category 2 = kingFlag
        SELECT * FROM (
            SELECT id,value,pts,cash,statusCode,type,news,1 AS tableId
            FROM flag 
            WHERE statusCode = STATUS_CODE_OK and value = _flagValue and type <> 11
              UNION ALL
            SELECT id,value,pts,0,NULL,NULL,NULL,2 AS tableId
            FROM kingFlag 
            WHERE value = _flagValue
        ) AS x INTO _flagRec;

        -- if the flag is found, determine if it is a flag or a kingFlag
        -- then assign the flag
        GET DIAGNOSTICS _rowCount = ROW_COUNT;
        if _rowCount = 1 then

            -- Validate already submitted
            SELECT id INTO _alreadySubmit FROM team_flag WHERE teamId = _teamRec.id and flagId = _flagRec.id;
            if FOUND then
                PERFORM raise_p('Flag already submitted.');
            end if;

            if _flagRec.tableId = 1 then
                -- If flag is standard or king, process now. Otherwise, manage in processNonStandardFlag() function.
                if _flagRec.type = FLAG_TYPE_STANDARD or _flagRec.type = FLAG_TYPE_KING then
                    _pts := _flagRec.pts;
                    --_ret := 'Congratulations. You received ' || _flagRec.pts::text || 'pts and ' || _flagRec.cash::text || '$ for this flag. ';
                    _ret := 'Congratulations. You received ' || _flagRec.pts::text || 'pts for this flag.';
                    _retEvent := _teamRec.name || ' received ' || _flagRec.pts::text || 'pts and ' || _flagRec.cash::text || '$ for this flag. ';

                    -- Give cash if flag contains cash
                    if _flagRec.cash is not NULL and _flagRec.cash <> 0 then
                        PERFORM transferCashFlag(_flagRec.id,_teamRec.id);
                    end if;
                else
                    SELECT *
                    FROM processNonStandardFlag(_flagRec.id,_teamRec.id,_playerIp)
                    INTO _pts,_ret;
                    _retEvent := _ret;
                end if;

                -- Get number of time it was submitted
                SELECT count(*) INTO _flagSbtCt 
                FROM team_flag 
                WHERE flagId = _flagRec.id;
                -- Add news if first submit.
                if _flagRec.news is not null and _flagRec.news != '' and _flagSbtCt = 0 then
                    _news := replace(_flagRec.news, '$team', _teamRec.name);
                    PERFORM addNews(_news, NULL);
                    -- replace(string text, from text, to text)
                end if;
                INSERT INTO team_flag(teamId,flagId,pts,playerIp)
                        VALUES(_teamRec.id,_flagRec.id,_pts,_playerIp);
            elsif _flagRec.tableId = 2 then
                INSERT INTO team_kingFlag(teamId,kingFlagId,playerIp)
                        VALUES(_teamRec.id,_flagRec.id,_playerIp);
                
                _ret := _ret || 'Congratulations. You received ' || _flagRec.pts::text || 'pts for this flag. ';
                _retEvent := _retEvent || _teamRec.name || ' received ' || _flagRec.pts::text || 'pts for this flag. ';
            end if;
        else
            PERFORM raise_p(format('Invalid flag'));
        end if;
 
        PERFORM addEvent(_retEvent,'flag');

        RETURN _ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
/* 
    Stored Proc: submitFlagFromIp(userIp,flagValue)
*/ 
CREATE OR REPLACE FUNCTION submitFlagFromIp(_flagValue flag.value%TYPE,
                                             _playerIpStr varchar(20)) 
RETURNS text AS $$
    DECLARE
        _teamId team.id%TYPE;
        _playerIp inet;
    BEGIN
        -- Logging
        raise notice 'submitFlagFromIp(%,%)',$1,$2;
    
        _playerIp := _playerIpStr::inet;

        -- Get team from teamId
        SELECT id INTO _teamId FROM team where _playerIp << net ORDER BY id DESC LIMIT 1;
        if NOT FOUND then
            PERFORM raise_p(format('Team not found for IP %',_playerIp));
        end if;

        RETURN submitFlag(_flagValue,_teamId,_playerIpStr);
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getScore(top = 30)
*/
CREATE OR REPLACE FUNCTION getScore(_top integer default 30,
                                    _timestamp varchar(30) default NULL,
                                    _category flagCategory.name%TYPE default NULL)
RETURNS TABLE (
                id team.id%TYPE,
                team team.name%TYPE,
                loc teamLocation.name%TYPE,
                cash text,
                flagTotal flag.pts%TYPE
              ) AS $$
    DECLARE
        _settings settings%ROWTYPE;
        _ts timestamp;
        -- _aCat flagCategory.id%TYPE[];    -- This doesn't work :(
        _aCat integer[];
        _rowCount integer;
    BEGIN
        -- Logging
        if _timestamp is NULL then          -- Tmp bypass because it logs too much
            raise notice 'getScore(%,%)',$1,$2;
        end if;
   
        -- Get settings
        SELECT * INTO _settings FROM settings ORDER BY ts DESC LIMIT 1;

        -- Check time. Players can submit only if game is started
        if _settings.gameStartTs > current_timestamp then
            PERFORM raise_p(format('Game is not started yet. Game will start at: %s',_settings.gameStartTs));
        end if;

        -- Some check 
        if _top <= 0 then
            PERFORM raise_p(format('_top argument cannot be a negative value. _top=%s',_top));
        end if;

        -- Prepare filters
        if _timestamp is NULL then
            _ts := current_timestamp;
        else
            _ts := _timestamp::timestamp;
        end if;

        if _category is NULL then
            SELECT array(select flagCategory.id from flagCategory) INTO _aCat;
        else
            SELECT array[flagCategory.id] INTO _aCat FROM flagCategory WHERE name = _category;
            GET DIAGNOSTICS _rowCount = ROW_COUNT;
            if _rowCount <> 1 then
                raise exception 'Category "%" not found',_category;
            end if;
        end if;

        return QUERY SELECT t.id AS id,
                            t.name AS team,
                            tl.name AS location,
                            w.amount::text || ' $' AS cash,
                            coalesce(tf3.sum::integer,0) AS flagPts
                         FROM team AS t
                         LEFT OUTER JOIN (
                            SELECT tl.id,
                                   tl.name
                            FROM teamLocation as tl
                         ) AS tl ON t.loc = tl.id
                         LEFT OUTER JOIN (
                            SELECT w.id,
                                   w.amount
                            FROM wallet as w
                         ) AS w ON t.wallet = w.id
                         LEFT OUTER JOIN (
                            SELECT tf2.teamId,
                                   sum(tf2.pts) AS sum
                            FROM (
                                SELECT tf.flagId,
                                       tf.teamId,
                                       tf.ts,
                                       tf.pts
                                FROM team_flag as tf
                                LEFT OUTER JOIN (
                                    SELECT flag.id,
                                           flag.category
                                    FROM flag
                                    ) as f ON tf.flagId = f.id
                                    WHERE f.category = ANY (_aCat)
                                ) AS tf2
                                WHERE tf2.ts <= _ts
                            GROUP BY tf2.teamId
                            ) AS tf3 ON t.id = tf3.teamId
                         LEFT OUTER JOIN (
                             SELECT tf4.teamId,
                                    max(tf4.id) as last_submit
                             FROM team_flag as tf4
                             GROUP BY tf4.teamId
                         ) AS tf4 ON t.id = tf4.teamId
                         WHERE t.hide = False
                         ORDER BY flagPts DESC, tf4.last_submit NULLS LAST
                         LIMIT _top;

--
-- King flags were removed for Hackfest 2015. To add king flags in getScore(), 
-- simply add these lines in the return table
--
--                            coalesce(tfi3.sum::integer,0) AS kingFlagPts,
--                            (coalesce(tf3.sum::integer,0) + coalesce(tfi3.sum::integer,0)) AS flagTotal,
--
-- Then add this to the query
--
--                         LEFT OUTER JOIN (
--                            SELECT tfi2.teamId,
--                                   sum(tfi2.pts) AS sum
--                            FROM (
--                                SELECT tfi.kingFlagId,
--                                       tfi.teamId,
--                                       tfi.ts,
--                                       fi.pts
--                                FROM team_kingFlag as tfi
--                                LEFT OUTER JOIN (
--                                    SELECT kf.id,
--                                           kf.flagId,
--                                           kf.pts
--                                    FROM kingFlag as kf
--                                    LEFT OUTER JOIN (
--                                        SELECT flag.id,
--                                               flag.category
--                                        FROM flag 
--                                        ) as ff ON kf.flagId = ff.id
--                                        WHERE ff.category = ANY (_aCat)
--                                    ) as fi ON tfi.kingFlagId = fi.id
--                                ) AS tfi2
--                                WHERE tfi2.ts <= _ts
--                            GROUP BY tfi2.teamId
--                            ) AS tfi3 ON t.id = tfi3.teamId

    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


/*
    Stored Proc: getCatProgress(teamId)
*/
CREATE OR REPLACE FUNCTION getCatProgress(_teamId team.id%TYPE) 
RETURNS TABLE (
                id flagCategory.id%TYPE,
                name flagCategory.name%TYPE,
                displayName flagCategory.displayName%TYPE,
                description flagCategory.description%TYPE,
                pts flag.pts%TYPE,
                total flag.pts%TYPE,
                hidden flagCategory.hidden%TYPE
              ) AS $$
    DECLARE
        _settings settings%ROWTYPE;

        KING_FLAG_TYPE integer := 11;
    BEGIN
        -- Logging
        raise notice 'getCatProgress(%)',$1;
    
        -- Get settings
        SELECT * INTO _settings FROM settings ORDER BY ts DESC LIMIT 1;

        -- Check time. Players can submit only if game is started
        if _settings.gameStartTs > current_timestamp then
            PERFORM raise_p(format('Game is not started yet. Game will start at: %',_settings.gameStartTs));
        end if;

        return QUERY SELECT c.id AS id,
                            c.name AS name,
                            c.displayName AS displayName,
                            c.description AS description,
                            coalesce(tf3.sum::integer,0) AS pts,
                            coalesce(tft3.sum::integer,0) AS total,
                            c.hidden as hidden
                     FROM flagCategory AS c
                     LEFT OUTER JOIN (
                        SELECT tf2.category,
                               sum(tf2.pts) AS sum
                        FROM (
                            SELECT tf.flagId,
                                   tf.teamId,
                                   f.category,
                                   tf.pts
                            FROM team_flag AS tf
                            LEFT OUTER JOIN (
                                SELECT f.id,
                                       f.category
                                FROM flag AS f
                                WHERE f.type <> KING_FLAG_TYPE 
                                ) as f ON tf.flagId = f.id
                            WHERE tf.teamId = _teamId
                            ) AS tf2
                        GROUP BY tf2.category
                        ) AS tf3 ON c.id = tf3.category
                     LEFT OUTER JOIN (
                         SELECT f2.category,
                                sum(f2.pts) AS sum
                         FROM flag AS f2
                         WHERE f2.type <> KING_FLAG_TYPE
                         GROUP BY f2.category
                        ) AS tft3 ON c.id = tft3.category
                     WHERE c.hidden = False
                     ORDER BY c.name;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getCatProgressFromIp(varchar)
*/
CREATE OR REPLACE FUNCTION getCatProgressFromIp(_playerIp varchar(20)) 
RETURNS TABLE (
                id flagCategory.id%TYPE,
                name flagCategory.name%TYPE,
                displayName flagCategory.displayName%TYPE,
                description flagCategory.description%TYPE,
                pts flag.pts%TYPE,
                total flag.pts%TYPE,
                hidden flagCategory.hidden%TYPE
              ) AS $$
    DECLARE
        _teamId team.id%TYPE;
        _iPlayerIp inet;
    BEGIN
        -- Logging
        raise notice 'getCatProgressFromIp(%)',$1;

        -- Get team ID from client address
        _iPlayerIp := _playerIp::inet;
        SELECT team.id INTO _teamId FROM team WHERE _iPlayerIp << net LIMIT 1;
        if NOT FOUND then
            PERFORM raise_p(format('Team not found for %.',_iPlayerIp));
        end if;

        RETURN QUERY SELECT * FROM getCatProgress(_teamId);
    
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getFlagProgress(teamId)
*/
CREATE OR REPLACE FUNCTION getFlagProgress(_teamId team.id%TYPE) 
RETURNS TABLE (
                id flag.id%TYPE,
                name flag.name%TYPE,
                description flag.description%TYPE,
                pts flag.pts%TYPE,
                flagPts flag.pts%TYPE,
                displayPts varchar(20),
                catId flagCategory.id%TYPE,
                catName flagCategory.name%TYPE,
                isDone boolean,
                author flagAuthor.nick%TYPE,
                displayInterval flag.displayInterval%TYPE
              ) AS $$
    DECLARE 
        _settings settings%ROWTYPE;
        KING_FLAG_TYPE flagType.code%TYPE := 11;
    BEGIN
        -- Logging
        raise notice 'getFlagProgress(%)',$1;

        -- Get settings
        SELECT * INTO _settings FROM settings ORDER BY ts DESC LIMIT 1;

        -- Check time. Players can submit only if game is started
        if _settings.gameStartTs > current_timestamp then
            PERFORM raise_p(format('Game is not started yet. Game will start at: %',_settings.gameStartTs));
        end if;
    
        return QUERY SELECT f.id AS id,
                            f.name AS name,
                            f.description AS description,
                            tf2.pts AS pts,
                            f.pts AS flagPts,
                            (f.pts || 'pts/' || f.cash || '$')::varchar AS displayPts,
                            f.category AS catId,
                            c.name AS catName,
                            tf2.teamId IS NOT NULL AS isDone,
                            a.nick as author,
                            f.displayInterval
                     FROM flag AS f
                     LEFT OUTER JOIN (
                        SELECT a.id, a.nick
                        FROM flagAuthor AS a
                        ) AS a ON f.author = a.id
                     LEFT OUTER JOIN (
                        SELECT c.id, c.name, c.hidden
                        FROM flagCategory AS c
                        ) AS c ON f.category = c.id
                     LEFT OUTER JOIN (
                         SELECT tf.flagId,
                                tf.teamId,
                                tf.pts
                         FROM team_flag AS tf
                         WHERE tf.teamId = _teamId
                         ) AS tf2 ON f.id = tf2.flagId
                    WHERE (f.displayInterval is NULL 
                            or _settings.gameStartTs + f.displayInterval < current_timestamp)
                          and f.type <> KING_FLAG_TYPE
                          and c.hidden = False
                    ORDER BY f.id;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getFlagProgressFromIp(varchar)
*/
CREATE OR REPLACE FUNCTION getFlagProgressFromIp(_playerIp varchar(20)) 
RETURNS TABLE (
                id flag.id%TYPE,
                name flag.name%TYPE,
                description flag.description%TYPE,
                pts flag.pts%TYPE,
                flagPts flag.pts%TYPE,
                displayPts varchar(20),
                catId flagCategory.id%TYPE,
                catName flagCategory.name%TYPE,
                isDone boolean,
                author flagAuthor.nick%TYPE,
                displayInterval flag.displayInterval%TYPE
              ) AS $$
    DECLARE 
        _teamId team.id%TYPE;
        _iPlayerIp inet;
    BEGIN
        -- Logging
        raise notice 'getFlagProgressFromIp(%)',$1;

        -- Get team ID from client address
        _iPlayerIp := _playerIp::inet;
        SELECT team.id INTO _teamId FROM team WHERE _iPlayerIp << net LIMIT 1;
        if NOT FOUND then
            PERFORM raise_p(format('Team not found for %.',_iPlayerIp));
        end if;

        return QUERY SELECT * from getFlagProgress(_teamId);
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getNewsList()
*/
CREATE OR REPLACE FUNCTION getNewsList() 
RETURNS TABLE (
                id news.id%TYPE,
                displayTs news.displayTs%TYPE,
                title news.title%TYPE
              ) AS $$
    DECLARE
        _settings settings%ROWTYPE;
    BEGIN
        -- Logging
        raise notice 'getNewsList()';

        -- Get settings
        SELECT * INTO _settings FROM settings ORDER BY ts DESC LIMIT 1;

        -- Check time. Players can submit only if game is started
        if _settings.gameStartTs > current_timestamp then
            PERFORM raise_p(format('Game is not started yet. Game will start at: %',_settings.gameStartTs));
        end if;

        RETURN QUERY SELECT news.id,
                            news.displayTs,
                            news.title
                     FROM news
                     WHERE news.displayTs < current_timestamp
                     ORDER BY news.id DESC;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getTeamInfo(teamId)
*/
CREATE OR REPLACE FUNCTION getTeamInfo(_teamId team.id%TYPE)
RETURNS TABLE (
                info varchar(50),
                value varchar(200)
              ) AS $$
    DECLARE
        _rowCount integer;
        _playerIp inet;
        _teamRec team%ROWTYPE;
        _activePlayerCt integer;
        _teamFlagSubmitCt integer;
        _playerNick player.nick%TYPE;
        _playerFlagSubmitCt integer;
        _teamScore flag.pts%TYPE;
        _teamMoney wallet.amount%TYPE;
    BEGIN
        -- Logging
        raise notice 'getTeamInfo(%)',$1;

        -- Get team informations
        SELECT id,name,net 
        INTO _teamRec 
        FROM team 
        WHERE _teamId = team.id
        LIMIT 1;
        GET DIAGNOSTICS _rowCount = ROW_COUNT;
        if _rowCount <> 1 then
            PERFORM raise_p(format('Team not found.'));
        end if;

        -- Get team score
        SELECT sum(sum) AS total
        INTO _teamScore
        FROM (
                SELECT sum(tf.pts) AS sum
                FROM (
                    SELECT flagId,
                           teamId,
                           pts
                    FROM team_flag
                    WHERE teamId = _teamRec.id
                    ) AS tf
                UNION
                SELECT sum(tfi2.pts) AS sum
                FROM (
                    SELECT tfi.kingFlagId,
                           tfi.teamId,
                           fi.pts
                    FROM team_kingFlag as tfi
                    LEFT OUTER JOIN (
                        SELECT kingFlag.id,
                               kingFlag.pts
                        FROM kingFlag
                        ) as fi ON tfi.kingFlagId = fi.id
                    ) AS tfi2
                    WHERE tfi2.teamId = _teamRec.id
                ) as score;

        -- Get team money
        SELECT w.amount
        INTO _teamMoney
        FROM team
        LEFT OUTER JOIN (
            SELECT id,
                   amount
            FROM wallet
        ) AS w ON team.wallet = w.id
        WHERE team.id = _teamRec.id;
        
        -- Return
        RETURN QUERY SELECT 'ID'::varchar, _teamRec.id::varchar
                     UNION ALL SELECT 'Name'::varchar, _teamRec.name
                     UNION ALL SELECT 'Player Nick'::varchar, _playerNick
                     UNION ALL SELECT 'Net'::varchar, _teamRec.net::varchar
                     UNION ALL SELECT 'Active Players'::varchar, 'Undefined'::varchar
                     UNION ALL SELECT 'Team Submit Attempts'::varchar, 'Undefined'::varchar
                     UNION ALL SELECT 'Player Submit Attempts'::varchar, 'Undefined'::varchar
                     UNION ALL SELECT 'Team score'::varchar, _teamScore::varchar
                     UNION ALL SELECT 'Team money'::varchar, _teamMoney::varchar;
                     --ORDER BY 1;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getTeamInfoFromIp()
*/
CREATE OR REPLACE FUNCTION getTeamInfoFromIp(_playerIpStr varchar(20))
RETURNS TABLE (
                info varchar(50),
                value varchar(200)
              ) AS $$
    DECLARE
        _rowCount integer;
        _playerIp inet;
        _teamRec team%ROWTYPE;
        _activePlayerCt integer;
        _teamFlagSubmitCt integer;
        _playerNick player.nick%TYPE;
        _playerFlagSubmitCt integer;
        _teamScore flag.pts%TYPE;
        _teamMoney wallet.amount%TYPE;
    BEGIN
        -- Logging
        raise notice 'getTeamInfoFromIp(%)',$1;

        _playerIp := _playerIpStr::inet;

        -- Get team informations
        SELECT id,name,net 
        INTO _teamRec 
        FROM team 
        WHERE _playerIp << team.net
        LIMIT 1;
        GET DIAGNOSTICS _rowCount = ROW_COUNT;
        if _rowCount <> 1 then
            PERFORM raise_p(format('Team not found.'));
        end if;

        -- Get active players count;
        PERFORM playerip
        FROM submit_history 
        WHERE playerip << _teamRec.net
        GROUP BY playerip;
        GET DIAGNOSTICS _activePlayerCt = ROW_COUNT;

        -- Get player submitted flag count
        SELECT count(*)
        INTO _teamFlagSubmitCt
        FROM submit_history 
        WHERE playerip << _teamRec.net;

        -- Get player nick
        SELECT nick
        INTO _playerNick
        FROM player
        WHERE ip = _playerIp;
        
        -- Get team submitted flag count
        SELECT count(*)
        INTO _playerFlagSubmitCt
        FROM submit_history 
        WHERE playerip = _playerIp;

        -- Get team score
        SELECT sum(sum) AS total
        INTO _teamScore
        FROM (
                SELECT sum(tf.pts) AS sum
                FROM (
                    SELECT flagId,
                           teamId,
                           pts
                    FROM team_flag
                    WHERE teamId = _teamRec.id
                    ) AS tf
                UNION
                SELECT sum(tfi2.pts) AS sum
                FROM (
                    SELECT tfi.kingFlagId,
                           tfi.teamId,
                           fi.pts
                    FROM team_kingFlag as tfi
                    LEFT OUTER JOIN (
                        SELECT kingFlag.id,
                               kingFlag.pts
                        FROM kingFlag
                        ) as fi ON tfi.kingFlagId = fi.id
                    ) AS tfi2
                    WHERE tfi2.teamId = _teamRec.id
                ) as score;

        -- Get team money
        SELECT w.amount
        INTO _teamMoney
        FROM team
        LEFT OUTER JOIN (
            SELECT id,
                   amount
            FROM wallet
        ) AS w ON team.wallet = w.id
        WHERE team.id = _teamRec.id;
        
        -- Return
        RETURN QUERY SELECT 'ID'::varchar, _teamRec.id::varchar
                     UNION ALL SELECT 'Name'::varchar, _teamRec.name
                     UNION ALL SELECT 'Player Nick'::varchar, _playerNick
                     UNION ALL SELECT 'Net'::varchar, _teamRec.net::varchar
                     UNION ALL SELECT 'Active Players'::varchar, _activePlayerCt::varchar
                     UNION ALL SELECT 'Team Submit Attempts'::varchar, _teamFlagSubmitCt::varchar
                     UNION ALL SELECT 'Player Submit Attempts'::varchar, _playerFlagSubmitCt::varchar
                     UNION ALL SELECT 'Team score'::varchar, _teamScore::varchar
                     UNION ALL SELECT 'Team money'::varchar, _teamMoney::varchar;
                     --ORDER BY 1;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getTeamSecretsFromIp(playerIp)
*/
CREATE OR REPLACE FUNCTION getTeamSecrets(_teamId team.id%TYPE) 
RETURNS TABLE (
                name teamSecrets.name%TYPE,
                value teamSecrets.value%TYPE
              ) AS $$
    BEGIN
        -- Logging
        raise notice 'getTeamSecrets(%)',$1;

        -- Get team's settings
        return QUERY SELECT ts.name,
                            ts.value
                     FROM teamSecrets AS ts
                     WHERE ts.teamId = _teamId;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getTeamSecretsFromIp(playerIp)
*/
CREATE OR REPLACE FUNCTION getTeamSecretsFromIp(_playerIpStr varchar) 
RETURNS TABLE (
                name teamSecrets.name%TYPE,
                value teamSecrets.value%TYPE
              ) AS $$
    DECLARE
        _playerIp inet;
        _teamId team.id%TYPE;
    BEGIN
        -- Logging
        raise notice 'getTeamSecretsFromIp(%)',$1;

        -- Convert player IP
        _playerIp := _playerIpStr::inet;

        -- Determine player's team
        SELECT id INTO _teamId FROM team where _playerIp << net LIMIT 1;
        if NOT FOUND then
            PERFORM raise_p(format('Team not found for %',_playerIp));
        end if;

        -- Get team's settings
        return QUERY SELECT * from getTeamSecrets(_teamId);
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: identifyPlayerFromIp(nick,playerIp)
*/
CREATE OR REPLACE FUNCTION identifyPlayerFromIp(_nick player.nick%TYPE,
                                                _playerIpStr varchar) 
RETURNS text AS $$
    DECLARE
        _playerIp inet;
        _teamId team.id%TYPE;
        _playerRec player%ROWTYPE;
        _ret text;
    BEGIN
        -- Logging
        raise notice 'identifyPlayerFromIp(%,%)',$1,$2;
    
        -- Convert player IP
        _playerIp := _playerIpStr::inet;

        -- Determine player's team
        SELECT id INTO _teamId FROM team where _playerIp << net LIMIT 1;
        if NOT FOUND then
            PERFORM raise_p(format('Team not found for %',_playerIp));
        end if;

        -- Determine if IP is already used
        SELECT id,teamId,nick,ip 
        INTO _playerRec
        FROM player
        WHERE _playerIp = ip
        LIMIT 1;

        -- if IP is already used, overwrite
        if FOUND then
            UPDATE player
            SET nick = _nick
            WHERE id = _playerRec.id;

            _ret := format('IP %s was already identified to %s. Updating to %s.',_playerIpStr,_playerRec.nick,_nick);
        else
        -- if not, insert new entry
            INSERT INTO player(teamId,nick,ip) VALUES(_teamId,_nick,_playerIp);
            _ret := format('IP %s was assigned to %s.',_playerIpStr,_nick);
        end if;

        RETURN _ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

