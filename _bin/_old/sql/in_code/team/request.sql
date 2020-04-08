/*
  GETTERS
*/
-- TEAMREQUEST
DROP FUNCTION IF EXISTS getteamrequests CASCADE;
CREATE OR REPLACE FUNCTION getteamrequests(in_id_team integer, in_id_viewer integer) RETURNS SETOF teamrequests AS $$
BEGIN
  IF EXISTS (SELECT FROM teams WHERE teams.id=in_id_team AND teams.id_user=in_id_viewer) THEN
    RETURN QUERY
      SELECT *
        FROM teamrequests
          WHERE teamrequests.id_team=in_id_team;
  ELSE
    RAISE EXCEPTION USING MESSAGE='403, unauthorized content';
  END IF;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS getteamrequest CASCADE;
CREATE OR REPLACE FUNCTION getteamrequest(in_id_team integer, in_id_user integer, in_id_viewer integer, OUT out_request teamrequests) AS $$
BEGIN
  IF EXISTS(SELECT FROM teams WHERE teams.id=in_id_team AND teams.id_user=in_id_viewer) THEN
    SELECT * INTO out_request
      FROM teamrequests
        WHERE teamrequests.id_team=in_id_team
          AND teamrequests.id_user=in_id_user;
  ELSE
    RAISE EXCEPTION USING MESSAGE='403, unauthorized content';
  END IF;
END;
$$ LANGUAGE plpgsql;
  -- LOG
DROP FUNCTION IF EXISTS getlogteamrequests CASCADE;
CREATE OR REPLACE FUNCTION getlogteamrequests(in_id_team integer, filter_id_user integer, filter_status log_teamrequest_status[], in_id_viewer integer) RETURNS SETOF log_teamrequests AS $$
BEGIN
  IF EXISTS(SELECT FROM teams WHERE teams.id=in_id_team AND teams.id_user=in_id_viewer) THEN
    RETURN QUERY
      SELECT * FROM log_teamrequests
        WHERE log_teamrequests.id_team=in_id_team
          AND (filter_id_user IS NULL OR log_teamrequests.id_user=filter_id_user)
          AND (log_teamrequests.status<>'CANCELED' AND cardinality(filter_status)=0 OR log_teamrequests.status::text=ANY(filter_status::text[]));
  ELSE
    RAISE EXCEPTION USING MESSAGE='403, unauthorized content';
  END IF;
END;
$$ LANGUAGE plpgsql;
--VIEWER
DROP FUNCTION IF EXISTS getviewerteamrequests CASCADE;
CREATE OR REPLACE FUNCTION getviewerteamrequests(in_id_viewer integer) RETURNS SETOF teamrequests AS $$
BEGIN
  RETURN QUERY
    SELECT * FROM teamrequests
      WHERE id_user=in_id_viewer;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS getviewerteamrequest CASCADE;
CREATE OR REPLACE FUNCTION getviewerteamrequest(in_id_team integer, in_id_viewer integer, OUT out_request teamrequests) AS $$
BEGIN
  SELECT * INTO out_request
    FROM teamrequests
      WHERE teamrequests.id_team=in_id_team
        AND teamrequests.id_user=in_id_viewer;
END;
$$ LANGUAGE plpgsql;
  -- LOG
DROP FUNCTION IF EXISTS getviewerlogteamrequests CASCADE;
CREATE OR REPLACE FUNCTION getviewerlogteamrequests(filter_id_team integer, filter_status log_teamrequest_status[], in_id_viewer integer) RETURNS SETOF log_teamrequests AS $$
BEGIN
  RETURN QUERY
    SELECT * FROM log_teamrequests
      WHERE id_user=in_id_viewer
        AND (filter_id_team IS NULL OR log_teamrequests.id_team=filter_id_team)
        AND (cardinality(filter_status)=0 OR log_teamrequests.status::text=ANY(filter_status::text[]));
END;
$$ LANGUAGE plpgsql;

/*
  METHODS
*/
  --ADMIN
DROP FUNCTION IF EXISTS acceptteamrequest CASCADE;
CREATE OR REPLACE FUNCTION acceptteamrequest(in_id_team integer, in_id_user integer, in_id_viewer integer, OUT new_teammember teammembers) AS $$
DECLARE
  resolved_request teamrequests;
BEGIN
  IF EXISTS (SELECT FROM teams WHERE id=in_id_team AND id_user=in_id_viewer) THEN
    DELETE FROM teamrequests
      WHERE id_team=in_id_team
        AND id_user=in_id_user
    RETURNING * INTO resolved_request;
    IF resolved_request IS NULL THEN
      RAISE '404, REQUEST NOT FOUND';
    ELSE
      INSERT INTO log_teamrequests(id_team, id_user, status, data_request, created_at)
        VALUES(resolved_request.id_team, resolved_request.id_user, 'ACCEPTED'::log_teamrequest_status, resolved_request.data_request, resolved_request.created_at);
      INSERT INTO teammembers(id_team, id_user)
        VALUES (resolved_request.id_team, resolved_request.id_user)
      RETURNING * INTO new_teammember;
    END IF;
  ELSE
    RAISE EXCEPTION USING MESSAGE='403, unauthorized action';
  END IF;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS denyteamrequest CASCADE;
CREATE OR REPLACE FUNCTION denyteamrequest(in_id_team integer, in_id_user integer, in_id_viewer integer, OUT success boolean) AS $$
DECLARE
  resolved_request teamrequests;
BEGIN
  IF EXISTS (SELECT FROM teams WHERE id=in_id_team AND id_user=in_id_viewer) THEN
    DELETE FROM teamrequests
      WHERE id_team=in_id_team
        AND id_user=in_id_user
    RETURNING * INTO resolved_request;
    IF resolved_request IS NULL THEN
      RAISE '404, REQUEST NOT FOUND';
    ELSE
      INSERT INTO log_teamrequests(id_team, id_user, status, data_request, created_at)
        VALUES(resolved_request.id_team, resolved_request.id_user, 'DENIED'::log_teamrequest_status, resolved_request.data_request, resolved_request.created_at)
      RETURNING true INTO success;
    END IF;
  ELSE
    RAISE EXCEPTION USING MESSAGE='403, unauthorized action';
  END IF;
END;
$$ LANGUAGE plpgsql;

  --VIEWER
DROP FUNCTION IF EXISTS cancelteamrequest CASCADE;
CREATE OR REPLACE FUNCTION cancelteamrequest(in_id_team integer, in_id_viewer integer, OUT success boolean) AS $$
DECLARE
  resolved_request teamrequests;
BEGIN
  DELETE FROM teamrequests
    WHERE id_team=in_id_team
      AND id_user=in_id_viewer
  RETURNING * INTO resolved_request;
  IF resolved_request IS NULL THEN
    RAISE '404, REQUEST NOT FOUND';
  ELSE
    INSERT INTO log_teamrequests(id_team, id_user, data_request, created_at)
      VALUES(resolved_request.id_team, resolved_request.id_user, resolved_request.data_request, resolved_request.created_at)
    RETURNING true INTO success;
  END IF;
END;
$$ LANGUAGE plpgsql;