/*
BASICS
--user
	lobby_create
	lobby_join
		=lobby_joinrequest_create
	  =lobby_user_joinrequest_confirm
		=lobby_invite_confirm
		allowed_to_join ?
			update joinrequest_status IN('INV_WAITING_USER', 'INV_WAITING_LOBBY) to ('WAITING_USER', 'WAITING_LOBBY)
		RETURN has_joined ? 1 : 2
--member
	lobby_leave
REQUEST
--user
	lobby_user_joinrequest_create
		==lobby_join
	lobby_user_joinrequest_confirm
		==lobby_join
	lobby_user_joinrequest_deny/cancel
--lobby
	lobby_manage_joinrequest_accept
	lobby_manage_joinrequest_deny/cancel

INVITATION
__def__
INV_WAITING_USER
	//prevent delete of invitations if lobby update privacy
INV_WAITING_LOBBY
	//hidden from user until lobby response

--member
	lobby_invite_create
	lobby_invite_cancel
--target
	lobby_target_invite_confirm
		==lobby_join
		?enforce check lobby_invitation
	lobby_target_invite_deny
		==lobby_user_joinrequest_cancel
		?notifications
--lobby
	lobby_manage_invite_accept
		==lobby_manage_joinrequest_accept
	lobby_manage_invite_deny/cancel
		==lobby_manage_joinrequest_deny

PERMISSIONS
--lobby
	lobby_set_check_join
	lobby_set_privacy
	lobby_set_perms
	lobby_set_owner
	lobby_ban_user
	lobby_set_slots
UTILS
	lobby_utils_refresh_member_authz
	lobby_utils_delete_member_invitation
*/

DROP FUNCTION IF EXISTS lobby_create, lobby_join, lobby_leave,
  lobby_user_joinrequest_deny, lobby_manage_joinrequest_accept, lobby_manage_joinrequest_deny,
	lobby_invite_create, lobby_invite_cancel,
  lobby_set_check_join, lobby_ban_user, lobby_set_privacy, lobby_set_owner, lobby_set_slots CASCADE;

CREATE OR REPLACE FUNCTION lobby_create(_id_viewer integer, _max_slots integer, _check_join boolean, _privacy lobby_privacy, OUT id_lobby_ integer) AS $$
BEGIN
  SET CONSTRAINTS fk_lobby_owner, fk_lobby_slots DEFERRED;
  INSERT INTO lobbys
    (id_owner, check_join, privacy)
    VALUES(_id_viewer, _check_join, _privacy)
    RETURNING id INTO id_lobby_;
  INSERT INTO lobby_slots(id_lobby, free_slots, max_slots)
    VALUES(id_lobby_, _max_slots-1, _max_slots);

  INSERT INTO lobby_members
    (id_lobby, id_user, is_owner)
    VALUES(id_lobby, _id_viewer,  true);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_join(_id_viewer integer, _id_lobby integer) RETURNS integer AS $$
/*
RETURN
	1 - user joined lobby
	2 - user created request
*/
DECLARE
  __lobby_params record;
BEGIN
  SELECT check_join, privacy, id_owner INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

  SELECT pg_advisory_lock(hashtextextended('lobby_user:'||_id_lobby||'_'||_id_viewer));
	PERFORM FROM lobby_bans WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND ban_resolved_at > NOW();
  IF FOUND THEN RAISE EXCEPTION 'lobby_ban user'; END IF;
  PERFORM FROM lobby_members WHERE id_lobby=_id_lobby AND id_user=_id_viewer;
  IF FOUND THEN RAISE EXCEPTION 'already member'; END IF;

  DELETE FROM lobby_requests WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND status='WAITING_USER';
  IF FOUND OR (__lobby_params.check_join IS FALSE AND __lobby_params.privacy='DEFAULT')  THEN
		INSERT INTO lobby_members(id_lobby, id_user) VALUES(_id_lobby, _id_viewer);
		UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby=_id_lobby;
		RETURN 1;
	ELSIF __lobby_params.check_join AND __lobby_params.privacy='DEFAULT' THEN
    INSERT INTO lobby_requests(id_user, id_lobby, status) VALUES(_id_viewer, _id_lobby, 'WAITING_LOBBY')
  	  ON CONFLICT (id_user, id_lobby) DO UPDATE SET id_creator=null
  		  WHERE id_creator IS NOT NULL;
    IF NOT FOUND THEN RAISE EXCEPTION 'failed'; END IF;
    RETURN 2;
	END IF;

  RETURN 0;
END
$$ LANGUAGE plpgsql;

--todo
CREATE OR REPLACE FUNCTION lobby_leave(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
  __id_lobby integer;
  __was_owner boolean;
  __new_owner integer;
BEGIN
  SET CONSTRAINTS fk_lobby_owner, lobby_invitations_id_creator_id_lobby_fkey DEFERRED;
  SELECT id_lobby, is_owner INTO __id_lobby, __was_owner FROM lobby_members WHERE id_user=_id_viewer AND (id_lobby=_id_lobby OR _id_lobby IS NULL);
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_user not member'; END IF;

  IF __was_owner THEN
    PERFORM FROM lobbys WHERE id=__id_lobby AND id_owner=_id_viewer FOR UPDATE;
	ELSE
    PERFORM FROM lobbys WHERE id=__id_lobby AND id_owner<>_id_viewer FOR SHARE;
  END IF;
	IF NOT FOUND THEN RAISE EXCEPTION 'serialization error #1'; END IF;

  DELETE FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=__id_lobby;
  IF NOT FOUND THEN RAISE EXCEPTION 'serialization error #2'; END IF;

  PERFORM FROM lobby_utils_delete_member_invitation(ARRAY[_id_viewer], __id_lobby);
	--todo idea allow concurrent leave? use of lobby_slots, skip locked for invitation deleted

  IF __was_owner THEN
    SELECT id_user INTO __new_owner FROM lobby_members WHERE id_lobby=__id_lobby LIMIT 1 FOR NO KEY UPDATE; --todo idea use of lobby_slots to prevent this call
    IF NOT FOUND THEN --last lobby_member
      DELETE FROM lobbys WHERE id=__id_lobby;
      RETURN true;
    ELSE
      --todo test lobby_set_owner ?
      PERFORM lobby_set_owner(_id_viewer,__new_owner,__id_lobby,true);
    END IF;
  END IF;

  UPDATE lobby_slots SET free_slots=free_slots+1 WHERE id_lobby=__id_lobby;
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_user_joinrequest_deny(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  DELETE FROM lobby_requests
    WHERE id_lobby=_id_lobby AND id_user=_id_viewer
      AND (id_creator IS NOT NULL AND status='WAITING_LOBBY') IS FALSE; --prevent delete of INV_WAITING_LOBBY
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_request not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_manage_joinrequest_accept(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobbys WHERE id=_id_lobby AND id_owner=_id_viewer FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  UPDATE lobby_requests SET status='WAITING_USER'
    WHERE id_lobby=_id_lobby AND id_user=_id_target AND status='WAITING_LOBBY';
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_request not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_manage_joinrequest_deny(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobbys WHERE id=_id_lobby AND id_owner=_id_viewer FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  DELETE FROM lobby_requests
    WHERE id_lobby=_id_lobby
      AND id_user=_id_target;
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_request not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_invite_create(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
    __trust_invite boolean;
BEGIN
  PERFORM FROM friends WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target) FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'not friends'; END IF;

  SELECT pg_advisory_lock(hashtextextended('lobby_user:'||_id_lobby||'_'||_id_viewer));
	PERFORM FROM lobby_bans WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND ban_resolved_at > NOW();
  IF FOUND THEN RAISE EXCEPTION 'lobby_ban user'; END IF;
  PERFORM FROM lobby_members WHERE id_lobby=_id_lobby AND id_user=_id_viewer;
  IF FOUND THEN RAISE EXCEPTION 'already member'; END IF;

  SELECT (check_join IS FALSE OR id_owner=_id_viewer) INTO __trust_invite FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

  INSERT INTO lobby_requests(id_user, id_lobby, status, id_creator)
    VALUES(_id_target, _id_lobby, CASE WHEN __trust_invite THEN 'WAITING_USER'::lobby_request_status ELSE 'WAITING_LOBBY'::lobby_request_status END, _id_viewer)
    ON CONFLICT(id_lobby, id_user) DO UPDATE
      SET status='WAITING_USER'::lobby_request_status
    WHERE __trust_invite
      AND lobby_requests.status<>'WAITING_USER';

  INSERT INTO lobby_invitations(id_creator, id_target, id_lobby) VALUES(_id_viewer, _id_target, _id_lobby);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_invite_cancel(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  SET CONSTRAINTS fk_lobby_request_creator DEFERRED;
  DELETE FROM lobby_invitations WHERE id_creator=_id_viewer AND id_target=_id_target AND id_lobby=_id_lobby; --fk lock invitations if creator ?
	--SELECT FROM lobby_invitations WHERE id_lobby=_id_lobby AND id_target=_id_target FOR KEY SHARE SKIP LOCKED

  SELECT FROM lobby_requests WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND id_creator=_id_viewer FOR UPDATE;
  IF NOT FOUND THEN RETURN true; END IF;

  UPDATE lobby_requests SET id_creator=t_lobby_invit.id_creator
    FROM (SELECT id_target, id_lobby, id_creator FROM lobby_invitations WHERE id_lobby=_id_lobby AND id_target=_id_target LIMIT 1 FOR KEY SHARE SKIP LOCKED) t_lobby_invit
    WHERE id_user=t_lobby_invit.id_target AND id_lobby=t_lobby_invit.id_lobby;
  IF FOUND THEN RETURN true; END IF;

  DELETE FROM lobby_requests WHERE id_lobby=_id_lobby AND id_user=_id_target;
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_set_check_join(_id_viewer integer, _id_lobby integer, _check_join boolean) RETURNS boolean AS $$
BEGIN
  UPDATE lobbys SET check_join=_check_join
    WHERE id=_id_lobby
      AND id_owner=_id_viewer
      AND check_join<>_check_join;
  IF NOT FOUND THEN RAISE EXCEPTION 'update not needed'; END IF;

  IF _check_join IS FALSE THEN --update request to invitations
	  UPDATE lobby_requests
	    SET id_creator=t_invit_lobby.id_creator
			FROM (SELECT id_target, id_lobby, id_creator FROM lobby_invitations WHERE id_lobby=_id_lobby FOR KEY SHARE SKIP LOCKED) t_invit_lobby
	      WHERE id_user=t_invit_lobby.id_target AND id_lobby=t_invit_lobby.id_lobby
	        AND id_creator IS NULL;

    DELETE FROM lobby_requests WHERE id_lobby=_id_lobby AND id_creator IS NULL;

	  UPDATE lobby_requests SET status='WAITING_USER'
      WHERE id_lobby=_id_lobby AND status<>'WAITING_USER';
  END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_set_privacy(_id_viewer integer, _id_lobby integer, _privacy lobby_privacy) RETURNS boolean AS $$
BEGIN
  UPDATE lobbys SET privacy=_privacy WHERE id_owner=_id_viewer AND id=_id_lobby AND privacy<>_privacy;
  IF NOT FOUND THEN RAISE EXCEPTION 'update not needed'; END IF;

	IF _privacy='PRIVATE' THEN --keep request with invitation
	  UPDATE lobby_requests
	    SET id_creator=t_invit_lobby.id_creator
			FROM (SELECT id_target, id_lobby, id_creator FROM lobby_invitations WHERE id_lobby=_id_lobby FOR KEY SHARE SKIP LOCKED) t_invit_lobby
	      WHERE id_user=t_invit_lobby.id_target AND id_lobby=t_invit_lobby.id_lobby
	        AND id_creator IS NULL;

	  DELETE FROM lobby_requests WHERE id_lobby=_id_lobby AND id_creator IS NULL;
  END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_set_owner(_id_viewer integer, _id_target integer, _id_lobby integer, _owner_deleted boolean DEFAULT false) RETURNS boolean AS $$
BEGIN
  SET CONSTRAINTS fk_lobby_owner DEFERRED;

  IF(_id_viewer=_id_target)
    THEN RAISE EXCEPTION '_id_viewer == _id_target';
  END IF;

	UPDATE lobbys SET id_owner=_id_target
		WHERE id=_id_lobby AND id_owner=_id_viewer;
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

  IF _owner_deleted IS FALSE THEN
		UPDATE lobby_users SET is_owner=false
			WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner;
    IF NOT FOUND THEN RAISE EXCEPTION 'serialization error'; END IF;
	END IF;

	UPDATE lobby_users SET is_owner=true
		WHERE fk_member=_id_target AND id_lobby=_id_lobby AND is_owner IS FALSE;
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_member target not found'; END IF;

  UPDATE lobby_users SET joinrequest_status=CASE WHEN joinrequest_status='WAITING_LOBBY' THEN 'WAITING_USER'::lobby_active_joinrequest_status ELSE 'INV_WAITING_USER'::lobby_active_joinrequest_status END
    WHERE id_user IN(SELECT id_target FROM lobby_invitations WHERE id_creator=_id_target FOR KEY SHARE) AND id_lobby=_id_lobby
      AND joinrequest_status IN('WAITING_LOBBY','INV_WAITING_LOBBY');

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_ban_user(_id_viewer integer, _id_target integer, _id_lobby integer, _ban_resolved_at timestamptz) RETURNS boolean AS $$
DECLARE
  __was_member boolean;
BEGIN
  IF _id_viewer=_id_target THEN RAISE EXCEPTION '_id_viewer=_id_target'; END IF;

  PERFORM FROM lobbys WHERE id=_id_lobby AND id_owner=_id_viewer FOR SHARE;
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_user unauthz'; END IF;

  SELECT pg_advisory_lock(hashtextextended('lobby_user:'||_id_lobby||'_'||_id_viewer));

	DELETE FROM lobby_requests WHERE id_user=_id_target AND id_lobby=_id_lobby;
  DELETE FROM lobby_members WHERE id_user=_id_target AND id_lobby=_id_lobby RETURNING FOUND INTO __was_member;
	IF _ban_resolved_at > NOW() THEN
	  INSERT INTO lobby_bans(id_user, id_lobby, ban_resolved_at) VALUES(_id_viewer, _id_lobby, _ban_resolved_at);
  END IF;

  IF __was_member THEN
    PERFORM FROM lobby_utils_delete_member_invitation(ARRAY[_id_target],_id_lobby);
    UPDATE lobby_slots SET free_slots=free_slots+1 WHERE id_lobby=_id_lobby;
  END IF;
  
	RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_set_slots(_id_viewer integer, _id_lobby integer, _max_slots integer) RETURNS boolean AS $$
DECLARE
  __change_slots integer;
  __ids_member integer[];
BEGIN
	PERFORM FROM lobbys WHERE id=_id_lobby AND id_owner=_id_viewer FOR NO KEY UPDATE; --prevent join
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

	SELECT _max_slots-(max_slots-free_slots) INTO __change_slots
		FROM lobby_slots
		WHERE id_lobby=_id_lobby AND _max_slots<>max_slots FOR NO KEY UPDATE; --prevent left
	IF NOT FOUND THEN RAISE EXCEPTION 'serialization error, lobby_slots not found'; END IF;

	UPDATE lobby_slots SET max_slots=_max_slots,
	                       free_slots=CASE WHEN __change_slots < 0 THEN 0 ELSE __change_slots END
		WHERE id_lobby=_id_lobby AND max_slots<>_max_slots;
	
	IF __change_slots < 0 THEN
	  WITH delete_members AS (
			DELETE FROM lobby_users
				WHERE fk_member IN(
		      SELECT fk_member FROM lobby_users
		        WHERE fk_member IS NOT NULL AND id_lobby=_id_lobby AND is_owner IS FALSE
		        ORDER BY id_user FOR UPDATE LIMIT -__change_slots)
	      RETURNING fk_member
	  )
	  SELECT array_agg(delete_members.fk_member) INTO __ids_member FROM delete_members;
		PERFORM FROM lobby_utils_delete_member_invitation(__ids_member, _id_lobby);
	END IF;

	RETURN TRUE;
END
$$ LANGUAGE plpgsql;

--UTILS
DROP FUNCTION IF EXISTS lobby_utilis_delete_member_invitation CASCADE;

CREATE OR REPLACE FUNCTION lobby_utils_delete_member_invitation(_ids_creator integer[], _id_lobby integer) RETURNS void AS $$
DECLARE
  __ids_target integer[];
BEGIN
  --alias multiple lobby_invite_cancel
  --[_ids_creator].lobby_users FOR UPDATE - this prevent add of new invitations in name of creator
	SET CONSTRAINTS fk_lobby_request_creator DEFERRED;

  WITH dli AS (
    DELETE FROM lobby_invitations WHERE id_creator=ANY(_ids_creator) AND id_lobby=_id_lobby RETURNING id_target, id_creator
	)
  SELECT array_agg(lobby_request_need_creator.id_user) INTO __ids_target --lock creator requests
    FROM (SELECT id_user FROM lobby_requests lr
      WHERE lr.id_user=dli.id_target AND lr.id_lobby=_id_lobby
        AND lr.id_creator=dli.id_creator
      ORDER BY lr.id_user FOR UPDATE OF lobby_requests) lobby_request_need_creator;

	UPDATE lobby_requests
		  SET id_creator=li_new_creator.id_creator
		FROM (
		  SELECT li.id_target, li.id_creator
				FROM lobby_invitations li, (SELECT DISTINCT id_target FROM lobby_invitations WHERE id_target=ANY(__ids_target) AND id_lobby=_id_lobby) dis_li
				WHERE id_lobby=_id_lobby AND li.id_target=dis_li.id_target
				ORDER BY id_creator FOR KEY SHARE OF lobby_invitations SKIP LOCKED
		) li_new_creator
		WHERE id_lobby=_id_lobby AND id_user=li_new_creator.id_target;

  DELETE FROM lobby_requests WHERE id_lobby=_id_lobby AND id_user=ANY(__ids_target) AND id_creator=ANY(_ids_creator);
END;
$$ LANGUAGE plpgsql;