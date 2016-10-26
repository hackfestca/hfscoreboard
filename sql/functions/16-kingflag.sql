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

