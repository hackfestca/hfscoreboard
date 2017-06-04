/*
    Stored Proc: addFlagStatus(name,description)
*/
CREATE OR REPLACE FUNCTION addFlagStatus(_code flagStatus.code%TYPE,
                                    _name flagStatus.name%TYPE, 
                                    _description text default ''
                                    ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addFlagStatus(%,%,%)',$1,$2,$3;

        -- Insert a new row
        INSERT INTO flagStatus(code,name,description)
                VALUES(_code,_name,_description);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addFlagCategory(name,description)
*/
CREATE OR REPLACE FUNCTION addFlagCategory(_name flagCategory.name%TYPE, 
                                       _displayName flagCategory.displayName%TYPE,
                                       _description text,
                                       _hidden flagCategory.hidden%TYPE default false
                                      ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addFlagCategory(%,%,%,%)',$1,$2,$3,$4;

        -- Insert a new row
        INSERT INTO flagCategory(name,displayName,description,hidden)
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
        if _displayTs is NULL then
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
        if _id is NULL or _id < 1 then
            raise exception 'ID cannot be NULL or lower than 1';
        end if;

        if _title is NULL or _title = '' then
            raise exception 'Title cannot be NULL';
        end if;

        if _displayTs is NULL then
            _displayTs := current_timestamp;        -- Kinda redundant...
        end if;

        -- Update
        UPDATE news 
        SET title=_title,displayTs=_displayTs::timestamp
        WHERE id=_id;
        IF not found THEN
            raise exception 'Could not find news with id %i', _id;
            RETURN 1;
        END IF;

        PERFORM addEvent(format('News "%s" was updated. title="%s",displayTs="%s".',_id,_title,_displayTs),'global');

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
    Stored Proc: addFlagType(code,name)
*/
CREATE OR REPLACE FUNCTION addFlagType(_code flagType.code%TYPE, 
                                   _name flagType.name%TYPE
                                   ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addFlagType(%,%)',$1,$2;

        -- Insert a new row
        INSERT INTO flagType(code,name)
                VALUES(_code,_name);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addFlagTypeExt(name,typeExt,ptsLimit,ptsStep,trapCmd,updateCmd)
*/
CREATE OR REPLACE FUNCTION addFlagTypeExt(_name flagTypeExt.name%TYPE,
                                          _type flagType.name%TYPE,
                                          _pts flagTypeExt.pts%TYPE DEFAULT NULL,
                                          _ptsLimit flagTypeExt.ptsLimit%TYPE DEFAULT NULL,
                                          _ptsStep flagTypeExt.ptsStep%TYPE DEFAULT NULL,
                                          _trapCmd flagTypeExt.trapCmd%TYPE DEFAULT NULL,
                                          _updateCmd flagTypeExt.updateCmd%TYPE DEFAULT NULL)
RETURNS integer AS $$
    DECLARE
        _i flag.pts%TYPE;
        _typeId flagType.id%TYPE;
        _typeCode flagType.code%TYPE;
        _flagId flag.id%TYPE;
        _flagName text;
        _flagDesc text;
        _flagIds flagTypeExt.flagIds%TYPE := NULL;
        FLAG_AUTHOR text := 'HF Crew';
        DISPLAY_INTERVAL varchar := '12 hours';
    BEGIN
        -- Logging
        raise notice 'addFlagTypeExt(%,%,%,%,%,%,%)',$1,$2,$3,$4,$5,$6,$7;

        -- Get category id from name
        SELECT id,code INTO _typeId,_typeCode FROM flagType WHERE name = _type;
        if not FOUND then
            raise exception 'Could not find flag type "%"',_type;
        end if;

        -- If bonus or group bonus, generate bonus flags
        if _typeCode = 13 then      -- Bonus
            FOR _i IN SELECT generate_series 
                FROM generate_series(_pts,1,_ptsStep)
            LOOP
                _flagName := _name || '_' || _i::text;
                _flagDesc := '';
                _flagId := addRandomFlag(_flagName, _i, NULL, 'scoreboard.hf', 'bonus', 1,
                                       DISPLAY_INTERVAL, 'Scoreboard', 'Bonus', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
                _flagIds := array_append(_flagIds,_flagId);
            END LOOP;
        elsif _typeCode = 22 then   -- Group Bonus
            FOR _i IN SELECT generate_series 
                FROM generate_series(_pts,1,_ptsStep)
            LOOP
                _flagName := _name || '_' || _i::text;
                _flagDesc := '';
                _flagId := addRandomFlag(_flagName, _i, NULL, 'scoreboard.hf', 'bonus', 1,
                                       DISPLAY_INTERVAL, 'Scoreboard', 'Bonus', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
                _flagIds := array_append(_flagIds,_flagId);
            END LOOP;
        elsif _typeCode = 32 then   -- Team Group Pokemon
            _flagName := _name || '_Pokemon';
            _flagDesc := '';
            _flagId := addRandomFlag(_flagName, _pts, NULL, 'scoreboard.hf', 'bonus', 1,
                                   DISPLAY_INTERVAL, 'Scoreboard', 'Bonus', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
            _flagIds := array_append(_flagIds,_flagId);
        end if;

        -- Insert a new row
        INSERT INTO flagTypeExt(name,typeId,pts,ptsLimit,ptsStep,trapCmd,updateCmd,flagIds)
                VALUES(_name,_typeId,_pts,_ptsLimit,_ptsStep,_trapCmd,_updateCmd,_flagIds);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addFlag(...)
*/
CREATE OR REPLACE FUNCTION addFlag(_name flag.name%TYPE, 
                                    _value flag.value%TYPE, 
                                    _pts flag.pts%TYPE,
                                    _cash flag.cash%TYPE,
                                    _host host.name%TYPE,
                                    _category flagCategory.name%TYPE,
                                    _statusCode flagStatus.code%TYPE,
                                    _displayInterval varchar(20),
                                    _author flagAuthor.nick%TYPE,
                                    _type flagType.name%TYPE,
                                    _typeExt flagTypeExt.name%TYPE,
                                    _arg1 flag.arg1%TYPE,
                                    _arg2 flag.arg2%TYPE,
                                    _arg3 flag.arg3%TYPE,
                                    _arg4 flag.arg4%TYPE,
                                    _description flag.description%TYPE,
                                    _news flag.news%TYPE
                                    ) 
RETURNS flag.id%TYPE AS $$
    DECLARE
        _hostId host.id%TYPE;
        _catId flagCategory.id%TYPE;
        _authorId flagAuthor.id%TYPE;
        _typeCode flagType.code%TYPE;
        _typeExtId flagTypeExt.id%TYPE;
        _display flag.displayInterval%TYPE;
    BEGIN
        -- Logging
        raise notice 'addFlag(%,%,%,%,%,%,%,%,%,%,%,%,%,%,%,%,%)',
                    $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17;    
    
        -- Get host id from name
        SELECT id INTO _hostId FROM host WHERE name = _host;
        if not FOUND then
            raise exception 'Could not find host "%"',_host;
        end if;

        -- Get category id from name
        SELECT id INTO _catId FROM flagCategory WHERE name = _category;
        if not FOUND then
            raise exception 'Could not find category "%"',_category;
        end if;

        -- Get author id from name
        if _author is not NULL then
            SELECT id INTO _authorId FROM flagAuthor WHERE nick = _author;
            if not FOUND then
                raise exception 'Could not find author "%"',_author;
            end if;
        else
            _authorId = _author;
        end if;

        -- Get type id from name
        SELECT code INTO _typeCode FROM flagType WHERE name = _type;
        if not FOUND then
            raise exception 'Could not find flag type "%"',_type;
        end if;

        -- Get type ext id from name
        if _typeExt is not NULL then
            SELECT id INTO _typeExtId FROM flagTypeExt WHERE name = _typeExt;
            if not FOUND then
                raise exception 'Could not find flag type extension "%"',_typeExt;
            end if;
        else
            _typeExtId = _typeExt;
        end if;

        -- Convert displayInterval
        if _displayInterval is not NULL then
            _display = _displayInterval::interval;
        else
            _display = _displayInterval;
        end if;

        -- Convert cash if NULL
        if _cash is NULL then
            _cash = 0;
        end if;

        -- Insert a new row
        INSERT INTO flag(name,value,pts,cash,host,category,statusCode,displayInterval,author,
                        type,typeExt,arg1,arg2,arg3,arg4,description,news)
                VALUES(_name,_value,_pts,_cash,_hostId,_catId,_statusCode,_display,_authorId,
                        _typeCode,_typeExtId,_arg1,_arg2,_arg3,_arg4,_description,_news);

        RETURN LASTVAL();
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addRandomFlag(...);
                _flagId := addRandomFlag(_flagName, 
                                        _i, 
                                        NULL, 
                                        'scoreboard.hf', 
                                        'bonus', 
                                        1,
                                       DISPLAY_INTERVAL, 
                                       'Scoreboard',        // author 
                                       'Bonus',             // type
                                       NULL, 
                                       NULL, 
                                       NULL, 
                                       NULL, 
                                       NULL, 
                                       NULL);
*/
CREATE OR REPLACE FUNCTION addRandomFlag(_name flag.name%TYPE, 
                                    _pts flag.pts%TYPE,
                                    _cash flag.cash%TYPE,
                                    _host host.name%TYPE,
                                    _category flagCategory.name%TYPE,
                                    _statusCode flagStatus.code%TYPE,
                                    _displayInterval varchar(20),
                                    _author flagAuthor.nick%TYPE,
                                    _type flagType.name%TYPE,
                                    _typeExt flagTypeExt.name%TYPE,
                                    _arg1 flag.arg1%TYPE,
                                    _arg2 flag.arg2%TYPE,
                                    _arg3 flag.arg3%TYPE,
                                    _arg4 flag.arg4%TYPE,
                                    _description flag.description%TYPE,
                                    _news flag.news%TYPE
                                    ) 
RETURNS flag.id%TYPE AS $$
    DECLARE
        _flagId flag.id%TYPE;
        _flagValue flag.value%TYPE;
    BEGIN
        -- Logging
        raise notice 'addRandomFlag(%,%,%,%,%,%,%,%,%,%,%,%,%,%,%,%)',
                    $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16;    

        -- Loop just to be sure that we get no collision with random_32()
        LOOP
            BEGIN
                -- Generate a king flag
                SELECT random_32() INTO _flagValue;

                -- addFlag
                SELECT addFlag(_name,_flagValue,_pts,_cash,_host,_category,_statusCode,
                                _displayInterval,_author,_type,_typeExt,_arg1,_arg2,
                                _arg3,_arg4,_description,_news)
                INTO _flagId;
                RETURN _flagId;
            EXCEPTION WHEN unique_violation THEN
                -- Do nothing, and loop to try the addKingFlag again.
                raise notice 'A collision occured';
            END;
        END LOOP;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: checkFlag(value)
*/
CREATE OR REPLACE FUNCTION checkFlag( _flagValue flag.value%TYPE) 
RETURNS text AS $$
    BEGIN
        -- Logging
        raise notice 'checkFlag(%)',$1;
    
        PERFORM id FROM flag WHERE value = _flagValue;
        if FOUND then
            return 'The flag is valid';
        else
            return 'The flag is not valid';
        end if;

    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


/*
    Stored Proc: getFlagList()
*/
CREATE OR REPLACE FUNCTION getFlagList(_top integer DEFAULT 30) 
RETURNS TABLE (
                id flag.id%TYPE,
                name flag.name%TYPE,
                pts flag.pts%TYPE,
                cash flag.cash%TYPE,
                category flagCategory.name%TYPE,
                status flagStatus.name%TYPE,
                type flagType.name%TYPE,
                typeExt flagTypeExt.name%TYPE,
                author flagAuthor.nick%TYPE,
                displayInterval flag.displayInterval%TYPE,
                description flag.description%TYPE
              ) AS $$

    BEGIN
        return QUERY SELECT f.id AS id,
                            f.name AS name,
                            f.pts AS pts,
                            f.cash AS cash,
                            c.name AS catName,
                            s.name AS statusName,
                            ft.name AS type,
                            fte.name AS typeExt,
                            a.nick as author,
                            f.displayInterval,
                            f.description AS description
                     FROM flag AS f
                     LEFT OUTER JOIN (
                        SELECT a.id, a.nick
                        FROM flagAuthor AS a
                        ) AS a ON f.author = a.id
                     LEFT OUTER JOIN (
                        SELECT c.id, c.name
                        FROM flagCategory AS c
                        ) AS c ON f.category = c.id
                     LEFT OUTER JOIN (
                        SELECT s.id, s.name
                        FROM flagStatus AS s
                        ) AS s ON f.statusCode = s.id
                     LEFT OUTER JOIN (
                        SELECT ft.code, ft.name
                        FROM flagType AS ft
                        ) AS ft ON f.type = ft.code
                     LEFT OUTER JOIN (
                        SELECT fte.id, fte.name
                        FROM flagTypeExt AS fte
                        ) AS fte ON f.typeExt = fte.id
                    ORDER BY f.id
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
    BEGIN
        -- Logging
        raise notice 'getFlagValueFromName(%)',$1;
    
        SELECT name,value INTO _flagRec FROM flag where name = _name LIMIT 1;
        if not FOUND then
            raise exception 'Could not find flag "%".',_name;
        end if;

        RETURN _flagRec.value;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: setSetting()
*/
CREATE OR REPLACE FUNCTION startGame() 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'startGame()';

        UPDATE settings SET gameStartTs = current_timestamp;

        PERFORM addEvent('Starting the game!','global');
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

        PERFORM addEvent('Changing a setting.','global');

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

        RETURN QUERY SELECT unnest(array['gameStartTs','gameEndTs','teamStartMoney'])::text AS "Key", 
                            unnest(array[gameStartTs::text,gameEndTs::text,teamStartMoney::text])::text as "Value" 
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
        MAX_HOST                integer := 2;
        MAX_CAT                 integer := 9;
        MAX_TYPE                integer := 9;
        CASH_START_AMOUNT       wallet.amount%TYPE := 1200;
        _teamId team.id%TYPE;
        _net team.net%TYPE;
    BEGIN
        -- Logging
        raise notice 'insertRandomData()';

        -- Insert random teams
        INSERT INTO team(name,net,wallet) 
        SELECT 'RTeam '||id,
                ('172.29.'||id||'.0/24')::inet,
                addWallet('RTeam '||id, 'Wallet of team '||id, CASH_START_AMOUNT)
        FROM generate_series(1,TEAM_COUNT) as id;

        -- Insert random flags 
        INSERT INTO flag(name,value,pts,cash,host,category,statusCode,type,description) 
        SELECT 'RFlag '||id,
                random_32(),
                random() * (MAX_PTS - 1) + 1,
                0,
                random() * (MAX_HOST - 1) + 1,
                random() * (MAX_CAT - 1) + 1,
                1,
                1,
                'Lorem ipsum dolor sit amet.' 
        FROM generate_series(1,FLAG_COUNT) as id;

        /*
        -- Insert random king flags
        INSERT INTO flag(name,value,pts,host,category,statusCode,description) 
        SELECT 'Flag '||id,
                random_32(),
                random() * (MAX_PTS - 1) + 1,
                random() * (MAX_HOST - 1) + 1,
                random() * (MAX_CAT - 1) + 1,
                1,
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis elementum sem non porttitor vestibulum.'
        FROM generate_series(FLAG_COUNT+1,FLAG_COUNT+1+FLAG_IS_KING_COUNT) as id;

        -- Insert random king flags
        INSERT INTO kingFlag(flagId,value,pts) 
        SELECT flag.id,
                random_32(),
                1           --random() * 9 + 1
        FROM flag,generate_series(1,KINGFLAG_PER_FLAG_COUNT)
        WHERE flag.type = 11;
        */

        -- Assign flags to team randomly
        FOR _teamId,_net IN SELECT id,net FROM team LOOP
            INSERT INTO team_flag(teamId,flagId,pts,playerIp,ts)
                SELECT _teamId,
                        flag.id,
                        flag.pts,
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

        /*
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
        */

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

/*
    Stored Proc: getSubmitHistory()
    _typeFilter: NULL=Flag+KingFlag, 1=Flag only, 2=KingFlag only
*/
CREATE OR REPLACE FUNCTION getSubmitHistory(_top integer DEFAULT 10, _typeFilter integer DEFAULT NULL)
RETURNS TABLE (
                ts timestamp,
                teamName team.name%TYPE,
                flagName flag.name%TYPE,
                flagPts flag.pts%TYPE,
                flagCat flagCategory.name%TYPE,
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
                                tf.pts AS FlagPts,
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
                                   name,
                                   category
                            FROM flag
                         ) AS f ON tf.flagId = f.id
                         LEFT OUTER JOIN (
                            SELECT id,
                                   name
                            FROM flagCategory
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
                            FROM flagCategory
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
        SELECT count(*) INTO _catCt FROM flagCategory;
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
                    tf.pts,
                    t.name as teamName
            FROM team_flag AS tf
            LEFT OUTER JOIN (
                SELECT id,name FROM flag
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
                            tf.ts IS NOT NULL,
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
                            tf.ts IS NOT NULL,
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
    Note: Max number of interval on scoreboard seems to be 15 so default here is 15.
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

        -- if less than 15 teams are registered, raise exception
        PERFORM id FROM team OFFSET _maxTeams LIMIT 1;
        if not FOUND then
            PERFORM raise_p(FORMAT('Dashboard will be printed when %s teams are registered.',_maxTeams));
        end if;
        
        if _intLimit is NULL then
            _intLimit := 21;        -- Kinda redundant...
        end if;

        if _intLimit < 1 then
            PERFORM raise_p(format('Interval Limit cannot be NULL or lower than 1'));
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
        if _minTs is NULL or _minTs = _maxTs then
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

