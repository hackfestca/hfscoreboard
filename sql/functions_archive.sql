/*
    Stored Proc: buyLotoFromIp(amount,playerIp)
*/
CREATE OR REPLACE FUNCTION buyLotoFromIp(_playerIpStr varchar(20))
RETURNS text AS $$
    DECLARE
        TR_LOTO_CODE transactionType.code%TYPE := 5;
        LOTO_ID wallet.id%TYPE := 2;
        _playerIp inet;
        _teamName team.name%TYPE;
        _srcWalletId team.id%TYPE;
        _amount wallet.amount%TYPE := 1000;
    BEGIN
        -- Logging
        raise notice 'buyLotoFromIp(%)',$1;
    
        _playerIp := _playerIpStr::inet;

        -- Get team from userIp 
        SELECT name,wallet INTO _teamName,_srcWalletId FROM team where _playerIp << net ORDER BY id DESC LIMIT 1;
        if NOT FOUND then
            PERFORM raise_p(format('Team not found for %',_playerIp));
        end if;

        PERFORM transferMoney(_srcWalletId,LOTO_ID,_amount,TR_LOTO_CODE);

        -- DB Logging
        PERFORM addEvent(format('Team %s have bought a loto ticket for %s$.',_teamName,_amount),'loto');

        RETURN format('You successfully bought a ticket for %s$',_amount::text);
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
        PERFORM addNews(_ret,NOW()::timestamp);
        PERFORM addEvent(_ret,'loto');

        RETURN _ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getLotoCurrentList(_top)
*/
CREATE OR REPLACE FUNCTION getLotoCurrentList(_top integer DEFAULT 30)  
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
        _lastWinTs transaction.ts%TYPE;
        _gameStartTs settings.gameStartTS%TYPE;
    BEGIN
        -- Logging
        raise notice 'getLotoCurrentList(%)',$1;

        -- Some check 
        if _top <= 0 then
            PERFORM raise_p(format('_top argument cannot be a negative value. _top=%',_top));
        end if;

        -- Get last win timestamp
        SELECT t.ts
        INTO _lastWinTs
        FROM transaction AS t
        WHERE type = TR_LOTO_CODE
            and srcWalletId = LOTO_ID
        ORDER BY t.ts DESC LIMIT 1;

        if _lastWinTs IS NULL then
            -- Get team starting money
            SELECT gameStartTs into _lastWinTs FROM settings AS st ORDER BY st.ts DESC LIMIT 1;
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
                        and t.dstWalletId = LOTO_ID
                        and t.ts > _lastWinTs
                    ORDER BY t.ts
                    LIMIT _top;
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
            PERFORM raise_p(format('_top argument cannot be a negative value. _top=%',_top));
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
    Stored Proc: getLotoInfo(_top)
*/
CREATE OR REPLACE FUNCTION getLotoInfo()
RETURNS TABLE (
                info varchar(50),
                value varchar(250)
              ) AS $$
    DECLARE
        TR_LOTO_CODE transactionType.code%TYPE := 5;
        LOTO_ID wallet.id%TYPE := 2;
        _drawingAmount transaction.amount%TYPE;
        _lastWinTs transaction.ts%TYPE;
    BEGIN
        -- Logging
        raise notice 'getLotoInfo()';

        -- Get last win timestamp
        SELECT ts
        INTO _lastWinTs
        FROM transaction
        WHERE type = TR_LOTO_CODE
            and srcWalletId = LOTO_ID
        ORDER BY ts DESC LIMIT 1;

        -- Get current drawing amount
        SELECT SUM(amount)
        INTO _drawingAmount
        FROM transaction
        WHERE type = TR_LOTO_CODE
            and srcWalletId = LOTO_ID
            and ts > _lastWinTs;

        -- Return
        RETURN QUERY SELECT 'Amount'::varchar, coalesce(_drawingAmount,0)::varchar
                     UNION ALL SELECT 'Last Win time'::varchar, coalesce(to_char(_lastWinTs,'HH24:MI:SS'),'not won yet')::varchar;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/* 
    Model related
*/

/*
    Stored Proc: getModelCountDown()
*/
CREATE OR REPLACE FUNCTION getModelCountDown()
RETURNS varchar(8) AS $$
    DECLARE
        _ret varchar(8);
        _format text := 'HH24:MI:SS';
    BEGIN
        -- Logging
        raise notice 'getModelCountDown()';
                      
        SELECT to_char((gameEndTs - NOW()::timestamp),_format) INTO _ret FROM settings;
        
        -- Return
        RETURN _ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getModelNews()
*/
CREATE OR REPLACE FUNCTION getModelNews(_pos integer DEFAULT 0)
RETURNS varchar(500) AS $$
    DECLARE
        _maxLineLen integer := 20;
        _ret varchar(500);
    BEGIN
        -- Logging
        raise notice 'getModelNews()';

        SELECT substring(title from (_pos*_maxLineLen) for _maxLineLen) INTO _ret FROM getNewsList() ORDER BY displayts DESC LIMIT 1;

        -- Return
        RETURN _ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getModelTeamsTop()
*/
CREATE OR REPLACE FUNCTION getModelTeamsTop(_pos integer DEFAULT 0)
RETURNS varchar(40) AS $$
    DECLARE
        _ret varchar(40);
    BEGIN
        -- Logging
        raise notice 'getModelTeamsTop()';

        SELECT (_pos+1) || '- ' || team INTO _ret FROM getScore() LIMIT 1 OFFSET _pos;
        
        -- Return
        RETURN _ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addGateKey(value)
*/
CREATE OR REPLACE FUNCTION addGateKey(_value gateKey.value%TYPE)
RETURNS integer AS $$
    BEGIN
        -- Logging
        raise notice 'addGateKey(%)',$1;

        -- Insert a new row
        INSERT INTO gateKey(value) VALUES(_value);

        RETURN LASTVAL();
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: assignGateKey(teamId)
*/
CREATE OR REPLACE FUNCTION assignGateKey(_teamId team.id%TYPE)
RETURNS integer AS $$
    DECLARE
        _gateKeyRec gateKey%ROWTYPE;
    BEGIN
        -- Logging
        raise notice 'assignGateKey(%)',$1;

        -- Get unique and unused gateKey
        SELECT id,value INTO _gateKeyRec FROM gateKey WHERE used = False LIMIT 1;

        -- Set the gatekey as Used
        UPDATE gateKey SET used = True WHERE id = _gateKeyRec.id;

        -- Create a team secret 
        PERFORM addTeamSecrets(_teamId,'Gate Key',_gateKeyRec.value);

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

