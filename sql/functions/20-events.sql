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
                                            _facility eventFacility.name%TYPE DEFAULT 'global',
                                            _severity eventSeverity.name%TYPE DEFAULT 'notice')
RETURNS integer AS $$
    DECLARE
        _facilityCode eventFacility.code%TYPE := NULL;
        _severityCode eventSeverity.code%TYPE := NULL;
    BEGIN
        -- Logging
        raise notice 'addEvent(%,%,%)',$1,$2,$3;

        if _title is NULL or _title = '' then
            raise exception 'Invalid event';
        end if;

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
    Stored Proc: getEventsFromIp(lastUpdateTS,facility,severity,grep,top)
    TODOO: Restrict specific events
*/
CREATE OR REPLACE FUNCTION getEventsFromIp(_lastUpdateTS timestamp,
                                     _facility eventFacility.name%TYPE,
                                     _severity eventSeverity.name%TYPE,
                                     _grep varchar(30),
                                     _top integer, 
                                     _playerIpStr varchar(20))
RETURNS TABLE (
                title event.title%TYPE,
                facility eventFacility.name%TYPE,
                severity eventSeverity.name%TYPE,
                ts event.ts%TYPE
              ) AS $$
    DECLARE
        _playerIp inet;
    BEGIN
        _playerIp := _playerIpStr::inet;

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

-- getAuthorList()

