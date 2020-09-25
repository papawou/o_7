/*
create
join
leave

ban
set_specific_perms
set_owner
*/

CREATE OR REPLACE FUNCTION lobby_create(_id_viewer integer, _id_game integer, _id_platform integer, _id_cross integer, _max_slots integer, _check_join boolean, _privacy lobby_privacy, _auth_default integer, _auth_follower integer, _auth_friend integer, OUT id_lobby_ integer) RETURNS integer AS $$
BEGIN
  INSERT INTO lobbys
    (id_owner, id_game, id_platform, id_cross, check_join, privacy, auth_default, auth_follower, auth_friend)
    VALUES
    (_id_viewer, _id_game, _id_platform, _id_cross, _check_join, _privacy, 1,1,1)
    RETURNING id INTO id_lobby_;
  INSERT INTO lobby_slots(id_lobby, free_slots, max_slots) VALUES(id_lobby_, _max_slots-1, _max_slots);

  INSERT INTO lobby_users
    (id_lobby, id_user, fk_member, is_owner, cached_perms)
    VALUES
    (id_lobby_, _id_viewer, _id_viewer,  true, 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_join(_id_viewer integer, _id_lobby integer) RETURNS integer AS $$
DECLARE
  __lobby_params lobbys%rowtype;
  __viewer_perms integer;
BEGIN
  SELECT * INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

  IF __lobby_params.privacy='private'::lobby_privacy OR __lobby_params.check_join THEN
	  RAISE EXCEPTION 'private or check_join lobby';
  END IF;
  
  --check_ban
  SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, __lobby_params.id_owner),greatest(_id_viewer, __lobby_params.id_owner)));
  PERFORM FROM user_bans WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND id_userb=greatest(_id_viewer, __lobby_params.id_owner) AND ban_resolved_at < NOW ();
  IF FOUND THEN RAISE EXCEPTION 'users_ban'; END IF;

    --perms
  PERFORM FROM friendships WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND id_userb=greatest(_id_viewer, __lobby_params.id_owner) FOR SHARE;
  IF FOUND THEN __viewer_perms:=__lobby_params.auth_friend;
  ELSE IF __lobby_params.privacy!='FRIEND'::lobby_privacy THEN
    PERFORM FROM follows WHERE id_follower=_id_viewer AND id_following=__lobby_params.id_owner FOR SHARE;
    IF FOUND THEN __viewer_perms:=__lobby_params.auth_follower;
    ELSE IF __lobby_params.privacy='GUEST'::lobby_privacy THEN
        __viewer_perms:=__lobby_params.auth_default;
        ELSE RAISE EXCEPTION 'unauth';
        END IF;
    END IF;
  ELSE
    RAISE EXCEPTION 'unauth';
  END IF; END IF;
  
  INSERT INTO lobby_users (id_user, id_lobby, fk_member)
    VALUES (_id_viewer, _id_lobby, _id_viewer)
    ON CONFLICT (id_user, id_lobby) DO UPDATE SET fk_member=_id_viewer
    WHERE fk_member IS NULL AND ban_resolved_at < NOW();

  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_users not found'; END IF;
  UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby=_id_lobby;
END
$$ LANGUAGE plpgsql;


--deadlock ?
CREATE OR REPLACE FUNCTION lobby_leave(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
  __was_owner boolean;
  __new_owner integer;
BEGIN
  UPDATE lobby_users SET fk_member=NULL WHERE id_lobby=_id_lobby AND fk_member=_id_viewer RETURNING is_owner INTO __was_owner;
  IF NOT FOUND THEN RETURN true; END IF;
  
  IF __was_owner IS TRUE THEN
    SELECT FROM lobbys WHERE id=_id_lobby FOR UPDATE; --prevent join
    SELECT fk_member INTO __new_owner FROM lobby_users WHERE id_lobby=_id_lobby AND fk_member IS NOT NULL LIMIT 1 FOR UPDATE; --prevent left
    IF NOT FOUND THEN --last leave
      DELETE FROM lobbys WHERE id=_id_lobby;
    ELSE
      UPDATE lobbys SET id_owner=__new_owner WHERE id=_id_lobby;
      UPDATE lobby_users SET is_owner=true WHERE id_lobby=_id_lobby AND fk_member=__new_owner;
    END IF;
  END IF;

  UPDATE lobby_slots SET free_slots=free_slots+1 WHERE id_lobby=_id_lobby;
  RETURN true;
END
$$ LANGUAGE plpgsql;

/*
--JOIN_REQUEST
creator
  create to WAITING_LOBBY
  confirm WAITING_USER to DONED_REQUEST
  deny to DONED_REQUEST --or cancel if status=WAITING_LOBBY
manager
  accept WAITING_LOBBY to WAITING_USER
  deny  WAITING_LOBBY to DONED_REQUEST
*/
--user
CREATE OR REPLACE FUNCTION lobby_user_join_request_create(_id_viewer integer, _id_lobby integer) RETURNS integer AS $$
DECLARE
  __lobby_params lobbys%rowtype;
BEGIN
  SELECT * INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;
  
  IF __lobby_params.privacy='PRIVATE' OR __lobby_params.check_join IS FALSE THEN
	  RAISE EXCEPTION 'private or not check_join lobby';
  END IF;
  
  --check_ban
  SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, __lobby_params.id_owner),greatest(_id_viewer, __lobby_params.id_owner)));
  PERFORM FROM user_bans WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND greatest(_id_viewer, __lobby_params.id_owner) AND ban_resolved_at > NOW ();
  IF FOUND THEN RAISE EXCEPTION 'users_ban'; END IF;

  --perms
  PERFORM FROM friendships WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND greatest(_id_viewer, __lobby_params.id_owner) FOR SHARE;
  IF NOT FOUND AND __lobby_params.privacy='FRIEND' THEN
    RAISE EXCEPTION 'not friends';
  ELSE IF __lobby_params.privacy='FOLLOWER' THEN
    PERFORM FROM follows WHERE id_follower=_id_viewer AND id_following=__lobby_params.id_owner FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;
  END IF; END IF;
  
  INSERT INTO lobby_users (id_user, id_lobby, status)
    VALUES (_id_viewer, _id_lobby, 'WAITING_LOBBY')
    ON CONFLICT (id_user, id_lobby) DO UPDATE SET status='WAITING_LOBBY'
    WHERE fk_member IS NULL
      AND ban_resolved_at<NOW() 
      AND request_resolved_at+interval'00:01:00'<NOW()
      AND status NOT IN ('WAITING_USER', 'WAITING_LOBBY');
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_user_join_request_confirm(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
  __lobby_params lobbys%rowtype;
  __viewer_perms integer;
BEGIN
  SELECT * INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;
	
  SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, __lobby_params.id_owner),greatest(_id_viewer, __lobby_params.id_owner)));
    --perms
  PERFORM FROM friendships WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND greatest(_id_viewer, __lobby_params.id_owner) FOR SHARE;
  IF FOUND THEN __viewer_perms:=__lobby_params.auth_friend;
  ELSE IF __lobby_params.privacy!='FRIEND'::lobby_privacy THEN
    PERFORM FROM follows WHERE id_follower=_id_viewer AND id_following=__lobby_params.id_owner FOR SHARE;
    IF FOUND THEN __viewer_perms:=__lobby_params.auth_follower;
    ELSE IF __lobby_params.privacy='GUEST'::lobby_privacy THEN __viewer_perms:=__lobby_params.auth_default; ELSE RAISE EXCEPTION 'unauth'; END IF;
    END IF;
  ELSE
    RAISE EXCEPTION 'unauth';
  END IF; END IF;
  
  UPDATE lobby_users SET fk_member=_id_viewer,
                         status=NULL,
                         request_resolved_at=NULL,
                         joined_at=NOW(),
                         cached_perms=__viewer_perms
    WHERE id_user=_id_viewer
      AND id_lobby=_id_lobby
      AND status='WAITING_USER';
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_join_request not found'; END IF;
  
  UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby=_id_lobby;
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_user_join_request_cancel(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  UPDATE lobby_users SET status='DENIED_BY_USER',
                         ban_resolved_at=NOW()
    WHERE id_user=_id_viewer
      AND id_lobby=_id_lobby
      AND status IN ('WAITING_LOBBY', 'WAITING_USER');
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

--lobby
CREATE OR REPLACE FUNCTION lobby_manage_join_request_accept(_id_viewer integer, _id_user integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  UPDATE lobby_users SET status='WAITING_USER'
    WHERE id_lobby=_id_lobby
      AND id_user=_id_user
      AND status IN ('WAITING_CONFIRM_LOBBY', 'WAITING_LOBBY', 'DENIED_BY_LOBBY');
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_manage_join_request_deny(_id_viewer integer, _id_user integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  UPDATE lobby_users SET status='DENIED_BY_LOBBY',
                         last_attempt=NOW()
    WHERE id_lobby=_id_lobby
      AND id_user=_id_user
      AND status IN ('WAITING_CONFIRM_LOBBY', 'WAITING_LOBBY', 'WAITING_USER');
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
DECLARE
  __was_member boolean;
BEGIN
    PERFORM FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

    INSERT INTO lobby_users(id_lobby, id_user, ban_resolved_at) VALUES(_id_lobby, _id_target, _ban_resolved_at)
        ON CONFLICT (id_lobby, id_user) DO UPDATE SET ban_resolved_at=_ban_resolved_at,
                                                      fk_member=NULL,
                                                      status=NULL
        RETURNING fk_member IS NOT NULL INTO __was_member;

    IF FOUND AND __was_member THEN UPDATE lobby_slots SET free_slots=free_slots+1 WHERE id_lobby=_id_lobby; END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_update_privacy(_id_viewer integer, _id_lobby integer, _lobby_privacy lobby_privacy) RETURNS boolean AS $$
BEGIN
  UPDATE lobbys SET privacy=_lobby_privacy WHERE id=_id_lobby AND id_owner=_id_viewer AND privacy<>_lobby_privacy;
  IF NOT FOUND THEN RAISE EXCEPTION 'failed change privacy'; END IF;
END
$$ LANGUAGE plpgsql;