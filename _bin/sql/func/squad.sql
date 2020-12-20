DROP FUNCTION IF EXISTS squad_create, squad_join, squad_leave,
  squad_user_request_deny, squad_manage_request_accept, squad_manage_request_deny,
	squad_invite_create, squad_invite_cancel,
  squad_set_check_join, squad_ban_user, squad_set_privacy, squad_set_owner, squad_set_slots CASCADE;

CREATE OR REPLACE FUNCTION squad_create(_id_viewer integer, _private boolean, _max_slots integer, OUT id_squad_ integer) AS $$
BEGIN
  SET CONSTRAINTS fk_squad_owner, fk_squad_slots DEFERRED;

  INSERT INTO squads
    (id_owner, private)
    VALUES(_id_viewer, _private)
    RETURNING id INTO id_squad_;
	INSERT INTO squad_slots(id_squad, free_slots, max_slots)
		VALUES(id_squad_, _max_slots-1, _max_slots);

  INSERT INTO squad_users
    (id_squad, id_user, fk_member)
    VALUES(id_squad_, _id_viewer, _id_viewer);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_join(_id_viewer integer, _id_squad integer) RETURNS integer AS $$
DECLARE
  __private boolean;
  __id_owner integer;
BEGIN
  UPDATE squads SET free_slots=free_slots-1 FROM squads WHERE id=_id_squad RETURNING private, id_owner INTO __private, __id_owner;

  PERFORM pg_advisory_lock(hashtextextended('user_user:'||least(_id_viewer, __id_owner)||'_'||greatest(_id_viewer, __id_owner)::text, least(_id_viewer, __id_owner)));
  PERFORM FROM friends WHERE id_usera=least(_id_viewer, __id_owner) AND id_userb=greatest(_id_viewer, __id_owner) FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauthz'; END IF;

  PERFORM pg_advisory_lock(hashtextextended('lobby_squad:'||_id_viewer::text, _id_viewer));
  PERFORM FROM lobby_requests WHERE id_user=_id_viewer AND id_creator IS NULL;
  IF FOUND THEN RAISE EXCEPTION 'already lobby request'; END IF;
  PERFORM FROM lobby_members WHERE id_user=_id_viewer;
  IF FOUND THEN RAISE EXCEPTION 'already lobby member'; END IF;

  IF __private IS FALSE THEN
    INSERT INTO squad_users(id_squad, id_user, fk_member)
      VALUES(_id_squad, _id_viewer, _id_viewer)
      ON CONFLICT(id_squad, id_user) DO UPDATE SET fk_member=_id_viewer, fk_invitation=null, pending=null, id_creator=null
      WHERE fk_member IS NULL;
  ELSE
    UPDATE squad_users SET fk_member=_id_viewer, pending=null, id_creator=null, fk_invitation=null
      WHERE id_squad=_id_squad AND fk_invitation=_id_viewer AND pending IS FALSE;
  END IF;

  IF FOUND THEN
	  DELETE FROM squad_invitations WHERE id_target=_id_viewer;
	ELSE
    RAISE EXCEPTION 'failed';
  END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_leave(_id_viewer integer, _id_squad integer) RETURNS boolean AS $$
DECLARE
  __is_owner boolean;
  __need_delete boolean;

  __new_owner integer;
BEGIN
  SET CONSTRAINTS fk_squad_owner DEFERRED;

  SELECT id_owner=_id_viewer, max_slots-(free_slots+1) < 2 INTO __is_owner, __need_delete FROM squads WHERE id=_id_squad FOR NO KEY UPDATE;

  DELETE FROM squad_users
    WHERE fk_member=_id_viewer AND id_squad=_id_squad;
	IF NOT FOUND THEN RAISE EXCEPTION 'not squad member'; END IF;
  PERFORM FROM squad_utils_delete_member_invitation(ARRAY[_id_viewer], _id_squad);

  IF __need_delete THEN
	  DELETE FROM squads WHERE id=_id_squad;
	  RETURN TRUE;
  END IF;

  IF __is_owner THEN
    SELECT id_user INTO __new_owner FROM squad_users WHERE id_squad=_id_squad AND fk_member IS NOT NULL LIMIT 1 FOR SHARE;
    UPDATE squads SET id_owner=__new_owner WHERE id=_id_squad; --AND id_owner=_id_viewer
		UPDATE squad_users SET pending=false
      WHERE fk_invitation IN(SELECT id_target FROM squad_invitations WHERE id_creator=__new_owner FOR KEY SHARE SKIP LOCKED)
        AND id_squad=_id_squad AND id_creator=__new_owner
        AND pending;
  END IF;

  UPDATE squads SET free_slots=free_slots+1 WHERE id=_id_squad;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_user_invit_deny(_id_viewer integer, _id_squad integer) RETURNS boolean AS $$
BEGIN
  DELETE FROM squad_users
    WHERE id_squad=_id_squad AND fk_invitation=_id_viewer
      AND pending IS FALSE;
  IF NOT FOUND THEN RAISE EXCEPTION 'squad_request not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_manage_request_accept(_id_viewer integer, _id_target integer, _id_squad integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM squads WHERE id=_id_squad AND id_owner=_id_viewer FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  UPDATE squad_users SET pending=false
    WHERE id_squad=_id_squad AND fk_invitation=_id_target AND pending;
	IF NOT FOUND THEN RAISE EXCEPTION 'squad_request not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_manage_request_deny(_id_viewer integer, _id_target integer, _id_squad integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM squads WHERE id=_id_squad AND id_owner=_id_viewer FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  DELETE FROM squad_users
    WHERE id_squad=_id_squad AND fk_invitation=_id_target;
	IF NOT FOUND THEN RAISE EXCEPTION 'squad_request not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_invite_create(_id_viewer integer, _id_target integer, _id_squad integer) RETURNS boolean AS $$
DECLARE
    __trust_invite boolean;
BEGIN
  SET CONSTRAINTS fk_squad_request_creator DEFERRED;

  PERFORM FROM friends WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target) FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'not friends'; END IF;

  SELECT (private IS FALSE OR id_owner=_id_viewer) INTO __trust_invite FROM squads WHERE id=_id_squad FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'squad not found'; END IF;

  INSERT INTO squad_users(id_squad, id_user, fk_invitation, pending, id_creator)
    VALUES(_id_squad, _id_target, _id_target, __trust_invite IS FALSE, _id_viewer)
    ON CONFLICT(id_squad, id_user) DO UPDATE
      SET pending=false
    WHERE fk_invitation IS NOT NULL AND __trust_invite AND pending;

  INSERT INTO squad_invitations(id_creator, id_target, id_squad) VALUES(_id_viewer, _id_target, _id_squad);
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_invite_cancel(_id_viewer integer, _id_target integer, _id_squad integer) RETURNS boolean AS $$
BEGIN
  DELETE FROM squad_invitations WHERE id_creator=_id_viewer AND id_target=_id_target AND id_squad=_id_squad;
	IF NOT FOUND THEN RAISE EXCEPTION 'invit not found'; END IF;

  PERFORM FROM squad_users WHERE id_squad=_id_squad AND fk_invitation=_id_target AND id_creator=_id_viewer FOR UPDATE;
	IF NOT FOUND THEN RETURN true; END IF;

  UPDATE squad_users SET id_creator=t_squad_invit.id_creator
    FROM (SELECT id_creator FROM squad_invitations WHERE id_squad=_id_squad AND id_target=_id_target LIMIT 1 FOR KEY SHARE SKIP LOCKED) t_squad_invit
    WHERE id_squad=_id_squad AND fk_invitation=_id_target AND t_squad_invit.id_creator IS NOT NULL;
  IF NOT FOUND THEN
    DELETE FROM squad_users WHERE id_squad=_id_squad AND fk_invitation=_id_target; --AND id_creator=_id_viewer
  END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_set_private(_id_viewer integer, _id_squad integer, _private boolean) RETURNS boolean AS $$
BEGIN
  UPDATE squads SET private=_private WHERE id_owner=_id_viewer AND id=_id_squad AND private<>_private;
  IF NOT FOUND THEN RAISE EXCEPTION 'update not needed'; END IF;

	IF _private IS FALSE THEN
    UPDATE squad_users SET pending=false WHERE id_squad=_id_squad AND fk_invitation IS NOT NULL AND pending;
  END IF;
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_set_owner(_id_viewer integer, _id_target integer, _id_squad integer) RETURNS boolean AS $$
BEGIN
  SET CONSTRAINTS fk_squad_owner DEFERRED;
  UPDATE squads SET id_owner=_id_target WHERE id=_id_squad AND id_owner=_id_viewer AND _id_target<>_id_viewer;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauthz'; END IF;
	UPDATE squad_users SET pending=false
		FROM (SELECT id_target FROM squad_invitations WHERE id_squad=_id_squad AND id_creator=_id_viewer FOR KEY SHARE SKIP LOCKED) t_squad_inv
		WHERE id_squad=_id_squad AND fk_invitation=t_squad_inv.id_target
      AND pending;

  RETURN true;
END
$$ LANGUAGE plpgsql;+

CREATE OR REPLACE FUNCTION squad_ban_user(_id_viewer integer, _id_target integer, _id_squad integer, _block boolean) RETURNS boolean AS $$
DECLARE
  __was_member boolean DEFAULT FALSE;
  __delete_squad boolean DEFAULT FALSE;
BEGIN
  SET CONSTRAINTS fk_squad_request_creator DEFERRED;
  IF _id_viewer=_id_target THEN RAISE EXCEPTION '_id_viewer=_id_target'; END IF;

  SELECT max_slots-(free_slots+1) < 2 INTO __delete_squad FROM squads WHERE id=_id_squad AND id_owner=_id_viewer FOR NO KEY UPDATE;
	IF NOT FOUND THEN RAISE EXCEPTION 'squad_user unauthz'; END IF;

  IF _block THEN
    INSERT INTO squad_users(id_squad, id_user, is_blocked) VALUES(_id_squad, _id_target, true)
      ON CONFLICT(id_squad, id_user) DO UPDATE SET fk_member=null, pending=null, is_blocked=true
      WHERE is_blocked IS FALSE
      RETURNING fk_member IS NOT NULL INTO __was_member;
    DELETE FROM squad_invitations WHERE id_squad=_id_squad AND id_target=_id_target;
	ELSE
    DELETE FROM squad_users WHERE id_squad=_id_squad AND id_user=_id_target RETURNING fk_member IS NOT NULL INTO __was_member;
	END IF;

  IF __was_member THEN
    IF __delete_squad THEN
      DELETE FROM squads WHERE id=_id_squad;
	  ELSE
      PERFORM FROM squad_utils_delete_member_invitation(ARRAY[_id_target],_id_squad);
      UPDATE squads SET free_slots=free_slots+1 WHERE id=_id_squad;
    END IF;
  END IF;

	RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_set_slots(_id_viewer integer, _id_squad integer, _max_slots integer) RETURNS boolean AS $$
DECLARE
  __change_slots integer;
  __ids_member integer[];
BEGIN
  SET CONSTRAINTS fk_squad_request_creator DEFERRED;

	SELECT _max_slots-(max_slots-free_slots) INTO __change_slots FROM squads
		WHERE id=_id_squad AND id_owner=_id_viewer AND _max_slots<>max_slots FOR NO KEY UPDATE;
	IF NOT FOUND THEN RAISE EXCEPTION 'squad not found'; END IF;

	UPDATE squads SET max_slots=_max_slots,
	                  free_slots=CASE WHEN __change_slots < 0 THEN 0 ELSE __change_slots END
		WHERE id=_id_squad;

	IF __change_slots < 0 THEN
	  WITH delete_members AS (
			DELETE FROM squad_users
				WHERE squad_users IN(
		      SELECT id_user FROM squad_users
		        WHERE id_squad=_id_squad AND fk_member<>_id_viewer
		        ORDER BY fk_member FOR UPDATE LIMIT -__change_slots)
	      RETURNING fk_member
	  )
	  SELECT array_agg(delete_members.fk_member) INTO __ids_member FROM delete_members;
		PERFORM FROM squad_utils_delete_member_invitation(__ids_member, _id_squad);
	END IF;

	RETURN true;
END
$$ LANGUAGE plpgsql;
--UTILS
DROP FUNCTION IF EXISTS squad_utils_delete_member_invitation CASCADE;

CREATE OR REPLACE FUNCTION squad_utils_delete_member_invitation(_ids_creator integer[], _id_squad integer) RETURNS void AS $$
DECLARE
  __rec record;
BEGIN
  --alias multiple squad_invite_cancel
  --[_ids_creator].squad_users FOR UPDATE
  FOR __rec IN
    DELETE FROM squad_invitations WHERE id_squad=_id_squad AND id_creator=ANY(_ids_creator)
      RETURNING id_target, id_creator
  LOOP
		PERFORM FROM squad_users WHERE id_squad=_id_squad AND fk_invitation=__rec.id_target AND id_creator=__rec.id_creator FOR UPDATE;
		IF FOUND THEN
		  UPDATE squad_users SET id_creator=t_inv_creator.id_creator
		    FROM (SELECT id_creator FROM squad_invitations WHERE id_squad=_id_squad AND id_creator NOT IN(_ids_creator) AND id_target=__rec.id_target LIMIT 1 FOR KEY SHARE SKIP LOCKED) t_inv_creator
		    WHERE id_squad=_id_squad AND fk_invitation=__rec.id_target AND t_inv_creator.id_creator IS NOT NULL;
		  IF NOT FOUND THEN
		    DELETE FROM squad_users WHERE id_squad=_id_squad AND fk_invitation=__rec.id_target;
		  END IF;
		END IF;
	END LOOP;
END;
$$ LANGUAGE plpgsql;