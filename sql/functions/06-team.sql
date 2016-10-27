/*
    Stored Proc: addTeamLocation(name)
*/
CREATE OR REPLACE FUNCTION addTeamLocation(_name teamLocation.name%TYPE)
RETURNS teamLocation.id%TYPE AS $$
    BEGIN
        -- Logging
        raise notice 'addTeamLocation(%)',$1;

        -- Some checks
        if _name is NULL then
            raise exception 'Name cannot be NULL';
        end if;

        -- Insert a new row
        INSERT INTO teamLocation(name) VALUES(_name);

        RETURN LASTVAL();
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addTeam(name,net,pwd,loc)
*/
CREATE OR REPLACE FUNCTION addTeam(_num team.num%TYPE,
                                   _name team.name%TYPE,
                                   _net varchar(20) DEFAULT Null,
                                   _pwd team.pwd%TYPE DEFAULT Null,
                                   _loc team.loc%TYPE DEFAULT Null) 
RETURNS team.id%TYPE AS $$
    DECLARE
        _teamId team.id%TYPE;
        _inet inet;
        _walletId wallet.id%TYPE;
        _teamStartMoney settings.teamStartMoney%TYPE;
    BEGIN
        -- Logging
        raise notice 'addTeam(%,%,%,pwd,%)',$1,$2,$3,$5;

        _inet := _net::inet;

        -- Some checks
        if _name is NULL OR _name = '' then
            PERFORM raise_p('Name cannot be NULL');
        end if;
        if family(_inet) <> 4 then
            raise exception 'Only IPv4 addresses are supported';
        end if;

        -- Get team starting money
        SELECT teamStartMoney into _teamStartMoney FROM settings ORDER BY ts DESC LIMIT 1;

        -- Create wallet
        _walletId := addWallet(_name,'Wallet of team: '||_name,_teamStartMoney);

        -- Insert a new row
        INSERT INTO team(num,name,net,pwd,loc,wallet) 
        VALUES(_num,_name,_inet,sha256(_pwd),_loc,_walletId);

        _teamId := LASTVAL();

        RETURN _teamId;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: registerTeam(name,pwd1,pwd2,loc)
*/
CREATE OR REPLACE FUNCTION registerTeam(_name team.name%TYPE,
                                    _pwd1 team.pwd%TYPE,
                                    _pwd2 team.pwd%TYPE,
                                    _loc team.loc%TYPE)
RETURNS team.id%TYPE AS $$
    DECLARE
        NAME_MAX_LENGTH integer := 40;     -- TODO: Get length from table.
    BEGIN
        -- Logging
        raise notice 'registerTeam(%,pwd,%)',$1,$2;

        -- Some validations
        if length(_name) > NAME_MAX_LENGTH then
            PERFORM raise_p(format('Name cannot be longer than %',NAME_MAX_LENGTH));
        end if;
        if _pwd1 = '' OR _pwd2 = '' then
            PERFORM raise_p('Please fill both password fields.');
        end if;
        if _pwd1 <> _pwd2 then
            PERFORM raise_p('Both password must be identical.');
        end if;
        PERFORM id FROM teamLocation WHERE id = _loc;
        if not FOUND then
            PERFORM raise_p('Please choose a valid location.');
        end if;
        PERFORM id FROM team WHERE name = _name;
        if FOUND then
            PERFORM raise_p('Team name already choosen.');
        end if;

        RETURN addTeam(_name, Null, _pwd1, _loc);
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: loginTeam(name,pwd)
*/
CREATE OR REPLACE FUNCTION loginTeam(_name team.name%TYPE,
                                    _pwd team.pwd%TYPE)
RETURNS team.id%TYPE AS $$
    DECLARE
        _teamId team.id%TYPE;
    BEGIN
        -- Logging
        raise notice 'loginTeam(%,pwd)',$1;

        SELECT id INTO _teamId FROM team where name = _name AND pwd = sha256(_pwd) LIMIT 1;
        if not FOUND then
            PERFORM raise_p('Incorrect password.');
        end if;

        RETURN _teamId;
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
        if _id is NULL or _id < 1 then
            raise exception 'ID cannot be NULL or lower than 1';
        end if;

        if _name is NULL or _name = '' then
            raise exception 'Name cannot be NULL';
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

        PERFORM addEvent(format('Team "%s" was updated. name="%s",net="%s".',_id,_name,_inet),'team');

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: listTeam(top = 30)
*/
CREATE OR REPLACE FUNCTION listTeams(_grep varchar(30) DEFAULT NULL,
                                     _top integer default 30) 
RETURNS TABLE (
                id team.id%TYPE,
                team team.name%TYPE,
                net varchar(20),
                flagPts flag.pts%TYPE,
                kingFlagPts kingFlag.pts%TYPE,
                flagTotal flag.pts%TYPE,
                cash flag.cash%TYPE
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
                            (coalesce(tf3.sum::integer,0) + coalesce(tfi3.sum::integer,0)) AS flagTotal,
                            w.amount AS cash
                     FROM team AS t
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
                     WHERE (_grep IS NULL OR t.name LIKE '%'||_grep||'%' OR t.net::text LIKE '%'||_grep||'%')
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
        _flagId := addRandomFlag(_flagName, _pts, NULL, 'scoreboard.hf', 'bug', 1, 
                                 NULL, 'HF Crew', 'Standard', NULL, _desc);

        -- Assign flag
        raise notice 'team net: %s',_teamNet+1;
        INSERT INTO team_flag(teamId,flagId,pts,playerIp)
               VALUES(_teamId, _flagId,_pts,_teamNet+1);

        -- Create news
        _newsMsg := 'Thanks to '||_teamName||' for raising an issue to admins. That was worth '||_pts||' pts.';
        PERFORM addNews(_newsMsg,current_timestamp::timestamp);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addTeamSecrets(teamId,name,value)
*/
CREATE OR REPLACE FUNCTION addTeamSecrets(_teamId team.id%TYPE,
                                           _name teamSecrets.value%TYPE,
                                           _value teamSecrets.value%TYPE)
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addTeamSecrets(%,%,%)',$1,$2,$3;

        -- Some checks
        if _name is NULL then
            raise exception 'Name cannot be NULL';
        end if;

        -- Insert a new row
        INSERT INTO teamSecrets(teamId,name,value) VALUES(_teamId,_name,_value);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: listTeamSecrets(grep,top)
    TODO: Remap this function in admin.py. It was getTeamSecrets
*/
CREATE OR REPLACE FUNCTION listTeamSecrets(_grep varchar(30) DEFAULT NULL,
                                            _top integer DEFAULT 30) 
RETURNS TABLE (                             
                TeamName team.name%TYPE,
                name teamSecrets.name%TYPE,
                value teamSecrets.value%TYPE
              ) AS $$
    BEGIN
        -- Logging
        raise notice 'listTeamSecrets(%,%)',$1,$2;

        -- Get team's settings
        return QUERY SELECT a.teamName,
                            a.name,
                            a.value
                     FROM (
                         SELECT tv.teamId,
                                tv.name,
                                tv.value,
                                t.name AS teamName
                         FROM teamSecrets AS tv
                         LEFT OUTER JOIN (
                            SELECT t.id,
                                   t.name
                            FROM team AS t
                            ) AS t ON t.id = tv.teamId
                         WHERE (_grep IS NULL 
                                OR t.name LIKE '%'||_grep||'%' 
                                OR tv.name LIKE '%'||_grep||'%'
                                OR tv.value LIKE '%'||_grep||'%')
                     ) AS a
                     LIMIT _top;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

