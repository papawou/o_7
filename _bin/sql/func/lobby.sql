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
--todo refresh eligibility waiting_request / in set_privacy, set_owner
--todo change order of execution lock request and invitations using for key skip locked

DROP FUNCTION IF EXISTS lobby_create, lobby_join, lobby_leave,
  lobby_user_joinrequest_deny, lobby_manage_joinrequest_accept, lobby_manage_joinrequest_deny,
	lobby_invite_create, lobby_invite_cancel,
  lobby_set_check_join, lobby_ban_user, lobby_set_privacy, lobby_set_perms, lobby_set_owner, lobby_set_slots CASCADE;

CREATE OR REPLACE FUNCTION lobby_create(_id_viewer integer, _max_slots integer, _check_join boolean, _privacy lobby_privacy, OUT id_lobby_ integer) AS $$
BEGIN
  SET CONSTRAINTS ALL DEFERRED;
  INSERT INTO lobbys
    (id_owner, check_join, privacy)
    VALUES(_id_viewer, _check_join, _privacy)
    RETURNING id INTO id_lobby_;
  INSERT INTO lobby_slots(id_lobby, free_slots, max_slots)
    VALUES(id_lobby_, _max_slots-1, _max_slots);

  INSERT INTO lobby_users
    (id_lobby, id_user, fk_member, is_owner)
    VALUES(id_lobby_, _id_viewer, _id_viewer,  true);
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

  __allowed_to_join boolean := FALSE;
  __has_joined boolean := FALSE;
BEGIN
  SELECT check_join, privacy, id_owner INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

  --user_user rel
  CASE relation_user_user(_id_viewer, __lobby_params.id_owner)
    WHEN -1 THEN RAISE EXCEPTION 'user_user_ban';
    WHEN 2 THEN
      __allowed_to_join := __lobby_params.privacy IN('FRIEND', 'FOLLOWER', 'DEFAULT');
    WHEN 1 THEN
      __allowed_to_join := __lobby_params.privacy IN('FOLLOWER', 'DEFAULT');
    ELSE
      __allowed_to_join := __lobby_params.privacy IN('DEFAULT');
  END CASE;

  IF __allowed_to_join THEN
		INSERT INTO lobby_users (id_user, id_lobby, fk_member, is_owner, joinrequest_status)
    	VALUES(_id_viewer,
            _id_lobby,
            CASE WHEN __lobby_params.check_join IS FALSE THEN _id_viewer END,
    	      CASE WHEN __lobby_params.check_join IS FALSE THEN FALSE END,
            CASE WHEN __lobby_params.check_join THEN 'WAITING_LOBBY'::lobby_active_joinrequest_status END)
    	ON CONFLICT(id_user, id_lobby) DO UPDATE
    	  SET fk_member=CASE WHEN __lobby_params.check_join IS FALSE OR lobby_users.joinrequest_status IN('WAITING_USER','INV_WAITING_USER') THEN _id_viewer END,
    	      is_owner=CASE WHEN __lobby_params.check_join IS FALSE OR lobby_users.joinrequest_status IN('WAITING_USER','INV_WAITING_USER') THEN FALSE END,
    	      joinrequest_status=CASE WHEN __lobby_params.check_join AND lobby_users.joinrequest_status NOT IN('WAITING_USER', 'INV_WAITING_USER', 'WAITING_LOBBY') THEN 'WAITING_LOBBY'::lobby_active_joinrequest_status END
        WHERE __lobby_params.check_join IS FALSE
          OR lobby_users.joinrequest_status IN('INV_WAITING_USER', 'WAITING_USER')
          OR (__lobby_params.check_join AND lobby_users.joinrequest_status NOT IN('WAITING_USER', 'INV_WAITING_USER', 'WAITING_LOBBY'))
			RETURNING fk_member IS NOT NULL INTO __has_joined;
		IF NOT FOUND THEN RAISE EXCEPTION 'failed_1'; END IF;
  ELSE
    UPDATE lobby_users SET fk_member=_id_viewer,
                           is_owner=FALSE,
                           joinrequest_status=NULL
      WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND lobby_users.joinrequest_status IN('INV_WAITING_USER', 'WAITING_USER')
      RETURNING fk_member IS NOT NULL INTO __has_joined;
    IF NOT FOUND THEN RAISE EXCEPTION 'failed_2'; END IF;
	END IF;

  IF __has_joined THEN
		DELETE FROM lobby_invitations WHERE id_target=_id_viewer AND id_lobby=_id_lobby;
		UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby=_id_lobby;
		RETURN 1;
	ELSE
    RETURN 2;
  END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_leave(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
  __id_lobby integer;
  __was_owner boolean;
  __new_owner integer;
BEGIN
  SELECT id_lobby, is_owner INTO id_lobby, __was_owner FROM lobby_users WHERE fk_member=_id_viewer AND (id_lobby=_id_lobby OR _id_lobby IS NULL);
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_user not member'; END IF;

  IF __was_owner THEN
    SELECT FROM lobbys WHERE id=__id_lobby AND id_owner=_id_viewer FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'serialization error lobby_user not owner'; END IF;
	ELSE
    SELECT FROM lobbys WHERE id=_id_lobby FOR SHARE;
  END IF;

  DELETE FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=__id_lobby;
  IF NOT FOUND THEN RAISE EXCEPTION 'serialization error lobby_user not member'; END IF;

  PERFORM FROM lobby_utils_delete_member_invitation(ARRAY[_id_viewer], _id_lobby);

  IF __was_owner THEN
    SELECT fk_member INTO __new_owner FROM lobby_users WHERE id_lobby=__id_lobby AND fk_member IS NOT NULL LIMIT 1 FOR NO KEY UPDATE; --prevent leave
    IF NOT FOUND THEN --last lobby_member
      DELETE FROM lobbys WHERE id=__id_lobby;
      RETURN true;
    ELSE
      --lobby_set_owner ?
      UPDATE lobbys SET id_owner=__new_owner WHERE id=__id_lobby;
      UPDATE lobby_users SET is_owner=true WHERE id_lobby=__id_lobby AND fk_member=__new_owner;
    END IF;
  END IF;

  UPDATE lobby_slots SET free_slots=free_slots+1 WHERE id_lobby=__id_lobby;
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_user_joinrequest_deny(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  DELETE FROM lobby_users
    WHERE id_lobby=_id_lobby AND id_user=_id_viewer AND joinrequest_status IN('INV_WAITING_USER', 'WAITING_LOBBY', 'WAITING_USER');
  IF NOT FOUND THEN RAISE EXCEPTION 'joinrequest not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_manage_joinrequest_accept(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobbys WHERE id=_id_lobby AND id_owner=_id_viewer FOR SHARE; --PERFORM FOR SHARE lobby_users?
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  UPDATE lobby_users SET joinrequest_status=CASE joinrequest_status
      WHEN 'WAITING_LOBBY' THEN 'WAITING_USER'::lobby_active_joinrequest_status
      ELSE 'INV_WAITING_USER'::lobby_active_joinrequest_status END
    WHERE id_lobby=_id_lobby AND id_user=_id_target
      AND joinrequest_status IN('WAITING_LOBBY', 'INV_WAITING_LOBBY');
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_joinrequest not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_manage_joinrequest_deny(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobbys WHERE id=_id_lobby AND id_owner=_id_viewer FOR SHARE; --PERFORM FOR SHARE lobby_users?
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  DELETE FROM lobby_users
    WHERE id_lobby=_id_lobby
      AND id_user=_id_target
      AND joinrequest_status IN ('WAITING_USER', 'WAITING_LOBBY', 'INV_WAITING_USER', 'INV_WAITING_LOBBY');
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_joinrequest not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_invite_create(_id_viewer integer, _id_lobby integer, _id_target integer) RETURNS boolean AS $$
DECLARE
    __check_join boolean;
    __trust_invite boolean;
BEGIN
  PERFORM FROM friends WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target) FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'not friends'; END IF;

  SELECT check_join INTO __check_join FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;
  SELECT (__check_join IS FALSE) INTO __trust_invite FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'user not lobby_member'; END IF;

  INSERT INTO lobby_users(id_user, id_lobby, joinrequest_status)
    VALUES(_id_target,
           _id_lobby,
           CASE WHEN __trust_invite THEN 'INV_WAITING_USER'::lobby_active_joinrequest_status ELSE 'INV_WAITING_LOBBY'::lobby_active_joinrequest_status END)
    ON CONFLICT(id_user, id_lobby) DO UPDATE
      SET joinrequest_status=
        CASE WHEN lobby_users.joinrequest_status IN('INV_WAITING_USER', 'WAITING_USER') THEN lobby_users.joinrequest_status
          WHEN __trust_invite THEN
            CASE lobby_users.joinrequest_status WHEN 'WAITING_LOBBY' THEN 'WAITING_USER'::lobby_active_joinrequest_status
              ELSE 'INV_WAITING_USER'::lobby_active_joinrequest_status END
          WHEN lobby_users.joinrequest_status IN('WAITING_LOBBY') THEN 'WAITING_LOBBY'::lobby_active_joinrequest_status
          ELSE 'INV_WAITING_LOBBY'::lobby_active_joinrequest_status
        END;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_user not found'; END IF;

  INSERT INTO lobby_invitations(id_target, id_lobby, id_creator) VALUES(_id_target, _id_lobby, _id_viewer);
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_invite_cancel(_id_viewer integer, _id_lobby integer, _id_target integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobby_users WHERE id_user=_id_target AND id_lobby=_id_lobby AND joinrequest_status IS NOT NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_user not found'; END IF;
  DELETE FROM lobby_invitations WHERE id_creator=_id_viewer AND id_target=_id_target;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_invit not found'; END IF;

  PERFORM FROM lobby_invitations WHERE id_target=_id_target AND id_lobby=_id_lobby LIMIT 1 FOR KEY SHARE; --skip locked?
  IF NOT FOUND THEN
    DELETE FROM lobby_users WHERE id_user=_id_target AND id_lobby=_id_lobby AND joinrequest_status IN('INV_WAITING_LOBBY', 'INV_WAITING_USER');
  END IF;
  
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

  IF _check_join IS FALSE THEN
    PERFORM FROM lobby_users WHERE id_lobby=_id_lobby AND joinrequest_status IS NOT NULL ORDER BY id_user FOR UPDATE; --issue #1 <>'INV_WAITING_USER'
    
	  UPDATE lobby_users SET joinrequest_status='INV_WAITING_USER'
	    WHERE id_lobby=_id_lobby
	      AND joinrequest_status<>'INV_WAITING_USER'
	      AND EXISTS(SELECT FROM lobby_invitations WHERE id_target=lobby_users.id_user AND lobby_invitations.id_lobby=_id_lobby FOR KEY SHARE);
		
    DELETE FROM lobby_users
      WHERE id_lobby=_id_lobby
        AND joinrequest_status<>'INV_WAITING_USER';
  END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_set_privacy(_id_viewer integer, _id_lobby integer, _privacy lobby_privacy) RETURNS boolean AS $$
BEGIN
  UPDATE lobbys SET privacy=_privacy WHERE id_owner=_id_viewer AND id=_id_lobby AND privacy<>_privacy;
  IF NOT FOUND THEN RAISE EXCEPTION 'update not needed'; END IF;

  IF _privacy<>'DEFAULT' THEN --test
	  PERFORM FROM lobby_users WHERE id_lobby=_id_lobby AND joinrequest_status IS NOT NULL ORDER BY id_user FOR UPDATE;
	  IF _privacy='PRIVATE' THEN --keep request with invitation
      UPDATE lobby_users SET joinrequest_status=CASE WHEN joinrequest_status='WAITING_LOBBY' THEN 'INV_WAITING_LOBBY' ELSE 'INV_WAITING_USER' END
        WHERE id_lobby=_id_lobby AND joinrequest_status IN('WAITING_LOBBY', 'WAITING_USER')
          AND EXISTS(SELECT FROM lobby_invitations WHERE id_target=lobby_users.id_user AND id_lobby=_id_lobby FOR KEY SHARE);
      DELETE FROM lobby_users WHERE joinrequest_status IN('WAITING_LOBBY','WAITING_USER') AND id_lobby=_id_lobby;
    ELSE --keep request with invitation and eligible request
      DELETE FROM lobby_users --delete not eligible request
        WHERE joinrequest_status IN('WAITING_LOBBY','WAITING_USER') AND id_lobby=_id_lobby
	        AND (CASE relation_user_user(lobby_users.id_user, _id_viewer)
	            WHEN 2 THEN _privacy<>'PRIVATE'
	            WHEN 1 THEN _privacy IN('DEFAULT', 'FOLLOW')
	            ELSE _privacy IN('DEFAULT') END) IS NOT TRUE
	        AND NOT EXISTS(SELECT FROM lobby_invitations WHERE id_target=lobby_users.id_user AND id_lobby=_id_lobby FOR KEY SHARE);

			--update request.status not eligible with invitation to invitation
      UPDATE lobby_users SET joinrequest_status=CASE WHEN joinrequest_status='WAITING_LOBBY' THEN 'INV_WAITING_LOBBY' ELSE 'INV_WAITING_USER' END
        WHERE id_lobby=_id_lobby AND joinrequest_status IN('WAITING_LOBBY', 'WAITING_USER')
          AND (CASE relation_user_user(lobby_users.id_user, _id_viewer)
	            WHEN 2 THEN _privacy<>'PRIVATE'
	            WHEN 1 THEN _privacy IN('DEFAULT', 'FOLLOW')
	            ELSE _privacy IN('DEFAULT') END) IS NOT TRUE
          AND EXISTS(SELECT FROM lobby_invitations WHERE id_target=lobby_users.id_user AND id_lobby=_id_lobby FOR KEY SHARE);
    END IF;
  END IF;
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_set_owner(_id_viewer integer, _id_lobby integer, _id_target integer) RETURNS boolean AS $$
BEGIN
  IF(_id_viewer=_id_target)
    THEN RAISE EXCEPTION '_id_viewer == _id_target';
  END IF;

	UPDATE lobbys SET id_owner=_id_target
		WHERE id=_id_lobby AND id_owner=_id_viewer;
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

	UPDATE lobby_users SET is_owner=false
		WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner;
  IF NOT FOUND THEN RAISE EXCEPTION 'serialization error'; END IF;

	UPDATE lobby_users SET is_owner=true
		WHERE fk_member=_id_target AND id_lobby=_id_lobby AND is_owner IS FALSE;
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_member target not found'; END IF;
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_ban_user(_id_viewer integer, _id_lobby integer, _id_target integer, _ban_resolved_at timestamptz) RETURNS boolean AS $$
DECLARE
  __was_member boolean;
BEGIN
  PERFORM FROM lobby_users WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND is_owner FOR SHARE;
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_user unauthz'; END IF;

	IF _ban_resolved_at IS NULL OR _ban_resolved_at < NOW() THEN --kick
		DELETE FROM lobby_users
			WHERE id_user=_id_target AND id_lobby=_id_lobby AND is_owner IS FALSE
			RETURNING fk_member IS NOT NULL INTO __was_member;
	ELSE
	  INSERT INTO lobby_users(id_user, id_lobby, ban_resolved_at)
      VALUES(_id_target, _id_lobby, _ban_resolved_at)
      ON CONFLICT(id_user, id_lobby) DO UPDATE SET fk_member=null,
                                joinrequest_status=null,
                                ban_resolved_at=_ban_resolved_at
	    WHERE is_owner IS FALSE
      RETURNING fk_member IS NOT NULL INTO __was_member;
	END IF;
	IF NOT FOUND THEN RAISE EXCEPTION 'ban failed'; END IF;
  
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
CREATE OR REPLACE FUNCTION lobby_utils_delete_member_invitation(_ids_creator integer[], _id_lobby integer) RETURNS void AS $$
DECLARE
  __ids_target integer[];
BEGIN
  --alias multiple lobby_invite_cancel
  --[_ids_creator].lobby_users FOR UPDATE - this prevent add of new invitations
  
  PERFORM FROM lobby_users
    WHERE joinrequest_status IS NOT NULL --NOT IN('WAITING_USER' 'WAITING_LOBBY') --issue #3
      AND id_lobby=_id_lobby
      AND id_user IN(SELECT id_target FROM lobby_invitations WHERE id_creator=ANY(_ids_creator) AND id_lobby=_id_lobby)
      ORDER BY id_user FOR UPDATE OF lobby_users;

  WITH del_lobby_invitations AS (
    DELETE FROM lobby_invitations WHERE id_creator=ANY(_ids_creator) AND id_lobby=_id_lobby RETURNING id_target, id_creator
	)
	SELECT array_agg(id_target) INTO __ids_target FROM del_lobby_invitations;
  
  DELETE FROM lobby_users --todo get id_actor
    WHERE id_user=ANY(__ids_target)
      AND id_lobby=_id_lobby
      AND joinrequest_status NOT IN('WAITING_USER', 'WAITING_LOBBY')
      AND NOT EXISTS(SELECT FROM lobby_invitations WHERE id_target=lobby_users.id_user AND id_lobby=_id_lobby FOR KEY SHARE);--SKIP LOCKED
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION relation_user_user(_id_viewer integer, _id_target integer) RETURNS integer AS $$
/*
RETURN
	0 = no relation
	1 = _id_viewer follow _id_target
	2 = are friends
	-1= block
*/
DECLARE
  __least integer DEFAULT least(_id_viewer, _id_target);
  __greatest integer DEFAULT greatest(_id_viewer, _id_target);
BEGIN
  IF(_id_viewer=_id_target) THEN RAISE EXCEPTION '_id_viewer=_id_target'; END IF;

	--test
	PERFORM pg_advisory_xact_lock_shared(hashtextextended('user_user:' || __least,__greatest));
	PERFORM FROM user_bans WHERE id_usera=__least AND id_userb=__greatest FOR KEY SHARE;
	IF FOUND THEN RETURN -1; END IF;

	PERFORM FROM friends WHERE id_usera=__least AND id_userb=__greatest FOR KEY SHARE;
	IF FOUND THEN RETURN 2; END IF;

	PERFORM FROM follows WHERE id_follower=_id_viewer AND id_following=_id_target FOR KEY SHARE;
	IF FOUND THEN RETURN 1;
	ELSE RETURN 0;
	END IF;
END
$$ LANGUAGE plpgsql;