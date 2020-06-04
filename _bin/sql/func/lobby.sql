/*
create
join
leave

JOIN_REQUEST
--candidate
    confirm
    cancel
--lobby
    accept
    deny

INVITATION
invite
--creator
    cancel_invite
--target
    accept_invite
    deny_invite
    confirm_invite ?check_join
--lobby ?check_join
    accept_invite
    deny_invite

ban
set_specific_perms
set_owner
*/

CREATE OR REPLACE FUNCTION lobby_create(_id_viewer integer, _id_game integer, _id_platform integer, _id_cross integer, _max_slots integer, _check_join boolean, _privacy lobby_privacy, _auth_default integer, _auth_follower integer, _auth_friend integer, OUT id_lobby_ integer)
RETURNS integer AS $$
BEGIN
    INSERT INTO lobbys
        (id_owner, id_game, id_platform, id_cross, check_join, privacy, auth_default, auth_follower, auth_friend)
    VALUES
        (_id_viewer, _id_game, _id_platform, _id_cross, _check_join, _privacy, 1,1,1)
    RETURNING id INTO id_lobby_;
    INSERT INTO lobby_slots(id_lobby, free_slots, max_slots) VALUES(id_lobby_, _max_slots-1, _max_slots);

    INSERT INTO lobby_members
        (id_lobby, id_user, is_owner, specific_perms, cached_perms)
    VALUES
        (id_lobby_, _id_viewer, true, 1, 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_join(_id_viewer integer, _id_lobby integer, force_leave boolean) RETURNS integer AS $$
DECLARE
    __lobby_params lobbys%rowtype;
    __viewer_perms integer;
BEGIN
    SELECT * INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;
    --check_ban
    SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, __lobby_params.id_owner),greatest(_id_viewer, __lobby_params.id_owner)));
    PERFORM FROM user_bans WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND greatest(_id_viewer, __lobby_params.id_owner) AND ban_resolved_at < NOW ();
    IF FOUND THEN RAISE EXCEPTION 'users_block'; END IF;
    --perms
    IF __lobby_params.privacy='private'::lobby_privacy THEN RAISE EXCEPTION 'unauth'; END IF;
    PERFORM FROM user_friends WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND greatest(_id_viewer, __lobby_params.id_owner) FOR SHARE;
    IF FOUND
        THEN __viewer_perms:=__lobby_params.auth_friend;
    ELSE IF __lobby_params.privacy!='FRIEND'::lobby_privacy THEN
        PERFORM FROM user_followers WHERE id_follower=_id_viewer AND id_following=__lobby_params.id_owner FOR SHARE;
        IF FOUND THEN __viewer_perms:=__lobby_params.auth_follower;
            ELSE IF __lobby_params.privacy='GUEST'::lobby_privacy THEN __viewer_perms:=__lobby_params.auth_default; ELSE RAISE EXCEPTION 'unauth'; END IF;
        END IF;
        ELSE
            RAISE EXCEPTION 'unauth';
        END IF;
    END IF;
    --lobby_bans
    SELECT pg_advisory_xact_lock(hashtextextended('lobby_user:'||_id_lobby, _id_viewer));
    PERFORM FROM lobby_bans WHERE id_lobby=__lobby_params.id AND id_user=_id_viewer AND ban_resolved_at < NOW();
    IF FOUND THEN RAISE EXCEPTION 'lobby_ban'; END IF;

    IF __lobby_params.check_join IS FALSE THEN
      INSERT INTO lobby_members(id_lobby, id_user, cached_perms) VALUES(__lobby_params.id, _id_viewer, __viewer_perms);
      UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby=_id_lobby;
    ELSE
      PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby;
      IF FOUND THEN RAISE EXCEPTION 'already_member'; END IF;
      INSERT INTO lobby_join_requests(id_lobby, id_user) VALUES(__lobby_params.id, _id_viewer);
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_leave(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
    __was_owner boolean;
    __new_owner integer;
BEGIN
    DELETE FROM lobby_members WHERE id_lobby=_id_lobby AND id_user=_id_viewer RETURNING is_owner INTO __was_owner;
    IF NOT FOUND THEN RETURN true; END IF;
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
    DELETE FROM lobby_invitations WHERE id_lobby=_id_lobby AND created_by=_id_viewer;
    UPDATE lobby_slots SET free_slots=free_slots+1 WHERE id_lobby=_id_lobby;
    RETURN true;
END
$$ LANGUAGE plpgsql;

--JOIN_REQUEST
    --creator
CREATE OR REPLACE FUNCTION lobby_join_request_confirm(_id_viewer integer, _id_lobby integer, force_leave boolean) RETURNS boolean AS $$
DECLARE
    __lobby_params lobbys;
    __viewer_perms integer;
BEGIN
    SELECT * INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;

    SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, __lobby_params.id_owner),greatest(_id_viewer, __lobby_params.id_owner)));
    SELECT pg_advisory_xact_lock(hashtextextended('lobby_user:'||_id_lobby, _id_viewer));
    --perms
    PERFORM FROM user_friends WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND greatest(_id_viewer, __lobby_params.id_owner) FOR SHARE;
    IF FOUND THEN __viewer_perms:=__lobby_params.auth_friend;
    ELSE
        PERFORM FROM user_followers WHERE id_follower=_id_viewer AND id_following=__lobby_params.id_owner FOR SHARE;
        IF FOUND THEN __viewer_perms:=__lobby_params.auth_follower;
        ELSE __viewer_perms:=__lobby_params.auth_default;
    END IF; END IF;

    INSERT INTO lobby_members(id_lobby, id_user, cached_perms) VALUES(__lobby_params.id, _id_viewer, __viewer_perms);
    DELETE FROM lobby_join_requests WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND status='WAITING_USER'::lobby_join_request_status;
    IF NOT FOUND THEN RAISE EXCEPTION 'lobby_join_request not found'; END IF;
    UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby=_id_lobby;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_join_request_cancel(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
    DELETE FROM lobby_join_requests
     WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND status='WAITING_LOBBY'::lobby_join_request_status OR status='WAITING_USER'::lobby_join_request_status;
    RETURN FOUND;
END
$$ LANGUAGE plpgsql;
    --lobby
CREATE OR REPLACE FUNCTION lobby_join_request_accept(_id_viewer integer, _id_user integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
    PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;
    UPDATE lobby_join_requests
        SET status='WAITING_USER'::lobby_join_request_status
    WHERE id_lobby=_id_lobby AND id_user=_id_user AND 'WAITING_LOBBY'::lobby_join_request_status;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_join_request_deny(_id_viewer integer, _id_user integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
    PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;
    UPDATE lobby_join_requests
        SET status='DENIED_BY_LOBBY'::lobby_join_request_status
    WHERE id_lobby=_id_lobby AND id_user=_id_user AND status='WAITING_LOBBY'::lobby_join_request_status OR status='WAITING_USER'::lobby_join_request_status;
END
$$ LANGUAGE plpgsql;

--INVITATIONS
    --creator
CREATE OR REPLACE FUNCTION lobby_invite(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
    __id_owner integer;
    __check_join boolean;
    __trust_invite boolean;
BEGIN
    SELECT id_owner, check_join INTO __id_owner, __check_join FROM lobbys WHERE id=_id_lobby FOR SHARE;

    PERFORM FROM user_friends WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target) FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

    SELECT cached_perms INTO __trust_invite FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

    SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_target, __id_owner),greatest(_id_target, __id_owner)));
    SELECT pg_advisory_xact_lock_shared(hashtextextended('lobby_user:'||_id_lobby, _id_target));

    PERFORM FROM user_bans WHERE id_usera=least(_id_target, __id_owner) AND id_userb=greatest(_id_viewer, __id_owner) AND ban_resolved_at < NOW();
    IF FOUND THEN RAISE EXCEPTION 'unauth'; END IF;
    PERFORM FROM lobby_bans WHERE id_user=_id_target AND id_lobby=_id_lobby AND ban_resolved_at < NOW();
    IF FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

    PERFORM FROM lobby_members WHERE id_user=_id_target AND id_lobby=_id_lobby;
    IF FOUND THEN RAISE EXCEPTION 'already member'; END IF;

    IF __check_join AND __trust_invite IS FALSE THEN
        INSERT INTO lobby_invitations(id_user, id_lobby, created_by) VALUES(_id_target, _id_lobby, _id_viewer);
        INSERT INTO lobby_join_requests(id_lobby, id_user, status) VALUES(_id_lobby, _id_target, 'WAITING_USER'::lobby_join_request_status)
            ON CONFLICT(id_lobby, id_user) DO UPDATE SET status='WAITING_BOTH' WHERE status='DENIED_BY_LOBBY' OR status!='WAITING_USER';
    ELSE
        INSERT INTO lobby_invitations(id_user, id_lobby, created_by) VALUES(_id_target, _id_lobby, _id_viewer);
        UPDATE lobby_join_requests SET status='WAITING_USER' WHERE id_user=_id_target AND id_lobby=_id_lobby;
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_invite_cancel(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
    DELETE FROM lobby_invitations WHERE id_user=_id_target AND id_lobby=_id_lobby AND created_by=_id_viewer;
    RETURN FOUND;
END
$$ LANGUAGE plpgsql;

    --target
CREATE OR REPLACE FUNCTION lobby_invite_confirm(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
    __lobby_params record;
    __viewer_perms integer;
BEGIN
    SELECT * INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;

/*
    SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, __lobby_params.id_owner),greatest(_id_viewer,  __lobby_params.id_owner)));
    SELECT pg_advisory_xact_lock(hashtextextended('lobby_user:'||__lobby_params.id, _id_viewer));
*/
    SELECT status INTO __invitation_status FROM lobby_invitations WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND status='WAITING_USER'::lobby_invitation_status OR status='WAITING_BOTH'::lobby_invitation_status FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'lobby_invitation not found'; END IF;
    IF __invitation_status='WAITING_BOTH'::lobby_invitation_status THEN --waiting lobby response
        UPDATE lobby_invitations SET status='WAITING_LOBBY'::lobby_invitation_status WHERE id_user=_id_viewer AND id_lobby=_id_lobby;
    ELSE --confirm invitation
        DELETE FROM lobby_invitations WHERE id_user=_id_viewer AND id_lobby=_id_lobby;

        --perms
        PERFORM FROM user_friends WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND greatest(_id_viewer, __lobby_params.id_owner) FOR SHARE;
        IF FOUND THEN __viewer_perms:=__lobby_params.auth_friend;
        ELSE
            PERFORM FROM user_followers WHERE id_follower=_id_viewer AND id_following=__lobby_params.id_owner FOR SHARE;
            IF FOUND THEN __viewer_perms:=__lobby_params.auth_follower;
            ELSE __viewer_perms:=__lobby_params.auth_default;
        END IF; END IF;

        INSERT INTO lobby_members(id_lobby, id_user, cached_perms) VALUES(__lobby_params.id, _id_viewer, __viewer_perms);
        UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby=_id_lobby;
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_invite_deny_by_target(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
    UPDATE lobby_invitations SET status='DENIED_BY_USER'::lobby_invitation_status WHERE id_user=_id_viewer AND id_lobby=_id_lobby;
END
$$ LANGUAGE plpgsql;

    --lobby
CREATE OR REPLACE FUNCTION lobby_invite_accept(_id_viewer integer, _id_lobby integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

    UPDATE lobby_invitations SET status='WAITING_USER'::lobby_invitation_status
        WHERE id_user=_id_target AND id_lobby=_id_lobby AND status='WAITING_BOTH'::lobby_invitation_status OR status='WAITING_LOBBY'::lobby_invitation_status;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_invite_deny_by_lobby(_id_viewer integer, _id_lobby integer, _id_target integer) RETURNS boolean AS $$
BEGIN
    PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

    UPDATE lobby_invitations SET status='DENIED_BY_LOBBY'::lobby_invitation_status WHERE id_user=_id_target AND id_lobby=_id_lobby;
END
$$ LANGUAGE plpgsql;

--PERMISSIONS
CREATE OR REPLACE FUNCTION lobby_set_owner(_id_viewer integer, _id_lobby integer, _id_target integer) RETURNS boolean AS $$
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

CREATE OR REPLACE FUNCTION lobby_set_user_permissions(_id_viewer integer, _id_lobby integer, _id_target integer, _perms integer) RETURNS boolean AS $$
BEGIN
    PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;
    UPDATE lobby_members SET specific_perms=_perms WHERE id_user=_id_target AND id_lobby=_id_lobby;
    IF NOT FOUND THEN RAISE EXCEPTION 'lobby_member not found'; END IF;
    RETURN TRUE;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_ban_user(_id_viewer integer, _id_lobby integer, _id_target integer, _ban_resolved_at timestamptz) RETURNS boolean AS $$
BEGIN
    PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

    SELECT pg_advisory_xact_lock(hashtextextended('lobby_user:'||_id_lobby, _id_target));
    INSERT INTO lobby_bans(id_lobby, id_user, ban_resolved_at, created_by) VALUES(_id_lobby, _id_target, _ban_resolved_at, _id_viewer)
        ON CONFLICT (id_lobby, id_user) DO UPDATE SET ban_resolved_at=_ban_resolved_at;

    DELETE FROM lobby_invitations WHERE id_lobby=_id_lobby AND (id_user=_id_target OR created_by=_id_target);
    DELETE FROM lobby_join_requests WHERE id_user=_id_target AND id_lobby=_id_lobby;
    DELETE FROM lobby_members WHERE id_user=_id_target AND id_lobby=_id_lobby;
    IF FOUND THEN UPDATE lobby_slots SET free_slots=free_slots+1 WHERE id_lobby=_id_lobby; END IF;
END
$$ LANGUAGE plpgsql;