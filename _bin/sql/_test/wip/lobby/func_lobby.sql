--[ADMIN, MODERATOR] WHERE MODERATOR x- ADMIN AND MODERATOR x- MODERATOR
CREATE OR REPLACE FUNCTION kick_lobby_member
    (IN _id_viewer integer, IN _jti_viewer integer, IN _id_lobby integer, IN _id_user integer, OUT success_ boolean) AS $$
BEGIN
    SELECT FROM lobby_members WHERE id_lobby=_id_lobby AND id_user=_id_viewer AND jti=_jti_viewer FOR SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'viewer auth lobby_member not found';
    end if;
    UPDATE lobbys SET size=size+1 WHERE id=_id_lobby;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'lobby not found';
    END IF;
    DELETE FROM lobby_members WHERE id_lobby=_id_lobby AND id_user=_id_user AND is_owner=false;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'lobby_member not found';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION change_right_lobby_member
    (IN _id_viewer integer, IN _jti_viewer integer, IN _id_lobby integer, IN _roles json,IN _id_user integer) AS $$
DECLARE
    __original_jti integer;
BEGIN
    SELECT jti into __original_jti FROM lobby_members WHERE id_lobby=_id_lobby AND id_user=_id_viewer FOR SHARE;
    IF(jti =! __original_jti)
        RAISE EXCEPTION 'need refresh jti';
    ELSE IF NOT FOUND THEN
        RAISE EXCEPTION 'no rights';
    endif;endif;
    END;
    UPDATE lobby_members SET  WHERE id_user=_id_user AND id_lobby=_id_lobby AND is_owner=false AND is_;
    IF NOT FOUND THEN RAISE EXCEPTION 'viewer locked';
END;
$$ LANGUAGE plpgsql;

