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
    (_id_viewer, _id_game, _id_platform, _id_cross, _check_join, _privacy, _auth_default, _auth_follower, _auth_friend)
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
  PERFORM FROM user_bans WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND id_userb=greatest(_id_viewer, __lobby_params.id_owner);
  IF FOUND THEN RAISE EXCEPTION 'users_ban'; END IF;
  --perms
  PERFORM FROM friends WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND id_userb=greatest(_id_viewer, __lobby_params.id_owner) FOR SHARE;
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
    ON CONFLICT (id_user, id_lobby) DO UPDATE SET fk_member=_id_viewer;

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
  DELETE FROM lobby_users WHERE id_lobby=_id_lobby AND fk_member=_id_viewer RETURNING is_owner INTO __was_owner;
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
--joinrequest
user_joinrequest_create
user_joinrequest_confirm
user_joinrequest_cancel

manage_joinrequest_accept
manage_joinrequest_deny
*/
--user
CREATE OR REPLACE FUNCTION lobby_user_joinrequest_create(_id_viewer integer, _id_lobby integer) RETURNS integer AS $$
DECLARE
  __lobby_params lobbys%rowtype;
BEGIN
  SELECT * INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;
  
  IF __lobby_params.privacy='PRIVATE' OR __lobby_params.check_join IS FALSE THEN
	  RAISE EXCEPTION 'private or not check_join lobby';
  END IF;
  
  --check_user_owner
  SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, __lobby_params.id_owner),greatest(_id_viewer, __lobby_params.id_owner)));
  PERFORM FROM user_bans WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND greatest(_id_viewer, __lobby_params.id_owner);
  IF FOUND THEN RAISE EXCEPTION 'users_ban'; END IF;
  PERFORM FROM friends WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND greatest(_id_viewer, __lobby_params.id_owner) FOR SHARE;
  IF NOT FOUND AND __lobby_params.privacy='FRIEND' THEN
    RAISE EXCEPTION 'not friends';
  ELSE IF __lobby_params.privacy='FOLLOWER' THEN
    PERFORM FROM follows WHERE id_follower=_id_viewer AND id_following=__lobby_params.id_owner FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;
  END IF; END IF;
  
  INSERT INTO lobby_users (id_user, id_lobby, joinrequest_status, joinrequest_updated_at, joinrequest_history)
    VALUES (_id_viewer, _id_lobby, 'WAITING_LOBBY', NOW(), jsonb_build_array(jsonb_build_object('action',  'WAITING_LOBBY', 'created_by', _id_viewer, 'created_at', NOW())))
    ON CONFLICT (id_user, id_lobby) DO UPDATE SET joinrequest_status='WAITING_LOBBY', joinrequest_updated_at=NOW(), joinrequest_history=jsonb_build_array(jsonb_build_object('action',  'WAITING_LOBBY', 'created_by', _id_viewer, 'created_at', NOW()))
    WHERE joinrequest_status NOT IN ('WAITING_USER', 'WAITING_LOBBY');
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_joinrequest not created_at'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_user_joinrequest_confirm(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
  __lobby_params lobbys%rowtype;
  __viewer_perms integer;
  __log_joinrequest_history jsonb;
BEGIN
  SELECT * INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;
	
  SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, __lobby_params.id_owner),greatest(_id_viewer, __lobby_params.id_owner)));
    --perms
  PERFORM FROM friends WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND greatest(_id_viewer, __lobby_params.id_owner) FOR SHARE;
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
                         joined_at=NOW(),
                         cached_perms=__viewer_perms,
                         joinrequest_status=NULL,
                         joinrequest_history=NULL,
                         joinrequest_updated_at=NULL
    WHERE id_user=_id_viewer
      AND id_lobby=_id_lobby
      AND joinrequest_status='WAITING_USER'
  RETURNING joinrequest_history INTO __log_joinrequest_history;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_joinrequest not found'; END IF;

  INSERT INTO log_lobby_joinrequests
      (id_user, id_lobby, created_at, status, resolved_at, resolved_by, history)
    VALUES
      (_id_viewer, _id_lobby,__log_joinrequest_history->0->created_at, 'CONFIRMED_BY_USER', NOW(), _id_viewer, __log_joinrequest_history);

  UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby=_id_lobby;
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_user_joinrequest_cancel(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
  __log_joinrequest_history jsonb;
BEGIN
  DELETE FROM lobby_users
    WHERE id_lobby=_id_lobby AND id_user=_id_viewer AND joinrequest_status IN('WAITING_LOBBY', 'WAITING_USER')
    RETURNING joinrequest_history INTO __log_joinrequest_history;

  INSERT INTO log_lobby_joinrequests
    (id_user, id_lobby, created_at, status, resolved_at, resolved_by, history)
  VALUES
    (_id_viewer, _id_lobby,__log_joinrequest_history->0->created_at, 'CANCELED_BY_USER', NOW(), _id_viewer, __log_joinrequest_history);

  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

--manage
CREATE OR REPLACE FUNCTION lobby_manage_joinrequest_accept(_id_viewer integer, _id_user integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  UPDATE lobby_users SET joinrequest_status='WAITING_USER', joinrequest_history=joinrequest_history||jsonb_build_object('action',  'WAITING_USER', 'created_by', _id_viewer, 'created_at', NOW())
    WHERE id_lobby=_id_lobby
      AND id_user=_id_user
      AND joinrequest_status='WAITING_LOBBY'
      AND joinrequest_updated_at=NOW();
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_manage_joinrequest_deny(_id_viewer integer, _id_user integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
  __log_joinrequest_history jsonb;
BEGIN
  PERFORM FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  DELETE FROM lobby_users
    WHERE id_lobby=_id_lobby
      AND id_user=_id_user
      AND joinrequest_status IN ('WAITING_USER', 'WAITING_LOBBY')
  RETURNING joinrequest_history INTO __log_joinrequest_history;

  INSERT INTO log_lobby_joinrequests
    (id_user, id_lobby, created_at, status, resolved_at, resolved_by, history)
  VALUES
    (_id_viewer, _id_lobby,__log_joinrequest_history->0->created_at, 'CANCELED_BY_LOBBY', NOW(), _id_viewer, __log_joinrequest_history);
END
$$ LANGUAGE plpgsql;

--PERMISSIONS
CREATE OR REPLACE FUNCTION lobby_set_owner(_id_viewer integer, _id_lobby integer, _id_target integer) RETURNS boolean AS $$
BEGIN
     UPDATE lobbys SET id_owner=_id_target WHERE id=_id_lobby AND id_owner=_id_viewer;
     UPDATE lobby_users SET is_owner=FALSE WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE;
     UPDATE lobby_users SET is_owner=true WHERE fk_member=_id_target AND id_lobby=_id_lobby;
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
                                                      joinrequest_status=NULL,
                                                      joinrequest_updated_at=NULL,
                                                      joinrequest_history=NULL
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