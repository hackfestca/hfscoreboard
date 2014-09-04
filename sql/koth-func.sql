SELECT 'DROP FUNCTION ' || ns.nspname || '.' || proname 
       || '(' || oidvectortypes(proargtypes) || ');'
FROM pg_proc INNER JOIN pg_namespace ns ON (pg_proc.pronamespace = ns.oid)
WHERE ns.nspname = 'mon2k14'  order by proname;

/*
    sha256()
*/
CREATE OR REPLACE FUNCTION sha256(text) returns text AS $$
    SELECT encode(pgcrypto.digest($1, 'sha256'), 'hex')
$$ LANGUAGE SQL STRICT IMMUTABLE;

/*
    random_64()
*/
CREATE OR REPLACE FUNCTION random_64() returns text AS $$
    SELECT encode(pgcrypto.digest(to_char(random(),'9.999999999999999'), 'sha256'), 'hex')
$$ LANGUAGE SQL;

/*
    random_32()
*/
CREATE OR REPLACE FUNCTION random_32() returns text AS $$
    SELECT encode(pgcrypto.digest(to_char(random(),'9.999999999999999'), 'md5'), 'hex')
$$ LANGUAGE SQL;

/*
    Stored Proc: addTeam(name,net)
*/
CREATE OR REPLACE FUNCTION addTeam(_name team.name%TYPE,
                                   _net varchar(20)) 
RETURNS integer AS $$
    DECLARE
        _inet inet;
    BEGIN
        -- Logging
        raise notice 'addTeam(%,%)',$1,$2;

        _inet := _net::inet;

        -- Some checks
        if _name is null then
            raise exception 'Name cannot be null';
        end if;

        if family(_inet) <> 4 then
            raise exception 'Only IPv4 addresses are supported';
        end if;

        -- Insert a new row
        INSERT INTO team(name,net) VALUES(_name,_inet);
        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: modTeam(id,name,net)
*/
CREATE OR REPLACE FUNCTION modTeam(_id team.id%TYPE,
                                   _name team.name%TYPE,
                                   _net varchar(20)) 
RETURNS integer AS $$
    DECLARE
        _inet inet;
    BEGIN
        -- Logging
        raise notice 'modTeam(%,%)',$1,$2;

        _inet := _net::inet;

        -- Some checks
        if _id is null or _id < 1 then
            raise exception 'ID cannot be null or lower than 1';
        end if;

        if _name is null or _name = '' then
            raise exception 'Name cannot be null';
        end if;

        if family(_inet) <> 4 then
            raise exception 'Only IPv4 addresses are supported';
        end if;

        -- Insert a new row
        UPDATE team 
        SET name=_name,net=_inet
        WHERE id=_id;
        IF not found THEN
            raise exception 'Could not find team with id %i', _id;
            RETURN 1;
        END IF;

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: listTeam(top = 30)
*/
CREATE OR REPLACE FUNCTION listTeams(_top integer default 30) 
RETURNS TABLE (
                id team.id%TYPE,
                team team.name%TYPE,
                net varchar(20),
                flagPts flag.pts%TYPE,
                kingFlagPts kingFlag.pts%TYPE,
                flagTotal flag.pts%TYPE
              ) AS $$
    BEGIN
        -- Logging
        raise notice 'listTeam(%)',$1;
    
        if _top <= 0 then
            raise exception '_top argument cannot be a negative value. _top=%',_top;
        end if;
        return QUERY SELECT t.id AS id,
                            t.name AS team,
                            t.net::varchar AS net,
                            coalesce(tf3.sum::integer,0) AS flagPts,
                            coalesce(tfi3.sum::integer,0) AS kingFlagPts,
                            (coalesce(tf3.sum::integer,0) + coalesce(tfi3.sum::integer,0)) AS flagTotal 
                     FROM team AS t
                     LEFT OUTER JOIN (
                        SELECT tf2.teamId,
                               sum(tf2.pts) AS sum
                        FROM (
                            SELECT tf.flagId,
                                   tf.teamId,
                                   f.pts
                            FROM team_flag as tf
                            LEFT OUTER JOIN (
                                SELECT flag.id,
                                       flag.pts
                                FROM flag
                                ) as f ON tf.flagId = f.id
                            ) AS tf2
                        GROUP BY tf2.teamId
                        ) AS tf3 ON t.id = tf3.teamId
                     LEFT OUTER JOIN (
                        SELECT tfi2.teamId,
                               sum(tfi2.pts) AS sum
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
                        GROUP BY tfi2.teamId
                        ) AS tfi3 ON t.id = tfi3.teamId
                     ORDER BY t.id 
                     LIMIT _top;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addStatus(name,description)
*/
CREATE OR REPLACE FUNCTION addStatus(_code status.code%TYPE,
                                    _name status.name%TYPE, 
                                    _description text default ''
                                    ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addStatus(%,%,%)',$1,$2,$3;

        -- Insert a new row
        INSERT INTO status(code,name,description)
                VALUES(_code,_name,_description);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addCategory(name,description)
*/
CREATE OR REPLACE FUNCTION addCategory(_name category.name%TYPE, 
                                       _displayName category.displayName%TYPE,
                                       _description text default ''
                                      ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addCategory(%,%,%)',$1,$2,$3;

        -- Insert a new row
        INSERT INTO category(name,displayName,description)
                VALUES(_name,_displayName,_description);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addNews(title,displayTs)
*/
CREATE OR REPLACE FUNCTION addNews(_title news.title%TYPE, 
                                   _displayTs news.displayTs%TYPE default NOW()
                                   ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addNews(%,%)',$1,$2;

        -- Insert a new row
        INSERT INTO news(title,displayTs)
                VALUES(_title,_displayTs);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addNews(title,displayTs::varchar)
*/
CREATE OR REPLACE FUNCTION addNews(_title news.title%TYPE, 
                                   _displayTs varchar default NOW()::varchar
                                   ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addNews(%,%)',$1,$2;

        -- Insert a new row
        INSERT INTO news(title,displayTs)
                VALUES(_title,_displayTs::timestamp);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addHost(name,description)
*/
CREATE OR REPLACE FUNCTION addHost(_name host.name%TYPE, 
                                    _description text default ''
                                    ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addHost(%,%)',$1,$2;

        -- Insert a new row
        INSERT INTO host(name,description)
                VALUES(_name,_description);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addAuthor(name,nick)
*/
CREATE OR REPLACE FUNCTION addAuthor(_name flagAuthor.name%TYPE, 
                                   _nick flagAuthor.nick%TYPE
                                   ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addAuthor(%,%)',$1,$2;

        -- Insert a new row
        INSERT INTO flagAuthor(name,nick)
                VALUES(_name,_nick);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;


/*
    Stored Proc: addFlag(...)
*/
CREATE OR REPLACE FUNCTION addFlag(_name flag.name%TYPE, 
                                    _value flag.value%TYPE, 
                                    _pts flag.pts%TYPE,
                                    _host host.name%TYPE,
                                    _category category.name%TYPE,
                                    _statusCode status.code%TYPE default 1,
                                    _displayInterval varchar(20) default Null,
                                    _author flagAuthor.name%TYPE  default Null,
                                    _isKing flag.isKing%TYPE default false,
                                    _description flag.description%TYPE default '',
                                    _hint flag.hint%TYPE default '',
                                    _updateCmd flag.updateCmd%TYPE default '',
                                    _monitorCmd flag.monitorCmd%TYPE default ''
                                    ) 
RETURNS integer AS $$
    DECLARE
        _hostId host.id%TYPE;
        _catId category.id%TYPE;
        _authorId flagAuthor.id%TYPE;
        _display flag.displayInterval%TYPE;
    BEGIN
        -- Logging
        raise notice 'addFlag(%,%,%,%,%,%,%,%,%,%,%,%,%)',$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13;    
    
        -- Get host id from name
        SELECT id INTO _hostId FROM host WHERE name = _host;
        if not FOUND then
            raise exception 'Could not find host "%"',_host;
        end if;

        -- Get category id from name
        SELECT id INTO _catId FROM category WHERE name = _category;
        if not FOUND then
            raise exception 'Could not find category "%"',_category;
        end if;

        -- Get author id from name
        if _author != Null then
            SELECT id INTO _authorId FROM flagAuthor WHERE name = _author;
            if not FOUND then
                raise exception 'Could not find author "%"',_author;
            end if;
        else
            _authorId = _author;
        end if;

        -- Get author id from name
        if _displayInterval != Null then
            _display = _displayInterval::interval;
        else
            _display = _displayInterval;
        end if;
        
        -- Insert a new row
        INSERT INTO flag(name,value,pts,host,category,statusCode,displayInterval,author,
                        description,hint,isKing,updateCmd,monitorCmd)
                VALUES(_name,_value,_pts,_hostId,_catId,_statusCode,_display,_authorId,
                        _description,_hint,_isKing,_updateCmd,_monitorCmd);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addRandomFlag(...);
*/
CREATE OR REPLACE FUNCTION addRandomFlag(_name flag.name%TYPE, 
                                    _pts flag.pts%TYPE,
                                    _host host.name%TYPE,
                                    _category category.name%TYPE,
                                    _statusCode status.code%TYPE default 1,
                                    _displayInterval varchar(20) default Null,
                                    _author flagAuthor.name%TYPE  default Null,
                                    _isKing flag.isKing%TYPE default false,
                                    _description flag.description%TYPE default '',
                                    _hint flag.hint%TYPE default '',
                                    _updateCmd flag.updateCmd%TYPE default '',
                                    _monitorCmd flag.monitorCmd%TYPE default ''
                                    ) 
RETURNS flag.value%TYPE AS $$
    DECLARE
        _flagValue flag.value%TYPE;
    BEGIN
        -- Logging
        raise notice 'addRandomFlag(%,%,%,%,%,%,%,%,%,%,%,%)',1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12;    
    
        -- Generate a flag
        SELECT random_32() INTO _flagValue;

        -- addFlag
        PERFORM addFlag(_name,_flagValue,_pts,_host,_category,
                        _statusCode,_displayInterval,_author,_isKing,_description,
                        _hint,_updateCmd,_monitorCmd);
        
        -- Return the flag value
        RETURN _flagValue;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addKingFlagFromId(flagId,value,pts)
*/
CREATE OR REPLACE FUNCTION addKingFlagFromId( _flagId flag.id%TYPE, 
                                              _value flag.value%TYPE, 
                                              _pts flag.pts%TYPE 
                                            ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addKingFlagFromId(%,%,%)',1,$2,$3;
    
        INSERT INTO kingFlag(flagId,value,pts)
                VALUES(_flagId,_value,_pts);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addKingFlagFromName(flagName,value,pts)
*/
CREATE OR REPLACE FUNCTION addKingFlagFromName( _flagName flag.name%TYPE, 
                                                _value flag.value%TYPE, 
                                                _pts flag.pts%TYPE
                                               ) 
RETURNS integer AS $$
    DECLARE
        _flagId flag.id%TYPE := Null;
    BEGIN
        -- Logging
        raise notice 'addKingFlagFromName(%,%,%)',1,$2,$3;
    
        -- Get flag id from name
        SELECT id INTO _flagId FROM flag WHERE name = _flagName;

        -- Add the flag
        RETURN addKingFlagFromId(_flagId,_value,_pts);
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addRandomKingFlagFromId(flagId,pts)
*/
CREATE OR REPLACE FUNCTION addRandomKingFlagFromId( _flagId flag.id%TYPE, 
                                                    _pts flag.pts%TYPE
                                                  ) 
RETURNS kingFlag.value%TYPE AS $$
    DECLARE
        _flagValue flag.value%TYPE;
    BEGIN
        -- Logging
        raise notice 'addRandomKingFlagFromId(%,%)',$1,$2;
    
        -- Generate a king flag
        SELECT random_32() INTO _flagValue;

        -- Add king flag 
        PERFORM addKingFlagFromId(_flagId,_flagValue,_pts);
        
        -- Return flag
        RETURN _flagValue;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


/* 
    Stored Proc: submitFlagFromIp(userIp,flagValue)
*/ 
CREATE OR REPLACE FUNCTION submitFlagFromIp( _playerIpStr varchar(20), 
                                             _flagValue flag.value%TYPE
                                           ) 
RETURNS integer AS $$
    DECLARE
        _teamRec team%ROWTYPE;
        _flagRec RECORD;
        _rowCount smallint;
        _teamAttempts smallint;
        _playerIp inet;
        _settings settings%ROWTYPE;
        ANTI_BF_INT interval := '10 second';
        ANTI_BF_LIMIT integer := 4;
        STATUS_CODE_OK integer := 1;
    BEGIN
        -- Logging
        raise notice 'submitFlagFromIp(%,%)',$1,$2;
    
        _playerIp := _playerIpStr::inet;

        -- Get settings
        SELECT * INTO _settings FROM settings ORDER BY ts DESC LIMIT 1;

        -- Check time. Players can submit only if game is started
        if _settings.gameStartTs > current_timestamp then
            raise exception 'Game is not started yet. Game will start at: %',_settings.gameStartTs;
        end if;

        -- Get team from userIp 
        SELECT id,net INTO _teamRec FROM team where _playerIp << net;
        GET DIAGNOSTICS _rowCount = ROW_COUNT;
        if _rowCount <> 1 then
            raise exception 'Team not found for %. _rowCount=%',_playerIp,_rowCount;
        end if;

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
            raise exception 'Anti-Bruteforce: Limit reached! (% attempts every %)',ANTI_BF_LIMIT,ANTI_BF_INT::text;
        end if;

        -- Save attempt in submit_history table
        INSERT INTO submit_history(teamId,playerIp,value)
                VALUES(_teamRec.id,_playerIp,_flagValue);

        -- Search for the flag in flag and kingFlag tables
        -- Flag statusCode must be equal 1
        -- category 1 = flag, category 2 = kingFlag
        SELECT * FROM (
            SELECT id,value,pts,statusCode,1 AS category FROM flag WHERE statusCode = STATUS_CODE_OK and value = _flagValue
            UNION ALL
            SELECT id,value,pts,Null,2 AS category FROM kingFlag WHERE value = _flagValue
        ) AS x INTO _flagRec;

        -- if the flag is found, determine if it is a flag or a kingFlag
        GET DIAGNOSTICS _rowCount = ROW_COUNT;
        if _rowCount = 1 then
            if _flagRec.category = 1 then
                INSERT INTO team_flag(teamId,flagId)
                        VALUES(_teamRec.id, _flagRec.id);
            elsif _flagRec.category = 2 then
                INSERT INTO team_kingFlag(teamId,kingFlagId)
                        VALUES(_teamRec.id, _flagRec.id);
            end if;
            RETURN _flagRec.pts;
        else
            raise exception 'Invalid flag';
            RETURN 0;
        end if;

    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/* 
    Stored Proc: submitFlag(flagValue)
*/ 
CREATE OR REPLACE FUNCTION submitFlag(_flagValue flag.value%TYPE) 
RETURNS integer AS $$
    DECLARE
        _playerIp inet;
        _ret flag.pts%TYPE;
    BEGIN
        -- Logging
        raise notice 'submitFlag(%)',$1;
    
        _playerIp := inet_client_addr();
        SELECT submitFlagFromIp(_playerIp::varchar,_flagValue) INTO _ret;
        return _ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/* 
    Stored Proc: submitRandomFlag()
*/ 
CREATE OR REPLACE FUNCTION submitRandomFlag() 
RETURNS integer AS $$
    DECLARE
        _ret integer;
    BEGIN
        -- Logging
        raise notice 'submitRandomFlag()';
    
        SELECT submitFlag(getRandomFlag()) INTO _ret;
        return _ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getTeamScoreFromName(name)
*/

/*
    Stored Proc: getTeamScoreFromId(id)
*/

/*
    Stored Proc: getScore(top = 30)
*/
CREATE OR REPLACE FUNCTION getScore(_top integer default 30,
                                    _timestamp varchar(20) default Null)
RETURNS TABLE (
                id team.id%TYPE,
                team team.name%TYPE,
                flagPts flag.pts%TYPE,
                kingFlagPts kingFlag.pts%TYPE,
                flagTotal flag.pts%TYPE
              ) AS $$
    DECLARE
        _settings settings%ROWTYPE;
        _ts timestamp;
    BEGIN
        -- Logging
        raise notice 'getScore(%,%)',$1,$2;
   
        -- Get settings
        SELECT * INTO _settings FROM settings ORDER BY ts DESC LIMIT 1;

        -- Check time. Players can submit only if game is started
        if _settings.gameStartTs > current_timestamp then
            raise exception 'Game is not started yet. Game will start at: %',_settings.gameStartTs;
        end if;

        -- Some check 
        if _top <= 0 then
            raise exception '_top argument cannot be a negative value. _top=%',_top;
        end if;

        if _timestamp is Null then
            _ts := current_timestamp;
        else
            _ts := _timestamp::timestamp;
        end if;

        return QUERY SELECT t.id AS id,
                            t.name AS team,
                            coalesce(tf3.sum::integer,0) AS flagPts,
                            coalesce(tfi3.sum::integer,0) AS kingFlagPts,
                            (coalesce(tf3.sum::integer,0) + coalesce(tfi3.sum::integer,0)) AS flagTotal 
                     FROM team AS t
                     LEFT OUTER JOIN (
                        SELECT tf2.teamId,
                               sum(tf2.pts) AS sum
                        FROM (
                            SELECT tf.flagId,
                                   tf.teamId,
                                   tf.ts,
                                   f.pts
                            FROM team_flag as tf
                            LEFT OUTER JOIN (
                                SELECT flag.id,
                                       flag.pts
                                FROM flag
                                ) as f ON tf.flagId = f.id
                            ) AS tf2
                            WHERE tf2.ts <= _ts
                        GROUP BY tf2.teamId
                        ) AS tf3 ON t.id = tf3.teamId
                     LEFT OUTER JOIN (
                        SELECT tfi2.teamId,
                               sum(tfi2.pts) AS sum
                        FROM (
                            SELECT tfi.kingFlagId,
                                   tfi.teamId,
                                   tfi.ts,
                                   fi.pts
                            FROM team_kingFlag as tfi
                            LEFT OUTER JOIN (
                                SELECT kingFlag.id,
                                       kingFlag.pts
                                FROM kingFlag
                                ) as fi ON tfi.kingFlagId = fi.id
                            ) AS tfi2
                            WHERE tfi2.ts <= _ts
                        GROUP BY tfi2.teamId
                        ) AS tfi3 ON t.id = tfi3.teamId
                     ORDER BY flagTotal DESC
                     LIMIT _top;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/* 
    Stored Proc: getFlagValueFromName(name)
*/
CREATE OR REPLACE FUNCTION getFlagValueFromName(_name flag.name%TYPE) 
RETURNS flag.value%TYPE AS $$
    DECLARE
        _flagRec RECORD;
        _rowCount smallint;
    BEGIN
        -- Logging
        raise notice 'getFlagValueFromName(%)',$1;
    
        SELECT name,value INTO _flagRec FROM flag where name = _name LIMIT 1;
        --GET DIAGNOSTICS rowCount = ROW_COUNT;
        if not FOUND then
            raise exception 'Could not find flag "%".',_name;
        end if;

        RETURN _flagRec.value;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: getKingFlagValueFromFlagName(name)
*/

/* 
    Stored Proc: disableFlagFromName(name)
*/

/*
    Stored Proc: getCatProgressFromIp(varchar)
*/
CREATE OR REPLACE FUNCTION getCatProgressFromIp(_playerIp varchar(20)) 
RETURNS TABLE (
                id category.id%TYPE,
                name category.name%TYPE,
                displayName category.displayName%TYPE,
                description category.description%TYPE,
                pts flag.pts%TYPE,
                total flag.pts%TYPE
              ) AS $$
    DECLARE
        _teamId team.id%TYPE;
        _iPlayerIp inet;
        _settings settings%ROWTYPE;
    BEGIN
        -- Logging
        raise notice 'getCatProgressFromIp(%)',$1;

        -- Get settings
        SELECT * INTO _settings FROM settings ORDER BY ts DESC LIMIT 1;

        -- Check time. Players can submit only if game is started
        if _settings.gameStartTs > current_timestamp then
            raise exception 'Game is not started yet. Game will start at: %',_settings.gameStartTs;
        end if;

        -- Get team ID from client address
        _iPlayerIp := _playerIp::inet;
        SELECT team.id INTO _teamId FROM team WHERE _iPlayerIp << net LIMIT 1;
        if NOT FOUND then
            raise exception 'Team not found for %.',_iPlayerIp;
        end if;
    
        return QUERY SELECT c.id AS id,
                            c.name AS name,
                            c.displayName AS displayName,
                            c.description AS description,
                            coalesce(tf3.sum::integer,0) AS pts,
                            coalesce(tft3.sum::integer,0) AS total
                     FROM category AS c
                     LEFT OUTER JOIN (
                        SELECT tf2.category,
                               sum(tf2.pts) AS sum
                        FROM (
                            SELECT tf.flagId,
                                   tf.teamId,
                                   f.category,
                                   f.pts
                            FROM team_flag AS tf
                            LEFT OUTER JOIN (
                                SELECT f.id,
                                       f.category,
                                       f.pts
                                FROM flag AS f
                                ) as f ON tf.flagId = f.id
                            WHERE tf.teamId = _teamId
                            ) AS tf2
                        GROUP BY tf2.category
                        ) AS tf3 ON c.id = tf3.category
                     LEFT OUTER JOIN (
                         SELECT f2.category,
                                sum(f2.pts) AS sum
                         FROM flag AS f2
                         GROUP BY f2.category
                        ) AS tft3 ON c.id = tft3.category;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getCatProgress()
*/
CREATE OR REPLACE FUNCTION getCatProgress() 
RETURNS TABLE (
                id category.id%TYPE,
                name category.name%TYPE,
                displayName category.displayName%TYPE,
                description category.description%TYPE,
                pts flag.pts%TYPE,
                total flag.pts%TYPE 
              ) AS $$
    DECLARE
        _playerIp inet;
    BEGIN
        -- Logging
        raise notice 'getCatProgress()';
    
        -- Get team ID from client address
        _playerIp := inet_client_addr();
        return QUERY SELECT * FROM getCatProgressFromIp(_playerIp::varchar);
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
                catId category.id%TYPE,
                catName category.name%TYPE,
                isDone boolean,
                displayInterval flag.displayInterval%TYPE
              ) AS $$
    DECLARE 
        _teamId team.id%TYPE;
        _iPlayerIp inet;
        _settings settings%ROWTYPE;
    BEGIN
        -- Logging
        raise notice 'getFlagProgressFromIp(%)',$1;

        -- Get settings
        SELECT * INTO _settings FROM settings ORDER BY ts DESC LIMIT 1;

        -- Check time. Players can submit only if game is started
        if _settings.gameStartTs > current_timestamp then
            raise exception 'Game is not started yet. Game will start at: %',_settings.gameStartTs;
        end if;

        -- Get team ID from client address
        _iPlayerIp := _playerIp::inet;
        SELECT team.id INTO _teamId FROM team WHERE _iPlayerIp << net LIMIT 1;
        if NOT FOUND then
            raise exception 'Team not found for %.',_iPlayerIp;
        end if;

    
        return QUERY SELECT f.id AS id,
                            f.name AS name,
                            f.description AS description,
                            f.pts AS pts,
                            f.category AS catId,
                            c.name AS catName,
                            tf2.teamId IS NOT Null AS isDone,
                            f.displayInterval
                     FROM flag AS f
                     LEFT OUTER JOIN (
                        SELECT c.id, c.name
                        FROM category AS c
                        ) AS c ON f.category = c.id
                     LEFT OUTER JOIN (
                         SELECT tf.flagId,
                                tf.teamId
                         FROM team_flag AS tf
                         WHERE tf.teamId = _teamId
                         ) AS tf2 ON f.id = tf2.flagId
                    WHERE f.displayInterval is null 
                            or _settings.gameStartTs + f.displayInterval < current_timestamp;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getFlagProgress()
*/
CREATE OR REPLACE FUNCTION getFlagProgress() 
RETURNS TABLE (
                id flag.id%TYPE,
                name flag.name%TYPE,
                description flag.description%TYPE,
                pts flag.pts%TYPE,
                catId category.id%TYPE,
                catName category.name%TYPE,
                isDone boolean,
                displayInterval flag.displayInterval%TYPE
              ) AS $$
    DECLARE
        _playerIp inet;
    BEGIN
        -- Logging
        raise notice 'getFlagProgress()';
    
        _playerIp := inet_client_addr();
        return QUERY SELECT * FROM getFlagProgressFromIp(_playerIp::varchar);
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getAllKingFlags()
*/
CREATE OR REPLACE FUNCTION getAllKingFlags() 
RETURNS TABLE (
                id flag.id%TYPE,
                name flag.name%TYPE,
                host host.name%TYPE,
                updateCmd flag.updateCmd%TYPE,
                statusCode flag.statusCode%TYPE,
                isKing flag.isKing%TYPE
              ) AS $$
    BEGIN
        -- Logging
        raise notice 'getAllKingFlags()';
    
        return QUERY SELECT f.id,
                            f.name,
                            h.name AS host,
                            f.updateCmd,
                            f.statusCode,
                            f.isKing 
                     FROM flag AS f
                     LEFT OUTER JOIN (
                        SELECT host.id,
                               host.name
                        FROM host
                        ) AS h ON h.id = f.host
                     WHERE f.isKing = True;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getKingFlagsFromHost(varchar)
*/
CREATE OR REPLACE FUNCTION getKingFlagsFromHost(_host host.name%TYPE) 
RETURNS TABLE (
                id flag.id%TYPE,
                name flag.name%TYPE,
                host host.name%TYPE,
                updateCmd flag.updateCmd%TYPE,
                statusCode flag.statusCode%TYPE,
                isKing flag.isKing%TYPE
              ) AS $$
    BEGIN
        -- Logging
        raise notice 'getKingFlagsFromHost(%)',$1;
    
        return QUERY SELECT f.id,
                            f.name,
                            h.name AS host,
                            f.updateCmd,
                            f.statusCode,
                            f.isKing 
                     FROM flag AS f
                     LEFT OUTER JOIN (
                        SELECT host.id,
                               host.name
                        FROM host
                        ) AS h ON h.id = f.host
                     WHERE f.isKing = True and h.name = _host;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getKingFlagsFromName(varchar)
*/
CREATE OR REPLACE FUNCTION getKingFlagsFromName(_name flag.name%TYPE) 
RETURNS TABLE (
                id flag.id%TYPE,
                name flag.name%TYPE,
                host host.name%TYPE,
                updateCmd flag.updateCmd%TYPE,
                statusCode flag.statusCode%TYPE,
                isKing flag.isKing%TYPE
              ) AS $$
    BEGIN
        -- Logging
        raise notice 'getKingFlagsFromName(%)',$1;
    
        return QUERY SELECT f.id,
                            f.name,
                            h.name AS host,
                            f.updateCmd,
                            f.statusCode,
                            f.isKing 
                     FROM flag AS f
                     LEFT OUTER JOIN (
                        SELECT host.id,
                               host.name
                        FROM host
                        ) AS h ON h.id = f.host
                     WHERE f.isKing = True and f.name = _name;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getValidNews()
*/
CREATE OR REPLACE FUNCTION getValidNews() 
RETURNS TABLE (
                id news.id%TYPE,
                displayTs news.displayTs%TYPE,
                title news.title%TYPE
              ) AS $$
    DECLARE
        _settings settings%ROWTYPE;
    BEGIN
        -- Logging
        raise notice 'getValidNews()';

        -- Get settings
        SELECT * INTO _settings FROM settings ORDER BY ts DESC LIMIT 1;

        -- Check time. Players can submit only if game is started
        if _settings.gameStartTs > current_timestamp then
            raise exception 'Game is not started yet. Game will start at: %',_settings.gameStartTs;
        end if;

        RETURN QUERY SELECT news.id,
                            news.displayTs,
                            news.title
                     FROM news
                     WHERE news.displayTs < NOW();
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getTeamInfoFromIp()
*/
CREATE OR REPLACE FUNCTION getTeamInfoFromIp(_playerIpStr varchar(20))
RETURNS TABLE (
                info varchar(30),
                value varchar(100)
              ) AS $$
    DECLARE
        _rowCount integer;
        _playerIp inet;
        _teamRec team%ROWTYPE;
        _activePlayerCt integer;
        _teamFlagSubmitCt integer;
        _playerFlagSubmitCt integer;
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
            raise exception 'Team not found.';
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
        
        -- Get team submitted flag count
        SELECT count(*)
        INTO _playerFlagSubmitCt
        FROM submit_history 
        WHERE playerip = _playerIp;
        
        -- Return
        RETURN QUERY SELECT 'ID'::varchar, _teamRec.id::varchar
                     UNION ALL SELECT 'Name'::varchar, _teamRec.name
                     UNION ALL SELECT 'Net'::varchar, _teamRec.net::varchar
                     UNION ALL SELECT 'Active Players'::varchar, _activePlayerCt::varchar
                     UNION ALL SELECT 'Team Submit Attempts'::varchar, _teamFlagSubmitCt::varchar
                     UNION ALL SELECT 'Player Submit Attempts'::varchar, _playerFlagSubmitCt::varchar;
                     --ORDER BY 1;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: getTeamInfo()
*/
CREATE OR REPLACE FUNCTION getTeamInfo()
RETURNS TABLE (
                info varchar(20),
                value varchar(100)
              ) AS $$
    DECLARE
        _playerIp inet;
    BEGIN
        -- Logging
        raise notice 'getTeamInfo()';

        _playerIp := inet_client_addr();
        RETURN QUERY SELECT * FROM getTeamInfoFromIp(_playerIp::varchar);
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getGameStats()
*/
CREATE OR REPLACE FUNCTION getGameStats()
RETURNS TABLE (
                info varchar(30),
                value varchar(100)
              ) AS $$
    DECLARE
        _rowCt integer;
        _teamCt integer;
        _hostCt integer;
        _catCt integer;
        _flagCt integer;
        _kingFlagCt integer;
        _teamFlagCt integer;
        _teamKingFlagCt integer;
        _newsCt integer;
        _activePlayerCt integer;
        _flagSubmitCt integer;
        _flagSubmitCt1 integer;
        _flagSubmitCt5 integer;
        _flagSubmitCt15 integer;
        _flagSubmitCt60 integer;
        _firstFlag varchar(100);
        _firstKingFlag varchar(100);
        _gameStartTs timestamp;
    BEGIN
        -- Logging
        raise notice 'getGameStats()';

        -- Get tables informations
        SELECT count(*) INTO _teamCt FROM team;
        SELECT count(*) INTO _hostCt FROM host;
        SELECT count(*) INTO _catCt FROM category;
        SELECT count(*) INTO _flagCt FROM flag;
        SELECT count(*) INTO _kingFlagCt FROM kingFlag;
        SELECT count(*) INTO _teamFlagCt FROM team_flag;
        SELECT count(*) INTO _teamKingFlagCt FROM team_kingFlag;
        SELECT count(*) INTO _newsCt FROM news;

        -- Get active players count;
        PERFORM playerip FROM submit_history GROUP BY playerip;
        GET DIAGNOSTICS _activePlayerCt = ROW_COUNT;

        -- Get player submitted flag count
        SELECT count(*) INTO _flagSubmitCt FROM submit_history;

        -- Get submit attemps per minute (top style: 1, 5, 15)
        SELECT count(*) INTO _flagSubmitCt1 FROM submit_history 
        WHERE current_timestamp - '1 minute'::interval < ts;
        SELECT count(*)/5 INTO _flagSubmitCt5 FROM submit_history 
        WHERE current_timestamp - '5 minute'::interval < ts;
        SELECT count(*)/15 INTO _flagSubmitCt15 FROM submit_history 
        WHERE current_timestamp - '15 minute'::interval < ts;
        SELECT count(*)/60 INTO _flagSubmitCt60 FROM submit_history 
        WHERE current_timestamp - '60 minute'::interval < ts;

        -- Get successful flag submit per minute (top style: 1, 5, 15)
        
        -- Get first flag successfuly submitted
        SELECT t.teamName || ' entered "' || t.flagName || 
                '" for ' || t.pts || 'pts on ' || to_char(t.ts,'YYYY-MM-DD HH24:MM')
        INTO _firstFlag
        FROM (
            SELECT tf.teamId,
                    tf.flagId,
                    tf.ts,
                    f.name AS flagName,
                    f.pts,
                    t.name as teamName
            FROM team_flag AS tf
            LEFT OUTER JOIN (
                SELECT id,name,pts FROM flag
            ) AS f ON f.id = tf.flagId
            LEFT OUTER JOIN (
                SELECT id,name FROM team
            ) AS t ON t.id = tf.teamId
            ORDER BY tf.ts DESC
            LIMIT 1
        ) AS t;
        GET DIAGNOSTICS _rowCt = ROW_COUNT;
        if _rowCt <> 1 then
            _firstFlag := ''::varchar;
        end if;

        -- Get first king flag successfuly submitted
        SELECT t.teamName || ' entered "' || t.flagName || 
                '" for ' || t.pts || 'pts on ' || to_char(t.ts,'YYYY-MM-DD HH24:MM')
        INTO _firstKingFlag
        FROM (
            SELECT tf.teamId,
                    tf.ts,
                    f.name AS flagName,
                    f.pts,
                    t.name as teamName
            FROM team_kingFlag AS tf
            LEFT OUTER JOIN (
                SELECT kf.id,
                       kf.pts,
                       ff.name
                FROM kingFlag as kf
                LEFT OUTER JOIN (
                    SELECT id,name FROM flag
                ) AS ff ON ff.id = kf.flagId
            ) AS f ON f.id = tf.kingFlagId
            LEFT OUTER JOIN (
                SELECT id,name FROM team
            ) AS t ON t.id = tf.teamId
            ORDER BY tf.ts DESC
            LIMIT 1
        ) AS t;
        GET DIAGNOSTICS _rowCt = ROW_COUNT;
        if _rowCt <> 1 then
            _firstKingFlag := ''::varchar;
        end if;

        -- Get game start date&time
        SELECT gameStartTs into _gameStartTs FROM settings;

        -- Return
        RETURN QUERY SELECT 'Team count'::varchar, _teamCt::varchar
                     UNION ALL SELECT 'Host count'::varchar, _hostCt::varchar
                     UNION ALL SELECT 'Category count'::varchar, _catCt::varchar
                     UNION ALL SELECT 'Flag count'::varchar, _flagCt::varchar
                     UNION ALL SELECT 'King Flag count'::varchar, _kingFlagCt::varchar
                     UNION ALL SELECT 'Team Flags count'::varchar, _teamFlagCt::varchar
                     UNION ALL SELECT 'Team King Flag count'::varchar, _teamKingFlagCt::varchar
                     UNION ALL SELECT 'News count'::varchar, _newsCt::varchar
                     UNION ALL SELECT 'Active players'::varchar, _activePlayerCt::varchar
                     UNION ALL SELECT 'Submit Attempts'::varchar, _flagSubmitCt::varchar
                     UNION ALL SELECT 'Submit Attempt per min'::varchar, _flagSubmitCt1::varchar||', '||
                                                                      _flagSubmitCt5::varchar||', '||
                                                                      _flagSubmitCt15::varchar||', '||
                                                                      _flagSubmitCt60::varchar||
                                                                      ' (1min, 5min, 15min, 60min)'
                     UNION ALL SELECT 'First Flag'::varchar, _firstFlag::varchar
                     UNION ALL SELECT 'First King Flag'::varchar, _firstKingFlag::varchar
                     UNION ALL SELECT 'Game Start at:'::varchar, _gameStartTs::varchar;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getScoreProgress()
    Note: Max number of interval on scoreboard seems to be 21 so default here is 21.
*/
CREATE OR REPLACE FUNCTION getScoreProgress(_intLimit integer default 21)
RETURNS TABLE (
                ts timestamp,
                t0_score flag.pts%TYPE,
                t1_score flag.pts%TYPE,
                t2_score flag.pts%TYPE,
                t3_score flag.pts%TYPE,
                t4_score flag.pts%TYPE,
                t5_score flag.pts%TYPE,
                t6_score flag.pts%TYPE,
                t7_score flag.pts%TYPE,
                t8_score flag.pts%TYPE,
                t9_score flag.pts%TYPE
              ) AS $$
    DECLARE
        INTERVAL interval := '45 minute';
        MAX_TEAM_NUMBER integer := 200;
        _intervalTotal interval;
        _ts timestamp;
        _topTeams integer[10];
    BEGIN
        -- Logging
        raise notice 'getScoreProgress(%)',_intLimit;
        
        if _intLimit is null then
            _intLimit := 21;        -- Kinda redundant...
        end if;

        if _intLimit < 1 then
            raise exception 'Interval Limit cannot be null or lower than 1';
        end if;

        -- Determine the total range to select   
        _intervalTotal := _intLimit * INTERVAL;

        -- Generate a serie of all checkpoint
        -- http://www.postgresql.org/docs/9.1/static/functions-srf.html
        -- SELECT * FROM generate_series(current_timestamp-_intervalTotal,current_timestamp,INTERVAL);

        -- foreach timestamp: SELECT team,flagTotal FROM getScore(10,timestamp)

        -- Create temporary table for all this data
        CREATE TEMPORARY TABLE scoreProgress(
            ts timestamp,
            id integer,
            name varchar(50),
            total integer) ON COMMIT DROP;

        -- Get top 10 teams
        SELECT array(SELECT id FROM getScore(10) ORDER BY id LIMIT 10) INTO _topTeams; 

        -- For each checkpoint, append a score checkpoint to the temporary table
        FOR _ts IN SELECT generate_series AS time 
                   FROM generate_series(current_timestamp-_intervalTotal,current_timestamp,INTERVAL) 
        LOOP
            INSERT INTO scoreProgress(ts,id,name,total)
                   SELECT  _ts,
                           id,
                           team,
                           flagTotal
                   FROM getScore(MAX_TEAM_NUMBER,_ts::varchar) AS s
                   WHERE id = ANY(_topTeams);

        END LOOP;

        -- Return a crosstab of the temporary table 
        RETURN QUERY SELECT * FROM tablefunc.crosstab(
            'SELECT ts,name,total FROM scoreProgress ORDER BY ts'
                     ) as ct(
                        ts timestamp,
                        t0_score integer,
                        t1_score integer,
                        t2_score integer,
                        t3_score integer,
                        t4_score integer,
                        t5_score integer,
                        t6_score integer,
                        t7_score integer,
                        t8_score integer,
                        t9_score integer
                        );
                        
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: setSetting()
*/
CREATE OR REPLACE FUNCTION setSetting(_attr text, _value text, _type varchar(10) default 'text') 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'setSetting(%,%,%)',_attr,_value,_type;

        -- Safe update using format()
        -- TODO: See if %s is vulnerable to sqli
        EXECUTE format('UPDATE settings SET %I = %L::%s;',lower(_attr),_value,_type);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getSettings()
*/
CREATE OR REPLACE FUNCTION getSettings() 
RETURNS TABLE (
        key text,
        value text
    ) AS $$
    BEGIN
        -- Logging
        raise notice 'getSettings()';

        RETURN QUERY SELECT unnest(array['gameStartTs'])::text AS "Key", 
                            unnest(array[gameStartTs])::text as "Value" 
                     FROM settings;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getRandomFlag()
*/
CREATE OR REPLACE FUNCTION getRandomFlag() 
RETURNS flag.value%TYPE AS $$
    DECLARE
        _flagValue flag.value%TYPE;
        _offset integer;
    BEGIN
        -- Logging
        raise notice 'getRandomFlag()';

        _offset := floor(random()*(SELECT count(*) FROM flag));

        SELECT value 
        INTO _flagValue 
        FROM flag 
        OFFSET _offset
        LIMIT 1;
        if not FOUND then
            raise exception 'Could not find a random flag. Offset=%',_offset;
        end if;

        RETURN _flagValue;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: emptyTables()
*/
CREATE OR REPLACE FUNCTION emptyTables() 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'emptyTables()';

        TRUNCATE team,
                 status,
                 host,
                 category,
                 flagAuthor,
                 flag,
                 kingFlag,
                 team_flag,
                 team_kingFlag,
                 news,
                 submit_history,
                 status_history,
                 settings
            RESTART IDENTITY
            CASCADE;
        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: insertRandomData()
*/
CREATE OR REPLACE FUNCTION insertRandomData() 
RETURNS integer AS $$
    DECLARE
        TEAM_COUNT              integer := 30;
        FLAG_COUNT              integer := 100;
        FLAG_IS_KING_COUNT      integer := 100;
        KINGFLAG_PER_FLAG_COUNT integer := 10;
        FLAG_ASSIGN_LIMIT       integer := 100;
        FLAG_TS_MIN             integer := 960;
        KINGFLAG_ASSIGN_LIMIT   integer := 100;
        KINGFLAG_TS_MIN         integer := 960;
        PLAYER_IP_MIN           integer := 100;
        PLAYER_IP_MAX           integer := 200;
        SUBMIT_HIST_COUNT       integer := 1000;
        SUBMIT_HIST_TS_MIN      integer := 960;
        _teamId team.id%TYPE;
        _net team.net%TYPE;
    BEGIN
        -- Logging
        raise notice 'insertRandomData()';

        -- Insert random teams
        INSERT INTO team(name,net) 
        SELECT 'Team '||id,('172.29.'||id||'.0/32')::inet
        FROM generate_series(1,TEAM_COUNT) as id;

        -- Insert random flags where isKing = False
        INSERT INTO flag(name,value,pts,host,category,updateCmd,monitorCmd,statusCode,isKing,description,hint) 
        SELECT 'Flag '||id,
                random_32(),
                random() * 9 + 1,
                random() * 9 + 1,
                random() * 5 + 1,
                'echo $FLAG > /root/flag'||id||'.txt',
                'bla',
                1,
                False,
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis elementum sem non porttitor vestibulum.',
                ''
        FROM generate_series(1,FLAG_COUNT) as id;

        -- Insert random flags where isKing = True
        INSERT INTO flag(name,value,pts,host,category,updateCmd,monitorCmd,statusCode,isKing,description,hint) 
        SELECT 'Flag '||id,
                random_32(),
                random() * 9 + 1,
                random() * 9 + 1,
                random() * 5 + 1,
                'echo $FLAG > /root/flag'||id||'.txt',
                'bla',
                1,
                True,
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis elementum sem non porttitor vestibulum.',
                ''
        FROM generate_series(FLAG_COUNT+1,FLAG_COUNT+1+FLAG_IS_KING_COUNT) as id;

        -- Insert random king flags
        INSERT INTO kingFlag(flagId,value,pts) 
        SELECT flag.id,
                random_32(),
                random() * 9 + 1
        FROM flag,generate_series(1,KINGFLAG_PER_FLAG_COUNT)
        WHERE flag.isKing = True;

        -- Assign flags to team randomly
        FOR _teamId,_net IN SELECT id,net FROM team LOOP
            INSERT INTO team_flag(teamId,flagId,ts)
                SELECT _teamId,
                       flag.id,
                       current_timestamp - (random() * FLAG_TS_MIN || ' minutes')::interval
                FROM flag
                WHERE random() < 0.01 
                LIMIT FLAG_ASSIGN_LIMIT;
            INSERT INTO submit_history(teamId,playerIp,value,ts)
                SELECT  _teamId,
                        (_net + (random() * PLAYER_IP_MIN + PLAYER_IP_MAX)::integer),
                        f.value,
                       current_timestamp - (random() * SUBMIT_HIST_TS_MIN || ' minutes')::interval
                FROM team_flag AS tf
                LEFT OUTER JOIN (
                    SELECT id,value
                    FROM flag
                ) AS f ON tf.flagId = f.id
                WHERE teamId = _teamId;
        END LOOP;

        -- Assign king flags to teams randomly
        FOR _teamId IN SELECT id FROM team LOOP
            INSERT INTO team_kingFlag(teamId,kingFlagId,ts)
                SELECT _teamId,
                       kingFlag.id,
                       current_timestamp - (random() * KINGFLAG_TS_MIN || ' minutes')::interval
                FROM kingFlag
                WHERE random() < 0.01 
                LIMIT KINGFLAG_ASSIGN_LIMIT;
            INSERT INTO submit_history(teamId,playerIp,value,ts)
                SELECT  _teamId,
                        (_net + (random() * PLAYER_IP_MIN + PLAYER_IP_MAX)::integer),
                        f.value,
                       current_timestamp - (random() * SUBMIT_HIST_TS_MIN || ' minutes')::interval
                FROM team_kingFlag AS tkf
                LEFT OUTER JOIN (
                    SELECT id,value
                    FROM kingFlag
                ) AS f ON tkf.kingFlagId = f.id
                WHERE teamId = _teamId;
        END LOOP;

        -- Insert some fake flag submit in submit_history
        FOR _teamId,_net IN SELECT id,net FROM team LOOP
            INSERT INTO submit_history(teamId,playerIp,value,ts)
            SELECT  _teamId,
                (_net + (random() * PLAYER_IP_MIN + PLAYER_IP_MAX)::integer),
                random()::varchar,
                current_timestamp - (random() * SUBMIT_HIST_TS_MIN || ' minutes')::interval
            FROM generate_series(1,SUBMIT_HIST_COUNT) as id;
        END LOOP;

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

