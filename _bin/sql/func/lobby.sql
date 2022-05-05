/*
create_lobby

join_lobby
  - lobby SHARE
  - lobby_slots UPDATE
  - lobby_members INSERT
leave_lobby
  lobby SHARE
  --as_owner
    lobby UPDATE
  lobby_slots UPDATE
  lobby_member DELETE
  --as_owner
    ?last_member
      lobby DELETE
    : lobby_member* SHARE
      lobby UPDATE
*/
DROP FUNCTION IF EXISTS raise_except;
CREATE OR REPLACE FUNCTION raise_except(_trigger boolean, _msg text) RETURNS void AS $$
BEGIN
  IF _trigger THEN
      RAISE EXCEPTION '%', _msg;
  END IF;
END
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS lock_lobbyuser;
CREATE OR REPLACE FUNCTION lock_lobbyuser(_shared boolean, _id_user integer) RETURNS void AS $$
DECLARE
  __hash bigint = hashtext('lobbyuser:'||_id_user);
BEGIN
  IF _shared THEN
    PERFORM pg_advisory_xact_lock_shared(__hash);
  ELSE
    PERFORM pg_advisory_xact_lock(__hash);
  END IF;
  PERFORM raise_except(NOT FOUND, 'fail_lock lobbyuser');
END
$$ LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS create_lobby, join_lobby, leave_lobby;
CREATE OR REPLACE FUNCTION create_lobby(_id_viewer integer, _max_slots integer, OUT id_lobby_ integer) AS $$
BEGIN
  SET CONSTRAINTS fk_lobby_slots, fk_lobby_owner DEFERRED;
  INSERT INTO lobbys(id_owner) VALUES(_id_viewer) RETURNING id INTO id_lobby_;
  INSERT INTO lobby_slots(id_lobby, free_slots, max_slots) VALUES (id_lobby_, _max_slots - 1, _max_slots);
  INSERT INTO lobby_members(id_lobby, id_user) VALUES (id_lobby_, _id_viewer);
END
$$ LANGUAGE plpgsql;

/*
0 - request created / updated
1 - lobby joined
*/
CREATE OR REPLACE FUNCTION join_lobby(_id_viewer integer, _id_lobby integer) RETURNS integer AS $$
DECLARE
  __filter_join bool;
BEGIN
  PERFORM lock_lobbyuser(false, _id_viewer);
  SELECT filter_join INTO __filter_join FROM lobbys WHERE id = _id_lobby FOR SHARE; PERFORM raise_except(NOT FOUND, 'lobby not found');
  IF __filter_join THEN
    PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby; PERFORM raise_except(FOUND, 'already lobby member');
    DELETE FROM lobby_requests WHERE id_lobby = _id_lobby AND id_user = _id_viewer AND status = 'wait_user';
    IF NOT FOUND THEN
      INSERT INTO lobby_requests (id_lobby, id_user, status) VALUES (_id_lobby, _id_viewer, 'wait_lobby')
        ON CONFLICT DO UPDATE SET id_creator = NULL WHERE id_creator IS NOT NULL;
      PERFORM raise_except(NOT FOUND, 'request already exist');
      RETURN 0;
    END IF;
  END IF;
  
  UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby = _id_lobby;
  INSERT INTO lobby_members(id_lobby, id_user) VALUES(_id_lobby, _id_viewer);
  DELETE FROM lobby_requests WHERE id_lobby = _id_lobby AND id_user = _id_viewer; -- CASCADE DELETE FROM lobby_invitations WHERE id_lobby = _id_lobby AND id_target = _id_viewer;
  RETURN 1;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION leave_lobby(_id_viewer integer) RETURNS integer AS $$
/*
 1 = member leaved
 2 = lobby closed
 3 = lobby owner changed
 */
DECLARE
  __id_lobby integer;
  __id_owner integer;
  __slots integer;
BEGIN
  SET CONSTRAINTS fk_lobby_owner DEFERRED;
  SELECT id_lobby INTO __id_lobby FROM lobby_members WHERE id_user = _id_viewer; PERFORM raise_except(NOT FOUND, 'viewer not in a lobby');
  
  SELECT id_owner INTO __id_owner FROM lobbys WHERE id = __id_lobby FOR SHARE; PERFORM raise_except(NOT FOUND,'lobby not found');
  PERFORM FROM lobbys WHERE id = __id_lobby AND id_owner = _id_viewer FOR UPDATE;
  
  UPDATE lobby_slots SET free_slots = free_slots + 1 WHERE id_lobby = __id_lobby RETURNING max_slots - free_slots INTO __slots;
  
  DELETE FROM lobby_members WHERE id_lobby = __id_lobby AND id_user = _id_viewer; PERFORM raise_except(NOT FOUND,'serialization error, viewer lobby_member no longer exist');
  IF __id_owner = _id_viewer THEN
    IF __slots = 0 THEN
      DELETE FROM lobbys WHERE id = __id_lobby;
      RETURN 2;
    ELSE
      WITH cte_new_owner AS (
        SELECT id_user FROM lobby_members WHERE id_lobby = __id_lobby LIMIT 1
      ) SELECT lobby_members.id_user INTO __id_owner
                                     FROM lobby_members, cte_new_owner
                                     WHERE id_lobby = __id_lobby AND lobby_members.id_user = cte_new_owner.id_user FOR KEY SHARE;
      UPDATE lobbys SET id_owner = __id_owner WHERE id = __id_lobby;
      RETURN 3;
    END IF;
  END IF;
  RETURN 1;
END
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS lobby_invite, lobby_invite_cancel;
CREATE OR REPLACE FUNCTION lobby_invite(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
  __authz bool;
BEGIN
  PERFORM lock_lobbyuser(true, _id_target);
  SELECT (id_owner = _id_viewer OR filter_join IS FALSE) INTO __authz FROM lobbys WHERE id = _id_lobby FOR SHARE; PERFORM raise_except(NOT __authz, 'lobby authz fail');
  PERFORM FROM lobby_members WHERE id_lobby = _id_lobby AND id_user = _id_target; PERFORM raise_except(FOUND, 'target already member');
  
  INSERT INTO lobby_requests(id_lobby, id_user, status, id_creator)
    VALUES(_id_lobby, _id_target, CASE WHEN __authz THEN 'wait_user' ELSE 'wait_lobby' END, _id_viewer)
    ON CONFLICT DO UPDATE SET status=CASE status WHEN 'wait_user' THEN 'wait_user' ELSE EXCLUDED.status END;
  INSERT INTO lobby_invitations(id_lobby, id_target, id_creator) VALUES (_id_lobby, _id_target, _id_viewer);
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_invite_cancel(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
--invit creator is the only one locking with lobby_request
DECLARE
  __id_lobby integer;
  __id_creator integer;
BEGIN
  SELECT id_lobby INTO __id_lobby FROM lobby_members WHERE id_user = _id_viewer;
  
  DELETE FROM lobby_invitations WHERE id_lobby = __id_lobby AND id_target = _id_target AND id_creator = _id_viewer; PERFORM raise_except(NOT FOUND, 'invit not found');
  PERFORM FROM lobby_requests WHERE id_lobby=__id_lobby AND id_user = _id_target AND id_creator = _id_viewer FOR SHARE;
  IF FOUND THEN
    SELECT id_target INTO __id_creator FROM lobby_invitations WHERE id_lobby = __id_lobby AND id_target = _id_target LIMIT 1 FOR KEY SHARE SKIP LOCKED;
    IF FOUND THEN --still invit left
      UPDATE lobby_requests SET id_creator = __id_creator WHERE id_lobby = __id_lobby AND id_user = _id_target;
    ELSE --no lobby invit left
      DELETE FROM lobby_requests WHERE id_lobby = __id_lobby AND id_user = _id_target;
    END IF;
  END IF;
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

/*
CREATE OR REPLACE FUNCTION lobby_invite_cancel(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
DECLARE
  __id_lobby integer;
  __id_creator integer;
BEGIN
  SELECT id_lobby INTO __id_lobby FROM lobby_members WHERE id_user = _id_viewer;
  SELECT id_creator = _id_viewer INTO __id_creator FROM lobby_requests WHERE id_lobby=__id_lobby AND id_user = _id_target FOR SHARE;
  PERFORM FROM lobby_requests WHERE id_lobby=__id_lobby AND id_user = _id_target AND id_creator = _id_viewer FOR UPDATE;
  DELETE FROM lobby_invitations WHERE id_lobby = __id_lobby AND id_creator = _id_viewer AND id_target = _id_target; PERFORM raise_except(NOT FOUND, 'invit not found');
  IF __id_creator = _id_viewer THEN
    SELECT id_target INTO __id_creator FROM lobby_invitations WHERE id_lobby = __id_lobby AND id_target = _id_target LIMIT 1;
    IF FOUND THEN --still invit left
      UPDATE lobby_requests SET id_creator = __id_creator WHERE id_lobby = __id_lobby AND id_user = _id_target;
    ELSE --no lobby invit left
      DELETE FROM lobby_requests WHERE id_lobby = __id_lobby AND id_user = _id_target;
    END IF;
  END IF;
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;
*/

DROP FUNCTION IF EXISTS lobbyuser_del_invit, lobbyuser_upd_invits;
CREATE OR REPLACE FUNCTION lobbyuser_del_invits(_id_lobby integer, _id_user integer) RETURNS void AS $$
DECLARE
  __new_creator integer;
  __tmp_loop integer;
BEGIN
  FOR __tmp_loop IN DELETE FROM lobby_invitations WHERE id_lobby = _id_lobby AND id_creator = _id_user RETURNING id_target
  LOOP
    PERFORM FROM lobby_requests WHERE id_lobby = _id_lobby AND id_user = __tmp_loop AND id_creator = _id_user FOR SHARE;
    SELECT id_creator INTO __new_creator FROM lobby_invitations WHERE id_lobby = _id_lobby AND id_target = __tmp_loop LIMIT 1 FOR KEY SHARE SKIP LOCKED;
    IF FOUND THEN
      UPDATE lobby_requests SET id_creator = __new_creator  WHERE id_lobby = _id_lobby AND id_user = __tmp_loop ;
    ELSE
      DELETE FROM lobby_requests WHERE id_lobby = _id_lobby AND id_user = __tmp_loop;
    END IF;
  END LOOP;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobbyuser_upd_invits(_id_lobby integer, _id_user integer, _authz bool) RETURNS void AS $$
DECLARE
  __tmp_loop integer;
BEGIN
  IF NOT _authz THEN RETURN ; END IF;
  FOR __tmp_loop IN SELECT id_target FROM lobby_invitations WHERE id_lobby = _id_lobby AND id_creator = _id_user FOR SHARE
  LOOP
    UPDATE lobby_requests SET status = 'wait_user' WHERE id_lobby = _id_lobby AND id_user = __tmp_loop;
  END LOOP;
END
$$ LANGUAGE plpgsql;
