/*
FRIEND_REQUEST
--creator
	friend_request_create
	friend_request_cancel
--target
	friend_request_accept

FRIEND
friend_delete

USER
user_ban
*/
DROP FUNCTION IF EXISTS friend_request_create, friend_request_cancel, friend_request_accept CASCADE;

CREATE OR REPLACE FUNCTION friend_request_create(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
  PERFORM pg_advisory_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target)||'_'||greatest(_id_viewer, _id_target)::text, least(_id_viewer, _id_target)));
  PERFORM FROM friends WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target);
	IF FOUND THEN RAISE EXCEPTION 'already_friends'; END IF;
  PERFORM FROM user_bans WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target);
  IF FOUND THEN RAISE EXCEPTION 'users_block'; END IF;

  INSERT INTO friend_requests(id_usera, id_userb, created_by) VALUES(least(_id_viewer, _id_target), greatest(_id_viewer,_id_target), _id_viewer);
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION friend_request_cancel(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
	DELETE FROM friend_requests
		WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target)
      AND created_by=_id_viewer;
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION friend_request_accept(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
	PERFORM pg_advisory_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target)||'_'||greatest(_id_viewer, _id_target)::text, least(_id_viewer, _id_target)));
  DELETE FROM friend_requests WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target) AND created_by<>_id_viewer;
  IF NOT FOUND THEN RAISE EXCEPTION 'friend_request not found'; END IF;

  INSERT INTO friends(id_usera, id_userb) VALUES(least(_id_viewer, _id_target), greatest(_id_viewer, _id_target));
  INSERT INTO follows(id_follower, id_following) VALUES(_id_viewer, _id_target), (_id_target, _id_viewer) ON CONFLICT DO NOTHING;
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION friend_delete(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
	DELETE FROM friends WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target);
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

/*
FOLLOW
user_follow
user_unfollow
*/
CREATE OR REPLACE FUNCTION follow_user(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
  PERFORM pg_advisory_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target)||'_'||greatest(_id_viewer, _id_target)::text, least(_id_viewer, _id_target)));
  PERFORM FROM user_bans WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target);
  IF FOUND THEN RAISE EXCEPTION 'unauthz'; END IF;

  INSERT INTO follows(id_follower, id_following) VALUES(_id_viewer, _id_target);
  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION unfollow_user(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
  DELETE FROM follows WHERE id_follower=_id_viewer AND id_following=_id_target;
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

/*
 user_ban
 user_unban
*/
CREATE OR REPLACE FUNCTION user_ban(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
DECLARE
  __lobby record;
BEGIN
  PERFORM pg_advisory_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target)||'_'||greatest(_id_viewer, _id_target)::text, least(_id_viewer, _id_target)));
  INSERT INTO user_bans(id_usera, id_userb, created_by)
    VALUES(least(_id_viewer, _id_target), greatest(_id_viewer, _id_target), _id_viewer);

  DELETE FROM friends WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target);
  DELETE FROM follows WHERE (id_follower=_id_viewer AND id_following=_id_target) OR (id_follower=_id_target AND id_following=_id_viewer);
  DELETE FROM friend_requests WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target);

  FOR __lobby IN
    SELECT id, id_owner, CASE WHEN id_owner=_id_viewer THEN _id_target ELSE _id_viewer END AS id_target FROM lobbys WHERE id_owner IN(_id_viewer, _id_target) ORDER BY id FOR SHARE
  LOOP
    PERFORM pg_advisory_lock_shared(hashtextextended('lobby_squad'||__lobby.id_target::text, __lobby.id_target));
	  DELETE FROM lobby_requests WHERE id_lobby=__lobby.id AND id_user=__lobby.id_target;
	  DELETE FROM lobby_bans WHERE id_lobby=__lobby.id AND id_user=__lobby.id_target;
	  DELETE FROM lobby_members WHERE id_lobby=__lobby.id AND id_user=__lobby.id_target;
    IF FOUND THEN
      PERFORM lobby_utils_delete_member_invitation(ARRAY[__lobby.id_target], __lobby.id);
      UPDATE lobby_slots SET free_slots=free_slots+1 WHERE id_lobby=__lobby.id;
    END IF;
  END LOOP;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION user_unban(_id_viewer integer, _id_target integer) RETURNS boolean AS $$
BEGIN
  PERFORM pg_advisory_lock(hashtextextended('user_user:'||least(_id_viewer, _id_target)||'_'||greatest(_id_viewer, _id_target)::text, least(_id_viewer, _id_target)));
  DELETE FROM user_bans WHERE id_usera=least(_id_viewer, _id_target) AND id_userb=greatest(_id_viewer, _id_target) AND created_by=_id_viewer;
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;
