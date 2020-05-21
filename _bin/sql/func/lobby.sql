CREATE OR REPLACE FUNCTION lobby_create(IN _id_user integer, IN _id_game integer, IN _id_platform integer, IN _id_cross integer, IN _max_size integer, IN  OUT id_lobby_ integer) AS $$
BEGIN
    SET CONSTRAINTS ALL DEFERRED;
    INSERT INTO lobbys
        (id_owner, id_game, id_platform, id_cross, max_size, size)
    VALUES
        (_id_user, _id_game, _id_platform, _id_cross, _max_size, _max_size-1)
    RETURNING id INTO id_lobby_;
    INSERT INTO lobby_users
        (id_lobby, id_user, fk_member, joined_at)
    VALUES
        (_id_user, id_lobby_, _id_user, NOW());
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_join(IN _id_user integer, IN _id_lobby integer, IN _id_cv integer, OUT success_ boolean) AS $$
DECLARE
    __bit_auth_member integer;
    __check_join boolean;
BEGIN
    UPDATE lobbys
        SET size=lobbys.size-1
        WHERE id=_id_lobby;

    SELECT
        CASE
        WHEN user_user.status='FRIEND'
            THEN lobbys.auth_friend
        WHEN user_user.status='FOLLOWER' AND relation_only!='FRIEND'
            THEN lobbys.auth_follower
        WHEN user_user.status IS NULL AND relation_only IS NULL
            THEN lobbys.auth_default
        END, check_join
    INTO __bit_auth_member, __check_join FROM lobbys
        JOIN user_user ON id_user=lobbys.id_owner AND id_target=_id_user
    WHERE lobbys.id=_id_lobby AND is_private IS FALSE;

    INSERT INTO lobby_users
        (id_user, fk_member, id_lobby, id_cv, joined_at)
    VALUES
        (_id_user, _id_user, _id_lobby, _id_cv, NOW())
    ON CONFLICT ON CONSTRAINT lobby_users_pkey DO UPDATE
        SET fk_member=_id_user, id_cv=_id_cv, joined_at=NOW()
    WHERE fk_member IS NULL;
    success_ := true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE lobby_leave(IN _id_viewer integer, INOUT id_lobby_ integer) AS $$
DECLARE
    __is_last boolean;
    __new_owner integer;
    __is_owner boolean;
BEGIN
    SET CONSTRAINTS ALL DEFERRED;
    DELETE FROM lobby_users WHERE fk_member=_id_viewer RETURNING ((bit_roles & 2) > 0), id_lobby INTO __is_owner, id_lobby_;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'viewer not in a lobby';
    ELSIF NOT __is_owner THEN
        RAISE NOTICE '*lobbymember is not owner';
        COMMIT;
    END IF;
    UPDATE lobbys SET size=size+1 WHERE id=id_lobby_ RETURNING size=max_size INTO __is_last; --PREVENT EXEC "ELSE IF(__is_owner)" when lobby is empty
    IF NOT FOUND THEN
        RAISE NOTICE 'lobby not found';
    ELSIF(__is_last) THEN
        RAISE NOTICE 'viewer is last lobbymember';
        DELETE FROM lobbys WHERE id=id_lobby_;
    ELSIF(__is_owner) THEN
        SELECT fk_member INTO __new_owner FROM lobby_users WHERE id_lobby=id_lobby_ LIMIT 1 FOR UPDATE;
        IF NOT FOUND THEN
            RAISE NOTICE 'lobbymembers not found';
            DELETE FROM lobbys WHERE id=id_lobby_;
        ELSE
            UPDATE lobby_users SET bit_roles=2, cbit_auth=3 WHERE id_lobby=id_lobby_ AND fk_member=__new_owner;
            UPDATE lobbys SET id_owner=__new_owner WHERE id=id_lobby_;
        END IF;
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE lobby_ban_user(IN _id_viewer integer, _id_lobby integer, _id_user integer, _ban_time timestamptz, INOUT success_ boolean) AS $$
DECLARE
__was_member boolean;
BEGIN
    PERFORM FROM lobby_users WHERE id_lobby=_id_lobby AND fk_member=_id_viewer  AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauthorized'; END IF;
    INSERT INTO lobby_users
        (id_lobby, id_user, ban_resolved_at)
    VALUES
        (_id_lobby, _id_user, _ban_time)
    ON CONFLICT ON CONSTRAINT lobby_users_pkey DO UPDATE
        SET ban_resolved_at=_ban_time, fk_member=NULL, id_cv=NULL, joined_at=NULL
    WHERE __bit_roles > bit_roles  RETURNING fk_member IS NOT NULL INTO __was_member ;
    IF NOT FOUND THEN RAISE EXCEPTION 'user not in your lobby'; END IF;
    COMMIT;
    IF(__was_member) THEN
        UPDATE lobbys SET size=size+1 WHERE id=_id_lobby;
    END IF;
    success_:= true;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lobby_unban_user(IN _id_viewer integer, _id_lobby integer, IN _id_user integer, OUT success_ boolean) AS $$
BEGIN
    PERFORM FROM lobby_users WHERE id_lobby=_id_lobby AND id_user=_id_viewer AND is_owner IS TRUE FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unauthorized'; END IF;
    UPDATE lobby_users SET ban_resolved_at=null WHERE id_lobby=_id_lobby AND id_user=_id_user AND ban_resolved_at IS NOT NULL;
    IF NOT FOUND THEN RAISE EXCEPTION 'invalid user'; END IF;
END
$$ LANGUAGE plpgsql;

SELECT FROM lobbys
    JOIN user_user ON user_user.id_user=LEAST(lobbys.id_owner, _id_user) AND id_target=GREATEST(lobbys.id_user, _id_user)
WHERE k