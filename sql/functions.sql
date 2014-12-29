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
    sha256()
*/
CREATE OR REPLACE FUNCTION sha256(text) returns text AS $$
    SELECT encode(pgcrypto.digest($1, 'sha256'), 'hex');
$$ LANGUAGE SQL STRICT IMMUTABLE;

/*
    random_64()
*/
CREATE OR REPLACE FUNCTION random_64() returns text AS $$
    SELECT encode(pgcrypto.digest(random()::text, 'sha256'), 'hex');
    --SELECT encode(pgcrypto.digest(to_char(random(),'9.999999999999999'), 'sha256'), 'hex')
$$ LANGUAGE SQL;

/*
    random_32()
*/
CREATE OR REPLACE FUNCTION random_32() returns text AS $$
    SELECT encode(pgcrypto.digest(random()::text, 'md5'), 'hex');
    --SELECT encode(pgcrypto.digest(to_char(random(),'9.999999999999999'), 'md5'), 'hex')
$$ LANGUAGE SQL;

/*
    idx: Used in some ORDER BY
*/
CREATE OR REPLACE FUNCTION idx(anyarray, anyelement)
  RETURNS int AS 
$$
  SELECT i FROM (
     SELECT generate_series(array_lower($1,1),array_upper($1,1))
  ) g(i)
  WHERE $1[i] = $2
  LIMIT 1;
$$ LANGUAGE sql IMMUTABLE;

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
        raise notice 'modTeam(%,%,%)',$1,$2,$3;

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

        -- Update
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
    Stored Proc: rewardTeam(teamId,desc,pts)
*/
CREATE OR REPLACE FUNCTION rewardTeam(_teamId team.id%TYPE,
                                   _desc news.title%TYPE,
                                   _pts flag.pts%TYPE) 
RETURNS integer AS $$
    DECLARE
        _newsMsg news.title%TYPE;
        _teamNet team.net%TYPE;
        _teamName team.name%TYPE;
        _flagId flag.id%TYPE;
        _flagName flag.name%TYPE;
    BEGIN
        -- Logging
        raise notice 'rewardTeam(%,%,%)',$1,$2,$3;

        SELECT name,net INTO _teamName,_teamNet FROM team WHERE id = _teamId;
        if not FOUND then
            raise exception 'Could not find team "%"',_teamId;
        end if;

        -- Generate flag
        _flagName := 'Bug Bounty'||current_timestamp::varchar;
        PERFORM addRandomFlag(_flagName, _pts, 'scoreboard.hf', 'bug', 
                 1::smallint, Null, 'HF Crew', False, _desc);

        -- Assign flag
        SELECT id INTO _flagId FROM flag WHERE name = _flagName LIMIT 1;
        raise notice 'team net: %s',_teamNet+1;
        INSERT INTO team_flag(teamId,flagId,playerIp)
               VALUES(_teamId, _flagId,_teamNet+1);

        -- Create news
        _newsMsg := 'Thanks to '||_teamName||' for raising an issue to admins ('||_pts||' pts)';
        PERFORM addNews(_newsMsg,current_timestamp::timestamp);

        RETURN 0;
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
                                       _description text,
                                       _hidden category.hidden%TYPE default false
                                      ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addCategory(%,%,%,%)',$1,$2,$3,$4;

        -- Insert a new row
        INSERT INTO category(name,displayName,description,hidden)
                VALUES(_name,_displayName,_description,_hidden);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addNews(title,displayTs)
*/
CREATE OR REPLACE FUNCTION addNews(_title news.title%TYPE, 
                                   _displayTs news.displayTs%TYPE default current_timestamp
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
                                   _displayTs varchar default current_timestamp::varchar
                                   ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addNews(%,%)',$1,$2;

        -- Some validations
        if _displayTs is null then
            _displayTs := current_timestamp;        -- Kinda redundant...
        end if;

        -- Insert a new row
        INSERT INTO news(title,displayTs)
                VALUES(_title,_displayTs::timestamp);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: modNews(id,title,displayTs::varchar)
*/
CREATE OR REPLACE FUNCTION modNews(_id news.id%TYPE,
                                   _title news.title%TYPE, 
                                   _displayTs varchar default current_timestamp::varchar
                                   ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'modNews(%,%,%)',$1,$2,$3;

        -- Some validations
        if _id is null or _id < 1 then
            raise exception 'ID cannot be null or lower than 1';
        end if;

        if _title is null or _title = '' then
            raise exception 'Title cannot be null';
        end if;

        if _displayTs is null then
            _displayTs := current_timestamp;        -- Kinda redundant...
        end if;

        -- Update
        UPDATE news 
        SET title=_title,displayTs=_displayTs
        WHERE id=_id;
        IF not found THEN
            raise exception 'Could not find news with id %i', _id;
            RETURN 1;
        END IF;

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addHost(name,description)
*/
CREATE OR REPLACE FUNCTION addHost(_name host.name%TYPE, 
                                   _os host.os%TYPE,
                                    _description text default ''
                                    ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addHost(%,%,%)',$1,$2,$3;

        -- Insert a new row
        INSERT INTO host(name,os,description)
                VALUES(_name,_os,_description);

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
        if _author is not Null then
            SELECT id INTO _authorId FROM flagAuthor WHERE name = _author;
            if not FOUND then
                raise exception 'Could not find author "%"',_author;
            end if;
        else
            _authorId = _author;
        end if;

        -- Get author id from name
        if _displayInterval is not Null then
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

        -- Loop just to be sure that we get no collision with random_32()
        LOOP
            BEGIN
                -- Generate a king flag
                SELECT random_32() INTO _flagValue;

                -- addFlag
                PERFORM addFlag(_name,_flagValue,_pts,_host,_category,
                                _statusCode,_displayInterval,_author,_isKing,_description,
                                _hint,_updateCmd,_monitorCmd);

                RETURN _flagValue;
            EXCEPTION WHEN unique_violation THEN
                -- Do nothing, and loop to try the addKingFlag again.
                raise notice 'A collision occured';
            END;
        END LOOP;
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
   
        -- Loop just to be sure that we get no collision with random_32()
        LOOP
            BEGIN
                -- Generate a king flag
                SELECT random_32() INTO _flagValue;
        
                -- Add king flag 
                PERFORM addKingFlagFromId(_flagId,_flagValue,_pts);

                RETURN _flagValue;
            EXCEPTION WHEN unique_violation THEN
                -- Do nothing, and loop to try the addKingFlag again.
                raise notice 'A collision occured';
            END;
        END LOOP;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: listFlags()
*/
CREATE OR REPLACE FUNCTION listFlags(_top integer DEFAULT 30) 
RETURNS TABLE (
                id flag.id%TYPE,
                name flag.name%TYPE,
                pts flag.pts%TYPE,
                category category.name%TYPE,
                author flagAuthor.nick%TYPE,
                displayInterval flag.displayInterval%TYPE,
                description flag.description%TYPE
              ) AS $$

    BEGIN
        return QUERY SELECT f.id AS id,
                            f.name AS name,
                            f.pts AS pts,
                            c.name AS catName,
                            a.nick as author,
                            f.displayInterval,
                            f.description AS description
                     FROM flag AS f
                     LEFT OUTER JOIN (
                        SELECT a.id, a.nick
                        FROM flagAuthor AS a
                        ) AS a ON f.author = a.id
                     LEFT OUTER JOIN (
                        SELECT c.id, c.name, c.hidden
                        FROM category AS c
                        ) AS c ON f.category = c.id
                    ORDER BY f.id;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/* 
    Stored Proc: logSubmit(playerip,flagValue)
*/ 
CREATE OR REPLACE FUNCTION logSubmit( _playerIpStr varchar(20),
                                      _flagValue flag.value%TYPE)
RETURNS integer AS $$
    DECLARE
        _playerIp inet;
        _teamId team.id%TYPE;
    BEGIN
        -- Logging
        raise notice 'logSubmit(%,%)',$1,$2;

        _playerIp := _playerIpStr::inet;

        -- Get team from userIp 
        SELECT id INTO _teamId FROM team WHERE _playerIp << net ORDER BY id DESC LIMIT 1;
        if NOT FOUND then
            raise exception 'Team not found for %',_playerIp;
        end if;

        -- Save attempt in submit_history table
        INSERT INTO submit_history(teamId,playerIp,value)
                VALUES(_teamId,_playerIp,_flagValue);

        RETURN 0;
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
        ANTI_BF_INT interval := '20 second';
        ANTI_BF_LIMIT integer := 20;
        STATUS_CODE_OK integer := 1;
        FLAG_MAX_LENGTH integer := 64;
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
        SELECT id,net INTO _teamRec FROM team where _playerIp << net ORDER BY id DESC LIMIT 1;
        if NOT FOUND then
            raise exception 'Team not found for %',_playerIp;
        end if;

        -- Validate flag max length
        if length(_flagValue) > FLAG_MAX_LENGTH then
            raise exception 'Flag too long';
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
            raise exception 'Anti-Bruteforce: Limit reached! (% attempts per team every %)',ANTI_BF_LIMIT,ANTI_BF_INT::text;
        end if;

        -- Search for the flag in flag and kingFlag tables
        -- Flag statusCode must be equal 1
        -- category 1 = flag, category 2 = kingFlag
        SELECT * FROM (
            SELECT id,value,pts,statusCode,1 AS category FROM flag WHERE statusCode = STATUS_CODE_OK and value = _flagValue and isKing = False
            UNION ALL
            SELECT id,value,pts,Null,2 AS category FROM kingFlag WHERE value = _flagValue
        ) AS x INTO _flagRec;

        -- if the flag is found, determine if it is a flag or a kingFlag
        GET DIAGNOSTICS _rowCount = ROW_COUNT;
        if _rowCount = 1 then
            if _flagRec.category = 1 then
                INSERT INTO team_flag(teamId,flagId,playerIp)
                        VALUES(_teamRec.id, _flagRec.id,_playerIp);
            elsif _flagRec.category = 2 then
                INSERT INTO team_kingFlag(teamId,kingFlagId,playerIp)
                        VALUES(_teamRec.id, _flagRec.id,_playerIp);
            end if;
            RETURN _flagRec.pts;
        else
            raise exception 'Invalid flag';
            RETURN 0;
        end if;

    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getScore(top = 30)
*/
CREATE OR REPLACE FUNCTION getScore(_top integer default 30,
                                    _timestamp varchar(30) default Null,
                                    _category category.name%TYPE default Null)
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
        -- _aCat category.id%TYPE[];    -- This doesn't work :(
        _aCat integer[];
        _rowCount integer;
    BEGIN
        -- Logging
        if _timestamp is null then          -- Tmp bypass because it logs too much
            raise notice 'getScore(%,%)',$1,$2;
        end if;
   
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

        -- Prepare filters
        if _timestamp is Null then
            _ts := current_timestamp;
        else
            _ts := _timestamp::timestamp;
        end if;

        if _category is Null then
            SELECT array(select category.id from category) INTO _aCat;
        else
            SELECT array[category.id] INTO _aCat FROM category WHERE name = _category;
            GET DIAGNOSTICS _rowCount = ROW_COUNT;
            if _rowCount <> 1 then
                raise exception 'Category "%" not found',_category;
            end if;
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
                                           flag.pts,
                                           flag.category
                                    FROM flag
                                    ) as f ON tf.flagId = f.id
                                    WHERE f.category = ANY (_aCat)
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
                                    SELECT kf.id,
                                           kf.flagId,
                                           kf.pts
                                    FROM kingFlag as kf
                                    LEFT OUTER JOIN (
                                        SELECT flag.id,
                                               flag.category
                                        FROM flag 
                                        ) as ff ON kf.flagId = ff.id
                                        WHERE ff.category = ANY (_aCat)
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
                total flag.pts%TYPE,
                hidden category.hidden%TYPE
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
                            coalesce(tft3.sum::integer,0) AS total,
                            c.hidden as hidden
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
                                WHERE f.isKing = False
                                ) as f ON tf.flagId = f.id
                            WHERE tf.teamId = _teamId
                            ) AS tf2
                        GROUP BY tf2.category
                        ) AS tf3 ON c.id = tf3.category
                     LEFT OUTER JOIN (
                         SELECT f2.category,
                                sum(f2.pts) AS sum
                         FROM flag AS f2
                         WHERE f2.isKing = False
                         GROUP BY f2.category
                        ) AS tft3 ON c.id = tft3.category
                     WHERE c.hidden = False
                     ORDER BY c.name;
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
                author flagAuthor.nick%TYPE,
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
                            a.nick as author,
                            f.displayInterval
                     FROM flag AS f
                     LEFT OUTER JOIN (
                        SELECT a.id, a.nick
                        FROM flagAuthor AS a
                        ) AS a ON f.author = a.id
                     LEFT OUTER JOIN (
                        SELECT c.id, c.name, c.hidden
                        FROM category AS c
                        ) AS c ON f.category = c.id
                     LEFT OUTER JOIN (
                         SELECT tf.flagId,
                                tf.teamId
                         FROM team_flag AS tf
                         WHERE tf.teamId = _teamId
                         ) AS tf2 ON f.id = tf2.flagId
                    WHERE (f.displayInterval is null 
                            or _settings.gameStartTs + f.displayInterval < current_timestamp)
                          and f.isKing = False
                          and c.hidden = False
                    ORDER BY f.name;
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
    Stored Proc: getNews()
*/
CREATE OR REPLACE FUNCTION getNews() 
RETURNS TABLE (
                id news.id%TYPE,
                displayTs news.displayTs%TYPE,
                title news.title%TYPE
              ) AS $$
    DECLARE
        _settings settings%ROWTYPE;
    BEGIN
        -- Logging
        raise notice 'getNews()';

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
                     WHERE news.displayTs < current_timestamp
                     ORDER BY news.id DESC;
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
        _teamScore flag.pts%TYPE;
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

        -- Get team score
        SELECT sum(sum) AS total
        INTO _teamScore
        FROM (
                SELECT sum(tf2.pts) AS sum
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
                    WHERE tf2.teamId = _teamRec.id
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
        
        -- Return
        RETURN QUERY SELECT 'ID'::varchar, _teamRec.id::varchar
                     UNION ALL SELECT 'Name'::varchar, _teamRec.name
                     UNION ALL SELECT 'Net'::varchar, _teamRec.net::varchar
                     UNION ALL SELECT 'Active Players'::varchar, _activePlayerCt::varchar
                     UNION ALL SELECT 'Team Submit Attempts'::varchar, _teamFlagSubmitCt::varchar
                     UNION ALL SELECT 'Player Submit Attempts'::varchar, _playerFlagSubmitCt::varchar
                     UNION ALL SELECT 'Team score'::varchar, _teamScore::varchar;
                     --ORDER BY 1;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
    Stored Proc: getSubmitHistory()
    _typeFilter: Null=Flag+KingFlag, 1=Flag only, 2=KingFlag only
*/
CREATE OR REPLACE FUNCTION getSubmitHistory(_top integer DEFAULT 10, _typeFilter integer DEFAULT Null)
RETURNS TABLE (
                ts timestamp,
                teamName team.name%TYPE,
                flagName flag.name%TYPE,
                flagPts flag.pts%TYPE,
                flagCat category.name%TYPE,
                flagType integer
              ) AS $$
    BEGIN
        -- Logging
        raise notice 'getSubmitHistory(%,%)',$1,$2;

        RETURN QUERY SELECT r.timestamp,
                            r.TeamName,
                            r.FlagName,
                            r.FlagPts,
                            r.FlagCategory,
                            r.type
                     FROM (
                         SELECT tf.ts AS timestamp,
                                t.name AS TeamName,
                                f.name AS FlagName,
                                f.pts AS FlagPts,
                                c.name AS FlagCategory,
                                1 AS type
                         FROM team_flag as tf
                         LEFT OUTER JOIN (
                            SELECT id,
                                   name
                            FROM team
                         ) AS t ON tf.teamId = t.id
                         LEFT OUTER JOIN (
                            SELECT id,
                                   pts,
                                   name,
                                   category
                            FROM flag
                         ) AS f ON tf.flagId = f.id
                         LEFT OUTER JOIN (
                            SELECT id,
                                   name
                            FROM category
                         ) AS c ON f.category = c.id
                         UNION ALL
                         SELECT tkf.ts AS timestamp,
                                t2.name AS TeamName,
                                f2.name AS FlagName,
                                kf.pts AS FlagPts,
                                c2.name AS FlagCategory,
                                2 AS type
                         FROM team_kingFlag as tkf
                         LEFT OUTER JOIN (
                            SELECT id,
                                   name
                            FROM team
                         ) AS t2 ON tkf.teamId = t2.id
                         LEFT OUTER JOIN (
                            SELECT id,
                                   flagId,
                                   pts
                            FROM kingFlag
                         ) AS kf ON tkf.kingFlagId = kf.id
                         LEFT OUTER JOIN (
                             SELECT id,
                                    name,
                                    category
                             FROM flag
                         ) AS f2 ON kf.flagId = f2.id
                         LEFT OUTER JOIN (
                            SELECT id,
                                   name
                            FROM category
                         ) AS c2 ON f2.category = c2.id
                    ) AS r
                    ORDER BY r.timestamp DESC
                    LIMIT _top;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


/*
    Stored Proc: getFlagsSubmitCount()
*/
CREATE OR REPLACE FUNCTION getFlagsSubmitCount(_flagNameFilter flag.name%TYPE DEFAULT '%')
RETURNS TABLE (
                flagName flag.name%TYPE,
                submitCount bigint
              ) AS $$
    BEGIN
        -- Logging
        raise notice 'getFlagsSubmitCount(%)',$1;

        return QUERY SELECT ff.fname,count(ff.fname) 
                FROM (  SELECT flag.name as fname, 
                               team.name as tname 
                        FROM team_flag 
                        INNER JOIN flag ON flag.id = team_flag.flagId 
                                           AND team_flag.flagId IN (SELECT id 
                                                                    FROM flag 
                                                                    WHERE name like _flagNameFilter)
                        INNER JOIN team ON team.id = team_flag.teamid 
                        ORDER BY flag.name
                ) as ff GROUP BY ff.fname;
                
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
        _fnctCt integer;
        _tblCt integer;
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
            ORDER BY tf.ts 
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
            ORDER BY tf.ts 
            LIMIT 1
        ) AS t;
        GET DIAGNOSTICS _rowCt = ROW_COUNT;
        if _rowCt <> 1 then
            _firstKingFlag := ''::varchar;
        end if;

        -- Get game start date&time
        SELECT gameStartTs into _gameStartTs FROM settings;

        -- Get function count in scoreboard schema
        SELECT count(*) INTO _fnctCt
        FROM pg_proc 
        INNER JOIN pg_namespace ns ON (pg_proc.pronamespace = ns.oid) 
        WHERE ns.nspname = 'scoreboard';

        -- Get table count in scoreboard schema
        SELECT count(*) INTO _tblCt
        FROM pg_tables 
        WHERE schemaname = 'scoreboard';

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
                     UNION ALL SELECT 'Game Start at:'::varchar, _gameStartTs::varchar
                     UNION ALL SELECT 'Function count:'::varchar, _fnctCt::varchar
                     UNION ALL SELECT 'Table count:'::varchar, _tblCt::varchar;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getTeamProgress()
*/
CREATE OR REPLACE FUNCTION getTeamProgress(_teamId team.id%TYPE)
RETURNS TABLE (
                flagName flag.name%TYPE,
                isDone boolean,
                submitTs team_flag.ts%TYPE
              ) AS $$
    DECLARE
        _ret team.id%TYPE;
    BEGIN
        -- Logging
        raise notice 'getTeamProgress(%)',$1;

        SELECT id INTO _ret FROM team WHERE id = _teamId;
        IF not found THEN
            raise exception 'Could not find team with id %', _teamId;
        END IF;

        return QUERY SELECT name,
                            tf.ts IS NOT Null,
                            tf.ts 
                     FROM flag 
                     LEFT OUTER JOIN (
                        SELECT id,flagId,ts 
                        FROM team_flag 
                        WHERE teamId=_teamId
                     ) AS tf ON flag.id = tf.flagId 
                     ORDER BY tf.ts,name;
                
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getFlagProgress()
*/
CREATE OR REPLACE FUNCTION getFlagProgress(_flagName flag.name%TYPE)
RETURNS TABLE (
                teamName team.name%TYPE,
                isDone boolean,
                submitTime team_flag.ts%TYPE
              ) AS $$

    DECLARE
        _flagId flag.id%TYPE;
    BEGIN
        -- Logging
        raise notice 'getFlagProgress(%)',$1;

        -- Get id from name
        SELECT id INTO _flagId FROM flag WHERE name = _flagName LIMIT 1;
        if NOT FOUND then
            raise exception 'Could not find flag %', _flagName;
        end if;

        return QUERY SELECT name,
                            tf.ts IS NOT Null,
                            tf.ts 
                     FROM team 
                     LEFT OUTER JOIN (
                        SELECT id,teamId,ts 
                        FROM team_flag 
                        WHERE flagId = _flagId
                     ) AS tf ON team.id = tf.teamId
                     ORDER BY tf.ts,name;
                
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
                t9_score flag.pts%TYPE,
                t10_score flag.pts%TYPE,
                t11_score flag.pts%TYPE,
                t12_score flag.pts%TYPE,
                t13_score flag.pts%TYPE,
                t14_score flag.pts%TYPE
              ) AS $$
    DECLARE
        MAX_TEAM_NUMBER integer := 200;
        _ts timestamp;
        _minTs timestamp;
        _maxTs timestamp;
        _maxTeams integer := 15;
        _topTeams integer[15];
    BEGIN
        -- Logging
        raise notice 'getScoreProgress(%)',$1;
        
        if _intLimit is null then
            _intLimit := 21;        -- Kinda redundant...
        end if;

        if _intLimit < 1 then
            raise exception 'Interval Limit cannot be null or lower than 1';
        end if;

        -- Determine minimum timestamp
        SELECT x.ts INTO _minTs FROM (
            SELECT team_flag.ts as ts FROM team_flag 
            UNION ALL
            SELECT team_kingFlag.ts as ts FROM team_kingFlag 
        ) AS x ORDER BY ts LIMIT 1;

        -- Determine maximum timestamp
        SELECT x.ts INTO _maxTs FROM (
            SELECT team_flag.ts as ts FROM team_flag 
            UNION ALL
            SELECT team_kingFlag.ts as ts FROM team_kingFlag 
        ) AS x ORDER BY ts DESC LIMIT 1;

        -- if min = max, throw an exception
        if _minTs is null or _minTs = _maxTs then
            _minTs = current_timestamp - '1 minute'::interval;
            _maxTs = current_timestamp;           
        end if;

        -- Generate a serie of all checkpoint
        -- http://www.postgresql.org/docs/9.1/static/functions-srf.html

        -- foreach timestamp: SELECT team,flagTotal FROM getScore(15,timestamp)

        -- Create temporary table for all this data
        CREATE TEMPORARY TABLE scoreProgress(
            ts timestamp,
            id integer,
            name varchar(50),
            total integer) ON COMMIT DROP;

        -- Get top 15 teams
        SELECT array(SELECT id FROM getScore(_maxTeams) ORDER BY flagTotal DESC) INTO _topTeams; 

        -- Insert a blank line 
        INSERT INTO scoreProgress(ts,id,name,total)
               SELECT  (_minTs - '1 minute'::interval)::timestamp,
                       s.id,
                       s.team,
                       0 
               FROM getScore(MAX_TEAM_NUMBER) AS s
               WHERE s.id = ANY(_topTeams)
               ORDER BY idx(_topTeams, s.id);

        -- For each checkpoint, append a score checkpoint to the temporary table
        FOR _ts IN SELECT generate_series 
            FROM generate_series(_minTs,_maxTs,(_maxTs-_minTs)::interval / _intLimit) 
        LOOP
            INSERT INTO scoreProgress(ts,id,name,total)
                   SELECT  _ts,
                           s.id,
                           s.team,
                           s.flagTotal
                   FROM getScore(MAX_TEAM_NUMBER,_ts::varchar) AS s
                   WHERE s.id = ANY(_topTeams)
                   ORDER BY idx(_topTeams, s.id);
        END LOOP;

        -- Insert current score
        INSERT INTO scoreProgress(ts,id,name,total)
               SELECT  _maxTs,
                       s.id,
                       s.team,
                       s.flagTotal 
               FROM getScore(MAX_TEAM_NUMBER,_maxTs::varchar) AS s
               WHERE s.id = ANY(_topTeams)
               ORDER BY idx(_topTeams, s.id);
        
        -- Return a crosstab of the temporary table 
        RETURN QUERY SELECT * FROM tablefunc.crosstab(
            'SELECT ts,name,total FROM scoreProgress ORDER BY ts',
            'SELECT name FROM team WHERE id = ANY(array[' || array_to_string(_topTeams,',') ||']) ORDER BY scoreboard.idx(array['||array_to_string(_topTeams,',')||'],id)'
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
                        t9_score integer,
                        t10_score integer,
                        t11_score integer,
                        t12_score integer,
                        t13_score integer,
                        t14_score integer
                        );
                        
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: setSetting()
*/
CREATE OR REPLACE FUNCTION startGame() 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'startGame()';

        UPDATE settings SET gameStartTs = current_timestamp;
        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: setSetting()
*/
CREATE OR REPLACE FUNCTION setSetting(_attr text, _value text, _type varchar(10) default 'text') 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'setSetting(%,%,%)',$1,$2,$3;

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
    Stored Proc: insertRandomData()
*/
CREATE OR REPLACE FUNCTION insertRandomData() 
RETURNS integer AS $$
    DECLARE
        TEAM_COUNT              integer := 50;
        FLAG_COUNT              integer := 1000;
        FLAG_IS_KING_COUNT      integer := 1000;
        KINGFLAG_PER_FLAG_COUNT integer := 3;
        FLAG_ASSIGN_LIMIT       integer := 500;
        FLAG_TS_MIN             integer := 960;
        KINGFLAG_ASSIGN_LIMIT   integer := 500;
        KINGFLAG_TS_MIN         integer := 960;
        PLAYER_IP_MIN           integer := 100;
        PLAYER_IP_MAX           integer := 200;
        SUBMIT_HIST_COUNT       integer := 1000;
        SUBMIT_HIST_TS_MIN      integer := 960;
        FLAG_SUBMIT_RATE        real := 0.11;
        KINGFLAG_SUBMIT_RATE    real := 0.11;
        MAX_PTS                 integer := 10;
        MAX_HOST                integer := 7;
        MAX_CAT                 integer := 9;
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
                random() * (MAX_PTS - 1) + 1,
                random() * (MAX_HOST - 1) + 1,
                random() * (MAX_CAT - 1) + 1,
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
                random() * (MAX_PTS - 1) + 1,
                random() * (MAX_HOST - 1) + 1,
                random() * (MAX_CAT - 1) + 1,
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
                1           --random() * 9 + 1
        FROM flag,generate_series(1,KINGFLAG_PER_FLAG_COUNT)
        WHERE flag.isKing = True;

        -- Assign flags to team randomly
        FOR _teamId,_net IN SELECT id,net FROM team LOOP
            INSERT INTO team_flag(teamId,flagId,playerIp,ts)
                SELECT _teamId,
                       flag.id,
                        (_net + (random() * PLAYER_IP_MIN + PLAYER_IP_MAX)::integer),
                       current_timestamp - (random() * FLAG_TS_MIN || ' minutes')::interval
                FROM flag
                WHERE random() < FLAG_SUBMIT_RATE
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
            INSERT INTO team_kingFlag(teamId,kingFlagId,playerIp,ts)
                SELECT _teamId,
                       kingFlag.id,
                       (_net + (random() * PLAYER_IP_MIN + PLAYER_IP_MAX)::integer),
                       current_timestamp - (random() * KINGFLAG_TS_MIN || ' minutes')::interval
                FROM kingFlag
                WHERE random() < KINGFLAG_SUBMIT_RATE 
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
