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
            PERFORM raise_p(format('Could not find the source wallet "%s"',_srcWalletId));
        end if;

        PERFORM id FROM wallet WHERE id = _dstWalletId;
        if not FOUND then
            PERFORM raise_p(format('Could not find the destination wallet "%s"',_dstWalletId));
        end if;

        if _amount < 0.01 then
            PERFORM raise_p(format('Cannot transfer less than 0.01$'));
        end if;

        if _amount < 0 then
            PERFORM raise_p(format('Cannot transfer negative value'));
        end if;

        if _amount = 0 then
            PERFORM raise_p(format('Cannot transfer a null value'));
        end if;

        PERFORM code FROM transactionType WHERE code = _transactionTypeCode;
        if not FOUND then
            PERFORM raise_p(format('Could not find transaction type "%s"',_transactionTypeCode));
        end if;

        -- Verify source wallet has enough money to transfer the amount
        PERFORM id,amount FROM wallet WHERE id = _srcWalletId and (amount - _amount) >= 0;
        if not FOUND then
            PERFORM raise_p(format('Sender does not have enough money'));
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

