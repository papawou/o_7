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

CREATE OR REPLACE FUNCTION create_lobby(_id_viewer integer, _max_slots integer, OUT id_lobby_ integer) AS $$
BEGIN
  INSERT INTO lobbys(id_owner) VALUES(_id_viewer) RETURNING id INTO id_lobby_;
  INSERT INTO lobby_slots(id_lobby, free_slots, max_slots) VALUES (id_lobby_, _max_slots - 1, _max_slots);
  INSERT INTO lobby_members(id_lobby, id_user) VALUES (id_lobby_, _id_viewer);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION join_lobby(_id_viewer integer, _id_lobby integer) AS $$
BEGIN
  PERFORM FROM lobbys WHERE id = _id_lobby FOR SHARE; IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;
  UPDATE lobby_slots SET free_slots=free_slots-1 WHERE id_lobby = _id_lobby;
  INSERT INTO lobby_members(id_lobby, id_user) VALUES(_id_lobby, _id_viewer);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION leave_lobby(_id_viewer integer) AS $$
DECLARE
  __id_lobby integer;
  __id_owner integer;
  __slots integer;
BEGIN
  SELECT id_lobby INTO __id_lobby FROM lobby_members WHERE id_user = _id_viewer; IF NOT FOUND THEN RAISE EXCEPTION 'viewer not in a lobby'; END IF;
  PERFORM FROM lobbys WHERE id = __id_lobby FOR SHARE; IF NOT FOUND THEN RAISE EXCEPTION 'lobby not found'; END IF;
  PERFORM FROM lobbys WHERE id = __id_lobby AND id_owner = _id_viewer FOR UPDATE;
  UPDATE lobby_slots SET free_slots=free_slots + 1 WHERE id_lobby = __id_lobby RETURNING max_slots - free_slots INTO __slots;
  DELETE FROM lobby_members WHERE id_lobby = __id_lobby AND id_user = _id_viewer; IF NOT FOUND THEN RAISE EXCEPTION 'viewer lobby_member no longer exist'; END IF;
  IF __id_owner = _id_viewer THEN
    IF __slots = 0 THEN --close lobby
      DELETE FROM lobbys WHERE id = __id_lobby;
    ELSE -- change lobby_owner
      SELECT id_user INTO __id_owner FROM lobby_members WHERE id_lobby = __id_lobby FOR KEY SHARE;
      UPDATE lobbys SET id_owner = __id_owner WHERE id = __id_lobby;
    END IF;
  END IF;
END
$$ LANGUAGE plpgsql;
