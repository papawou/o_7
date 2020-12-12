/*
BASICS
--user
	lobby_create
	lobby_join
		=lobby_request_create
	  =lobby_user_request_confirm
		=lobby_invite_confirm
		allowed_to_join ?
			update request_status id_creator=null
		RETURN has_joined ? 1 : 2
--member
	lobby_leave
REQUEST
--user
	lobby_user_request_create
		==lobby_join
	lobby_user_request_confirm
		==lobby_join
	lobby_user_request_deny/cancel
--lobby
	lobby_manage_request_accept
	lobby_manage_request_deny/cancel

--member
	lobby_invite_create
	lobby_invite_cancel
--target
	lobby_target_invite_confirm
		==lobby_join
		?enforce check lobby_invitation
	lobby_target_invite_deny
		==lobby_user_request_cancel
		?notifications
--lobby
	lobby_manage_invite_accept
		==lobby_manage_request_accept
	lobby_manage_invite_deny/cancel
		==lobby_manage_request_deny

PERMISSIONS
--lobby
	lobby_set_check_join
	lobby_set_privacy
	lobby_set_owner
	lobby_ban_user
	lobby_set_slots
UTILS
	lobby_utils_delete_member_invitation
*/

DROP FUNCTION IF EXISTS lobby_create, lobby_join, lobby_leave,
  lobby_user_request_deny, lobby_manage_request_accept, lobby_manage_request_deny,
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
    VALUES(id_lobby_, _id_viewer,  true);
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
  __request_valid boolean DEFAULT FALSE;
  __full_lobby boolean;
BEGIN
  SELECT check_join, privacy, id_owner INTO __lobby_params FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

  --user_user relation
  PERFORM pg_advisory_lock_shared(hashtextextended('user_user:'||least(_id_viewer, __lobby_params.id_owner)||'_'||greatest(_id_viewer, __lobby_params.id_owner)::text, least(_id_viewer, __lobby_params.id_owner)));
  PERFORM FROM user_bans WHERE id_usera=least(_id_viewer, __lobby_params.id_owner) AND id_userb=greatest(_id_viewer, __lobby_params.id_owner);
  IF FOUND THEN RAISE EXCEPTION 'users_block'; END IF;

  PERFORM pg_advisory_lock(hashtextextended('lobby:'||_id_viewer::text, _id_viewer));
	PERFORM FROM lobby_requests WHERE id_user=_id_viewer AND id_creator IS NULL AND id_lobby<>_id_lobby;
  IF FOUND THEN RAISE EXCEPTION 'already lobby request'; END IF;
  PERFORM FROM lobby_members WHERE id_user=_id_viewer;
  IF FOUND THEN RAISE EXCEPTION 'already lobby member'; END IF;
  PERFORM FROM lobby_bans WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND ban_resolved_at > NOW();
  IF FOUND THEN RAISE EXCEPTION 'lobby_ban user'; END IF;

  --PERFORM pg_advisory_lock(hashtextextended('lobby_user:'||_id_lobby||'_'||_id_viewer::text, _id_lobby));

  SELECT need_validation IS FALSE INTO __request_valid FROM lobby_requests WHERE id_user=_id_viewer AND id_lobby=_id_lobby FOR UPDATE;
  IF __request_valid OR (__lobby_params.check_join IS FALSE AND __lobby_params.privacy='DEFAULT') THEN --can_join the lobby
	  SELECT free_slots-1<0 INTO __full_lobby FROM lobby_slots WHERE id_lobby=_id_lobby FOR NO KEY UPDATE;
	  IF __full_lobby AND __lobby_params.check_join AND __lobby_params.privacy='DEFAULT' THEN --lobby_full, convert invit to request
			UPDATE lobby_requests SET id_creator=null
  		  WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND lobby_requests.id_creator IS NOT NULL;
			IF NOT FOUND THEN RAISE EXCEPTION 'failed_2'; END IF;
			RETURN 2;
		ELSIF __full_lobby IS FALSE THEN
		  DELETE FROM lobby_requests WHERE id_lobby=_id_lobby AND id_user=_id_viewer;
	    INSERT INTO lobby_members(id_lobby, id_user) VALUES(_id_lobby, _id_viewer);
	    UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby=_id_lobby;
			RETURN 1;
		END IF;
  ELSIF __lobby_params.check_join AND __lobby_params.privacy='DEFAULT' THEN
    INSERT INTO lobby_requests(id_user, id_lobby, need_validation) VALUES(_id_viewer, _id_lobby, true)
  	  ON CONFLICT (id_user, id_lobby)
  	    DO UPDATE SET id_creator=null
  		  WHERE lobby_requests.id_creator IS NOT NULL;
    IF NOT FOUND THEN RAISE EXCEPTION 'failed'; END IF;
    RETURN 2;
	END IF;
  RAISE EXCEPTION 'unauthz';
END
$$ LANGUAGE plpgsql;

--todo
CREATE OR REPLACE FUNCTION lobby_leave(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
  __id_lobby integer;
  __was_owner boolean;
  __new_owner integer;
BEGIN
  SET CONSTRAINTS fk_lobby_owner, fk_lobby_request_creator, lobby_invitations_id_lobby_id_creator_fkey DEFERRED;

  DELETE FROM lobby_members
    WHERE id_user=_id_viewer AND (id_lobby=_id_lobby OR _id_lobby IS NULL)
    RETURNING id_lobby, is_owner INTO __id_lobby, __was_owner;
	IF NOT FOUND THEN RAISE EXCEPTION 'not lobby member'; END IF;

  PERFORM FROM lobby_utils_delete_member_invitation(ARRAY[_id_viewer], __id_lobby);
  IF __was_owner THEN
    SELECT id_user INTO __new_owner FROM lobby_members WHERE id_lobby=__id_lobby LIMIT 1 FOR NO KEY UPDATE;
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

CREATE OR REPLACE FUNCTION lobby_user_request_deny(_id_viewer integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  DELETE FROM lobby_requests
    WHERE id_lobby=_id_lobby AND id_user=_id_viewer
      AND (id_creator IS NOT NULL AND need_validation) IS FALSE; --prevent delete of INV_WAITING_LOBBY
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby_request not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_manage_request_accept(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM lobbys WHERE id=_id_lobby AND id_owner=_id_viewer FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  UPDATE lobby_requests SET need_validation=false
    WHERE id_lobby=_id_lobby AND id_user=_id_target AND need_validation;
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_request not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_manage_request_deny(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
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
  SET CONSTRAINTS fk_lobby_request_creator DEFERRED;

  PERFORM FROM friends WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target) FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'not friends'; END IF;


  PERFORM pg_advisory_lock(hashtextextended('lobby:'||_id_target::text, _id_target));
	PERFORM FROM lobby_bans WHERE id_user=_id_target AND id_lobby=_id_lobby AND ban_resolved_at > NOW();
  IF FOUND THEN RAISE EXCEPTION 'lobby_ban user'; END IF;
  PERFORM FROM lobby_members WHERE id_lobby=_id_lobby AND id_user=_id_target;
  IF FOUND THEN RAISE EXCEPTION 'already member'; END IF;

  SELECT (check_join IS FALSE OR id_owner=_id_viewer) INTO __trust_invite FROM lobbys WHERE id=_id_lobby FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

  INSERT INTO lobby_requests(id_user, id_lobby, need_validation, id_creator)
    VALUES(_id_target, _id_lobby, __trust_invite IS FALSE, _id_viewer)
    ON CONFLICT(id_lobby, id_user) DO UPDATE
      SET need_validation=false
    WHERE __trust_invite
      AND need_validation;

  INSERT INTO lobby_invitations(id_creator, id_target, id_lobby) VALUES(_id_viewer, _id_target, _id_lobby);

  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_invite_cancel(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
BEGIN
  SET CONSTRAINTS fk_lobby_request_creator DEFERRED;
  /* --call lobby_manage_request_deny if owner
  PERFORM FROM lobbys WHERE id=_id_lobby AND id_owner=_id_viewer;

  IF FOUND THEN
    PERFORM lobby_manage_request_deny(_id_viewer,_id_target,_id_lobby);
    RETURN;
  END IF;
  */
  DELETE FROM lobby_invitations WHERE id_creator=_id_viewer AND id_target=_id_target AND id_lobby=_id_lobby; --fk lock invitations if creator ?

  PERFORM FROM lobby_requests WHERE id_user=_id_target AND id_lobby=_id_lobby AND id_creator=_id_viewer FOR UPDATE;
  IF NOT FOUND THEN RETURN true; END IF;

  UPDATE lobby_requests SET id_creator=t_lobby_invit.id_creator
    FROM (SELECT id_target, id_lobby, id_creator FROM lobby_invitations WHERE id_lobby=_id_lobby AND id_target=_id_target LIMIT 1 FOR KEY SHARE SKIP LOCKED) t_lobby_invit
    WHERE lobby_requests.id_user=t_lobby_invit.id_target AND lobby_requests.id_lobby=t_lobby_invit.id_lobby;
  IF NOT FOUND THEN
    DELETE FROM lobby_requests WHERE id_lobby=_id_lobby AND id_user=_id_target AND id_creator=_id_viewer;
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

  IF _check_join IS FALSE THEN --update request to invitations
	  UPDATE lobby_requests lr
	    SET id_creator=t_inv_creators.id_creator
			FROM (SELECT id_target, id_creator FROM lobby_invitations WHERE id_lobby=_id_lobby FOR KEY SHARE SKIP LOCKED) t_inv_creators --use of distinct use in subquery lobby_requests ?
	      WHERE lr.id_user=t_inv_creators.id_target AND lr.id_lobby=_id_lobby
	        AND lr.id_creator IS NULL;

    DELETE FROM lobby_requests WHERE id_lobby=_id_lobby AND id_creator IS NULL;

	  UPDATE lobby_requests SET need_validation=false
      WHERE id_lobby=_id_lobby AND need_validation;
  END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_set_privacy(_id_viewer integer, _id_lobby integer, _privacy lobby_privacy) RETURNS boolean AS $$
BEGIN
  UPDATE lobbys SET privacy=_privacy WHERE id_owner=_id_viewer AND id=_id_lobby AND privacy<>_privacy;
  IF NOT FOUND THEN RAISE EXCEPTION 'update not needed'; END IF;

	IF _privacy='PRIVATE' THEN --update request with invitation
	  UPDATE lobby_requests lr
	    SET id_creator=t_inv_creators.id_creator
			FROM (SELECT id_target, id_creator FROM lobby_invitations WHERE id_lobby=_id_lobby FOR KEY SHARE SKIP LOCKED) t_inv_creators --see lobby_set_check_join
	      WHERE lr.id_lobby=_id_lobby AND lr.id_creator IS NULL
	        AND lr.id_user=t_inv_creators.id_target;

	  DELETE FROM lobby_requests WHERE id_lobby=_id_lobby AND id_creator IS NULL;
  END IF;

  RETURN true;
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
		UPDATE lobby_members SET is_owner=false
			WHERE id_user=_id_viewer AND id_lobby=_id_lobby AND is_owner;
    IF NOT FOUND THEN RAISE EXCEPTION 'serialization error'; END IF;
	END IF;

	UPDATE lobby_members SET is_owner=true
		WHERE id_user=_id_target AND id_lobby=_id_lobby AND is_owner IS FALSE;
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_member target not found'; END IF;

  UPDATE lobby_requests SET need_validation=false
    WHERE id_user IN(SELECT id_target FROM lobby_invitations WHERE id_creator=_id_target FOR KEY SHARE SKIP LOCKED) AND id_lobby=_id_lobby
      AND need_validation;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_ban_user(_id_viewer integer, _id_target integer, _id_lobby integer, _ban_resolved_at timestamptz) RETURNS boolean AS $$
DECLARE
  __was_member boolean DEFAULT FALSE;
BEGIN
  SET CONSTRAINTS fk_lobby_request_creator DEFERRED;
  IF _id_viewer=_id_target THEN RAISE EXCEPTION '_id_viewer=_id_target'; END IF;

  PERFORM FROM lobbys WHERE id=_id_lobby AND id_owner=_id_viewer FOR SHARE;
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby_user unauthz'; END IF;

  PERFORM pg_advisory_lock(hashtextextended('lobby:'||_id_target::text, _id_target));
	DELETE FROM lobby_requests WHERE id_user=_id_target AND id_lobby=_id_lobby;
  DELETE FROM lobby_members WHERE id_user=_id_target AND id_lobby=_id_lobby RETURNING id_user IS NOT NULL INTO __was_member;
	IF _ban_resolved_at > NOW() THEN
	  INSERT INTO lobby_bans(id_user, id_lobby, ban_resolved_at) VALUES(_id_target, _id_lobby, _ban_resolved_at);
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
  SET CONSTRAINTS fk_lobby_request_creator DEFERRED;

	PERFORM FROM lobbys WHERE id=_id_lobby AND id_owner=_id_viewer FOR NO KEY UPDATE; --prevent join
	IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;

	SELECT _max_slots-(max_slots-free_slots) INTO __change_slots
		FROM lobby_slots
		WHERE id_lobby=_id_lobby AND _max_slots<>max_slots FOR NO KEY UPDATE; --prevent left
	IF NOT FOUND THEN RAISE EXCEPTION 'serialization error'; END IF;

	UPDATE lobby_slots SET max_slots=_max_slots,
	                       free_slots=CASE WHEN __change_slots < 0 THEN 0 ELSE __change_slots END
		WHERE id_lobby=_id_lobby AND max_slots<>_max_slots;
	
	IF __change_slots < 0 THEN
	  WITH delete_members AS (
			DELETE FROM lobby_members
				WHERE lobby_members IN(
		      SELECT id_user FROM lobby_members
		        WHERE id_lobby=_id_lobby AND is_owner IS FALSE
		        ORDER BY id_user FOR UPDATE LIMIT -__change_slots)
	      RETURNING id_user
	  )
	  SELECT array_agg(delete_members.id_user) INTO __ids_member FROM delete_members;
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
  --[_ids_creator].lobby_users FOR UPDATE
	SET CONSTRAINTS fk_lobby_request_creator DEFERRED;

  WITH dli AS (
    DELETE FROM lobby_invitations WHERE id_lobby=_id_lobby AND id_creator=ANY(_ids_creator)
    RETURNING id_target, id_creator
	)
  SELECT array_agg(lobby_request_need_creator.id_user) INTO __ids_target --lock creator requests
    FROM (SELECT id_user FROM dli, lobby_requests lr
      WHERE lr.id_user=dli.id_target AND lr.id_creator=dli.id_creator
        AND lr.id_lobby=_id_lobby
      ORDER BY lr.id_user FOR UPDATE OF lr) lobby_request_need_creator;

	UPDATE lobby_requests
		  SET id_creator=li_new_creator.id_creator
		FROM (
		  SELECT li.id_target, li.id_creator
				FROM lobby_invitations li, (SELECT DISTINCT id_target FROM lobby_invitations WHERE id_target=ANY(__ids_target) AND id_lobby=_id_lobby) dis_li
				WHERE id_lobby=_id_lobby AND li.id_target=dis_li.id_target
				ORDER BY id_creator FOR KEY SHARE OF li SKIP LOCKED
		) li_new_creator
		WHERE id_lobby=_id_lobby AND id_user=li_new_creator.id_target;

  DELETE FROM lobby_requests WHERE id_lobby=_id_lobby AND id_user=ANY(__ids_target) AND id_creator=ANY(_ids_creator);
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS test_lobby_utils_delete_member_invitation CASCADE;
CREATE OR REPLACE FUNCTION test_lobby_utils_delete_member_invitation(_ids_creator integer[], _id_lobby integer) RETURNS void AS $$
DECLARE
  __rec record;
BEGIN
  --[_ids_creator].lobby_users FOR UPDATE
	SET CONSTRAINTS fk_lobby_request_creator DEFERRED;

  FOR __rec IN
    DELETE FROM lobby_invitations WHERE id_lobby=_id_lobby AND id_creator=ANY(_ids_creator)
      RETURNING id_target, id_creator
  LOOP
		PERFORM FROM lobby_requests WHERE id_lobby=_id_lobby AND id_user=__rec.id_target AND id_creator=__rec.id_creator FOR UPDATE;
		IF FOUND THEN
			UPDATE lobby_requests SET id_creator=t_inv_new_creator.id_creator
				FROM (SELECT id_creator FROM lobby_invitations WHERE id_lobby=_id_lobby AND id_target=__rec.id_target AND id_creator NOT IN(_ids_creator) LIMIT 1 FOR KEY SHARE SKIP LOCKED) t_inv_new_creator
				WHERE id_lobby=_id_lobby AND id_user=__rec.id_target
				  AND t_inv_new_creator.id_creator IS NOT NULL;
			IF NOT FOUND THEN
				DELETE FROM lobby_requests WHERE id_lobby=_id_lobby AND id_user=__rec.id_target;
			END IF;
		END IF;
	END LOOP;
END;
$$ LANGUAGE plpgsql;