
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
    Stored Proc: getBMItemCategoryList()
*/
CREATE OR REPLACE FUNCTION getBMItemCategoryList()
RETURNS TABLE (
                name bmItemCategory.name%TYPE,
                description bmItemCategory.description%TYPE
              ) AS $$

    BEGIN
        return QUERY SELECT c.name,
                            c.description
                    FROM bmItemCategory AS c
                    ORDER BY c.id;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
    Stored Proc: getBMItemStatusList()
*/
CREATE OR REPLACE FUNCTION getBMItemStatusList()
RETURNS TABLE (
                code bmItemStatus.code%TYPE,
                name bmItemStatus.name%TYPE,
                description bmItemStatus.description%TYPE
              ) AS $$

    BEGIN
        return QUERY SELECT s.code,
                            s.name,
                            s.description
                    FROM bmItemStatus AS s
                    ORDER BY s.code;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: addBMItem(name,category,statusCode,ownerWallet,amount,qty,displayInterval,desc,data)
*/
CREATE OR REPLACE FUNCTION addBMItem(_name bmItem.name%TYPE, 
                                    _category bmItemCategory.name%TYPE,
                                    _statusCode bmItemStatus.code%TYPE,
                                    _ownerWallet bmItem.ownerWallet%TYPE,
                                    _amount bmItem.amount%TYPE,
                                    _qty bmItem.qty%TYPE,
                                    _displayInterval varchar(20),
                                    _description bmItem.description%TYPE,
                                    _importName bmItem.importName%TYPE,
                                    _data bmItem.data%TYPE,
                                    _updateCmd bmItem.updateCmd%TYPE) 
RETURNS bmItem.id%TYPE AS $$
    DECLARE
        _bmItemId bmItem.id%TYPE;
        _catId bmItemCategory.id%TYPE;
        _display bmItem.displayInterval%TYPE;
        _privateId bmItem.privateId%TYPE;
        _dlLink bmItem.dlLink%TYPE;
        -- DL_LINK bmItem.dlLink%TYPE := 'https://scoreboard.hf/bmi/?privateId=%s';
        DL_LINK bmItem.dlLink%TYPE := 'https://scoreboard.hf/blackmarket/%s%s';
    BEGIN
        -- Logging
        raise notice 'addBMItem(%,%,%,%,%,%,%,%,%,%,%)',$1,$2,$3,$4,$5,$6,$7,$8,$9,'data',$11;

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

        -- Set privateId
        _privateId := random_64();

        -- Set download link
        _dlLink := format(DL_LINK,_privateId,_importName);

        -- Insert a new row
        INSERT INTO bmItem(name,category,statusCode,ownerWallet,amount,
                    qty,displayInterval,description,privateId,importName,data,dlLink,updateCmd)
                VALUES(_name,_catId,_statusCode,_ownerWallet,_amount,
                        _qty,_display,_description,_privateId,_importName,_data,_dlLink,_updateCmd);
        _bmItemId := LASTVAL();

        -- Set initial status
        PERFORM setBMItemStatus(_bmItemId,_statusCode);

        RETURN _bmItemId;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: modBMItem(id,name,amount,qty,displayInterval,desc,data)
*/
CREATE OR REPLACE FUNCTION modBMItem(_id bmItem.id%TYPE,
                                    _name bmItem.name%TYPE, 
                                    _amount bmItem.amount%TYPE,
                                    _qty bmItem.qty%TYPE,
                                    _displayInterval varchar(20),
                                    _description bmItem.description%TYPE)
RETURNS integer AS $$
    DECLARE
        _display bmItem.displayInterval%TYPE;
    BEGIN
        -- Logging
        raise notice 'modBMItem(%,%,%,%,%,%)',$1,$2,$3,$4,$5,$6;

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
        UPDATE bmItem
        SET name = _name,
            amount = _amount,
            qty = _qty,
            displayInterval = _display,
            description = _description
        WHERE id = _id;

        PERFORM addEvent(format('The item "%s" was updated by an admin with name="%s",amount="%s"',
                        _id,_name,_amount),'bm');

        RETURN 0;
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
                i.qty AS qty,
                i.dllink AS link
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
                     UNION ALL SELECT 'Qty'::varchar, _qty
                     UNION ALL SELECT 'Link'::varchar, _ret.link;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getBMItemInfo()
*/
CREATE OR REPLACE FUNCTION getBMItemInfoFromIp(_bmItemId bmItem.id%TYPE,
                                               _playerIpStr varchar(20))
RETURNS TABLE (
                info varchar(30),
                value varchar(100)
              ) AS $$
    DECLARE
        _ret RECORD;
        _qty varchar(20);
        _playerIp inet;
        _teamId team.id%TYPE;
        _link varchar;
    BEGIN
        -- Logging
        raise notice 'getBMItemInfo(%)',$1;

        _playerIp := _playerIpStr::inet;

        -- Get teamId FROM playerIp
        SELECT team.id INTO _teamId FROM team WHERE _playerIp << net;
        if NOT FOUND then
            raise exception 'Your team does not exist';
        end if;

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
                i.qty AS qty,
                i.dlLink AS link
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

        -- Check if the item was bought
        -- if bought, set _link variable
        PERFORM id FROM team_bmItem
        WHERE teamId = _teamId
            and bmItemId = _bmItemId;
        if FOUND then
            _link = _ret.link;
        else
            _link = NULL;
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
                     UNION ALL SELECT 'Qty'::varchar, _qty
                     UNION ALL SELECT 'Link'::varchar, _link;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getBMItemLink(id)
*/
CREATE OR REPLACE FUNCTION getBMItemLink(_bmItemId bmItem.id%TYPE)
RETURNS text AS $$
    DECLARE
        _teamId team.id%TYPE;
        _dllink bmItem.dlLink%TYPE;
    BEGIN
        -- Logging
        raise notice 'getBMItemLink(%)',$1;

        -- Return data
        SELECT dllink INTO _dllink FROM bmItem WHERE id = _bmItemId;
        return _dllink;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getBMItemLinkFromIp(id)
*/
CREATE OR REPLACE FUNCTION getBMItemLinkFromIp(_bmItemId bmItem.id%TYPE,
                                               _playerIpStr varchar(20))
RETURNS text AS $$
    DECLARE
        _teamId team.id%TYPE;
        _playerIp inet;
        _dllink bmItem.dlLink%TYPE;
    BEGIN
        -- Logging
        raise notice 'getBMItemLinkFromIp(%,%)',$1,$2;

        _playerIp := _playerIpStr::inet;

        -- Get teamId FROM playerIp
        SELECT id INTO _teamId FROM team WHERE _playerIp << net;
        if NOT FOUND then
            PERFORM raise_p(format('You do not have permission to download this item'));
        end if;

        -- Verify that the team have successfuly bought the item
        PERFORM id FROM team_bmItem WHERE teamId = _teamId AND bmItemId = _bmItemId;
        if NOT FOUND then
            PERFORM raise_p(format('You have not bought the item yet.'));

            -- Reset the item's private ID is an authorized access was performed
            UPDATE bmItem
            SET privateId = random(64)
            WHERE id = _bmItemId;
        end if;

        -- Return data
        SELECT dllink INTO _dllink FROM bmItem WHERE id = _bmItemId;
        return _dllink;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getBMItemData(privateId,playerIp)
*/
CREATE OR REPLACE FUNCTION getBMItemData(_id bmItem.id%TYPE)
RETURNS bmItem.data%TYPE AS $$
    DECLARE
        _data bmItem.data%TYPE;
    BEGIN
        -- Logging
        raise notice 'getBMItemData(%)',$1;

        -- Return data
        SELECT data INTO _data FROM bmItem WHERE id = _id;
        return _data;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: getBMItemDataFromIp(id,playerIp)
*/
CREATE OR REPLACE FUNCTION getBMItemDataFromIp(_bmItemId bmItem.id%TYPE,
                                               _playerIpStr varchar(20))
RETURNS bytea AS $$
    DECLARE
        _teamId team.id%TYPE;
        _playerIp inet;
        _data bmItem.data%TYPE;
    BEGIN
        -- Logging
        raise notice 'getBMItemDataFromIp(%,%)',$1,$2;

        _playerIp := _playerIpStr::inet;

        -- Get teamId FROM playerIp
        SELECT id INTO _teamId FROM team WHERE _playerIp << net;
        if NOT FOUND then
            PERFORM raise_p(format('You do not have permission to download this item'));
        end if;

        -- Verify that the team have successfuly bought the item
        PERFORM id FROM team_bmItem WHERE teamId = _teamId AND bmItemId = _bmItemId;
        if NOT FOUND then
            PERFORM raise_p(format('You have not bought the item yet.'));

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
            PERFORM raise_p(format('You do not have permission to download this item'));
        end if;

        -- Get teamId FROM playerIp
        SELECT id INTO _teamId FROM team WHERE _playerIp << net;
        if NOT FOUND then
            PERFORM raise_p(format('You do not have permission to download this item'));
        end if;

        -- Verify that the team have successfuly bought the item
        PERFORM id FROM team_bmItem WHERE teamId = _teamId AND bmItemId = _bmItemId;
        if NOT FOUND then
            PERFORM raise_p(format('You have not bought the item yet.'));

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
    Stored Proc: getBMItemList(_top)
*/
CREATE OR REPLACE FUNCTION getBMItemList(_top integer DEFAULT 30)
RETURNS TABLE (
                id bmItem.id%TYPE,
                name bmItem.name%TYPE,
                description bmItem.description%TYPE,
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
                            i.description AS description,
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
    Stored Proc: getBMItemListFromIp(top,playerIp)
*/
CREATE OR REPLACE FUNCTION getBMItemListFromIp(_top integer,
                                         _playerIpStr varchar(20))
RETURNS TABLE (
                id bmItem.id%TYPE,
                name bmItem.name%TYPE,
                description bmItem.description%TYPE,
                category bmItemCategory.displayName%TYPE,
                status bmItemStatus.name%TYPE,
                rating text,
                owner wallet.name%TYPE,
                cost bmItem.amount%TYPE,
                qty text,
                bought boolean
              ) AS $$
    DECLARE
        _playerIp inet;
        _teamId team.id%TYPE;
        _aTeamItems integer[];
    BEGIN
        _playerIp := _playerIpStr::inet;

        -- Get teamId FROM playerIp
        SELECT team.id INTO _teamId FROM team WHERE _playerIp << net;
        if NOT FOUND then
            PERFORM raise_p(format('Your team does not exist'));
        end if;

        -- Get list of item already bought
        SELECT array(select bmItemId from team_bmItem WHERE teamId = _teamId) INTO _aTeamItems;
        
        return QUERY SELECT i.id AS id,
                            i.name AS name,
                            i.description AS description,
                            ic.displayName AS category,
                            ist.name AS status,
                            CASE WHEN ir.rating is NULL THEN '-' ELSE ir.rating::text || '/5' END,
                            w.name AS owner,
                            i.amount AS cost,
                            CASE WHEN i.qty is NULL THEN '-' ELSE i.qty::text END,
                            CASE WHEN i.id = ANY(_aTeamItems) THEN true ELSE false END
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
    Stored Proc: getBMItemListUpdater(_top)
*/
CREATE OR REPLACE FUNCTION getBMItemListUpdater(_top integer DEFAULT 30)
RETURNS TABLE (
                id bmItem.id%TYPE,
                name bmItem.name%TYPE,
                category bmItemCategory.name%TYPE,
                status bmItemStatus.code%TYPE,
                statusName bmItemStatus.name%TYPE,
                owner wallet.name%TYPE,
                qty bmItem.qty%TYPE,
                privateId bmItem.privateId%TYPE,
                importName bmItem.importName%TYPE,
                updateCmd bmItem.updateCmd%TYPE
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
                            i.importName as importName,
                            i.updateCmd as updateCmd
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
    Stored Proc: getBMItemPrivateId(_bmItemId)
*/
CREATE OR REPLACE FUNCTION getBMItemPrivateId(_bmItemId bmItem.id%TYPE)
RETURNS bmItem.privateId%TYPE AS $$
    DECLARE
        _privateId bmItem.privateId%TYPE;
    BEGIN
        SELECT privateId INTO _privateId FROM bmItem WHERE id = _bmItemId LIMIT 1;
        if not FOUND then
            raise exception 'Could not find the black market item id "%"',_bmItemId::text;
        end if;

        return _privateId;
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
            PERFORM raise_p(format('Team not found for %',_playerIp));
        end if;

        -- Check item availability
        PERFORM checkItemAvailability(_bmItemId,_teamId);

        -- Check team solvency
        PERFORM checkTeamSolvency(_teamId,_bmItemId);

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
        --raise notice 'sellBMItemFromIp(%,%,%,%,%,%)',$1,$2,$3,$4,'data',$6;
        raise notice 'sellBMItemFromIp(%,%,%,%,%,%)',$1,$2,$3,$4,'data',$6;

        -- Get team from userIp 
        _playerIp := _playerIpStr::inet;
        SELECT name,wallet INTO _teamName,_ownerWalletId FROM team where _playerIp << net ORDER BY wallet DESC LIMIT 1;
        if NOT FOUND then
            PERFORM raise_p(format('Team not found for %',_playerIp));
        end if;

        -- Add a new black market item
        PERFORM addBMItem(_name,_catName,BMI_APPROVAL_STATUS,_ownerWalletId,_amount,_qty,NULL,_description,random_32(),_data,NULL);

        PERFORM addEvent(format('Team "%s" submitted an item "%s" on the black market.',_teamName,_name),'bm');

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
    Stored Proc: reviewBMItem(bmItemId,bmItemStatus,rating,comments)
*/
CREATE OR REPLACE FUNCTION reviewBMItem(_bmItemId bmItem.id%TYPE,
                                        _approve boolean,
                                        _rating bmItemReview.rating%TYPE,
                                        _comments bmItemReview.comments%TYPE)
RETURNS integer AS $$
    DECLARE
        _reviewId bmItemReview.id%TYPE;
        _bmItemName bmItem.name%TYPE;
        _statusCode bmItemStatus.code%TYPE;
        CAT_PLAYER bmItemCategory.name%TYPE := 'player';
    BEGIN
        -- Logging
        raise notice 'reviewBMItem(%,%,%,%)',$1,$2,$3,$4;

        -- Get status code from _approve
        if _approve then
            _statusCode = 7;    -- 7 = READY TO RETRIEVE
        else
            _statusCode = 4;    -- 4 = REFUSED BY ADMIN
        end if;

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

        PERFORM addEvent(format('Item "%s" was published by the scoreboard.',_bmItemId),'bm');

        RETURN 0;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
