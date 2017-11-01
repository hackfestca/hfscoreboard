/* 
    Stored Proc: submitFeedbacks(rate,comments,teamId)
*/ 
CREATE OR REPLACE FUNCTION submitFeedbacks(_rate feedbacks.rate%TYPE,
                                      _comments feedbacks.comments%TYPE,
                                      _teamId team.id%TYPE,
                                      _playerIpStr varchar(20)) 
RETURNS text AS $$
    DECLARE
        _playerIp inet;
        _ret text := '';
        _flagId flag.id%TYPE;
        _flagName flag.name%TYPE;
        _flagDesc flag.description%TYPE;
        _pts flag.pts%TYPE := 5;
        _submitCount smallint;
        MAX_SUBMIT_COUNT integer := 4;
    BEGIN
        -- Logging
        raise notice 'submitFeedbacks(%,%,%,%)',$1,$2,$3,$4;
    
        _playerIp := _playerIpStr::inet;

        -- Get the number of submission of the team
        SELECT count(*)
        INTO _submitCount
        FROM feedbacks
        WHERE teamId = _teamId;

        -- Determine if the team reached the max submit count.
        if _submitCount >= MAX_SUBMIT_COUNT then
            PERFORM raise_p(format('We received enough submissions from your team (%s/%s). Thank you for playing the CTF.',_submitCount, MAX_SUBMIT_COUNT));
        end if;

        -- Save feedback
        INSERT INTO feedbacks(rate, comments, playerIp, teamId)
               VALUES(_rate, _comments, _playerIp, _teamId);

        -- Generate flag
        _flagName := 'Feedbacks'||current_timestamp::varchar;
        _flagDesc := 'For submitting feedbacks.';
        _flagId := addRandomFlag(_flagName, _pts, NULL, 'scoreboard.hf', 'feedbacks', 1, 
                                 NULL, 'HFCrew', 'Standard', NULL, NULL, NULL, NULL, NULL, NULL, _flagDesc);

        -- Assign flag
        INSERT INTO team_flag(teamId,flagId,pts,playerIp)
               VALUES(_teamId,_flagId,_pts,_playerIp);

        _ret := format('Thank you for submitting feedbacks. Your team just received %spts. Please ask your teammates to submit too. %s submission are remaining.', _pts, MAX_SUBMIT_COUNT - _submitCount - 1);

        RETURN _ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/* 
    Stored Proc: submitFeedbacksFromIp(userIp,flagValue)
*/ 
CREATE OR REPLACE FUNCTION submitFeedbacksFromIp(_rate feedbacks.rate%TYPE,
                                                _comments feedbacks.comments%TYPE,
                                                _playerIpStr varchar(20)) 
RETURNS text AS $$
    DECLARE
        _teamId team.id%TYPE;
        _playerIp inet;
    BEGIN
        -- Logging
        raise notice 'submitFeedbacksFromIp(%,%,%)',$1,$2,$3;
    
        _playerIp := _playerIpStr::inet;

        -- Get team from teamId
        SELECT id INTO _teamId FROM team where _playerIp << net ORDER BY id DESC LIMIT 1;
        if NOT FOUND then
            PERFORM raise_p(format('Team not found for IP %s',_playerIp));
        end if;

        RETURN submitFeedbacks(_rate,_comments,_teamId,_playerIpStr);
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/* 
    Stored Proc: submitFeedbacksPerCategory(category,rate,comments,teamId,playerIP)
*/ 
CREATE OR REPLACE FUNCTION submitFeedbacksPerCategory(_categoryId flagCategory.id%TYPE,
                                      _rate feedbacks.rate%TYPE,
                                      _comments feedbacks.comments%TYPE,
                                      _teamId team.id%TYPE,
                                      _playerIpStr varchar(20)) 
RETURNS text AS $$
    DECLARE
        _playerIp inet;
        _ret text := '';
        _submitCount smallint;
    BEGIN
        -- Logging
        raise notice 'submitFeedbacksPerCategory(%,%,%,%,%)',$1,$2,$3,$4,$5;
    
        _playerIp := _playerIpStr::inet;

        -- Save feedback
        INSERT INTO feedbacksPerCategory(categoryId, rate, comments, playerIp, teamId)
               VALUES(_categoryId, _rate, _comments, _playerIp, _teamId);

        RETURN _ret;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/* 
    Stored Proc: submitFeedbacksFromIp(userIp,flagValue)
*/ 
CREATE OR REPLACE FUNCTION submitFeedbacksPerCategoryFromIp(_categoryId flagCategory.id%TYPE,
                                                _rate feedbacks.rate%TYPE,
                                                _comments feedbacks.comments%TYPE,
                                                _playerIpStr varchar(20)) 
RETURNS text AS $$
    DECLARE
        _teamId team.id%TYPE;
        _playerIp inet;
    BEGIN
        -- Logging
        raise notice 'submitFeedbacksPerCategoryFromIp(%,%,%,%)',$1,$2,$3,$4;
    
        _playerIp := _playerIpStr::inet;

        -- Get team from teamId
        SELECT id INTO _teamId FROM team where _playerIp << net ORDER BY id DESC LIMIT 1;
        if NOT FOUND then
            PERFORM raise_p(format('Team not found for IP %s',_playerIp));
        end if;

        RETURN submitFeedbacksPerCategory(_categoryId,_rate,_comments,_teamId,_playerIpStr);
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

