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

