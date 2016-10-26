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
            PERFORM raise_p(format('_top argument cannot be a negative value. _top=%',_top));
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
            PERFORM raise_p(format('_top argument cannot be a negative value. _top=%',_top));
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

