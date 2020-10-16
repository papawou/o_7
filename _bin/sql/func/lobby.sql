/*
--user
create
join
leave

PERMISSIONS
--lobby
ban
set_specific_perms
set_owner
*/

CREATE OR REPLACE FUNCTION lobby_create(_id_viewer integer, _id_game integer, _id_platform integer, _id_cross integer, _max_slots integer, _check_join boolean, _privacy lobby_privacy, OUT id_lobby_ integer) RETURNS integer AS $$
BEGIN
  INSERT INTO lobbys
    (id_owner, id_game, id_platform, id_cross, check_join, privacy)
    VALUES
    (_id_viewer, _id_game, _id_platform, _id_cross, _check_join, _privacy)
    RETURNING id INTO id_lobby_;
  INSERT INTO lobby_slots(id_lobby, free_slots, max_slots) VALUES(id_lobby_, _max_slots-1, _max_slots);

  INSERT INTO lobby_users
    (id_lobby, id_user, fk_member, is_owner, cached_perms)
    VALUES
    (id_lobby_, _id_viewer, _id_viewer,  true, 1);
END;
$$ LANGUAGE plpgsql;

--polymorphic join (confirm joinrequest)  / create_join_request
CREATE OR REPLACE FUNCTION lobby_join(_id_viewer integer, _id_lobby integer) RETURNS integer AS $$
DECLARE
  __lobby_params lobbys%rowtype;
  __user_joined boolean;
BEGIN
  SELECT * INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

  INSERT INTO lobby_users (id_user, id_lobby, fk_member, joinrequest_status)
  VALUES (_id_viewer, _id_lobby, CASE WHEN __lobby_params.check_join IS FALSE THEN _id_viewer END, CASE WHEN __lobby_params.check_join THEN 'WAITING_LOBBY' END)
    ON CONFLICT (id_user, id_lobby) DO UPDATE SET fk_member=CASE WHEN joinrequest_status IN('WAITING_USER', 'INV_WAITING_USER') OR  __lobby_params.check_join IS FALSE THEN _id_viewer END,
                                                  joinrequest_status=CASE WHEN joinrequest_status IN('WAITING_USER', 'INV_WAITING_USER') THEN NULL WHEN __lobby_params.check_join THEN 'WAITING_LOBBY' END
  WHERE fk_member IS NULL
     AND ((__lobby_params.check_join IS FALSE OR joinrequest_status IN('WAITING_USER', 'INV_WAITING_USER'))
      OR (joinrequest_status<>'WAITING_LOBBY' AND __lobby_params.check_join))
  RETURNING fk_member IS NOT NULL INTO __user_joined;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_users not updated'; END IF;

  IF __user_joined THEN
	  DELETE FROM lobby_invitations WHERE id_target=_id_viewer AND id_lobby=_id_lobby;
	  UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby=_id_lobby;
  END IF;

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
JOINREQUEST
--user
user_joinrequest_create
user_joinrequest_confirm == lobby_join ?
user_joinrequest_cancel

--lobby
manage_joinrequest_accept
manage_joinrequest_deny / cancel
*/
--user
CREATE OR REPLACE FUNCTION lobby_user_joinrequest_create(_id_viewer integer, _id_lobby integer) RETURNS integer AS $$
DECLARE
  __lobby_params lobbys%rowtype;
  __viewer_perms integer;
BEGIN
  SELECT * INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;
  
  IF __lobby_params.privacy='PRIVATE' OR __lobby_params.check_join IS FALSE THEN
	  RAISE EXCEPTION 'private or not check_join lobby';
  END IF;
  
  --check_user_owner
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
  
  INSERT INTO lobby_users (id_user, id_lobby, joinrequest_status, perms)
    VALUES (_id_viewer, _id_lobby, 'WAITING_LOBBY', __viewer_perms)
    ON CONFLICT (id_user, id_lobby) DO UPDATE SET joinrequest_status='WAITING_LOBBY'
    WHERE joinrequest_status NOT IN ('INV_WAITING_USER', 'WAITING_USER', 'WAITING_LOBBY');
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_joinrequest not created_at'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_user_joinrequest_confirm(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  UPDATE lobby_users SET fk_member=_id_viewer,
                         joined_at=NOW(),
                         joinrequest_status=NULL
    WHERE id_user=_id_viewer
      AND id_lobby=_id_lobby
      AND joinrequest_status IN('WAITING_USER', 'INV_WAITING_USER');
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_joinrequest not found'; END IF;

  DELETE FROM lobby_invitations WHERE id_target=_id_viewer AND id_lobby=_id_lobby;

  UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby=_id_lobby;
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_user_joinrequest_cancel(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  DELETE FROM lobby_users
    WHERE id_lobby=_id_lobby AND id_user=_id_viewer AND joinrequest_status IN('WAITING_LOBBY', 'WAITING_USER');
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

--manage
CREATE OR REPLACE FUNCTION lobby_manage_joinrequest_accept(_id_viewer integer, _id_user integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  UPDATE lobby_users SET joinrequest_status='WAITING_USER'
    WHERE id_lobby=_id_lobby
      AND id_user=_id_user
      AND joinrequest_status='WAITING_LOBBY';

  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_manage_joinrequest_deny(_id_viewer integer, _id_user integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  DELETE FROM lobby_users
    WHERE id_lobby=_id_lobby
      AND id_user=_id_user
      AND joinrequest_status IN ('WAITING_USER', 'WAITING_LOBBY');

  DELETE FROM lobby_invitations WHERE id_target=_id_viewer AND id_lobby=_id_lobby;
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

/*
INVITATIONS

--DEFINITIONS--
INV_WAITING_USER //prevent delete of invitations if lobby update privacy
INV_WAITING_LOBBY //hidden from user until lobby response

--functions--
--creator
invite_create
invite_cancel

--target
invite_accept == joinrequest_confirm ? //enforce join via invitation ?
invite_deny ?

--lobby
invite_accept == joinrequest_accept ?
invite_deny /cancel == joinrequest_deny ?

*/
--creator
CREATE OR REPLACE FUNCTION lobby_invite_create(_id_viewer integer, _id_lobby integer, _id_target integer) RETURNS boolean AS $$
DECLARE
    __check_join boolean;
    __perms boolean;
BEGIN
	--perms
  --user_user
  PERFORM FROM friends WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target) FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;
  --lobby_user
  SELECT check_join INTO __check_join FROM lobbys WHERE id=_id_lobby FOR SHARE;
  SELECT cached_perms INTO __perms FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  INSERT INTO lobby_users(id_user, id_lobby, joinrequest_status)
    VALUES(_id_target, _id_lobby, CASE WHEN (__check_join IS FALSE OR __perms) THEN 'INV_WAITING_USER' ELSE 'INV_WAITING_LOBBY' END)
    ON CONFLICT DO UPDATE
        SET joinrequest_status=(CASE WHEN __check_join IS FALSE OR __perms THEN 'INV_WAITING_USER' ELSE 'INV_WAITING_LOBBY' END)
    WHERE joinrequest_status NOT IN ('INV_WAITING_USER', CASE WHEN (__check_join AND __perms IS FALSE) THEN 'INV_WAITING_LOBBY' END, 'WAITING_USER');
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  INSERT INTO lobby_invitations(id_target, id_lobby, id_creator) VALUES(_id_target, _id_lobby, _id_viewer);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_invite_cancel(_id_viewer integer, _id_lobby integer, _id_target integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobby_users WHERE id_user=_id_target AND id_lobby=_id_lobby AND joinrequest_status IN('INV_WAITING_USER', 'INV_WAITING_LOBBY') FOR UPDATE;

  DELETE FROM lobby_invitations WHERE id_creator=_id_viewer AND id_target=_id_viewer;

  PERFORM FROM lobby_invitations WHERE id_target=_id_target AND id_lobby=_id_lobby LIMIT 1 FOR SHARE;
  IF NOT FOUND THEN
    DELETE FROM lobby_users WHERE id_user=_id_target AND id_lobby=_id_lobby;
  END IF;
END
$$ LANGUAGE plpgsql;

--target

--lobby
CREATE OR REPLACE FUNCTION lobby_manage_invite_accept(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby;

  UPDATE lobby_users SET joinrequest_status='WAITING_USER'
    WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND joinrequest_status='INV_WAITING_LOBBY';
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_manage_invite_deny(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby;

  DELETE FROM lobby_users
    WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND joinrequest_status='INV_WAITING_LOBBY';
END;
$$ LANGUAGE plpgsql;