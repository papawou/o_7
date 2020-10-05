/*
FRIEND_REQUEST
--creator
friend_request_create
friend_request_cancel
--target
friend_request_accept
friend_request_deny
*/
--creator
CREATE OR REPLACE FUNCTION friendrequest_create(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    --auth
    PERFORM pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    PERFORM FROM friends WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target);
    IF FOUND THEN RAISE EXCEPTION 'already_friends'; END IF;
    PERFORM FROM user_bans WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target);
    IF FOUND THEN RAISE EXCEPTION 'users_block'; END IF;

    INSERT INTO friend_requests(id_usera, id_userb, status, created_by)
      VALUES(LEAST(_id_viewer, _id_target), GREATEST(_id_viewer,_id_target), 'WAITING', _id_viewer);
    RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION friendrequest_cancel(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    DELETE FROM friend_requests
      WHERE id_usera=LEAST(_id_viewer, _id_target)
        AND id_userb=GREATEST(_id_viewer, _id_target)
        AND created_by=_id_viewer;
    RETURN FOUND;
END
$$ LANGUAGE plpgsql;

--target
CREATE OR REPLACE FUNCTION friendrequest_accept(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    SELECT pg_advisory_xact_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    DELETE FROM friend_requests
      WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target) AND created_by<>_id_viewer;
    IF NOT FOUND THEN RAISE EXCEPTION 'friend_request not found'; END IF;

    INSERT INTO friends(id_usera, id_userb) VALUES(least(_id_viewer, _id_target), greatest(_id_viewer, _id_target));
    INSERT INTO follows(id_follower, id_following) VALUES(_id_viewer, _id_target), (_id_target, _id_viewer) ON CONFLICT DO NOTHING;
    RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION friendrequest_deny(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    UPDATE friend_requests
      SET status='DENIED'
      WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target)
        AND status='WAITING' AND created_by<>_id_viewer;

    RETURN FOUND;
END
$$ LANGUAGE plpgsql;

/*
FRIEND
friend_delete
*/
CREATE OR REPLACE FUNCTION friend_delete(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    DELETE FROM friends WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target);
    RETURN FOUND;
END
$$ LANGUAGE plpgsql;

/*
FOLLOW
user_follow
user_unfollow
*/
CREATE OR REPLACE FUNCTION user_follow(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    PERFORM FROM user_bans WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target);
    IF FOUND THEN RAISE EXCEPTION 'unauthorized'; END IF;
    INSERT INTO follows(id_follower, id_following) VALUES(_id_viewer, _id_target);
    RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION user_unfollow(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    DELETE FROM follows WHERE id_follower=_id_viewer AND id_following=_id_target;
    RETURN FOUND;
END
$$ LANGUAGE plpgsql;

/*
 user_ban
 user_unban
*/
CREATE OR REPLACE FUNCTION user_ban(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
DECLARE
    -- __lobbys_id_owner record;
BEGIN
    SELECT pg_advisory_xact_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    INSERT INTO user_bans(id_usera, id_userb, created_by)
        VALUES(LEAST(_id_viewer, _id_target), GREATEST(_id_viewer, _id_target), _id_viewer);
    IF NOT FOUND THEN RAISE EXCEPTION 'ban_failed'; END IF;
    DELETE FROM friends WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target);
    DELETE FROM follows WHERE (id_follower=_id_viewer AND id_following=_id_target) OR (id_follower=_id_target AND id_following=_id_viewer);
    DELETE FROM friend_requests WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target);
    /*
    FOR __lobbys_id_owner IN (SELECT id_lobby, id_user as id_owner FROM lobby_users WHERE (fk_member=_id_viewer OR id_user=_id_target) AND is_owner IS TRUE FOR SHARE) LOOP
        SELECT pg_advisory_xact_lock(hashtextextended('lobby_user:'||__lobbys_id_owner.id_lobby, (CASE WHEN __lobbys_id_owner.id_owner=_id_viewer THEN _id_target ELSE _id_viewer END)));
        DELETE FROM lobby_users WHERE id_lobby=__lobbys_id_owner.id_lobby AND id_user=(CASE WHEN __lobbys_id_owner.id_owner=_id_viewer THEN _id_target ELSE _id_viewer END) ;
        IF FOUND THEN UPDATE lobby_slots SET free_slots=free_slots+1 WHERE id_lobby=__lobbys_id_owner.id_lobby ; END IF;
    END LOOP;
    */
    RETURN TRUE;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION user_unban(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    SELECT pg_advisory_xact_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    DELETE FROM user_bans WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target) AND created_by=_id_viewer;
    RETURN FOUND;
END
$$ LANGUAGE plpgsql;
