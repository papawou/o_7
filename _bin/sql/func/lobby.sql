--utils
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

--native
DROP FUNCTION IF EXISTS create_lobby, join_lobby, leave_lobby;
CREATE OR REPLACE FUNCTION create_lobby(_id_viewer integer, _max_slots integer, OUT id_lobby_ integer) AS $$
BEGIN
  SET CONSTRAINTS fk_lobby_slots, fk_lobby_owner DEFERRED;
  INSERT INTO lobbys(id_owner) VALUES(_id_viewer) RETURNING id INTO id_lobby_;
  INSERT INTO lobby_slots(id_lobby, free_slots, max_slots) VALUES (id_lobby_, _max_slots - 1, _max_slots);
  INSERT INTO lobby_members(id_lobby, id_user) VALUES (id_lobby_, _id_viewer);
END
$$ LANGUAGE plpgsql;

--native
CREATE OR REPLACE FUNCTION join_lobby(_id_viewer integer, _id_lobby integer) RETURNS integer AS $$
/*
  0 - lobbyrequest created
  1 - lobby joined
  2 - invit change into request
*/
DECLARE
  __filter_join bool;
  /*
    0 - lobbyrequest not exist
    1 - lobbyrequest wait_user
    2 - lobbyrequest is an invit
    3 - lobbyrequest already exist
  */
  __status integer := 0;
BEGIN
  PERFORM lock_lobbyuser(false, _id_viewer);
  PERFORM FROM lobby_members WHERE id_user=_id_viewer AND id_lobby=_id_lobby; PERFORM raise_except(FOUND, 'already lobby member');
  
  SELECT filter_join INTO __filter_join FROM lobbys WHERE id = _id_lobby FOR SHARE; PERFORM raise_except(NOT FOUND, 'lobby not found');
  SELECT (CASE WHEN status = 'wait_user'::lobby_request_status THEN 1 WHEN id_creator IS NOT NULL THEN 2 ELSE 3 END) INTO __status FROM lobby_requests WHERE id_lobby = _id_lobby AND id_user = _id_viewer FOR SHARE;
  IF NOT FOUND AND __filter_join THEN
    INSERT INTO lobby_requests (id_lobby, id_user, status) VALUES (_id_lobby, _id_viewer, 'wait_lobby'::lobby_request_status); --? ON CONFLICT DO UPDATE SET id_creator = NULL (can be avoid because of lobbyuser advlock)
    RETURN 0;
  ELSIF __status = 1 THEN
    DELETE FROM lobby_requests WHERE id_lobby = _id_lobby AND id_user = _id_viewer;
  ELSIF __status = 2 THEN
    UPDATE lobby_requests SET  id_creator = NULL WHERE id_lobby = _id_lobby AND id_user = _id_viewer;
    RETURN 2;
  ELSIF __status = 3 THEN
    PERFORM raise_except(true, 'lobbyrequest already exist');
  END IF;
  
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
  SET CONSTRAINTS fk_lobby_owner, lobby_requests_id_lobby_id_user_id_creator_fkey, lobby_invitations_id_lobby_id_creator_fkey DEFERRED;
  SELECT id_lobby INTO __id_lobby FROM lobby_members WHERE id_user = _id_viewer; PERFORM raise_except(NOT FOUND, 'viewer not in a lobby');
  
  SELECT id_owner INTO __id_owner FROM lobbys WHERE id = __id_lobby FOR SHARE; PERFORM raise_except(NOT FOUND,'lobby not found');
  IF __id_owner = _id_viewer THEN
    PERFORM FROM lobbys WHERE id = __id_lobby AND id_owner = _id_viewer FOR UPDATE;
    UPDATE lobby_slots SET free_slots = free_slots + 1 WHERE id_lobby = __id_lobby RETURNING max_slots - free_slots INTO __slots;
    IF __slots = 0 THEN
      DELETE FROM lobbys WHERE id = __id_lobby;
      RETURN 2;
    END IF;
  END IF;
  DELETE FROM lobby_members WHERE id_lobby = __id_lobby AND id_user = _id_viewer; PERFORM raise_except(NOT FOUND,'serialization error, viewer lobby_member no longer exist');
  PERFORM lobbyuser_cancel_invits(__id_lobby, _id_viewer);
  IF __id_owner = _id_viewer THEN
    SELECT id_user INTO __id_owner FROM lobby_members WHERE id_lobby = __id_lobby FOR SHARE LIMIT 1; --FOR UPDATE? because new owner got his authz upd ?
    UPDATE lobbys SET id_owner = __id_owner WHERE id = __id_lobby;
    PERFORM lobbyuser_accept_invits(__id_lobby, _id_viewer);
    RETURN 3;
  END IF;
  UPDATE lobby_slots SET free_slots = free_slots + 1 WHERE id_lobby = __id_lobby RETURNING max_slots - free_slots INTO __slots;
  RETURN 1;
END
$$ LANGUAGE plpgsql;

--LOBBY INVITATION
DROP FUNCTION IF EXISTS lobby_invite, lobby_invite_cancel;
CREATE OR REPLACE FUNCTION lobby_invite(_id_viewer integer, _id_target integer, _id_lobby integer) RETURNS boolean AS $$
DECLARE
  __authz bool;
BEGIN
  SET CONSTRAINTS lobby_requests_id_lobby_id_user_id_creator_fkey DEFERRED;
  PERFORM lock_lobbyuser(true, _id_target);
  PERFORM FROM lobby_members WHERE id_lobby = _id_lobby AND id_user = _id_target; PERFORM raise_except(FOUND, 'target already member');
  
  SELECT (id_owner = _id_viewer OR filter_join IS FALSE) INTO __authz FROM lobbys WHERE id = _id_lobby FOR SHARE; PERFORM raise_except(NOT FOUND, 'lobby not found');
  INSERT INTO lobby_requests(id_lobby, id_user, status, id_creator)
    VALUES(_id_lobby, _id_target, CASE WHEN __authz THEN 'wait_user'::lobby_request_status ELSE 'wait_lobby'::lobby_request_status END, _id_viewer)
    ON CONFLICT (id_lobby, id_user) DO UPDATE SET status=CASE lobby_requests.status WHEN 'wait_user'::lobby_request_status THEN 'wait_user'::lobby_request_status ELSE EXCLUDED.status END;
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
  SET CONSTRAINTS lobby_requests_id_lobby_id_user_id_creator_fkey DEFERRED;
  SELECT id_lobby INTO __id_lobby FROM lobby_members WHERE id_user = _id_viewer;
  
  DELETE FROM lobby_invitations WHERE id_lobby = __id_lobby AND id_target = _id_target AND id_creator = _id_viewer; PERFORM raise_except(NOT FOUND, 'invit not found');
  PERFORM FROM lobby_requests WHERE id_lobby=__id_lobby AND id_user = _id_target AND id_creator = _id_viewer FOR SHARE;
  IF FOUND THEN
    SELECT id_creator INTO __id_creator FROM lobby_invitations WHERE id_lobby = __id_lobby AND id_target = _id_target LIMIT 1 FOR KEY SHARE SKIP LOCKED;
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
--LOBBY UTILS INVITATION
DROP FUNCTION IF EXISTS lobbyuser_cancel_invits, lobbyuser_accept_invits;
CREATE OR REPLACE FUNCTION lobbyuser_cancel_invits(_id_lobby integer, _id_user integer) RETURNS void AS $$
DECLARE
  __new_creator integer;
  __tmp_loop integer;
BEGIN
  SET CONSTRAINTS lobby_requests_id_lobby_id_user_id_creator_fkey DEFERRED;
  FOR __tmp_loop IN DELETE FROM lobby_invitations WHERE id_lobby = _id_lobby AND id_creator = _id_user RETURNING id_target
  LOOP
    PERFORM FROM lobby_requests WHERE id_lobby = _id_lobby AND id_user = __tmp_loop AND id_creator = _id_user FOR SHARE;
    IF NOT FOUND THEN CONTINUE; END IF;
    SELECT id_creator INTO __new_creator FROM lobby_invitations WHERE id_lobby = _id_lobby AND id_target = __tmp_loop LIMIT 1 FOR KEY SHARE SKIP LOCKED;
    IF FOUND THEN
      UPDATE lobby_requests SET id_creator = __new_creator  WHERE id_lobby = _id_lobby AND id_user = __tmp_loop ;
    ELSE
      DELETE FROM lobby_requests WHERE id_lobby = _id_lobby AND id_user = __tmp_loop AND id_creator = _id_user;
    END IF;
  END LOOP;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobbyuser_accept_invits(_id_lobby integer, _id_user integer) RETURNS void AS $$
DECLARE
  __tmp_loop integer;
BEGIN
  FOR __tmp_loop IN SELECT id_target FROM lobby_invitations WHERE id_lobby = _id_lobby AND id_creator = _id_user FOR SHARE
  LOOP
    UPDATE lobby_requests SET status = 'wait_user'::lobby_request_status WHERE id_lobby = _id_lobby AND id_user = __tmp_loop AND status != 'wait_user'::lobby_request_status;
  END LOOP;
END
$$ LANGUAGE plpgsql;
