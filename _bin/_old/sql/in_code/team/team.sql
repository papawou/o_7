DROP FUNCTION IF EXISTS createteam CASCADE;
CREATE OR REPLACE FUNCTION createteam(in_team_name varchar, in_id_viewer integer, OUT out_id integer) AS $$
BEGIN
  INSERT INTO teams(name, id_user)
    VALUES(in_team_name, in_id_viewer)
  RETURNING id INTO out_id;
  INSERT INTO teammembers(id_team, id_user)
    VALUES(out_id, in_id_viewer);
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS jointeam CASCADE;
CREATE OR REPLACE FUNCTION jointeam(in_id_team integer, in_id_viewer integer, OUT success boolean ) AS $$
BEGIN
  IF NOT EXISTS(SELECT FROM teammembers WHERE teammembers.id_team=in_id_team AND teammembers.id_user=in_id_viewer) THEN
    IF NOT EXISTS(SELECT FROM teamrequests WHERE teammembers.id_team=in_id_team AND teammembers.id_user=in_id_viewer) THEN
      INSERT INTO teamrequests(id_team, id_user)
        VALUES (in_id_team, in_id_viewer)
      RETURNING true INTO success;
    ELSE
      RAISE EXCEPTION USING MESSAGE='400, already requested';
    END IF;
  ELSE
    RAISE EXCEPTION USING MESSAGE='400, already member';
  END IF;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS leaveteam CASCADE;
CREATE OR REPLACE FUNCTION leaveteam(in_id_team integer, in_id_viewer integer, OUT success boolean ) AS $$
DECLARE
current_member teammembers;
BEGIN
  DELETE FROM teammembers
    WHERE id_team=in_id_team AND id_user=in_id_viewer
  RETURNING * INTO current_member;
  IF current_member IS NULL THEN
    RAISE EXCEPTION USING MESSAGE='400, not member';
  ELSE
    INSERT INTO log_teammembers(id_team, id_user, data_member, joined_at)
      VALUES (current_member.id_team, current_member.id_user, current_member.data_member, current_member.joined_at);
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS kickteammember CASCADE;
CREATE OR REPLACE FUNCTION kickteammember(in_id_team integer, in_id_user integer, in_id_viewer integer, OUT success boolean ) AS $$
DECLARE
current_member teammembers;
BEGIN
  IF EXISTS(SELECT FROM teams WHERE id=in_id_team AND id_user=in_id_viewer) THEN
    DELETE FROM teammembers
      WHERE id_team=in_id_team AND id_user=in_id_user
    RETURNING * INTO current_member;
    IF current_member IS NULL THEN
      RAISE EXCEPTION USING MESSAGE='404, member not found';
    ELSE
      INSERT INTO log_teammembers(id_team, id_user, data_member, reason, joined_at)
      VALUES (current_member.id_team, current_member.id_user, current_member.data_member, 'KICKED', current_member.joined_at)
      RETURNING true INTO success;
    END IF;
  ELSE
    RAISE EXCEPTION USING MESSAGE='400, not authorized';
  END IF;
END;
$$ LANGUAGE plpgsql;