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
  lobby_set_check_join, lobby_ban_user, lobby_set_privacy, lobby_set_perms, lobby_set_owner, lobby_set_slots CASCADE;

CREATE OR REPLACE FUNCTION lobby_create(_id_viewer integer, _max_slots integer, _check_join boolean, _privacy lobby_privacy, _authz_friend integer, _authz_follower integer, _authz_default integer, OUT id_lobby_ integer) AS $$
BEGIN
  SET CONSTRAINTS ALL DEFERRED;
  INSERT INTO lobbys
    (id_owner, check_join, privacy, authz_friend, authz_follow, authz_default)
    VALUES(_id_viewer, _check_join, _privacy, _authz_friend, _authz_follower, _authz_default)
    RETURNING id INTO id_lobby_;
  INSERT INTO lobby_slots(id_lobby, free_slots, max_slots)
    VALUES(id_lobby_, _max_slots-1, _max_slots);

  INSERT INTO lobby_users
    (id_lobby, id_user, fk_member, is_owner, authz)
    VALUES(id_lobby_, _id_viewer, _id_viewer,  true, 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_join(_id_viewer integer, _id_lobby integer) RETURNS integer AS $$
DECLARE
  __lobby_params lobbys%rowtype;
  
  __viewer_perms integer;
  __allowed_to_join boolean := FALSE;
  __has_joined boolean := FALSE;
BEGIN
  SELECT * INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

  --user
  PERFORM pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, __lobby_params.id_owner),greatest(_id_viewer, __lobby_params.id_owner)));
  PERFORM FROM user_bans WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND id_userb=greatest(_id_viewer, __lobby_params.id_owner) FOR KEY SHARE;
  IF FOUND THEN RAISE EXCEPTION 'users_ban'; END IF;
	PERFORM FROM friends WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND id_userb=greatest(_id_viewer, __lobby_params.id_owner) FOR KEY SHARE;
  IF FOUND THEN
    __viewer_perms := __lobby_params.authz_friend;
    __allowed_to_join := __lobby_params.privacy IN('FRIEND', 'FOLLOWER', 'DEFAULT');
  ELSE
    PERFORM FROM follows WHERE id_follower=_id_viewer AND id_following=__lobby_params.id_owner FOR KEY SHARE;
    IF FOUND THEN
      __viewer_perms := __lobby_params.authz_follow;
      __allowed_to_join := __lobby_params.privacy IN('FOLLOWER', 'DEFAULT');
    ELSE
      __viewer_perms := __lobby_params.authz_default;
      __allowed_to_join := __lobby_params.privacy IN('DEFAULT');
    END IF;
  END IF;

  IF __allowed_to_join THEN
		INSERT INTO lobby_users (id_user, id_lobby, fk_member, is_owner, authz, joinrequest_status)
    	VALUES(_id_viewer,
            _id_lobby,
            CASE WHEN __lobby_params.check_join IS FALSE THEN _id_viewer END,
    	      CASE WHEN __lobby_params.check_join IS FALSE THEN FALSE END,
            CASE WHEN __lobby_params.check_join IS FALSE THEN __viewer_perms END,
            CASE WHEN __lobby_params.check_join THEN 'WAITING_LOBBY'::lobby_active_joinrequest_status END)
    	ON CONFLICT(id_user, id_lobby) DO UPDATE
    	  SET fk_member=CASE WHEN __lobby_params.check_join IS FALSE OR lobby_users.joinrequest_status IN('WAITING_USER','INV_WAITING_USER') THEN _id_viewer END,
    	      is_owner=CASE WHEN __lobby_params.check_join IS FALSE OR lobby_users.joinrequest_status IN('WAITING_USER','INV_WAITING_USER') THEN FALSE END,
    	      authz=CASE WHEN __lobby_params.check_join IS FALSE OR lobby_users.joinrequest_status IN('WAITING_USER','INV_WAITING_USER') THEN __viewer_perms END,
            joinrequest_status=CASE WHEN __lobby_params.check_join AND lobby_users.joinrequest_status NOT IN('WAITING_USER', 'INV_WAITING_USER', 'WAITING_LOBBY') THEN 'WAITING_LOBBY'::lobby_active_joinrequest_status END
        WHERE __lobby_params.check_join IS FALSE
          OR lobby_users.joinrequest_status IN('INV_WAITING_USER', 'WAITING_USER')
          OR (__lobby_params.check_join AND lobby_users.joinrequest_status NOT IN('WAITING_USER', 'INV_WAITING_USER', 'WAITING_LOBBY'))
			RETURNING fk_member IS NOT NULL INTO __has_joined;
		IF NOT FOUND THEN RAISE EXCEPTION 'failed_1'; END IF;
  ELSE
    UPDATE lobby_users SET fk_member=_id_viewer,
                           is_owner=FALSE,
                           authz=__viewer_perms,
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
  SET CONSTRAINTS ALL DEFERRED;
  DELETE FROM lobby_users WHERE (id_lobby=_id_lobby OR _id_lobby IS NULL) AND fk_member=_id_viewer
    RETURNING is_owner, id_lobby INTO __was_owner, __id_lobby;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_users not found'; END IF;

  IF __was_owner IS TRUE THEN
    PERFORM FROM lobbys WHERE id=__id_lobby FOR UPDATE; --prevent join
    SELECT fk_member INTO __new_owner FROM lobby_users WHERE id_lobby=__id_lobby AND fk_member IS NOT NULL LIMIT 1 FOR UPDATE; --prevent leave
    IF NOT FOUND THEN --last lobby_member
      DELETE FROM lobbys WHERE id=__id_lobby;
    ELSE
      --or call lobby_set_owner()
      UPDATE lobbys SET id_owner=__new_owner WHERE id=__id_lobby;
      UPDATE lobby_users SET is_owner=true, authz=1 WHERE id_lobby=__id_lobby AND fk_member=__new_owner;
      
      PERFORM FROM lobby_utils_refresh_member_authz(_id_lobby, true);
    END IF;
  END IF;
  
  PERFORM FROM lobby_utils_delete_member_invitation(ARRAY[_id_viewer], _id_lobby);

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
  PERFORM FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  UPDATE lobby_users SET joinrequest_status=CASE joinrequest_status
      WHEN 'WAITING_LOBBY' THEN 'WAITING_USER'::lobby_active_joinrequest_status
      ELSE 'INV_WAITING_USER'::lobby_active_joinrequest_status END
    WHERE id_lobby=_id_lobby
      AND id_user=_id_target
      AND joinrequest_status IN('WAITING_LOBBY', 'INV_WAITING_LOBBY');
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_joinrequest not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_manage_joinrequest_deny(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner IS TRUE FOR SHARE;
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
  SELECT (0 < authz OR __check_join IS FALSE) INTO __trust_invite FROM lobby_users WHERE fk_member=_id_viewer AND id_lobby=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'user not lobby_member'; END IF;

  --always update if allowed to add lobby_invitations
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
  UPDATE lobbys SET check_join=_check_join --prevent add lobby_invitations/lobby_users
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
  IF NOT FOUND THEN RAISE EXCEPTION 'update failed'; END IF;
	--refresh request eligibility if check_join is true
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_set_perms(_id_viewer integer, _id_lobby integer, _authz_default integer, _authz_follow integer, _authz_friend integer) RETURNS boolean AS $$
BEGIN
  UPDATE lobbys SET authz_default=COALESCE(_authz_default, authz_default),
                    authz_follow=COALESCE(_authz_follow, authz_follow),
                    authz_friend=COALESCE(_authz_friend, authz_friend)
    WHERE id=_id_lobby AND id_owner=_id_viewer AND (authz_default<>_authz_default OR authz_follow<>_authz_follow OR authz_friend<>_authz_friend);
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found or no need to update'; END IF;
  
	PERFORM FROM lobby_utils_refresh_member_authz(_id_lobby,false);
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_set_owner(_id_viewer integer, _id_lobby integer, _id_target integer) RETURNS boolean AS $$
DECLARE
  __authz integer[];
  __check_join boolean;
BEGIN
  IF(_id_viewer=_id_target)
    THEN RAISE EXCEPTION '_id_viewer == _id_target';
  END IF;

	UPDATE lobbys SET id_owner=_id_target
		WHERE id=_id_lobby AND id_owner=_id_viewer
		RETURNING array[authz_friend, authz_follow, authz_default], check_join INTO __authz, __check_join;
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

	UPDATE lobby_users SET is_owner=false
		WHERE fk_member=_id_viewer AND id_lobby=_id_lobby AND is_owner;
  IF NOT FOUND THEN RAISE EXCEPTION 'serialization error'; END IF;

	UPDATE lobby_users SET is_owner=true, authz=1
		WHERE fk_member=_id_target AND id_lobby=_id_lobby AND is_owner IS FALSE;
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_users target not found'; END IF;

  PERFORM FROM lobby_utils_refresh_member_authz(_id_lobby, true);
  
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_ban_user(_id_viewer integer, _id_lobby integer, _id_target integer, _ban_resolved_at timestamptz) RETURNS boolean AS $$
DECLARE
  __was_member boolean;
BEGIN
  IF(_id_viewer=_id_target)
    THEN RAISE EXCEPTION '_id_viewer == _id_target';
  END IF;

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
                                authz=null,
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
	PERFORM FROM lobbys WHERE id=_id_lobby AND id_owner=_id_viewer FOR UPDATE; --prevent join
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

	SELECT _max_slots-(max_slots-free_slots) INTO __change_slots
		FROM lobby_slots
		WHERE id_lobby=_id_lobby AND _max_slots<>max_slots FOR UPDATE; --prevent left
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_slots not found'; END IF;

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
DROP FUNCTION IF EXISTS lobby_utils_refresh_member_authz, lobby_utils_delete_member_invitation CASCADE;

CREATE OR REPLACE FUNCTION lobby_utils_refresh_member_authz(_id_lobby integer,  _refresh_owner boolean) RETURNS void AS $$
/*
update members.authz
lobby.check_join ? update members.invitations
*/
DECLARE
  __authz integer[];
  __id_owner integer;
  __check_join boolean;
  __ids_request integer[];
BEGIN
  SELECT ARRAY[authz_default, authz_follow, authz_friend], id_owner, check_join INTO __authz, __id_owner,__check_join FROM lobbys WHERE lobbys.id=_id_lobby FOR UPDATE;
  IF __check_join IS FALSE THEN
	  UPDATE lobby_users
			SET authz =
				CASE WHEN EXISTS(SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:' || least(fk_member, __id_owner),greatest(fk_member, __id_owner)))) THEN
					CASE WHEN EXISTS(SELECT FROM friends WHERE id_usera = least(__id_owner, fk_member) AND id_userb = greatest(__id_owner, fk_member) FOR KEY SHARE) THEN __authz[1]
						WHEN EXISTS(SELECT FROM follows WHERE id_follower = fk_member AND id_following = __id_owner FOR KEY SHARE) THEN __authz[2]
						ELSE __authz[3]
					END
				END
		  WHERE fk_member IS NOT NULL AND id_lobby=_id_lobby AND is_owner IS FALSE;
	ELSE
    WITH upd_members AS (
			UPDATE lobby_users
		    SET authz = CASE WHEN is_owner THEN 1
          WHEN EXISTS(SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:' || least(fk_member, __id_owner),greatest(fk_member, __id_owner)))) THEN
					  CASE WHEN EXISTS(SELECT FROM friends WHERE id_usera = least(__id_owner, fk_member) AND id_userb = greatest(__id_owner, fk_member) FOR KEY SHARE) THEN __authz[1]
						  WHEN EXISTS(SELECT FROM follows WHERE id_follower = fk_member AND id_following = __id_owner FOR KEY SHARE) THEN __authz[2]
						  ELSE __authz[3]
					  END
				  END
        WHERE fk_member IS NOT NULL AND id_lobby=_id_lobby AND ((is_owner AND _refresh_owner) OR is_owner IS FALSE)
        RETURNING id_user, authz
    )
    SELECT array_agg(t_target_users.id) INTO __ids_request FROM (
      SELECT lobby_users.id_user AS id
        FROM (
			    SELECT DISTINCT lobby_invitations.id_target AS id_target FROM (SELECT id_user FROM upd_members WHERE upd_members.authz > 0) t_creators
	          JOIN lobby_invitations ON lobby_invitations.id_creator=t_creators.id_user AND lobby_invitations.id_lobby=_id_lobby
	        ) t_targets
	      JOIN lobby_users ON lobby_users.id_user=t_targets.id_target
				WHERE lobby_users.joinrequest_status IS NOT NULL --NOT IN('INV_WAITING_USER', 'WAITING_USER') --issue #2
        ORDER BY id_user FOR UPDATE OF lobby_users) t_target_users;
    
    UPDATE lobby_users --todo get id_actor
      SET joinrequest_status=
        CASE WHEN joinrequest_status='WAITING_LOBBY'
          THEN 'WAITING_USER'::lobby_active_joinrequest_status
          ELSE 'INV_WAITING_USER'::lobby_active_joinrequest_status END
      WHERE id_user=ANY(__ids_request) AND id_lobby=_id_lobby AND joinrequest_status NOT IN('INV_WAITING_USER', 'WAITING_USER');
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_utils_delete_member_invitation(_ids_member integer[], _id_lobby integer) RETURNS void AS $$
DECLARE
  __ids_target integer[];
BEGIN
  --alias multiple lobby_invite_cancel
  --[ids_member].lobby_users need UPDATE lock this prevent add of new invitations
  
  PERFORM FROM lobby_users
    WHERE joinrequest_status IS NOT NULL --NOT IN('WAITING_USER' 'WAITING_LOBBY') --issue #3
      AND id_lobby=_id_lobby
      AND id_user IN(SELECT id_target FROM lobby_invitations WHERE id_creator=ANY(_ids_member) AND id_lobby=_id_lobby)
      ORDER BY id_user FOR UPDATE OF lobby_users;

  WITH del_lobby_invitations AS (
    DELETE FROM lobby_invitations WHERE id_creator=ANY(_ids_member) AND id_lobby=_id_lobby RETURNING id_target
	)
	SELECT array_agg(id_target) INTO __ids_target FROM del_lobby_invitations;
  
  DELETE FROM lobby_users
    WHERE id_user=ANY(__ids_target)
      AND id_lobby=_id_lobby
      AND joinrequest_status NOT IN('WAITING_USER', 'WAITING_LOBBY')
      AND NOT EXISTS(SELECT FROM lobby_invitations WHERE id_target=lobby_users.id_user AND id_lobby=_id_lobby FOR KEY SHARE);--SKIP LOCKED
END;
$$ LANGUAGE plpgsql;