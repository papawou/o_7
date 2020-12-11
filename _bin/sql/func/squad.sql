DROP FUNCTION IF EXISTS squad_create, squad_join, squad_leave,
  squad_user_request_deny, squad_manage_request_accept, squad_manage_request_deny,
	squad_invite_create, squad_invite_cancel,
  squad_set_check_join, squad_ban_user, squad_set_privacy, squad_set_owner, squad_set_slots CASCADE;

CREATE OR REPLACE FUNCTION squad_create(_id_viewer integer, _private boolean, OUT id_squad_ integer) AS $$
BEGIN
  SET CONSTRAINTS fk_squad_owner DEFERRED;
  INSERT INTO squads
    (id_owner, private)
    VALUES(_id_viewer, _private)
    RETURNING id INTO id_squad_;

  INSERT INTO squad_users
    (id_squad, id_user, fk_member)
    VALUES(id_squad_, _id_viewer, _id_viewer);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_join(_id_viewer integer, _id_squad integer) RETURNS integer AS $$
DECLARE
  __private boolean;
BEGIN
  SELECT private INTO __private FROM squads WHERE id=_id_squad;

  INSERT INTO squad_users(id_squad, id_user, fk_member)
    VALUES(_id_squad, _id_viewer, _id_viewer)
    ON CONFLICT(id_squad, id_user) DO UPDATE SET fk_member=_id_viewer, pending=null, is_blocked=false
    WHERE is_blocked IS FALSE AND (pending IS TRUE OR __private IS TRUE);
  IF FOUND THEN
	  DELETE FROM squad_invitations WHERE id_target=_id_viewer;
	ELSE
    RAISE EXCEPTION 'failed';
  END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_leave(_id_viewer integer) RETURNS boolean AS $$
DECLARE
  __id_squad integer;
  __new_owner integer;
BEGIN
  SET CONSTRAINTS fk_squad_owner DEFERRED;

  DELETE FROM squad_users
    WHERE fk_member=_id_viewer
    RETURNING id_squad INTO __id_squad;
	IF NOT FOUND THEN RAISE EXCEPTION 'not squad member'; END IF;

  PERFORM FROM squad_utils_delete_member_invitation(ARRAY[_id_viewer], __id_squad);
  IF EXISTS(SELECT FROM squads WHERE id=__id_squad AND id_owner=_id_viewer FOR UPDATE) THEN
    SELECT id_user INTO __new_owner FROM squad_users WHERE id_squad=__id_squad AND fk_member IS NOT NULL LIMIT 1 FOR SHARE;
    IF NOT FOUND THEN --last squad_member
      DELETE FROM squads WHERE id=__id_squad;
    ELSE
      UPDATE squads SET id_owner=__new_owner
				WHERE id=__id_squad AND id_owner=_id_viewer;

      UPDATE squad_users SET pending=false
        WHERE id_user IN(SELECT id_target FROM squad_invitations WHERE id_creator=__new_owner FOR KEY SHARE SKIP LOCKED) AND id_squad=__id_squad
        AND pending;
    END IF;
  END IF;
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_user_invit_deny(_id_viewer integer, _id_squad integer) RETURNS boolean AS $$
BEGIN
  DELETE FROM squad_users
    WHERE id_squad=_id_squad AND id_user=_id_viewer
      AND pending;
  IF NOT FOUND THEN RAISE EXCEPTION 'squad_request not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_manage_request_accept(_id_viewer integer, _id_target integer, _id_squad integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM squads WHERE id=_id_squad AND id_owner=_id_viewer FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  UPDATE squad_users SET pending=true
    WHERE id_squad=_id_squad AND id_user=_id_target AND pending IS FALSE;
	IF NOT FOUND THEN RAISE EXCEPTION 'squad_request not found'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_manage_request_deny(_id_viewer integer, _id_target integer, _id_squad integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM squads WHERE id=_id_squad AND id_owner=_id_viewer FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  DELETE FROM squad_users
    WHERE id_squad=_id_squad AND id_user=_id_target AND pending IS NOT NULL;
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

  SELECT private IS FALSE INTO __trust_invite FROM squads WHERE id=_id_squad FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'squad not found'; END IF;

  INSERT INTO squad_users(id_user, id_squad, pending)
    VALUES(_id_target, _id_squad, __trust_invite IS FALSE)
    ON CONFLICT(id_squad, id_user) DO UPDATE
      SET pending=CASE WHEN pending OR __trust_invite THEN true ELSE false END;

  INSERT INTO squad_invitations(id_creator, id_target, id_squad) VALUES(_id_viewer, _id_target, _id_squad);
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_invite_cancel(_id_viewer integer, _id_target integer, _id_squad integer) RETURNS boolean AS $$
BEGIN
  DELETE FROM squad_invitations WHERE id_creator=_id_viewer AND id_target=_id_target AND id_squad=_id_squad;
	IF NOT FOUND THEN RAISE EXCEPTION 'invit not found'; END IF;

  PERFORM FROM squad_users WHERE id_user=_id_target AND id_squad=_id_squad FOR UPDATE;

  DELETE FROM squad_users WHERE id_user=_id_target AND id_squad=_id_squad
                            AND NOT EXISTS(SELECT FROM squad_invitations WHERE id_target=_id_target AND id_squad=_id_squad FOR KEY SHARE SKIP LOCKED);
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_set_private(_id_viewer integer, _id_squad integer, _private boolean) RETURNS boolean AS $$
BEGIN
  UPDATE squads SET private=_private WHERE id_owner=_id_viewer AND id=_id_squad AND private<>_private;
  IF NOT FOUND THEN RAISE EXCEPTION 'update not needed'; END IF;

	IF _private IS FALSE THEN
    UPDATE squad_users SET pending=true WHERE id_squad=_id_squad AND pending;
  END IF;
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_set_owner(_id_viewer integer, _id_target integer, _id_squad integer) RETURNS boolean AS $$
BEGIN
  SET CONSTRAINTS fk_squad_owner DEFERRED;

  IF(_id_viewer=_id_target)
    THEN RAISE EXCEPTION '_id_viewer == _id_target';
  END IF;

  UPDATE squads SET id_owner=_id_target WHERE id_owner=_id_viewer AND id=_id_squad;
  PERFORM FROM squad_users WHERE id_squad=_id_squad  AND fk_member=_id_target FOR UPDATE;
	UPDATE squad_users SET pending=false WHERE pending AND id_squad=_id_squad
	                                       AND id_user IN(SELECT id_target FROM squad_invitations WHERE id_creator=_id_viewer FOR KEY SHARE SKIP LOCKED);

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION squad_ban_user(_id_viewer integer, _id_target integer, _id_squad integer, _block boolean) RETURNS boolean AS $$
DECLARE
  __was_member boolean DEFAULT FALSE;
BEGIN
  SET CONSTRAINTS fk_squad_request_creator DEFERRED;
  IF _id_viewer=_id_target THEN RAISE EXCEPTION '_id_viewer=_id_target'; END IF;

  PERFORM FROM squads WHERE id=_id_squad AND id_owner=_id_viewer FOR SHARE;
	IF NOT FOUND THEN RAISE EXCEPTION 'squad_user unauthz'; END IF;

  IF _block THEN
    INSERT INTO squad_users(id_squad, id_user, is_blocked) VALUES(_id_squad, _id_target, true)
      ON CONFLICT(id_squad, id_user) DO UPDATE SET fk_member=null, pending=null, is_blocked=true
      WHERE is_blocked IS NULL
      RETURNING fk_member IS NOT NULL INTO __was_member;
    DELETE FROM squad_invitations WHERE id_squad=_id_squad AND id_target=_id_target;
	ELSE
    DELETE FROM squad_users WHERE id_squad=_id_squad AND fk_member=_id_target RETURNING fk_member IS NOT NULL INTO __was_member;
	END IF;

  IF __was_member THEN
    PERFORM FROM squad_utils_delete_member_invitation(ARRAY[_id_target],_id_squad);
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

	PERFORM FROM squads WHERE id=_id_squad AND id_owner=_id_viewer FOR NO KEY UPDATE; --prevent join
	IF NOT FOUND THEN RAISE EXCEPTION 'squad not found'; END IF;

	SELECT _max_slots-(max_slots-free_slots) INTO __change_slots
		FROM squad_slots
		WHERE id_squad=_id_squad AND _max_slots<>max_slots FOR NO KEY UPDATE; --prevent left
	IF NOT FOUND THEN RAISE EXCEPTION 'serialization error'; END IF;

	UPDATE squad_slots SET max_slots=_max_slots,
	                       free_slots=CASE WHEN __change_slots < 0 THEN 0 ELSE __change_slots END
		WHERE id_squad=_id_squad AND max_slots<>_max_slots;

	IF __change_slots < 0 THEN
	  WITH delete_members AS (
			DELETE FROM squad_members
				WHERE squad_members IN(
		      SELECT id_user FROM squad_members
		        WHERE id_squad=_id_squad AND is_owner IS FALSE
		        ORDER BY id_user FOR UPDATE LIMIT -__change_slots)
	      RETURNING id_user
	  )
	  SELECT array_agg(delete_members.id_user) INTO __ids_member FROM delete_members;
		PERFORM FROM squad_utils_delete_member_invitation(__ids_member, _id_squad);
	END IF;

	RETURN TRUE;
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
		PERFORM FROM squad_users WHERE id_squad=_id_squad AND id_user=__rec.id_target FOR UPDATE;
		IF FOUND THEN
		  IF NOT EXISTS(SELECT FROM squad_invitations WHERE id_squad=_id_squad AND id_target=__rec.id_target FOR KEY SHARE SKIP LOCKED) THEN
		    DELETE FROM squad_users WHERE id_squad=_id_squad AND id_user=__rec.id_target;
		  END IF;
		END IF;
	END LOOP;
END;
$$ LANGUAGE plpgsql;