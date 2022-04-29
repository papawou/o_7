/*
create
join
leave

ban
set_specific_perms
set_owner
*/

CREATE OR REPLACE FUNCTION group_create(_id_viewer integer, _id_game integer, _id_platform integer, _id_cross integer, _check_join boolean, _privacy group_privacy, _auth_default integer, _auth_follower integer, _auth_friend integer, OUT id_group_ integer) RETURNS integer AS $$
BEGIN
  INSERT INTO groups
    (id_owner, id_game, id_platform, id_cross, check_join, privacy, auth_default, auth_follower, auth_friend)
    VALUES
    (_id_viewer, _id_game, _id_platform, _id_cross, _check_join, _privacy, _auth_default, _auth_follower, _auth_friend)
    RETURNING id INTO id_group_;

  INSERT INTO group_members
    (id_group, id_user, is_owner)
    VALUES
    (id_group_, _id_viewer,  true);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION group_join(_id_viewer integer, _id_group integer) RETURNS integer AS $$
DECLARE
  __group_params groups%rowtype;
BEGIN
  SELECT * INTO __group_params FROM groups WHERE id=_id_group FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'group not found'; END IF;

  IF __group_params.privacy='private' OR __group_params.check_join THEN
	  RAISE EXCEPTION 'private or check_join group';
  END IF;

  SELECT pg_advisory_xact_lock(hashtextextended('group_user:'||_id_group,_id_viewer));
  PERFORM FROM group_bans WHERE id_group=_id_group AND id_user=_id_viewer;
  IF FOUND THEN RAISE EXCEPTION 'group_user banned'; END IF;

  INSERT INTO group_members (id_user, id_group)
    VALUES (_id_viewer, _id_group);
END
$$ LANGUAGE plpgsql;


--deadlock ?
CREATE OR REPLACE FUNCTION group_leave(_id_viewer integer, _id_group integer) RETURNS boolean AS $$
BEGIN
  DELETE FROM group_members WHERE id_user=_id_viewer AND id_group=_id_group AND is_owner IS FALSE;
END
$$ LANGUAGE plpgsql;

/*
--joinrequest
user_joinrequest_create
user_joinrequest_confirm
user_joinrequest_cancel

manage_joinrequest_accept
manage_joinrequest_deny
*/
--user
CREATE OR REPLACE FUNCTION group_user_join_request(_id_viewer integer, _id_group integer) RETURNS integer AS $$
DECLARE
  __group_params groups%rowtype;
BEGIN
  SELECT * INTO __group_params FROM groups WHERE id=_id_group FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'group not found'; END IF;

  IF __group_params.privacy='PRIVATE' OR __group_params.check_join IS FALSE THEN
	  RAISE EXCEPTION 'private or not check_join group';
  END IF;

  INSERT INTO group_join (id_user, id_group, joinrequest_status, joinrequest_updated_at, joinrequest_history)
    VALUES (_id_viewer, _id_group, 'WAITING_group', NOW(), jsonb_build_array(jsonb_build_object('action',  'WAITING_group', 'created_by', _id_viewer, 'created_at', NOW())))
    ON CONFLICT (id_user, id_group) DO UPDATE SET joinrequest_status='WAITING_group', joinrequest_updated_at=NOW(), joinrequest_history=jsonb_build_array(jsonb_build_object('action',  'WAITING_group', 'created_by', _id_viewer, 'created_at', NOW()))
    WHERE joinrequest_status NOT IN ('WAITING_USER', 'WAITING_group');
  IF NOT FOUND THEN RAISE EXCEPTION 'group_joinrequest not created_at'; END IF;

  RETURN true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION group_user_joinrequest_confirm(_id_viewer integer, _id_group integer) RETURNS boolean AS $$
DECLARE
  __group_params groups%rowtype;
  __viewer_perms integer;
  __log_joinrequest_history jsonb;
BEGIN
  SELECT * INTO __group_params FROM groups WHERE id=_id_group FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'group not found'; END IF;

  SELECT pg_advisory_xact_lock_shared(hashtextextended('user_user:'||least(_id_viewer, __group_params.id_owner),greatest(_id_viewer, __group_params.id_owner)));
    --perms
  PERFORM FROM friends WHERE id_usera=least(_id_viewer, __group_params.id_owner) AND greatest(_id_viewer, __group_params.id_owner) FOR SHARE;
  IF FOUND THEN __viewer_perms:=__group_params.auth_friend;
  ELSE IF __group_params.privacy!='FRIEND'::group_privacy THEN
    PERFORM FROM follows WHERE id_follower=_id_viewer AND id_following=__group_params.id_owner FOR SHARE;
    IF FOUND THEN __viewer_perms:=__group_params.auth_follower;
    ELSE IF __group_params.privacy='GUEST'::group_privacy THEN __viewer_perms:=__group_params.auth_default; ELSE RAISE EXCEPTION 'unauth'; END IF;
    END IF;
  ELSE
    RAISE EXCEPTION 'unauth';
  END IF; END IF;

  UPDATE group_users SET fk_member=_id_viewer,
                         joined_at=NOW(),
                         cached_perms=__viewer_perms,
                         joinrequest_status=NULL,
                         joinrequest_history=NULL,
                         joinrequest_updated_at=NULL
    WHERE id_user=_id_viewer
      AND id_group=_id_group
      AND joinrequest_status='WAITING_USER'
  RETURNING joinrequest_history INTO __log_joinrequest_history;
  IF NOT FOUND THEN RAISE EXCEPTION 'group_joinrequest not found'; END IF;

  INSERT INTO log_group_joinrequests
      (id_user, id_group, created_at, status, resolved_at, resolved_by, history)
    VALUES
      (_id_viewer, _id_group,__log_joinrequest_history->0->created_at, 'CONFIRMED_BY_USER', NOW(), _id_viewer, __log_joinrequest_history);

  UPDATE group_slots SET free_slots=free_slots-1 WHERE id_group=_id_group;
  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION group_user_joinrequest_cancel(_id_viewer integer, _id_group integer) RETURNS boolean AS $$
DECLARE
  __log_joinrequest_history jsonb;
BEGIN
  DELETE FROM group_users
    WHERE id_group=_id_group AND id_user=_id_viewer AND joinrequest_status IN('WAITING_group', 'WAITING_USER')
    RETURNING joinrequest_history INTO __log_joinrequest_history;

  INSERT INTO log_group_joinrequests
    (id_user, id_group, created_at, status, resolved_at, resolved_by, history)
  VALUES
    (_id_viewer, _id_group,__log_joinrequest_history->0->created_at, 'CANCELED_BY_USER', NOW(), _id_viewer, __log_joinrequest_history);

  RETURN FOUND;
END
$$ LANGUAGE plpgsql;

--manage
CREATE OR REPLACE FUNCTION group_manage_joinrequest_accept(_id_viewer integer, _id_user integer, _id_group integer) RETURNS boolean AS $$
BEGIN
  PERFORM FROM group_users WHERE fk_member=_id_viewer AND id_group=_id_group AND is_owner IS TRUE FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  UPDATE group_users SET joinrequest_status='WAITING_USER', joinrequest_history=joinrequest_history||jsonb_build_object('action',  'WAITING_USER', 'created_by', _id_viewer, 'created_at', NOW())
    WHERE id_group=_id_group
      AND id_user=_id_user
      AND joinrequest_status='WAITING_group'
      AND joinrequest_updated_at=NOW();
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION group_manage_joinrequest_deny(_id_viewer integer, _id_user integer, _id_group integer) RETURNS boolean AS $$
DECLARE
  __log_joinrequest_history jsonb;
BEGIN
  PERFORM FROM group_users WHERE fk_member=_id_viewer AND id_group=_id_group AND is_owner IS TRUE FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

  DELETE FROM group_users
    WHERE id_group=_id_group
      AND id_user=_id_user
      AND joinrequest_status IN ('WAITING_USER', 'WAITING_group')
  RETURNING joinrequest_history INTO __log_joinrequest_history;

  INSERT INTO log_group_joinrequests
    (id_user, id_group, created_at, status, resolved_at, resolved_by, history)
  VALUES
    (_id_viewer, _id_group,__log_joinrequest_history->0->created_at, 'CANCELED_BY_group', NOW(), _id_viewer, __log_joinrequest_history);
END
$$ LANGUAGE plpgsql;

--PERMISSIONS
CREATE OR REPLACE FUNCTION group_set_owner(_id_viewer integer, _id_group integer, _id_target integer) RETURNS boolean AS $$
BEGIN
     UPDATE groups SET id_owner=_id_target WHERE id=_id_group AND id_owner=_id_viewer;
     UPDATE group_users SET is_owner=FALSE WHERE fk_member=_id_viewer AND id_group=_id_group AND is_owner IS TRUE;
     UPDATE group_users SET is_owner=true WHERE fk_member=_id_target AND id_group=_id_group;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION group_ban_user(_id_viewer integer, _id_group integer, _id_target integer, _ban_resolved_at timestamptz) RETURNS boolean AS $$
DECLARE
  __was_member boolean;
BEGIN
	PERFORM FROM group_users WHERE fk_member=_id_viewer AND id_group=_id_group AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauth'; END IF;

    INSERT INTO group_users(id_group, id_user, ban_resolved_at) VALUES(_id_group, _id_target, _ban_resolved_at)
        ON CONFLICT (id_group, id_user) DO UPDATE SET ban_resolved_at=_ban_resolved_at,
                                                      fk_member=NULL,
                                                      joinrequest_status=NULL,
                                                      joinrequest_updated_at=NULL,
                                                      joinrequest_history=NULL
        RETURNING fk_member IS NOT NULL INTO __was_member;

    IF FOUND AND __was_member THEN UPDATE group_slots SET free_slots=free_slots+1 WHERE id_group=_id_group; END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION group_update_privacy(_id_viewer integer, _id_group integer, _group_privacy group_privacy) RETURNS boolean AS $$
BEGIN
  UPDATE groups SET privacy=_group_privacy WHERE id=_id_group AND id_owner=_id_viewer AND privacy<>_group_privacy;
  IF NOT FOUND THEN RAISE EXCEPTION 'failed change privacy'; END IF;
END
$$ LANGUAGE plpgsql;