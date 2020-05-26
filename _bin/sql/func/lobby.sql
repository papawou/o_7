/*
create_lobby X
join_lobby X
leave_lobby X

accept_join X
decline_join X

invite
accept_invite
decline_invite
accept_request_invite
decline_request_invite

ban_lobby X
unban_lobby X

set_specific_perms
set_owner x
*/

CREATE OR REPLACE FUNCTION create_lobby(_id_viewer integer, _id_cv integer, _id_game integer, _id_platform integer, _id_cross integer, _max_slots integer, _check_join boolean, _privacy lobby_privacy, _auth_default integer, _auth_follower integer, _auth_friend integer, OUT id_lobby_ integer)
RETURNS integer AS $$
BEGIN
    INSERT INTO lobbys
        (id_owner, id_game, id_platform, id_cross, check_join, privacy, auth_default, auth_follower, auth_friend)
    VALUES
        (_id_viewer, _id_game, _id_platform, _id_cross, _check_join, _privacy, 1,1,1)
    RETURNING id INTO id_lobby_;
    INSERT INTO lobby_slots(id_lobby, free_slots, max_slots) VALUES(id_lobby_, _max_slots-1, _max_slots);

    INSERT INTO lobby_members
        (id_lobby, id_user, id_cv, is_owner, allowed_perms, specific_perms, cached_perms)
    VALUES
        (id_lobby_, _id_viewer, _id_cv, true, 1, 1, 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION join_lobby(_id_viewer integer, _id_lobby integer, _id_cv integer, exp_link varchar(5)) RETURNS integer AS $$
DECLARE
    __lobby_params lobbys%rowtype;
    viewer_perms integer;
BEGIN
    SELECT * INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;

    SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, __lobby_params.id_owner),greatest(_id_viewer, __lobby_params.id_owner)));
    PERFORM FROM user_bans WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND greatest(_id_viewer, __lobby_params.id_owner) AND ban_resolved_at < NOW ();
    IF FOUND THEN RAISE EXCEPTION 'users_block'; END IF;
    PERFORM FROM user_friends WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND greatest(_id_viewer, __lobby_params.id_owner) FOR SHARE;
    IF FOUND THEN
        viewer_perms:=__lobby_params.auth_friend;
    ELSE
        PERFORM FROM user_followers WHERE id_follower=_id_viewer AND id_following=__lobby_params.id_owner FOR SHARE;
        IF FOUND THEN
            viewer_perms:=__lobby_params.auth_follower;
        ELSE
            viewer_perms:=__lobby_params.auth_default;
        END IF;
    END IF;

    SELECT pg_advisory_xact_lock_shared(hashtextextended('lobby_user:'||_id_lobby, _id_viewer));
    PERFORM FROM lobby_bans WHERE id_lobby=__lobby_params.id AND id_user=_id_viewer AND ban_resolved_at < NOW();
    IF FOUND THEN RAISE EXCEPTION 'lobby_ban'; END IF;
    IF __lobby_params.check_join IS FALSE THEN
      INSERT INTO lobby_members(id_lobby, id_user, id_cv, cached_perms) VALUES(__lobby_params.id, _id_viewer, _id_cv, viewer_perms);
      UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby=_id_lobby;
    ELSE
      INSERT INTO lobby_join_requests(id_lobby, id_user) VALUES(__lobby_params.id, _id_viewer);
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION leave_lobby(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
    __was_owner boolean;
    __new_owner integer;
BEGIN
    DELETE FROM lobby_members WHERE id_lobby=_id_lobby AND id_user=_id_viewer RETURNING is_owner INTO __was_owner;
    IF __was_owner IS TRUE THEN
        SELECT FROM lobbys WHERE id=_id_lobby FOR UPDATE; --prevent join
        SELECT id_user INTO __new_owner FROM lobby_members WHERE id_lobby=_id_lobby LIMIT 1 FOR UPDATE; --prevent left
        IF NOT FOUND THEN --last leave
            DELETE FROM lobbys WHERE id=_id_lobby;
        ELSE
            UPDATE lobbys SET id_owner=__new_owner WHERE id=_id_lobby;
            UPDATE lobby_members SET is_owner=true WHERE id_lobby=_id_lobby AND id_user=__new_owner;
        END IF;
    END IF;
    UPDATE lobby_slots SET free_slots=free_slots+1 WHERE id_lobby=_id_lobby;
    RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION accept_join(_id_viewer integer, _id_user integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
    PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;
    UPDATE lobby_join_requests
        SET status='WAITING_USER'
    WHERE id_lobby=_id_lobby AND id_user=_id_user AND 'WAITING_LOBBY';
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION deny_join(_id_viewer integer, _id_user integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
    PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;
    UPDATE lobby_join_requests
        SET status='DENIED_BY_LOBBY'::lobby_join_request_status
    WHERE id_lobby=_id_lobby AND id_user=_id_user AND status='WAITING_LOBBY'::lobby_join_request_status OR status='WAITING_USER'::lobby_join_request_status;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cancel_join(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
    DELETE FROM lobby_join_requests
     WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND status='WAITING_LOBBY'::lobby_join_request_status OR status='WAITING_USER'::lobby_join_request_status;
    RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ban_lobby_user(_id_viewer integer, _id_lobby integer, _id_target integer, _ban_resolved_at timestamptz) RETURNS boolean AS $$
BEGIN
    PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

    SELECT pg_advisory_xact_lock(hashtextextended('lobby_user:'||_id_lobby, _id_target));
    INSERT INTO lobby_bans(id_lobby, id_user, ban_resolved_at, created_by) VALUES(_id_lobby, _id_target, _ban_resolved_at, _id_viewer)
        ON CONFLICT (id_lobby, id_user) DO UPDATE SET ban_resolved_at=_ban_resolved_at;
    DELETE FROM lobby_join_requests WHERE id_user=_id_target AND id_lobby=_id_lobby;
    DELETE FROM lobby_members WHERE id_user=_id_target AND id_lobby=_id_lobby;
    IF FOUND THEN UPDATE lobby_slots SET free_slots=free_slots+1 WHERE id_lobby=_id_lobby; END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_update_owner(_id_viewer integer, _id_lobby integer, _id_target integer) RETURNS boolean AS $$
BEGIN
     PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR UPDATE;
     IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;
     SELECT FROM lobbys WHERE id=_id_lobby FOR UPDATE;
     UPDATE lobby_members SET is_owner=true WHERE id_user=_id_target AND id_lobby=_id_lobby;
     IF NOT FOUND THEN RAISE EXCEPTION 'lobby_member not found'; END IF;
     UPDATE lobby_members SET is_owner=false WHERE id_user=_id_viewer AND id_lobby=_id_lobby;
     UPDATE lobbys SET id_owner=_id_target WHERE id=_id_lobby;
END
$$ LANGUAGE plpgsql;