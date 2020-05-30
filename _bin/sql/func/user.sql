/*
add_friend
accept_friend_request
deny_friend_request
cancel_friend_request

delete_friend

follow_user
unfollow_user

ban_user
unban_user
*/
--friend
CREATE OR REPLACE FUNCTION add_friend(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    PERFORM FROM user_friends WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target);
    IF FOUND THEN RAISE EXCEPTION 'already_friends'; END IF;
    PERFORM FROM user_bans WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target) AND ban_resolved_at < NOW();
    IF FOUND THEN RAISE EXCEPTION 'users_block'; END IF;

    INSERT INTO user_friends_request(id_usera, id_userb, status)
      VALUES(LEAST(_id_viewer, _id_target), GREATEST(_id_viewer,_id_target), CASE WHEN _id_viewer<_id_target THEN 'WAITING_B'::user_friends_request_status ELSE 'WAITING_A'::user_friends_request_status END);
    IF FOUND THEN RETURN TRUE; ELSE RETURN FALSE; END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_friend(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    SELECT pg_advisory_xact_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    DELETE FROM user_friends WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target);
    IF FOUND THEN RETURN TRUE; ELSE RETURN FALSE; END IF;
END
$$ LANGUAGE plpgsql;

--friend_request
CREATE OR REPLACE FUNCTION friend_request(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    SELECT pg_advisory_xact_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    DELETE FROM user_friends_request
      WHERE id_usera=least(_id_viewer, _id_target)
        AND id_userb=greatest(_id_viewer, _id_target)
        AND (status=(CASE WHEN id_usera=_id_viewer THEN 'WAITING_A'::user_friends_request_status ELSE 'WAITING_B'::user_friends_request_status END)
         OR status=(CASE WHEN id_usera=_id_viewer THEN 'DENIED_BY_A'::user_friends_request_status ELSE 'DENIED_BY_B'::user_friends_request_status END));
    IF NOT FOUND THEN RAISE EXCEPTION 'friend_request not found'; END IF;
    INSERT INTO user_friends(id_usera, id_userb) VALUES(least(_id_viewer, _id_target), greatest(_id_viewer, _id_target));
    IF FOUND THEN RETURN TRUE; ELSE RETURN FALSE; END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION friend_request_deny(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    UPDATE user_friends_request
      SET status=(CASE WHEN id_usera=_id_viewer THEN 'DENIED_BY_A'::user_friends_request_status ELSE 'DENIED_BY_B'::user_friends_request_status END)
      WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target)
        AND status=(CASE WHEN id_usera=_id_viewer THEN 'WAITING_B'::user_friends_request_status ELSE 'WAITING_A'::user_friends_request_status END);
    IF FOUND THEN RETURN TRUE; ELSE RETURN FALSE; END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION friend_request_cancel(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    DELETE FROM user_friends_request
      WHERE id_usera=LEAST(_id_viewer, _id_target)
        AND id_userb=GREATEST(_id_viewer, _id_target)
        AND status=(CASE WHEN id_usera=_id_viewer THEN 'WAITING_B'::user_friends_request_status ELSE 'WAITING_A'::user_friends_request_status END);
    IF FOUND THEN RETURN TRUE; ELSE RETURN FALSE; END IF;
END
$$ LANGUAGE plpgsql;

--follow
CREATE OR REPLACE FUNCTION follow_user(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    SELECT pg_advisory_xact_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    PERFORM FROM user_bans WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target) AND ban_resolved_at > NOW();
    IF FOUND THEN RAISE EXCEPTION 'unauthorized'; END IF;
    INSERT INTO user_followers(id_follower, id_following) VALUES(_id_viewer, _id_target);
    IF FOUND THEN RETURN TRUE; ELSE RETURN FALSE; END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION unfollow_user(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    SELECT pg_advisory_xact_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    DELETE FROM user_followers WHERE id_follower=_id_viewer AND id_following=_id_target;
    IF FOUND THEN RETURN TRUE; ELSE RETURN FALSE; END IF;
END
$$ LANGUAGE plpgsql;

--permissions
CREATE OR REPLACE FUNCTION ban_user(_id_viewer integer, _id_target integer, _ban_resolved_at timestamptz) RETURNS boolean AS $$
DECLARE
    __lobbys_id_owner record;
BEGIN
    SELECT pg_advisory_xact_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target),greatest(_id_viewer, _id_target)));
    INSERT INTO user_bans(id_usera, id_userb, ban_resolved_at)
        VALUES(LEAST(_id_viewer, _id_target), GREATEST(_id_viewer, _id_target), _ban_resolved_at)
        ON CONFLICT (id_usera, id_userb) DO UPDATE SET ban_resolved_at=_ban_resolved_at;
    IF NOT FOUND THEN RAISE EXCEPTION 'ban_failed'; END IF;
    DELETE FROM user_friends WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target);
    DELETE FROM user_followers WHERE (id_follower=_id_viewer AND id_following=_id_target) OR (id_follower=_id_target AND id_following=_id_viewer);
    DELETE FROM user_friends_request WHERE id_usera=LEAST(_id_viewer, _id_target) AND id_userb=GREATEST(_id_viewer, _id_target);

    FOR __lobbys_id_owner IN (SELECT id_lobby, id_user as id_owner FROM lobby_members WHERE (id_user=_id_viewer OR id_user=_id_target) AND is_owner IS TRUE FOR SHARE) LOOP
        SELECT pg_advisory_xact_lock(hashtextextended('lobby_user:'||__lobbys_id_owner.id_lobby, (CASE WHEN __lobbys_id_owner.id_owner=_id_viewer THEN _id_target ELSE _id_viewer END)));
        DELETE FROM lobby_invitations WHERE id_lobby=__lobbys_id_owner.id_lobby AND (id_user=(CASE WHEN __lobbys_id_owner.id_owner=_id_viewer THEN _id_target ELSE _id_viewer END) OR created_by=(CASE WHEN __lobbys_id_owner.id_owner=_id_viewer THEN _id_target ELSE _id_viewer END));
        DELETE FROM lobby_join_requests WHERE id_lobby=__lobbys_id_owner.id_lobby AND id_user=(CASE WHEN __lobbys_id_owner.id_owner=_id_viewer THEN _id_target ELSE _id_viewer END);
        DELETE FROM lobby_bans WHERE id_lobby=__lobbys_id_owner.id_lobby AND id_user=(CASE WHEN __lobbys_id_owner.id_owner=_id_viewer THEN _id_target ELSE _id_viewer END) ;
        DELETE FROM lobby_members WHERE id_lobby=__lobbys_id_owner.id_lobby AND id_user=(CASE WHEN __lobbys_id_owner.id_owner=_id_viewer THEN _id_target ELSE _id_viewer END);
        IF FOUND THEN UPDATE lobby_slots SET free_slots=free_slots+1 WHERE id_lobby=__lobbys_id_owner.id_lobby ; END IF;
    END LOOP;
    RETURN TRUE;
END
$$ LANGUAGE plpgsql;