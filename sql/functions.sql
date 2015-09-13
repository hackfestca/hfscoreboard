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
$$ LANGUAGE SQL STRICT IMMUTABLE;

/*
    Stored Proc: transferMoney(srcWalletId,dstWalletId,amount,transactionType)
*/
CREATE OR REPLACE FUNCTION transferMoney(_srcWalletId wallet.id%TYPE,
                                   _dstWalletId wallet.id%TYPE, 
                                   _amount wallet.amount%TYPE, 
                                   _transactionTypeCode transactionType.code%TYPE) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'transferMoney(%,%,%,%)',$1,$2,$3,$4;

        -- Some checks
        PERFORM id FROM wallet WHERE id = _srcWalletId;
        if not FOUND then
            raise exception 'Could not find the source wallet "%"',_srcWalletId;
        end if;

        PERFORM id FROM wallet WHERE id = _dstWalletId;
        if not FOUND then
            raise exception 'Could not find the destination wallet "%"',_dstWalletId;
        end if;

        if _amount < 0.01 then
            raise exception 'Cannot transfer less than 0.01$';
        end if;

        if _amount < 0 then
            raise exception 'Cannot transfer negative value';
        end if;

        if _amount = 0 then
            raise exception 'Cannot transfer a null value';
        end if;

        PERFORM code FROM transactionType WHERE code = _transactionTypeCode;
        if not FOUND then
            raise exception 'Could not find transaction type "%"',_transactionTypeCode;
        end if;

        -- Verify source wallet has enough money to transfer the amount
        PERFORM id,amount FROM wallet WHERE id = _srcWalletId and (amount - _amount) >= 0;
        if not FOUND then
            raise exception 'Sender does not have enough money';
        end if;

        -- Update source wallet
        UPDATE wallet
        SET amount = amount - _amount
        WHERE id = _srcWalletId;

        -- Update destination wallet
        UPDATE wallet
        SET amount = amount + _amount
        WHERE id = _dstWalletId;

        -- log in transaction table
        INSERT INTO transaction(srcWalletId,dstWalletId,amount,type) 
                VALUES(_srcWalletId,_dstWalletId,_amount,_transactionTypeCode);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: launderMoney(dstWalletId,amount)
*/
CREATE OR REPLACE FUNCTION launderMoney(_dstWalletId wallet.id%TYPE, 
                                   _amount wallet.amount%TYPE)
RETURNS integer AS $$
    DECLARE
        TR_LAUNDERING_CODE transactionType.code%TYPE := 4;
        BANK_ID wallet.id%TYPE := 1;
    BEGIN
        -- Logging
        raise notice 'launderMoney(%,%)',$1,$2;

        PERFORM transferMoney(BANK_ID,_dstWalletId,_amount,TR_LAUNDERING_CODE);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: launderMoneyFromTeamId(dstWalletId,amount)
*/
CREATE OR REPLACE FUNCTION launderMoneyFromTeamId(_teamId team.id%TYPE, 
                                                  _amount wallet.amount%TYPE)
RETURNS integer AS $$
    DECLARE
        _teamName team.name%TYPE;
        _dstWalletId wallet.id%TYPE;
    BEGIN
        -- Logging
        raise notice 'launderMoneyFromTeamId(%,%)',$1,$2;

        -- Must force numeric because python send huge crap
        -- For example, 1.1 becomes 1.100000000000000088817841970012523233890533447265625
        _amount := formatCash(_amount);

        -- Get team wallet id
        SELECT name,wallet INTO _teamName,_dstWalletId FROM team WHERE id = _teamId;
        if not FOUND then
            raise exception 'Could not find team "%"',_teamId;
        end if;

        -- Perform laundering
        PERFORM launderMoney(_dstWalletId,_amount);

        -- DB Logging
        PERFORM addEvent(format('Team %s have laundered %s$.',_teamName,_amount),'cash');

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: buyLotoTicketFromIp(amount,playerIp)
*/
CREATE OR REPLACE FUNCTION buyLotoTicketFromIp(_amount wallet.amount%TYPE, 
                                                _playerIpStr varchar(20))
RETURNS integer AS $$
    DECLARE
        TR_LOTO_CODE transactionType.code%TYPE := 5;
        LOTO_ID wallet.id%TYPE := 2;
        _playerIp inet;
        _teamName team.name%TYPE;
        _srcWalletId team.id%TYPE;
    BEGIN
        -- Logging
        raise notice 'buyLotoTicketFromIp(%,%)',$1,$2;
    
        _playerIp := _playerIpStr::inet;

        -- Get team from userIp 
        SELECT name,wallet INTO _teamName,_srcWalletId FROM team where _playerIp << net ORDER BY id DESC LIMIT 1;
        if NOT FOUND then
            raise exception 'Team not found for %',_playerIp;
        end if;

        PERFORM transferMoney(_srcWalletId,LOTO_ID,_amount,TR_LOTO_CODE);

        -- DB Logging
        PERFORM addEvent(format('Team %s have bought a loto ticket for %s$.',_teamName,_amount),'loto');

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: processLotoWinner(winnerId)
*/
CREATE OR REPLACE FUNCTION processLotoWinner(_winnerId wallet.id%TYPE)
RETURNS text AS $$
    DECLARE
        TR_LOTO_CODE transactionType.code%TYPE := 5;
        LOTO_ID wallet.id%TYPE := 2;
        _amount wallet.amount%TYPE;
        _teamName team.name%TYPE;
        _lastWinTs transaction.ts%TYPE;
        _ret text;
    BEGIN
        -- Logging
        raise notice 'processLotoWinner(%)',$1;

        -- Get cash in loto wallet
        SELECT amount INTO _amount FROM wallet WHERE id = LOTO_ID;

        -- Get team name from wallet
        SELECT name INTO _teamName FROM team WHERE wallet = _winnerId;

        -- Get last win timestamp
        SELECT ts
        INTO _lastWinTs
        FROM transaction
        WHERE type = TR_LOTO_CODE
            and srcWalletId = LOTO_ID
        ORDER BY ts DESC LIMIT 1;

        -- Check that the winner have bought loto since last win
        PERFORM id 
        FROM transaction
        WHERE (ts > _lastWinTs or _lastWinTs is null)
            and dstWalletId = LOTO_ID
            and srcWalletId = _winnerId;
        if NOT FOUND then
            raise exception 'The wallet "%" cannot win as it did not participate since %.',
                            _winnerId,coalesce(to_char(_lastWinTs,'HH24:MI:SS'),'the begining');
        end if;
        
        -- Transfer cash to winner
        if _amount > 0 then
            PERFORM transferMoney(LOTO_ID,_winnerId,_amount,TR_LOTO_CODE);
            _ret := format('Team "%s" won loto HF for an amount of %s$.',_teamName,_amount::text);
        else
            raise notice 'Loto wallet was empty. No winner this time.';
            _ret := 'Loto wallet was empty. No winner this time.';
        end if;

        -- DB Logging
        PERFORM addEvent(_ret,'loto');

        RETURN _ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getLotoHistory(_top)
*/
CREATE OR REPLACE FUNCTION getLotoHistory(_top integer DEFAULT 30)  
RETURNS TABLE (
                srcId wallet.id%TYPE,
                srcName wallet.name%TYPE,
                dstId wallet.id%TYPE,
                dstName wallet.name%TYPE,
                amount transaction.amount%TYPE,
                transactionType transactionType.name%TYPE,
                ts timestamp
              ) AS $$
    DECLARE
        TR_LOTO_CODE transactionType.code%TYPE := 5;
        LOTO_ID wallet.id%TYPE := 2;
    BEGIN
        -- Logging
        raise notice 'getLotoHistory(%)',$1;

        -- Some check 
        if _top <= 0 then
            raise exception '_top argument cannot be a negative value. _top=%',_top;
        end if;

        RETURN QUERY SELECT t.srcWalletId,
                            w1.name as srcWallet,
                            t.dstWalletId,
                            w2.name as dstWallet,
                            t.amount,
                            tt.name as transactionType,
                            t.ts
                     FROM transaction as t
                     LEFT OUTER JOIN (
                         SELECT id,
                                name
                         FROM wallet
                     ) AS w1 ON t.srcWalletId= w1.id
                     LEFT OUTER JOIN (
                         SELECT id,
                                name
                         FROM wallet
                     ) AS w2 ON t.dstWalletId= w2.id
                     LEFT OUTER JOIN (
                         SELECT code,
                                name
                         FROM transactionType
                     ) AS tt ON t.type= tt.code
                    WHERE t.type = TR_LOTO_CODE
                    ORDER BY t.ts
                    LIMIT _top;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: transferCashFlag(flagId,teamId)
*/
CREATE OR REPLACE FUNCTION transferCashFlag(_flagId team.id%TYPE, 
                                            _teamId flag.id%TYPE)
RETURNS integer AS $$
    DECLARE
        _dstWalletId wallet.id%TYPE;
        _flagCashValue flag.cash%TYPE;
        BANK_ID wallet.id%TYPE := 1;
        TR_CASH_FLAG_CODE transactionType.code%TYPE := 2;
    BEGIN
        -- Logging
        raise notice 'transferCashFlag(%,%)',$1,$2;

        -- Get team wallet id
        SELECT wallet INTO _dstWalletId FROM team WHERE id = _teamId;
        if not FOUND then
            raise exception 'Could not find team "%"',_teamId;
        end if;

        -- Get flag cash value
        SELECT cash INTO _flagCashValue FROM flag WHERE id = _flagId;
        if not FOUND then
            raise exception 'Could not find flag "%"',_flagId;
        end if;
    
        -- Value cannot be 0$
        if _flagCashValue is NULL or _flagCashValue = 0 then
            raise exception 'Cannot transfer a 0$ flag';
        end if;

        -- Perform laundering
        PERFORM transferMoney(BANK_ID,_dstWalletId,_flagCashValue,TR_CASH_FLAG_CODE);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
            raise exception 'Could not find flag "%"',_flagId;
        end if;

        -- Contextualize the flag pts based on flag types
        if _flagRec.type = 2 then
            -- Check if the flag was already submitted
            PERFORM id FROM team_flag WHERE flagId = _flagRec.id;
            if FOUND then
                raise exception 'Unique flag already submitted by a team. Too late. :)';
            end if;
            _ret = 'Congratulations. You received ' || _flagRec.pts::text || 'pts for this flag. ';
            PERFORM addEvent(_ret,'flag');
            RETURN QUERY SELECT _flagRec.pts,_ret;
        elsif _flagRec.type = 12 then
            -- Calculate new value
            RETURN QUERY SELECT * FROM processDynamicFlag(_flagId,_teamId);
        elsif _flagRec.type = 13 then
            -- Calculate new value
            RETURN QUERY SELECT * FROM processBonusFlag(_flagId,_teamId,_playerIp);
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
        elsif _flagRec.type = 41 then
            -- Calculate new value
            RETURN QUERY SELECT _flagRec.pts,'trap';
        else
            raise exception 'Unsupported flag type "%"',_flagRec.type;
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
            raise exception 'Could not find flag "%"',_flagId;
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

        PERFORM addEvent(format('Team "%s" is the %sth team to submit flag "%s", for %s/%spts',
                        _teamId,(_ct+1),_flagRec.name,_pts,_flagRec.pts),'flag');

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
            raise exception 'Could not find flag "%"',_flagId;
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
            _ret = 'Congratulations. You received ' || _flagRec.pts::text || 'pts for this flag. ';
        end if;

        RETURN QUERY SELECT _flagRec.pts,_ret;
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
            raise exception 'Could not find flag "%"',_flagId;
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
            raise exception 'Could not find flag "%"',_flagId;
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
            _ret = 'Congratulations. You received ' || _flagRec.pts::text || 'pts for this flag. ';
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
            raise exception 'Could not find flag "%"',_flagId;
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
    
            PERFORM addEvent(format('Team "%s" successfully completed the track "%s" for %spts',_teamId,_flagRec.typeExtName,_bonusPts),'flag');
    
            _ret := format('You have successfully completed the track "%s" for %spts',
                            _flagRec.typeExtName,_bonusPts);
        else
            _ret = 'You have submitted a pokemon flag. Capture them all to get points.';
        end if;

        RETURN QUERY SELECT _flagRec.pts,_ret;

    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addWallet(name,desc,amount)
*/
CREATE OR REPLACE FUNCTION addWallet(_name wallet.name%TYPE,
                                   _desc wallet.description%TYPE, 
                                   _amount wallet.amount%TYPE,
                                   _isSystemWallet boolean DEFAULT false) 
RETURNS wallet.id%TYPE AS $$
    DECLARE
        _walletId wallet.id%TYPE;
    BEGIN
        -- Logging
        raise notice 'addWallet(%,%,%)',$1,$2,$3;

        -- Some checks
        if _name is NULL then
            raise exception 'Name cannot be NULL';
        end if;

        if _amount < 0 then
            raise exception 'Wallet amount cannot be under 0';
        end if;

        -- Insert a new row
        INSERT INTO wallet(publicId,name,description,amount) VALUES(random_64(),_name,_desc,0);
        _walletId := LASTVAL();

        -- Perform first transaction if _amount > 0
        if _isSystemWallet = false and _amount > 0then
            PERFORM transferMoney(1,_walletId,_amount,1);
        elsif _isSystemWallet = true then
            UPDATE wallet
            SET amount = _amount
            WHERE id = _walletId;
        end if;

        RETURN _walletId;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addTransactionType(code,name,desc)
*/
CREATE OR REPLACE FUNCTION addTransactionType(_code transactionType.code%TYPE,
                                    _name transactionType.name%TYPE, 
                                    _description transactionType.description%TYPE default ''
                                    ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addTransactionType(%,%,%)',$1,$2,$3;

        -- Insert a new row
        INSERT INTO transactionType(code,name,description)
                VALUES(_code,_name,_description);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: getTransactionHistory(_top)
*/
CREATE OR REPLACE FUNCTION getTransactionHistory(_top integer DEFAULT 30)  
RETURNS TABLE (
                srcWallet wallet.name%TYPE,
                dstWallet wallet.name%TYPE,
                amount transaction.amount%TYPE,
                transactionType transactionType.name%TYPE,
                ts timestamp
              ) AS $$
    BEGIN
        -- Logging
        raise notice 'getTransactionHistory(%)',$1;

        -- Some check 
        if _top <= 0 then
            raise exception '_top argument cannot be a negative value. _top=%',_top;
        end if;

        RETURN QUERY SELECT
                            w1.name as srcWallet,
                            w2.name as dstWallet,
                            t.amount,
                            tt.name as transactionType,
                            t.ts
                     FROM transaction as t
                     LEFT OUTER JOIN (
                         SELECT id,
                                name
                         FROM wallet
                     ) AS w1 ON t.srcWalletId= w1.id
                     LEFT OUTER JOIN (
                         SELECT id,
                                name
                         FROM wallet
                     ) AS w2 ON t.dstWalletId= w2.id
                     LEFT OUTER JOIN (
                         SELECT code,
                                name
                         FROM transactionType
                     ) AS tt ON t.type= tt.code
                     ORDER BY t.ts
                    LIMIT _top;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getTeamTransactionHistory(_top)
*/
CREATE OR REPLACE FUNCTION getTeamTransactionHistory(_teamId team.id%TYPE,
                                                     _top integer DEFAULT 30) 
RETURNS TABLE (
                srcWallet wallet.name%TYPE,
                dstWallet wallet.name%TYPE,
                amount transaction.amount%TYPE,
                transactionType transactionType.name%TYPE,
                ts timestamp
              ) AS $$
    DECLARE
        _walletId wallet.id%TYPE;
    BEGIN
        -- Logging
        raise notice 'getTeamTransactionHistory(%,%)',$1,$2;

        -- Some check 
        if _top <= 0 then
            raise exception '_top argument cannot be a negative value. _top=%',_top;
        end if;

        -- Get walletId from teamId
        SELECT wallet INTO _walletId FROM team WHERE id = _teamId;

        -- Get history
        RETURN QUERY SELECT
                            w1.name as srcWallet,
                            w2.name as dstWallet,
                            t.amount,
                            tt.name as transactionType,
                            t.ts
                     FROM transaction as t
                     LEFT OUTER JOIN (
                         SELECT id,
                                name
                         FROM wallet
                     ) AS w1 ON t.srcWalletId= w1.id
                     LEFT OUTER JOIN (
                         SELECT id,
                                name
                         FROM wallet
                     ) AS w2 ON t.dstWalletId= w2.id
                     LEFT OUTER JOIN (
                         SELECT code,
                                name
                         FROM transactionType
                     ) AS tt ON t.type= tt.code
                     WHERE t.srcWalletId = _walletId OR t.dstWalletId = _walletId
                     ORDER BY t.ts
                     LIMIT _top;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addTeam(name,net)
*/
CREATE OR REPLACE FUNCTION addTeam(_name team.name%TYPE,
                                   _net varchar(20)) 
RETURNS team.id%TYPE AS $$
    DECLARE
        _inet inet;
        _walletId wallet.id%TYPE;
        _teamStartMoney settings.teamStartMoney%TYPE;
    BEGIN
        -- Logging
        raise notice 'addTeam(%,%)',$1,$2;

        _inet := _net::inet;

        -- Some checks
        if _name is NULL then
            raise exception 'Name cannot be NULL';
        end if;

        if family(_inet) <> 4 then
            raise exception 'Only IPv4 addresses are supported';
        end if;

        -- Get team starting money
        SELECT teamStartMoney into _teamStartMoney FROM settings ORDER BY ts DESC LIMIT 1;

        -- Create wallet
        _walletId := addWallet(_name,'Wallet of team: '||_name,_teamStartMoney);

        -- Insert a new row
        INSERT INTO team(name,net,wallet) VALUES(_name,_inet,_walletId);

        RETURN LASTVAL();
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
        _newsMsg := 'Thanks to '||_teamName||' for raising an issue to admins ('||_pts||' pts)';
        PERFORM addNews(_newsMsg,current_timestamp::timestamp);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
                                       DISPLAY_INTERVAL, 'Scoreboard', 'Bonus', NULL, NULL);
                _flagIds := array_append(_flagIds,_flagId);
            END LOOP;
        elsif _typeCode = 22 then   -- Group Bonus
            FOR _i IN SELECT generate_series 
                FROM generate_series(_pts,1,_ptsStep)
            LOOP
                _flagName := _name || '_' || _i::text;
                _flagDesc := '';
                _flagId := addRandomFlag(_flagName, _i, NULL, 'scoreboard.hf', 'bonus', 1,
                                       DISPLAY_INTERVAL, 'Scoreboard', 'Bonus', NULL, NULL);
                _flagIds := array_append(_flagIds,_flagId);
            END LOOP;
        elsif _typeCode = 32 then   -- Team Group Pokemon
            _flagName := _name || '_Pokemon';
            _flagDesc := '';
            _flagId := addRandomFlag(_flagName, _pts, NULL, 'scoreboard.hf', 'bonus', 1,
                                   DISPLAY_INTERVAL, 'Scoreboard', 'Bonus', NULL, NULL);
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
                                    _author flagAuthor.name%TYPE,
                                    _type flagType.name%TYPE,
                                    _typeExt flagTypeExt.name%TYPE,
                                    _description flag.description%TYPE
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
        raise notice 'addFlag(%,%,%,%,%,%,%,%,%,%,%,%)',$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12;    
    
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
            SELECT id INTO _authorId FROM flagAuthor WHERE name = _author;
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
                        type,typeExt,description)
                VALUES(_name,_value,_pts,_cash,_hostId,_catId,_statusCode,_display,_authorId,
                        _typeCode,_typeExtId,_description);

        RETURN LASTVAL();
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addRandomFlag(...);
*/
CREATE OR REPLACE FUNCTION addRandomFlag(_name flag.name%TYPE, 
                                    _pts flag.pts%TYPE,
                                    _cash flag.cash%TYPE,
                                    _host host.name%TYPE,
                                    _category flagCategory.name%TYPE,
                                    _statusCode flagStatus.code%TYPE,
                                    _displayInterval varchar(20),
                                    _author flagAuthor.name%TYPE,
                                    _type flagType.name%TYPE,
                                    _typeExt flagTypeExt.name%TYPE,
                                    _description flag.description%TYPE
                                    ) 
RETURNS flag.id%TYPE AS $$
    DECLARE
        _flagId flag.id%TYPE;
        _flagValue flag.value%TYPE;
    BEGIN
        -- Logging
        raise notice 'addRandomFlag(%,%,%,%,%,%,%,%,%,%,%)',$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11;    

        -- Loop just to be sure that we get no collision with random_32()
        LOOP
            BEGIN
                -- Generate a king flag
                SELECT random_32() INTO _flagValue;

                -- addFlag
                SELECT addFlag(_name,_flagValue,_pts,_cash,_host,_category,_statusCode,
                                _displayInterval,_author,_type,_typeExt,_description)
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
        _flagId flag.id%TYPE := NULL;
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
RETURNS text AS $$
    DECLARE
        _teamRec team%ROWTYPE;
        _flagRec RECORD;
        _rowCount smallint;
        _teamAttempts smallint;
        _playerIp inet;
        _settings settings%ROWTYPE;
        _pts flag.pts%TYPE;
        _ret text := '';
        ANTI_BF_INT interval := '20 second';
        ANTI_BF_LIMIT integer := 20;
        STATUS_CODE_OK integer := 1;
        FLAG_MAX_LENGTH integer := 64;
        FLAG_TYPE_STANDARD flagType.code%TYPE := 1;
        FLAG_TYPE_KING flagType.code%TYPE := 11;
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
        -- tableId 1 = flag, category 2 = kingFlag
        SELECT * FROM (
            SELECT id,value,pts,cash,statusCode,type,1 AS tableId
            FROM flag 
            WHERE statusCode = STATUS_CODE_OK and value = _flagValue and type <> 11
              UNION ALL
            SELECT id,value,pts,NULL,NULL,NULL,2 AS tableId
            FROM kingFlag 
            WHERE value = _flagValue
        ) AS x INTO _flagRec;

        -- if the flag is found, determine if it is a flag or a kingFlag
        -- then assign the flag
        GET DIAGNOSTICS _rowCount = ROW_COUNT;
        if _rowCount = 1 then
            if _flagRec.tableId = 1 then
                -- If flag is standard or king, process now. Otherwise, manage in processNonStandardFlag() function.
                if _flagRec.type = FLAG_TYPE_STANDARD or _flagRec.type = FLAG_TYPE_KING then
                    _pts := _flagRec.pts;
                    _ret = _ret || 'Congratulations. You received ' || _flagRec.pts::text || 'pts for this flag. ';

                    -- Give cash if flag contains cash
                    if _flagRec.cash is not NULL and _flagRec.cash <> 0 then
                        PERFORM transferCashFlag(_flagRec.id,_teamRec.id);
                        _ret = _ret || 'You also received ' || _flagRec.cash::text || '$.';
                    end if;
                else
                    SELECT *
                    FROM processNonStandardFlag(_flagRec.id,_teamRec.id,_playerIp)
                    INTO _pts,_ret;
                end if;
                INSERT INTO team_flag(teamId,flagId,pts,playerIp)
                        VALUES(_teamRec.id,_flagRec.id,_pts,_playerIp);
            elsif _flagRec.tableId = 2 then
                INSERT INTO team_kingFlag(teamId,kingFlagId,playerIp)
                        VALUES(_teamRec.id,_flagRec.id,_playerIp);
                _ret = _ret || 'Congratulations. You received ' || _flagRec.pts::text || 'pts for this flag. ';
            end if;
        else
            raise exception 'Invalid flag';
        end if;

        -- PERFORM addEvent(_ret,'flag');

        RETURN _ret;
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
                flagPts flag.pts%TYPE,
                kingFlagPts kingFlag.pts%TYPE,
                flagTotal flag.pts%TYPE,
                cash text
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
            raise exception 'Game is not started yet. Game will start at: %',_settings.gameStartTs;
        end if;

        -- Some check 
        if _top <= 0 then
            raise exception '_top argument cannot be a negative value. _top=%',_top;
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
                            coalesce(tf3.sum::integer,0) AS flagPts,
                            coalesce(tfi3.sum::integer,0) AS kingFlagPts,
                            (coalesce(tf3.sum::integer,0) + coalesce(tfi3.sum::integer,0)) AS flagTotal,
                            w.amount::text || ' $' AS cash
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
                                WHERE f.type <> 2
                                ) as f ON tf.flagId = f.id
                            WHERE tf.teamId = _teamId
                            ) AS tf2
                        GROUP BY tf2.category
                        ) AS tf3 ON c.id = tf3.category
                     LEFT OUTER JOIN (
                         SELECT f2.category,
                                sum(f2.pts) AS sum
                         FROM flag AS f2
                         WHERE f2.type <> 2
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
        _settings settings%ROWTYPE;
        KING_FLAG_TYPE flagType.code%TYPE := 11;
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
                            tf2.pts AS pts,
                            f.pts AS flagPts,
                            (coalesce(tf2.pts,0) || '/' || f.pts)::varchar AS displayPts,
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
                updateCmd flagTypeExt.updateCmd%TYPE,
                statusCode flag.statusCode%TYPE
              ) AS $$
    DECLARE
        KING_FLAG_TYPE flagType.code%TYPE := 11;
    BEGIN
        -- Logging
        raise notice 'getAllKingFlags()';
    
        return QUERY SELECT f.id,
                            f.name,
                            h.name AS host,
                            fte.updateCmd,
                            f.statusCode
                     FROM flag AS f
                     LEFT OUTER JOIN (
                        SELECT host.id,
                               host.name
                        FROM host
                        ) AS h ON h.id = f.host
                     LEFT OUTER JOIN (
                        SELECT fte.updateCmd
                        FROM flagTypeExt AS fte
                        ) AS fte ON fte.id = f.typeExt
                     WHERE f.type = KING_FLAG_TYPE;
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
                updateCmd flagTypeExt.updateCmd%TYPE,
                statusCode flag.statusCode%TYPE
              ) AS $$
    DECLARE
        KING_FLAG_TYPE flagType.code%TYPE := 11;
    BEGIN
        -- Logging
        raise notice 'getKingFlagsFromHost(%)',$1;
    
        return QUERY SELECT f.id,
                            f.name,
                            h.name AS host,
                            fte.updateCmd,
                            f.statusCode
                     FROM flag AS f
                     LEFT OUTER JOIN (
                        SELECT host.id,
                               host.name
                        FROM host
                        ) AS h ON h.id = f.host
                     LEFT OUTER JOIN (
                        SELECT fte.updateCmd
                        FROM flagTypeExt AS fte
                        ) AS fte ON fte.id = f.typeExt
                     WHERE f.type = KING_FLAG_TYPE and h.name = _host;
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
                updateCmd flagTypeExt.updateCmd%TYPE,
                statusCode flag.statusCode%TYPE
              ) AS $$
    DECLARE
        KING_FLAG_TYPE flagType.code%TYPE := 11;
    BEGIN
        -- Logging
        raise notice 'getKingFlagsFromName(%)',$1;
    
        return QUERY SELECT f.id,
                            f.name,
                            h.name AS host,
                            fte.updateCmd,
                            f.statusCode
                     FROM flag AS f
                     LEFT OUTER JOIN (
                        SELECT host.id,
                               host.name
                        FROM host
                        ) AS h ON h.id = f.host
                     LEFT OUTER JOIN (
                        SELECT fte.updateCmd
                        FROM flagTypeExt AS fte
                        ) AS fte ON fte.id = f.typeExt
                     WHERE f.type = KING_FLAG_TYPE and f.name = _name;
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
        
        if _intLimit is NULL then
            _intLimit := 21;        -- Kinda redundant...
        end if;

        if _intLimit < 1 then
            raise exception 'Interval Limit cannot be NULL or lower than 1';
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

        RETURN QUERY SELECT unnest(array['gameStartTs','gameEndTs','teamStartMoney'])::text AS "Key", 
                            unnest(array[gameStartTs::text,gameEndTs::text,teamStartMoney::text])::text as "Value" 
                     FROM settings;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: insertRandomData()

    TODOO : Make this function work again. It's broken.
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
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis elementum sem non porttitor vestibulum.'
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
    Stored Proc: addBMItemCategory(name,displayName,description)
*/
CREATE OR REPLACE FUNCTION addBMItemCategory(_name bmItemCategory.name%TYPE, 
                                       _displayName bmItemCategory.displayName%TYPE,
                                       _description bmItemCategory.description%TYPE) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addBMItemCategory(%,%,%)',$1,$2,$3;

        -- Insert a new row
        INSERT INTO bmItemCategory(name,displayName,description)
                VALUES(_name,_displayName,_description);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addBMItemStatus(code,name,description)
*/
CREATE OR REPLACE FUNCTION addBMItemStatus(_code bmItemStatus.code%TYPE,
                                    _name bmItemStatus.name%TYPE, 
                                    _description text default ''
                                    ) 
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addBMItemStatus(%,%,%)',$1,$2,$3;

        -- Insert a new row
        INSERT INTO bmItemStatus(code,name,description)
                VALUES(_code,_name,_description);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: setBMItemStatus(_bmItemId,_bmItemStatusCode)
*/
CREATE OR REPLACE FUNCTION setBMItemStatus(_bmItemId bmItem.id%TYPE,
                                           _bmItemStatusCode bmItem.statusCode%TYPE)
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'setBMItemStatus(%,%)',$1,$2;

        -- Update bmItem
        UPDATE bmItem
        SET statusCode = _bmItemStatusCode
        WHERE id = _bmItemId;
        
        -- Insert a new row in history
        INSERT INTO bmItemStatus_history(bmItemId,statusCode)
                VALUES(_bmItemId,_bmItemStatusCode);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: addBMItem(name,category,statusCode,ownerWallet,amount,qty,displayInterval,desc)
*/
CREATE OR REPLACE FUNCTION addBMItem(_name bmItem.name%TYPE, 
                                    _category bmItemCategory.name%TYPE,
                                    _statusCode bmItemStatus.code%TYPE,
                                    _ownerWallet bmItem.ownerWallet%TYPE,
                                    _amount bmItem.amount%TYPE,
                                    _qty bmItem.qty%TYPE,
                                    _displayInterval varchar(20),
                                    _description bmItem.description%TYPE,
                                    _data bmItem.data%TYPE) 
RETURNS integer AS $$
    DECLARE
        _bmItemId bmItem.id%TYPE;
        _catId bmItemCategory.id%TYPE;
        _display bmItem.displayInterval%TYPE;
    BEGIN
        -- Logging
        raise notice 'addBMItem(%,%,%,%,%,%,%)',$1,$2,$3,$4,$5,$6,$7;

        -- Get category id from name
        SELECT id INTO _catId FROM bmItemCategory WHERE name = _category;
        if not FOUND then
            raise exception 'Could not find category "%"',_category;
        end if;

        -- Verify status code exist
        PERFORM code FROM bmItemStatus WHERE code = _statusCode;
        if not FOUND then
            raise exception 'Could not find status code "%"',_statusCode;
        end if;

        -- Verify amount
        if _amount <= 0 then
            raise exception 'Black market item cannot cost < 0';
        end if;

        -- Verify quantity
        if _qty is not NULL and _qty <= 0 then
            raise exception 'Black market item quantity cannot be < 0';
        end if;

        -- Convert displayInterval
        if _displayInterval is not NULL then
            _display = _displayInterval::interval;
        else
            _display = _displayInterval;
        end if;

        -- Insert a new row
        INSERT INTO bmItem(name,category,statusCode,ownerWallet,amount,qty,displayInterval,description,privateId,data)
                VALUES(_name,_catId,_statusCode,_ownerWallet,_amount,_qty,_display,_description,random_64(),_data);
        _bmItemId := LASTVAL();

        -- Set initial status
        PERFORM setBMItemStatus(_bmItemId,_statusCode);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql;

/*
    Stored Proc: listBMItems(_top)
*/
CREATE OR REPLACE FUNCTION listBMItems(_top integer DEFAULT 30)
RETURNS TABLE (
                id bmItem.id%TYPE,
                name bmItem.name%TYPE,
                category bmItemCategory.displayName%TYPE,
                status bmItemStatus.name%TYPE,
                rating text,
                owner wallet.name%TYPE,
                cost bmItem.amount%TYPE,
                qty text
              ) AS $$

    BEGIN
        return QUERY SELECT i.id AS id,
                            i.name AS name,
                            ic.displayName AS category,
                            ist.name AS status,
                            CASE WHEN ir.rating is NULL THEN '-' ELSE ir.rating::text || '/5' END,
                            w.name AS owner,
                            i.amount AS cost,
                            CASE WHEN i.qty is NULL THEN '-' ELSE i.qty::text END
                     FROM bmItem AS i
                     LEFT OUTER JOIN (
                        SELECT ic.id,ic.displayName 
                        FROM bmItemCategory AS ic
                        ) AS ic ON i.category = ic.id
                     LEFT OUTER JOIN (
                        SELECT ist.code,ist.name
                        FROM bmItemStatus AS ist
                        ) AS ist ON i.statusCode = ist.code
                     LEFT OUTER JOIN (
                        SELECT ir.id,ir.rating
                        FROM bmItemReview AS ir
                        ) AS ir ON i.review = ir.id
                     LEFT OUTER JOIN (
                        SELECT w.id,w.name
                        FROM wallet AS w
                        ) AS w ON i.ownerWallet = w.id
                    ORDER BY i.id
                    LIMIT _top;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: listBMItemsUpdater(_top)
*/
CREATE OR REPLACE FUNCTION listBMItemsUpdater(_top integer DEFAULT 30)
RETURNS TABLE (
                id bmItem.id%TYPE,
                name bmItem.name%TYPE,
                category bmItemCategory.name%TYPE,
                status bmItemStatus.code%TYPE,
                statusName bmItemStatus.name%TYPE,
                owner wallet.name%TYPE,
                qty bmItem.qty%TYPE,
                privateId bmItem.privateId%TYPE,
                dlLink bmItem.dlLink%TYPE
              ) AS $$

    BEGIN
        return QUERY SELECT i.id AS id,
                            i.name AS name,
                            ic.name AS category,
                            ist.code AS status,
                            ist.name AS statusName,
                            w.name AS owner,
                            i.qty AS qty,
                            i.privateId as privateId,
                            i.dlLink as dlLink
                     FROM bmItem AS i
                     LEFT OUTER JOIN (
                        SELECT ic.id,ic.name
                        FROM bmItemCategory AS ic
                        ) AS ic ON i.category = ic.id
                     LEFT OUTER JOIN (
                        SELECT ist.code,ist.name
                        FROM bmItemStatus AS ist
                        ) AS ist ON i.statusCode = ist.code
                     LEFT OUTER JOIN (
                        SELECT w.id,w.name
                        FROM wallet AS w
                        ) AS w ON i.ownerWallet = w.id
                    ORDER BY i.id
                    LIMIT _top;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getBMItemInfo()
*/
CREATE OR REPLACE FUNCTION getBMItemInfo(_bmItemId bmItem.id%TYPE)
RETURNS TABLE (
                info varchar(30),
                value varchar(100)
              ) AS $$
    DECLARE
        _ret RECORD;
        _qty varchar(20);
    BEGIN
        -- Logging
        raise notice 'getBMItemInfo(%)',$1;

        SELECT i.id AS id,
                i.name AS name,
                i.description AS description,
                ic.name AS catName,
                ic.displayName AS catDisplay,
                ist.code AS statusCode,
                ist.name AS statusName,
                ir.rating AS rating,
                ir.comments AS comments,
                w.name AS owner,
                i.amount AS cost,
                i.qty AS qty
         INTO _ret
         FROM bmItem AS i
         LEFT OUTER JOIN (
            SELECT ic.id,ic.name,ic.displayName 
            FROM bmItemCategory AS ic
            ) AS ic ON i.category = ic.id
         LEFT OUTER JOIN (
            SELECT ist.code,ist.name
            FROM bmItemStatus AS ist
            ) AS ist ON i.statusCode = ist.code
         LEFT OUTER JOIN (
            SELECT ir.id,ir.rating,ir.comments
            FROM bmItemReview AS ir
            ) AS ir ON i.review = ir.id
         LEFT OUTER JOIN (
            SELECT w.id,w.name
            FROM wallet AS w
            ) AS w ON i.ownerWallet = w.id
        WHERE i.id = _bmItemId;

        if _ret.qty is NULL then
            _qty := 'infinite';
        else
            _qty := _ret.qty::varchar;
        end if;
        
        -- Return
        RETURN QUERY SELECT 'ID'::varchar, _ret.id::varchar
                     UNION ALL SELECT 'Name'::varchar, _ret.name
                     UNION ALL SELECT 'Description'::varchar, _ret.description
                     UNION ALL SELECT 'Category'::varchar, _ret.catDisplay
                     UNION ALL SELECT 'Status'::varchar, _ret.statusName
                     UNION ALL SELECT 'Rating'::varchar, _ret.rating::varchar
                     UNION ALL SELECT 'Comments'::varchar, _ret.comments
                     UNION ALL SELECT 'Owner'::varchar, _ret.owner
                     UNION ALL SELECT 'Cost'::varchar, _ret.cost::varchar 
                     UNION ALL SELECT 'Qty'::varchar, _qty;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
/*
    Stored Proc: checkTeamSolvency(teamId,itemId)
*/
CREATE OR REPLACE FUNCTION checkTeamSolvency(_teamId team.id%TYPE,
                                             _itemId bmItem.id%TYPE)
RETURNS integer AS $$
    DECLARE
        _walletId wallet.id%TYPE;
        _walletAmount wallet.amount%TYPE;
        _bmItemAmount bmItem.amount%TYPE;
    BEGIN
        -- Logging
        raise notice 'checkTeamSolvency(%,%)',$1,$2;

        -- Get team walletId
        SELECT wallet INTO _walletId FROM team WHERE id = _teamId;
        if not FOUND then
            raise exception 'Could not find the team ID "%"',_teamId;
        end if;

        -- Get wallet amount
        SELECT amount INTO _walletAmount FROM wallet WHERE id = _walletId;
        if not FOUND then
            raise exception 'Could not find the wallet of team ID "%"',_teamId;
        end if;

        -- Get black market item amount
        SELECT amount INTO _bmItemAmount FROM bmItem WHERE id = _itemId;
        if not FOUND then
            raise exception 'Could not find the black market item ID "%"',_itemId;
        end if;

        -- Check that the player has enough money
        if _walletAmount < _bmItemAmount then
            raise exception 'Not enough money to buy the item';
        end if;

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: checkItemAvailability(bmItemId,teamId=NULL)
*/
CREATE OR REPLACE FUNCTION checkItemAvailability(_bmItemId bmItem.id%TYPE,
                                                 _teamId team.id%TYPE DEFAULT NULL)
RETURNS integer AS $$
    DECLARE
        _bmItemRec bmItem%ROWTYPE;
        _bmItemStatus bmItemStatus.name%TYPE;
    BEGIN
        -- Logging
        raise notice 'checkItemAvailability(%,%)',$1,$2;

        -- Get black market item record
        SELECT * INTO _bmItemRec FROM bmItem WHERE id = _bmItemId;
        if not FOUND then
            raise exception 'Could not find the black market item ID "%"',_bmItemId;
        end if;

        -- Check item status
        if _bmItemRec.statusCode > 1 then
            SELECT name INTO _bmItemStatus FROM bmItemStatus WHERE id = _bmItemRec.statusCode;
            raise exception 'Item is not available. Current status: "%"',_bmItemStatus;
        end if;

        -- Check item qty
        if _bmItemRec.qty = 0 then
            raise exception 'Item is out of stock.';
        end if;

        -- if a teamId is specified.
        if _teamId is not NULL then
            -- Determine if the team already bought this item
            PERFORM id FROM team_bmItem WHERE teamId = _teamId AND bmItemId = _bmItemId;
            if FOUND then
                raise exception 'Item "%" was already acquired by team "%"',_bmItemId,_teamId;
            end if;

            -- Determine if the team is the item's owner
            PERFORM t.id,
                    t.wallet 
            FROM team AS t
            LEFT OUTER JOIN (
                SELECT id,
                       ownerWallet
                FROM bmItem 
            ) AS bmi ON t.wallet = bmi.ownerWallet
            WHERE t.id= _teamId AND bmi.id = _bmItemId;
            if FOUND then
                raise exception 'You cannot buy an item you are selling';
            end if;
        end if;

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: buyBMItemFromIp(bmItemId,playerIp)
*/
CREATE OR REPLACE FUNCTION buyBMItemFromIp(_bmItemId bmItem.id%TYPE,
                                           _playerIpStr varchar(20))
RETURNS integer AS $$
    DECLARE
        _playerIp inet;
        _teamId team.id%TYPE;
        _teamName team.name%TYPE;
        _teamWalletId wallet.id%TYPE;
        _ownerWalletId wallet.id%TYPE;
        _bmItemName bmItem.name%TYPE;
        _bmItemAmount bmItem.amount%TYPE;
        _bmItemQty bmItem.qty%TYPE;
        BMI_SOLD_STATUS bmItemStatus.code%TYPE := 2;
        TR_BOUGHT_CODE transactionType.code%TYPE := 3;
    BEGIN
        -- Logging
        raise notice 'buyBMItem(%,%)',$1,$2;

        -- Get team from userIp 
        _playerIp := _playerIpStr::inet;
        SELECT id,name INTO _teamId,_teamName FROM team where _playerIp << net ORDER BY id DESC LIMIT 1;
        if NOT FOUND then
            raise exception 'Team not found for %',_playerIp;
        end if;

        -- Check team solvency
        PERFORM checkTeamSolvency(_teamId,_bmItemId);

        -- Check item availability
        PERFORM checkItemAvailability(_bmItemId,_teamId);

        -- Get team wallet ID
        SELECT wallet INTO _teamWalletId FROM team WHERE id = _teamId;

        -- Transfer money
        SELECT name,ownerWallet,amount,qty INTO _bmItemName,_ownerWalletId,_bmItemAmount,_bmItemQty 
        FROM bmItem WHERE id = _bmItemId;
        PERFORM transferMoney(_teamWalletId,_ownerWalletId,_bmItemAmount,TR_BOUGHT_CODE);

        -- Assign item
        INSERT INTO team_bmItem(teamId,bmItemId,playerIp)
               VALUES(_teamId,_bmItemId,_playerIp);

        -- Update qty
        UPDATE bmItem
        SET qty = qty - 1
        WHERE id = _bmItemId;

        -- Update status if needed
        if _bmItemQty = 1 then
            PERFORM setBMItemStatus(_bmItemId,BMI_SOLD_STATUS);
        end if;

        PERFORM addEvent(format('Team "%s" successfully bought item "%s" on the black market',_teamName,_bmItemName),'bm');

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: sellBMItemFromIp(name,amount,qty,desc,data,playerIp)
*/
CREATE OR REPLACE FUNCTION sellBMItemFromIp(_name bmItem.name%TYPE, 
                                    _amount bmItem.amount%TYPE,
                                    _qty bmItem.qty%TYPE,
                                    _description bmItem.description%TYPE,
                                    _data bmItem.data%TYPE, 
                                    _playerIpStr varchar(20))
RETURNS integer AS $$
    DECLARE
        _playerIp inet;
        _teamName team.name%TYPE;
        _ownerWalletId bmItem.ownerWallet%TYPE;
        _catId bmItemCategory.id%TYPE;
        _catName bmItemCategory.name%TYPE := 'player';
        BMI_APPROVAL_STATUS bmItemStatus.code%TYPE := 3;
    BEGIN
        -- Logging
        raise notice 'sellBMItemFromIp(%,%,%,%,%)',$1,$2,$3,$4,$5;

        -- Get team from userIp 
        _playerIp := _playerIpStr::inet;
        SELECT name,wallet INTO _teamName,_ownerWalletId FROM team where _playerIp << net ORDER BY wallet DESC LIMIT 1;
        if NOT FOUND then
            raise exception 'Team not found for %',_playerIp;
        end if;

        -- Add a new black market item
        PERFORM addBMItem(_name,_catName,BMI_APPROVAL_STATUS,_ownerWalletId,_amount,_qty,NULL,_description,_data);

        PERFORM addEvent(format('Team "%s" submitted an item "%s" on the black market.',_teamName,_name),'bm');

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: reviewBMItem(bmItemId,bmItemStatus,rating,comments)
*/
CREATE OR REPLACE FUNCTION reviewBMItem(_bmItemId bmItem.id%TYPE,
                                        _statusCode bmItemStatus.code%TYPE,
                                        _rating bmItemReview.rating%TYPE,
                                        _comments bmItemReview.comments%TYPE)
RETURNS integer AS $$
    DECLARE
        _reviewId bmItemReview.id%TYPE;
        _bmItemName bmItem.name%TYPE;
        CAT_PLAYER bmItemCategory.name%TYPE := 'player';
    BEGIN
        -- Logging
        raise notice 'reviewBMItem(%,%,%,%)',$1,$2,$3,$4;

        -- Can only review player items
        SELECT bmi.name
        INTO _bmItemName
        FROM bmItem AS bmi
        LEFT OUTER JOIN (
            SELECT id,
                   name
            FROM bmItemCategory AS c
        ) AS c ON bmi.category = c.id
        WHERE bmi.id = _bmItemId
            AND c.name = CAT_PLAYER
        LIMIT 1;
        if NOT FOUND then
            raise exception 'Black market player item "%" not found',_bmItemId;
        end if;

        -- Insert review
        INSERT INTO bmItemReview(rating,comments) VALUES(_rating,_comments);
        _reviewId := LASTVAL();

        -- Assign review
        UPDATE bmItem
        SET review = _reviewId
        WHERE id = _bmItemId;

        -- Update status
        PERFORM setBMItemStatus(_bmItemId,_statusCode);

        PERFORM addEvent(format('Item "%s" was reviewed by an admin.',_bmItemName),'bm');

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: publishBMItem(bmItemId,bmItemDLLink)
*/
CREATE OR REPLACE FUNCTION publishBMItem(_bmItemId bmItem.id%TYPE,
                                         _bmItemDLLink bmItem.dlLink%TYPE)
RETURNS integer AS $$
    DECLARE
        BMI_FORSALE_STATUS bmItemStatus.code%TYPE := 1;
        BMI_TOPUBLISH_STATUS bmItemStatus.code%TYPE := 6;
        _bmItemStatusName bmItemStatus.name%TYPE;
    BEGIN
        -- Logging
        raise notice 'publishBMItem(%,%)',$1,$2;

        -- Can only publish items with status "To Publish"
        SELECT ist.name
        INTO _bmItemStatusName
        FROM bmItem AS bmi
        LEFT OUTER JOIN (
            SELECT code,
                   name
            FROM bmItemStatus AS ist
        ) AS ist ON bmi.statusCode = ist.code
        WHERE bmi.id = _bmItemId
            AND bmi.statusCode <> BMI_TOPUBLISH_STATUS
        LIMIT 1;
        if NOT FOUND then
            raise exception 'Wrong black market item status for publishing. Current status: "%"',_bmItemStatusName;
        end if;

        -- Update status
        PERFORM setBMItemStatus(_bmItemId,BMI_FORSALE_STATUS);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getBMItemDataFromIp(privateId,playerIp)
*/
CREATE OR REPLACE FUNCTION getBMItemDataFromIp(_privateId bmItem.privateId%TYPE,
                                               _playerIpStr varchar(20))
RETURNS bytea AS $$
    DECLARE
        _bmItemId bmItem.id%TYPE;
        _teamId team.id%TYPE;
        _playerIp inet;
        _data bmItem.data%TYPE;
    BEGIN
        -- Logging
        raise notice 'getBMItemDataFromIp(%,%)',$1,$2;

        _playerIp := _playerIpStr::inet;

        -- Get bmItemId FROM privateId
        SELECT id INTO _bmItemId FROM bmItem WHERE privateId = _privateId;
        if NOT FOUND then
            raise exception 'You do not have permission to download this item';
        end if;

        -- Get teamId FROM playerIp
        SELECT id INTO _teamId FROM team WHERE _playerIp << net;
        if NOT FOUND then
            raise exception 'You do not have permission to download this item';
        end if;

        -- Verify that the team have successfuly bought the item
        PERFORM id FROM team_bmItem WHERE teamId = _teamId AND bmItemId = _bmItemId;
        if NOT FOUND then
            raise exception 'You do not have permission to download this item';

            -- Reset the item's private ID is an authorized access was performed
            UPDATE bmItem
            SET privateId = random(64)
            WHERE id = _bmItemId;
        end if;

        -- Return data
        SELECT data INTO _data FROM bmItem WHERE id = _bmItemId;
        return _data;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addEventFacility(code,name,displayName,desc)
*/
CREATE OR REPLACE FUNCTION addEventFacility(_code eventSeverity.code%TYPE,
                                            _name eventSeverity.name%TYPE,
                                            _displayName eventFacility.displayName%TYPE, 
                                            _description eventFacility.description%TYPE)
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addEventFacility(%,%,%,%)',$1,$2,$3,$4;

        -- Some checks
        if _name is NULL then
            raise exception 'Name cannot be NULL';
        end if;

        if _displayName is NULL then
            raise exception 'Display name cannot be NULL';
        end if;

        -- Insert a new row
        INSERT INTO eventFacility(code,name,displayName,description) VALUES(_code,_name,_displayName,_description);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addEventSeverity(code,name,displayName,desc)
*/
CREATE OR REPLACE FUNCTION addEventSeverity(_code eventSeverity.code%TYPE,
                                            _name eventSeverity.name%TYPE,
                                            _displayName eventSeverity.displayName%TYPE, 
                                            _description eventSeverity.description%TYPE)
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addEventSeverity(%,%,%,%)',$1,$2,$3,$4;

        -- Some checks
        if _name is NULL then
            raise exception 'Name cannot be NULL';
        end if;

        if _displayName is NULL then
            raise exception 'Display name cannot be NULL';
        end if;

        -- Insert a new row
        INSERT INTO eventSeverity(code,name,displayName,description) VALUES(_code,_name,_displayName,_description);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addEvent(title,facility,severity)
*/
CREATE OR REPLACE FUNCTION addEvent(_title event.title%TYPE,
                                            _facility eventFacility.name%TYPE DEFAULT NULL,
                                            _severity eventSeverity.name%TYPE DEFAULT NULL)
RETURNS integer AS $$
    DECLARE
        _facilityCode eventFacility.code%TYPE := NULL;
        _severityCode eventSeverity.code%TYPE := NULL;
    BEGIN
        -- Logging
        raise notice 'addEvent(%,%,%)',$1,$2,$3;

        -- Get facilityCode if name is specified
        if _facility is not NULL then
            SELECT code INTO _facilityCode FROM eventFacility WHERE name = _facility;
            if NOT FOUND then
                raise exception 'Could not find facility "%"',_facility;
            end if;
        end if;

        -- Get severityCode if name is specified
        if _severity is not NULL then
            SELECT code INTO _severityCode FROM eventSeverity WHERE name = _severity;
            if NOT FOUND then
                raise exception 'Could not find severity "%"',_severity;
            end if;
        end if;

        -- Insert a new row
        INSERT INTO event(title,facility,severity) 
        VALUES(_title,_facilityCode,_severityCode);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getEvents(lastUpdateTS,facility,severity,grep,top)
*/
CREATE OR REPLACE FUNCTION getEvents(_lastUpdateTS timestamp DEFAULT NULL,
                                     _facility eventFacility.name%TYPE DEFAULT NULL,
                                     _severity eventSeverity.name%TYPE DEFAULT NULL,
                                     _grep varchar(30) DEFAULT NULL,
                                     _top integer DEFAULT 300)
RETURNS TABLE (
                title event.title%TYPE,
                facility eventFacility.name%TYPE,
                severity eventSeverity.name%TYPE,
                ts event.ts%TYPE
              ) AS $$

    BEGIN
        return QUERY SELECT * FROM (
                     (SELECT e.title AS title,
                            ef.name AS facility,
                            es.name AS severity,
                            e.ts AS ts
                     FROM event AS e
                     LEFT OUTER JOIN (
                        SELECT ef.code,ef.name
                        FROM eventFacility AS ef
                        ) AS ef ON e.facility = ef.code
                     LEFT OUTER JOIN (
                        SELECT es.code,es.name
                        FROM eventSeverity AS es
                        ) AS es ON e.severity = es.code
                     )
                        UNION ALL
                     (
                     SELECT n.title,
                            'news',
                            NULL,
                            n.displayTs
                     FROM news AS n
                     )
                     ) AS t
                    WHERE (_lastUpdateTs IS NULL OR t.ts >= _lastUpdateTs)
                        AND (_facility IS NULL OR t.facility LIKE '%'||_facility||'%')
                        AND (_severity IS NULL OR t.severity LIKE '%'||_severity||'%')
                        AND (_grep IS NULL OR t.title LIKE '%'||_grep||'%')
                    ORDER BY t.ts
                    LIMIT _top;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addTeamVariables(teamId,name,value)
*/
CREATE OR REPLACE FUNCTION addTeamVariables(_teamId team.id%TYPE,
                                           _name teamVariables.value%TYPE,
                                           _value teamVariables.value%TYPE)
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addTeamVariables(%,%,%)',$1,$2,$3;

        -- Some checks
        if _name is NULL then
            raise exception 'Name cannot be NULL';
        end if;

        -- Insert a new row
        INSERT INTO teamVariables(teamId,name,value) VALUES(_teamId,_name,_value);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getTeamVariables(grep,top)
*/
CREATE OR REPLACE FUNCTION getTeamsVariables(_grep varchar(30) DEFAULT NULL,
                                            _top integer DEFAULT 30) 
RETURNS TABLE (                             
                TeamName team.name%TYPE,
                name teamVariables.name%TYPE,
                value teamVariables.value%TYPE
              ) AS $$
    BEGIN
        -- Logging
        raise notice 'getTeamsVariables(%,%)',$1,$2;

        -- Get team's settings
        return QUERY SELECT a.teamName,
                            a.name,
                            a.value
                     FROM (
                         SELECT tv.teamId,
                                tv.name,
                                tv.value,
                                t.name AS teamName
                         FROM teamVariables AS tv
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

/*
    Stored Proc: getTeamVariablesFromIp(playerIp)
*/
CREATE OR REPLACE FUNCTION getTeamVariablesFromIp(_playerIpStr varchar) 
RETURNS TABLE (
                name teamVariables.name%TYPE,
                value teamVariables.value%TYPE
              ) AS $$
    DECLARE
        _playerIp inet;
        _teamId team.id%TYPE;
    BEGIN
        -- Logging
        raise notice 'getTeamVariablesFromIp(%)',$1;

        -- Convert player IP
        _playerIp := _playerIpStr::inet;

        -- Determine player's team
        SELECT id INTO _teamId FROM team where _playerIp << net LIMIT 1;
        if NOT FOUND then
            raise exception 'Team not found for %',_playerIp;
        end if;

        -- Get team's settings
        return QUERY SELECT ts.name,
                            ts.value
                     FROM teamVariables
                     WHERE teamId = _teamId;
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
            raise exception 'Team not found for %',_playerIp;
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
