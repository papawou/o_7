CREATE OR REPLACE FUNCTION create_event(IN _id_game integer, IN _id_platform integer, IN _size integer, IN _need_request boolean, OUT __id_event integer) RETURNS integer AS
$$
BEGIN
    INSERT INTO events
        (id_game, id_platform, size, need_request)
    VALUES
        (_id_game, _id_platform, _size, _need_request) RETURNING id INTO __id_event;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION close_event(_id_event integer, OUT __success boolean) RETURNS boolean AS
$$
BEGIN
    UPDATE events
        SET is_log=true
        WHERE id=_id_event AND is_log=false;
    IF NOT FOUND THEN RAISE EXCEPTION 'FAILED'; END IF;

    DELETE FROM eventrequests WHERE id_event=_id_event;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cancel_event(_id_event integer, OUT __success boolean) RETURNS boolean AS
$$
DECLARE
    ___deleted_members integer[];
    ___deleted_requests integer[];
BEGIN
    SET CONSTRAINTS ALL DEFERRED;
    DELETE FROM events WHERE id=_id_event AND is_log=false;

    WITH deleted_members AS(
        DELETE FROM eventmembers WHERE id_event=_id_event RETURNING id_user
    )
    SELECT array_agg(id_user) INTO ___deleted_members FROM deleted_members;

    WITH deleted_requests AS(
        DELETE FROM eventrequests WHERE id_event=_id_event RETURNING id_user, status
    )
    SELECT array_agg(id_user) INTO ___deleted_requests FROM deleted_requests WHERE status='PENDING';

    __success := true;
END;
$$ LANGUAGE plpgsql;
/*
    USERS ACTION
*/
    --NORMAL
CREATE OR REPLACE FUNCTION join_event_direct(IN _id_event integer, IN _id_viewer integer, OUT __success boolean) RETURNS boolean AS
$$
BEGIN
    UPDATE events SET current_size=current_size+1
        WHERE id=_id_event AND need_request=false AND is_log=false AND current_size+1 <= size;
    IF NOT FOUND THEN RAISE EXCEPTION 'EVENT NOT FOUND'; END IF;

    INSERT INTO eventmembers(id_event, id_user) VALUES (_id_event, _id_viewer);
    IF NOT FOUND THEN RAISE EXCEPTION 'FAILED INSERT MEMBER'; END IF;

    __success := true;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION leave_event(in _id_event integer, IN _id_viewer integer, OUT __success boolean) RETURNS boolean AS
$$
BEGIN
    DELETE FROM eventmembers
        WHERE id_event=_id_event AND id_user=_id_viewer AND is_log=false;
    IF NOT FOUND THEN RAISE EXCEPTION 'FAILED'; END IF;

    __success:= true;
END;
$$ LANGUAGE plpgsql;

    --REQUEST
CREATE OR REPLACE FUNCTION join_event_request(IN _id_event integer, IN _id_viewer integer, OUT __success boolean) RETURNS boolean AS
$$
BEGIN
    INSERT INTO eventrequests(id_event, id_user) VALUES (_id_event, _id_viewer);
    IF NOT FOUND THEN RAISE EXCEPTION 'FAILED'; END IF;

    __success := true;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cancel_eventrequest(_id_request integer, _id_viewer integer, OUT __success boolean) RETURNS boolean AS
$$
BEGIN
    DELETE FROM eventrequests
        WHERE id=_id_request AND status='PENDING'::eventrequest_status AND id_user=_id_viewer;
    IF NOT FOUND THEN RAISE EXCEPTION 'FAILED'; END IF;

    __success := FOUND;
END;
$$ LANGUAGE plpgsql;

/*
    MANAGE EVENT REQUEST
*/
CREATE OR REPLACE FUNCTION accept_eventrequest(_id_request integer, OUT __success boolean) RETURNS boolean AS
$$
DECLARE
    ___data_request record;
BEGIN
    UPDATE eventrequests
        SET status='ACCEPTED'::eventrequest_status
        WHERE id=_id_request AND status='PENDING'::eventrequest_status
    RETURNING id_event, id_user INTO ___data_request;
    IF NOT FOUND THEN RAISE EXCEPTION 'FAILED'; END IF;

    UPDATE events
        SET current_size=events.current_size+1
        WHERE id=___data_request.id_event;
    IF NOT FOUND THEN RAISE EXCEPTION 'FAILED'; END IF;

    INSERT INTO eventmembers(id_event, id_user) VALUES(___data_request.id_event, ___data_request.id_user);
    IF NOT FOUND THEN RAISE EXCEPTION 'FAILED'; END IF;

    __success := FOUND;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION deny_eventrequest(_id_request integer, OUT __success boolean) RETURNS boolean AS
$$
BEGIN
    UPDATE eventrequests
        SET status='DENIED'::eventrequest_status
        WHERE id=_id_request AND status='PENDING'::eventrequest_status;
    IF NOT FOUND THEN RAISE EXCEPTION 'FAILED'; END IF;

    __success := FOUND;
END;
$$ LANGUAGE plpgsql;