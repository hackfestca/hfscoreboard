/*
    Stored Proc: processNonStandardFlag(flagId,teamId)
    This function does not manage king flags.
*/
CREATE OR REPLACE FUNCTION processNonStandardFlag(_flagId flag.id%TYPE, 
                                                  _teamId team.id%TYPE,
                                                  _playerIp team.net%TYPE)
RETURNS TABLE (
                pts flag.pts%TYPE,
                ret text
              ) AS $$
    DECLARE
        _flagRec RECORD;
        _ret text;
    BEGIN
        -- Logging
        raise notice 'processNonStandardFlag(%,%,%)',$1,$2,$3;

        -- Get flag attributes
        SELECT  f.id,
                f.pts,
                f.cash,
                f.type,
                f.typeExt,
                ft.code,
                fte.ptsLimit,
                fte.ptsStep,
                fte.trapCmd,
                fte.updateCmd
        INTO _flagRec
        FROM flag AS f
        LEFT OUTER JOIN (
            SELECT  code
            FROM flagType AS ft
        ) AS ft ON f.type = ft.code
        LEFT OUTER JOIN (
            SELECT  id,
                    ptsLimit,
                    ptsStep,
                    trapCmd,
                    updateCmd
            FROM flagTypeExt AS fte
        ) AS fte ON f.typeExt = fte.id
        WHERE f.id = _flagId;
        if not FOUND then
            PERFORM raise_p(format('Could not find flag "%"',_flagId));
        end if;

        -- Contextualize the flag pts based on flag types
        if _flagRec.type = 2 then
            -- Check if the flag was already submitted
            PERFORM id FROM team_flag WHERE flagId = _flagRec.id;
            if FOUND then
                PERFORM raise_p(format('Unique flag already submitted by a team. Too late. :)'));
            end if;
            _ret := 'Congratulations. You received ' || _flagRec.pts::text || 'pts and ' || _flagRec.cash::text || '$ for this flag. ';
            --PERFORM addEvent(_ret,'flag');
            RETURN QUERY SELECT _flagRec.pts,_ret;
        elsif _flagRec.type = 12 then
            -- Calculate new value
            RETURN QUERY SELECT * FROM processDynamicFlag(_flagId,_teamId);
        elsif _flagRec.type = 13 then
            -- Calculate new value
            RETURN QUERY SELECT * FROM processBonusFlag(_flagId,_teamId,_playerIp);
        elsif _flagRec.type = 14 then
            -- Calculate new value
            RETURN QUERY SELECT * FROM processExclusiveFlag(_flagId,_teamId,_playerIp);
        elsif _flagRec.type = 21 then
            -- Calculate new value
            RETURN QUERY SELECT * FROM processGroupDynamicFlag(_flagId,_teamId);
        elsif _flagRec.type = 22 then
            -- Calculate new value
            RETURN QUERY SELECT * FROM processTeamGroupBonusFlag(_flagId,_teamId,_playerIp);
        elsif _flagRec.type = 31 then
            -- Calculate new value
            RETURN QUERY SELECT * FROM processTeamGroupDynamicFlag(_flagId,_teamId);
        elsif _flagRec.type = 32 then
            -- Calculate new value
            RETURN QUERY SELECT * FROM processTeamGroupPokemonFlag(_flagId,_teamId,_playerIp);
        elsif _flagRec.type = 33 then
            -- Calculate new value
            RETURN QUERY SELECT * FROM processTeamGroupUniqueFlag(_flagId,_teamId,_playerIp);
        elsif _flagRec.type = 41 then
            -- Calculate new value
            RETURN QUERY SELECT _flagRec.pts,'trap';
        else
            PERFORM raise_p(format('Unsupported flag type "%"',_flagRec.type));
        end if;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: processDynamicFlag(flagId,teamId)
*/
CREATE OR REPLACE FUNCTION processDynamicFlag(_flagId flag.id%TYPE, 
                                              _teamId team.id%TYPE)
RETURNS TABLE (
                pts flag.pts%TYPE,
                ret text
              ) AS $$
    DECLARE
        _flagRec RECORD;
        _ct integer;
        _pts flag.pts%TYPE;
        _ret text;
    BEGIN
        -- Logging
        raise notice 'processDynamicFlag(%,%)',$1,$2;

        -- Get flag attributes
        SELECT  f.id,
                f.name,
                f.pts,
                f.type,
                f.typeExt,
                ft.code,
                fte.ptsLimit,
                fte.ptsStep,
                fte.trapCmd,
                fte.updateCmd
        INTO _flagRec
        FROM flag AS f
        LEFT OUTER JOIN (
            SELECT  code
            FROM flagType AS ft
        ) AS ft ON f.type = ft.code
        LEFT OUTER JOIN (
            SELECT  id,
                    ptsLimit,
                    ptsStep,
                    trapCmd,
                    updateCmd
            FROM flagTypeExt AS fte
        ) AS fte ON f.typeExt = fte.id
        WHERE f.id = _flagId;
        if not FOUND then
            PERFORM raise_p(format('Could not find flag "%"',_flagId));
        end if;

        -- Get count() of this flag's last submission
        SELECT count(id) INTO _ct FROM team_flag WHERE flagId = _flagId;

        -- Determine pts for the next submit
        _pts := _flagRec.pts + (_ct * _flagRec.ptsStep);
        if _flagRec.ptsStep < 0 and _flagRec.ptsLimit > _pts then
            _pts := _flagRec.ptsLimit;
        elsif _flagRec.ptsStep > 0 and _flagRec.ptsLimit < _pts then
            _pts := _flagRec.ptsLimit;
        end if;

        _ret := format('You are the %sth team to submit flag "%s", for %s/%spts',
                 (_ct+1),_flagRec.name,_pts,_flagRec.pts);

        RETURN QUERY SELECT _pts,_ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: processBonusFlag(flagId,teamId)
*/
CREATE OR REPLACE FUNCTION processBonusFlag(_flagId flag.id%TYPE, 
                                            _teamId team.id%TYPE,
                                            _playerIp inet)
RETURNS TABLE (
                pts flag.pts%TYPE,
                ret text
              ) AS $$
    DECLARE
        _flagRec RECORD;
        _ct integer;
        _bonusId flag.id%TYPE;
        _bonusPts flagTypeExt.pts%TYPE := 0;
        _ret text;
    BEGIN
        -- Logging
        raise notice 'processBonusFlag(%,%,%)',$1,$2,$3;

        -- Get flag attributes
        SELECT  f.id,
                f.name,
                f.pts,
                f.cash,
                f.type,
                f.typeExt,
                ft.code,
                fte.pts AS ftePts,
                fte.ptsLimit,
                fte.ptsStep,
                fte.flagIds
        INTO _flagRec
        FROM flag AS f
        LEFT OUTER JOIN (
            SELECT  code
            FROM flagType AS ft
        ) AS ft ON f.type = ft.code
        LEFT OUTER JOIN (
            SELECT  id,
                    fte.pts,
                    ptsLimit,
                    ptsStep,
                    flagIds
            FROM flagTypeExt AS fte
        ) AS fte ON f.typeExt = fte.id
        WHERE f.id = _flagId;
        if not FOUND then
            PERFORM raise_p(format('Could not find flag "%"',_flagId));
        end if;

        -- Get count() of this flag's last submission
        SELECT count(id) INTO _ct FROM team_flag WHERE flagId = _flagId;

        -- Determine bonus id and value
        SELECT flag.id,flag.pts 
        INTO _bonusId,_bonusPts
        FROM flag
        WHERE flag.id = ANY(_flagRec.flagIds) 
        ORDER BY pts DESC OFFSET _ct LIMIT 1;
        if _bonusPts is NULL then
            _bonusPts := 0;
        end if;

        if _bonusPts > 0 then
            -- Assign bonus flag
            INSERT INTO team_flag(teamId,flagId,pts,playerIp)
                   VALUES(_teamId,_bonusId,_bonusPts,_playerIp);
    
            PERFORM addEvent(format('Team "%s" received a bonus of %spts for being the %sth team to submit flag "%s" with value %spts',_teamId,_bonusPts,(_ct+1),_flagRec.name,_flagRec.pts),'flag');
    
            _ret := format('You have received a bonus of %spts for being the %sth team to submit flag "%s" with value %spts',
                     _bonusPts,(_ct+1),_flagRec.name,_flagRec.pts);
        else
            _ret := 'Congratulations. You received ' || _flagRec.pts::text || 'pts and ' || _flagRec.cash::text || '$ for this flag. ';
        end if;

        RETURN QUERY SELECT _flagRec.pts,_ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: processExclusiveFlag(flagId,teamId)
*/
CREATE OR REPLACE FUNCTION processExclusiveFlag(_flagId flag.id%TYPE, 
                                                   _teamId team.id%TYPE,
                                                   _playerIp team.net%TYPE)
RETURNS TABLE (
                pts flag.pts%TYPE,
                ret text
              ) AS $$
    DECLARE
        _flagRec RECORD;
        _ret text;
        _teamName team.name%TYPE;
        _teamNum team.num%TYPE;
        _flagTeamName team.name%TYPE;
    BEGIN
        -- Logging
        raise notice 'processTeamGroupUniqueFlag(%,%,%)',$1,$2,$3;

        -- Get flag attributes
        SELECT  f.id,
                f.name,
                f.pts,
                f.cash,
                f.arg1::integer as num,
                f.arg2::integer as penalty,
                ft.code
        INTO _flagRec
        FROM flag AS f
        LEFT OUTER JOIN (
            SELECT  code
            FROM flagType AS ft
        ) AS ft ON f.type = ft.code
        WHERE f.id = _flagId;
        if not FOUND then
            PERFORM raise_p(format('Could not find flag "%"',_flagId));
        end if;

        -- Get team num
        SELECT num,name
        FROM team
        WHERE id = _teamId
        INTO _teamNum,_teamName;

        -- Get flag's team name
        SELECT name
        FROM team
        WHERE num = _flagRec.num
        INTO _flagTeamName;

        -- Check if the team have permission to submit
        -- Apply penalty if the flag number is different than the _teamNum
        if _teamNum <> _flagRec.num then
            raise notice 'Team % have sent a flag from team %. Applying penalty of %pts.',
                         _teamName,_flagRec.num,_flagRec.penalty;

            PERFORM addNews(format('Team "%s" have FUCKED IT UP and got %spts for submitting a flag from "%s"',
                            _teamName,_flagRec.penalty,_flagTeamName), NULL);
    
            PERFORM addEvent(format('Team "%s" have sent a flag from team "%s". Applying penalty of %spts',
                                    _teamName,_flagTeamName,_flagRec.penalty),'flag');
    
            _ret := format('Cheater! You submitted a flag from team "%s". You received a %spts penalty. Oops!',
                          _flagTeamName,_flagRec.penalty);
            RETURN QUERY SELECT _flagRec.penalty,_ret;

        -- otherwise, no special actions
        else
            _ret := format('Congratulations. You received %spts and %s$ for this flag.',
                            _flagRec.pts::text,_flagRec.cash::text);
            RETURN QUERY SELECT _flagRec.pts,_ret;
        end if;

    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


/*
    Stored Proc: processGroupDynamicFlag(flagId,teamId)
*/
CREATE OR REPLACE FUNCTION processGroupDynamicFlag(_flagId flag.id%TYPE, 
                                                  _teamId team.id%TYPE)
RETURNS TABLE (
                pts flag.pts%TYPE,
                ret text
              ) AS $$
    DECLARE
        _flagRec RECORD;
        _ct integer := 0;
        _pts flag.pts%TYPE;
        _ret text;
        _aFlagIds integer[];
        _tmpTeamId team.id%TYPE;
    BEGIN
        -- Logging
        raise notice 'processGroupDynamicFlag(%,%)',$1,$2;

        -- Get flag attributes
        SELECT  f.id,
                f.name,
                f.pts,
                f.type,
                f.typeExt,
                ft.code,
                fte.name AS flagTypeExtName,
                fte.ptsLimit,
                fte.ptsStep,
                fte.trapCmd,
                fte.updateCmd
        INTO _flagRec
        FROM flag AS f
        LEFT OUTER JOIN (
            SELECT code
            FROM flagType AS ft
        ) AS ft ON f.type = ft.code
        LEFT OUTER JOIN (
            SELECT  id,
                    name,
                    ptsLimit,
                    ptsStep,
                    trapCmd,
                    updateCmd
            FROM flagTypeExt AS fte
        ) AS fte ON f.typeExt = fte.id
        WHERE f.id = _flagId;
        if not FOUND then
            PERFORM raise_p(format('Could not find flag "%"',_flagId));
        end if;
        
        -- Get a list of all flags with the same type extension
        SELECT array(
            SELECT id 
            FROM flag
            WHERE typeExt = _flagRec.typeExt
        ) 
        INTO _aFlagIds;

        -- Get count() of this group of flag's last submission
        SELECT count(t.ct)
        FROM (
            SELECT teamId,
                   count(flagId) AS ct
            FROM team_flag
            WHERE flagId = ANY(_aFlagIds)
            GROUP BY teamId
        ) AS t
        WHERE t.ct = array_length(_aFlagIds,1)
        INTO _ct;

        -- Make sure _ct is not NULL
        if _ct is NULL then
            _ct := 0;
        end if;

        -- Determine pts for the next submit
        _pts := _flagRec.pts + (_ct * _flagRec.ptsStep);
        if _flagRec.ptsStep < 0 and _flagRec.ptsLimit > _pts then
            _pts := _flagRec.ptsLimit;
        elsif _flagRec.ptsStep > 0 and _flagRec.ptsLimit < _pts then
            _pts := _flagRec.ptsLimit;
        end if;

        PERFORM addEvent(format('%s teams currently completed group "%s". Team "%s" score for %s/%spts',_ct,_flagRec.flagTypeExtName,_teamId,_pts,_flagRec.pts),'flag');

        _ret := format('%s teams currently completed group "%s". You scored for %s/%spts',
                _ct,_flagRec.flagTypeExtName,_pts,_flagRec.pts);

        RETURN QUERY SELECT _pts,_ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: processTeamGroupBonusFlag(flagId,teamId)
*/
CREATE OR REPLACE FUNCTION processTeamGroupBonusFlag(_flagId flag.id%TYPE, 
                                                 _teamId team.id%TYPE,
                                                 _playerIp team.net%TYPE)
RETURNS TABLE (
                pts flag.pts%TYPE,
                ret text
              ) AS $$
    DECLARE
        _flagRec RECORD;
        _ct integer;
        _pts flag.pts%TYPE;
        _bonusId flag.id%TYPE;
        _bonusPts flagTypeExt.pts%TYPE := 0;
        _ret text;
        _aFlagIds integer[];
        _isLastFlag boolean;
    BEGIN
        -- Logging
        raise notice 'processTeamGroupBonusFlag(%,%,%)',$1,$2,$3;

        -- Get flag attributes
        SELECT  f.id,
                f.name,
                f.pts,
                f.cash,
                f.type,
                f.typeExt,
                ft.code,
                fte.name AS typeExtName,
                fte.ptsLimit,
                fte.ptsStep,
                fte.flagIds
        INTO _flagRec
        FROM flag AS f
        LEFT OUTER JOIN (
            SELECT  code
            FROM flagType AS ft
        ) AS ft ON f.type = ft.code
        LEFT OUTER JOIN (
            SELECT  id,
                    name,
                    ptsLimit,
                    ptsStep,
                    flagIds
            FROM flagTypeExt AS fte
        ) AS fte ON f.typeExt = fte.id
        WHERE f.id = _flagId;
        if not FOUND then
            PERFORM raise_p(format('Could not find flag "%"',_flagId));
        end if;

        -- Get a list of all flags with the same type extension
        SELECT array(
            SELECT id 
            FROM flag
            WHERE typeExt = _flagRec.typeExt
        ) 
        INTO _aFlagIds;

        -- Get count() of this group of flag's last submission, for the current team.
        SELECT count(flagId) AS ct
        FROM team_flag
        WHERE flagId = ANY(_aFlagIds)
            and teamId = _teamId
        INTO _ct;

        -- Determine if submitting last flag of group
        SELECT count(flagId) + 1 = array_length(_aFlagIds,1) AS isLastFlag
        FROM team_flag
        WHERE flagId = ANY(_aFlagIds)
            and teamId = _teamId
        INTO _isLastFlag;

        -- Determine bonus id and value
        SELECT flag.id,flag.pts 
        INTO _bonusId,_bonusPts
        FROM flag
        WHERE flag.id = ANY(_flagRec.flagIds) 
        ORDER BY pts DESC OFFSET _ct LIMIT 1;
        if _bonusPts is NULL then
            _bonusPts := 0;
        end if;

        if _isLastFlag and _bonusPts > 0 then
            -- Assign bonus flag
            INSERT INTO team_flag(teamId,flagId,pts,playerIp)
                   VALUES(_teamId,_bonusId,_bonusPts,_playerIp);
    
            PERFORM addEvent(format('Team "%s" received a bonus of %spts for being the %sth team to complete track "%s" and submitting flag "%s" for %spts',_teamId,_bonusPts,(_ct+1),_flagRec.typeExtName,_flagRec.name,_flagRec.pts),'flag');
    
            _ret := format('You have received a bonus of %spts for being the %sth team to complete track "%s" and submitting flag "%s" for %spts',
                            _bonusPts,(_ct+1),_flagRec.typeExtName,_flagRec.name,_flagRec.pts);
        else
            _ret := 'Congratulations. You received ' || _flagRec.pts::text || 'pts and ' || _flagRec.cash::text || '$ for this flag. ';
        end if;

        RETURN QUERY SELECT _flagRec.pts,_ret;

    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: processTeamGroupPokemonFlag(flagId,teamId)
*/
CREATE OR REPLACE FUNCTION processTeamGroupPokemonFlag(_flagId flag.id%TYPE, 
                                                   _teamId team.id%TYPE,
                                                   _playerIp team.net%TYPE)
RETURNS TABLE (
                pts flag.pts%TYPE,
                ret text
              ) AS $$
    DECLARE
        _flagRec RECORD;
        _ct integer;
        _pts flag.pts%TYPE;
        _bonusId flag.id%TYPE;
        _bonusPts flagTypeExt.pts%TYPE := 0;
        _ret text;
        _aFlagIds integer[];
        _isLastFlag boolean;
    BEGIN
        -- Logging
        raise notice 'processTeamGroupPokemonFlag(%,%,%)',$1,$2,$3;

        -- Get flag attributes
        SELECT  f.id,
                f.name,
                f.pts,
                f.type,
                f.typeExt,
                ft.code,
                fte.name AS typeExtName,
                fte.ptsLimit,
                fte.ptsStep,
                fte.flagIds
        INTO _flagRec
        FROM flag AS f
        LEFT OUTER JOIN (
            SELECT  code
            FROM flagType AS ft
        ) AS ft ON f.type = ft.code
        LEFT OUTER JOIN (
            SELECT  id,
                    name,
                    ptsLimit,
                    ptsStep,
                    flagIds
            FROM flagTypeExt AS fte
        ) AS fte ON f.typeExt = fte.id
        WHERE f.id = _flagId;
        if not FOUND then
            PERFORM raise_p(format('Could not find flag "%"',_flagId));
        end if;

        -- Get a list of all flags with the same type extension
        SELECT array(
            SELECT id 
            FROM flag
            WHERE typeExt = _flagRec.typeExt
        ) 
        INTO _aFlagIds;

        -- Get count() of this group of flag's last submission
        SELECT count(t.ct)
        FROM (
            SELECT teamId,
                   count(flagId) AS ct
            FROM team_flag
            WHERE flagId = ANY(_aFlagIds)
            GROUP BY teamId
        ) AS t
        WHERE t.ct = array_length(_aFlagIds,1)
        INTO _ct;

        -- Determine if submitting last flag of group
        SELECT count(flagId) + 1 = array_length(_aFlagIds,1) AS isLastFlag
        FROM team_flag
        WHERE flagId = ANY(_aFlagIds)
            and teamId = _teamId
        INTO _isLastFlag;

        -- Determine bonus id and value
        SELECT flag.id,flag.pts 
        INTO _bonusId,_bonusPts
        FROM flag
        WHERE flag.id = ANY(_flagRec.flagIds) 
        LIMIT 1;
        if _bonusPts is NULL then
            _bonusPts := 0;
        end if;

        if _isLastFlag and _bonusPts > 0 then
            -- Assign bonus flag
            INSERT INTO team_flag(teamId,flagId,pts,playerIp)
                   VALUES(_teamId,_bonusId,_bonusPts,_playerIp);
    
            PERFORM addEvent(format('Team "%s" successfully completed the track "%s" for %spts',
                                    _teamId,_flagRec.typeExtName,_bonusPts),'flag');
    
            _ret := format('You have successfully completed the track "%s" for %spts',
                            _flagRec.typeExtName,_bonusPts);
        else
            _ret := 'You have submitted a pokemon flag. Capture them all to get points.';
        end if;

        RETURN QUERY SELECT _flagRec.pts,_ret;

    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: processTeamGroupUniqueFlag(flagId,teamId)
*/
CREATE OR REPLACE FUNCTION processTeamGroupUniqueFlag(_flagId flag.id%TYPE, 
                                                   _teamId team.id%TYPE,
                                                   _playerIp team.net%TYPE)
RETURNS TABLE (
                pts flag.pts%TYPE,
                ret text
              ) AS $$
    DECLARE
        _flagRec RECORD;
        _ret text;
        _aFlagGroupIds integer[];
        _subGroup text;
    BEGIN
        -- Logging
        raise notice 'processTeamGroupUniqueFlag(%,%,%)',$1,$2,$3;

        -- Get flag attributes
        SELECT  f.id,
                f.name,
                f.pts,
                f.cash,
                f.arg1 as group,
                f.arg2 as subgroup,
                ft.code
        INTO _flagRec
        FROM flag AS f
        LEFT OUTER JOIN (
            SELECT  code
            FROM flagType AS ft
        ) AS ft ON f.type = ft.code
        WHERE f.id = _flagId;
        if not FOUND then
            PERFORM raise_p(format('Could not find flag "%"',_flagId));
        end if;

        -- Get a list of all flags with the same group
        -- Those flags can be submitted if no other subgroup have been submitted.
        SELECT array(
            SELECT id 
            FROM flag
            WHERE arg1 = _flagRec.group
        ) 
        INTO _aFlagGroupIds;

        -- Determine if a flag was already submitted among this group. (Is a difficulty level already choosen?)
        SELECT a.arg2
        FROM (
            SELECT f.id,
                   f.arg2
            FROM team_flag AS tf
            LEFT OUTER JOIN(
                SELECT id,
                       arg2
                FROM flag AS f
            ) AS f ON f.id = tf.flagId
            WHERE tf.flagId = ANY(_aFlagGroupIds)
            LIMIT 1
        ) AS a
        INTO _subGroup;

        -- If no flag was submitted, the player can submit any flag.
        if not FOUND then
            raise notice 'Subgroup not choosen yet. OK to submit.';
    
            PERFORM addEvent(format('Team "%s" choose subgroup "%s" on group "%s"',
                                    _teamId,_subGroup,_flagRec.group),'flag');
    
            _ret := 'Congratulations. You received ' || _flagRec.pts::text || 'pts and ' 
                    || _flagRec.cash::text || '$ for this flag of ' || _flagRec.subgroup || ' difficulty.';

        -- If a flag was already submitted, the player can only submit flags of the same subgroup
        else
            raise notice 'Subgroup % choosen. Must attempt to submit on the same subgroup.',_subGroup;

            -- Check if the flag is in the same group and subgroup.
            if _subGroup = _flagRec.subgroup then
                raise notice 'Subgroup the same than previous flag. OK to submit.';

                PERFORM addEvent(format('Team "%s" submitted a new flag in subgroup "%s" and group "%s"',
                                        _teamId,_subGroup,_flagRec.group),'flag');
        
                _ret := 'Congratulations. You received ' || _flagRec.pts::text || 'pts and ' 
                        || _flagRec.cash::text || '$ for this flag of ' || _subGroup || ' difficulty.';
            else
                PERFORM raise_p(format('You cannot submit this flag because you already started the "%s" difficulty',_subGroup));
            end if;
        end if;

        RETURN QUERY SELECT _flagRec.pts,_ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

