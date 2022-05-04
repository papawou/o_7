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
DROP FUNCTION IF EXISTS create_lobby, join_lobby, leave_lobby;

CREATE OR REPLACE FUNCTION create_lobby(_id_viewer integer, _max_slots integer, OUT id_lobby_ integer) AS $$
BEGIN
  SET CONSTRAINTS fk_lobby_slots, fk_lobby_owner DEFERRED;
  INSERT INTO lobbys(id_owner) VALUES(_id_viewer) RETURNING id INTO id_lobby_;
  INSERT INTO lobby_slots(id_lobby, free_slots, max_slots) VALUES (id_lobby_, _max_slots - 1, _max_slots);
  INSERT INTO lobby_members(id_lobby, id_user) VALUES (id_lobby_, _id_viewer);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION join_lobby(_id_viewer integer, _id_lobby integer) RETURNS integer AS $$
BEGIN
  PERFORM FROM lobbys WHERE id = _id_lobby FOR SHARE; IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;
  UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby = _id_lobby;
  INSERT INTO lobby_members(id_lobby, id_user) VALUES(_id_lobby, _id_viewer);
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
  SELECT id_lobby INTO __id_lobby FROM lobby_members WHERE id_user = _id_viewer; IF NOT FOUND THEN RAISE EXCEPTION 'viewer not in a lobby'; END IF;
  
  --lock lobby authz
  SELECT id_owner INTO __id_owner FROM lobbys WHERE id = __id_lobby FOR SHARE; IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;
  PERFORM FROM lobbys WHERE id = __id_lobby AND id_owner = _id_viewer FOR UPDATE;
  
  UPDATE lobby_slots SET free_slots = free_slots + 1 WHERE id_lobby = __id_lobby RETURNING max_slots - free_slots INTO __slots;
  
  --lock lobby_member authz
  DELETE FROM lobby_members WHERE id_lobby = __id_lobby AND id_user = _id_viewer; IF NOT FOUND THEN RAISE EXCEPTION 'viewer lobby_member no longer exist'; END IF;
  
  IF __id_owner = _id_viewer THEN
    IF __slots = 0 THEN
      DELETE FROM lobbys WHERE id = __id_lobby;
      RETURN 2;
    ELSE
      WITH cte_new_owner AS (
        SELECT id_user FROM lobby_members WHERE id_lobby = __id_lobby LIMIT 1
      ) SELECT id_user INTO __id_owner FROM lobby_members WHERE id_lobby = __id_lobby AND id_user = cte_new_owner.id_user FOR KEY SHARE;
      UPDATE lobbys SET id_owner = __id_owner WHERE id = __id_lobby;
      RETURN 3;
    END IF;
  END IF;
  RETURN 1;
END
$$ LANGUAGE plpgsql;
