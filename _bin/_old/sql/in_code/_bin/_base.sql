-- EVENTS
CREATE TABLE events (
    id bigserial PRIMARY KEY,
    id_user integer references users,
    id_team integer references teams,

    id_game integer references games,
    id_platform integer references platforms,

    name varchar(80) NOT NULL,

    data_event text
);
CREATE TABLE eventmembers (
    id_event integer references events NOT NULL,
    id_user integer references users NOT NULL,

    data_member text,

    PRIMARY KEY (id_event, id_user)
);
CREATE TABLE eventrequests (
    id_event integer references events NOT NULL,
    id_user integer references users NOT NULL,

    data_request text,

    PRIMARY KEY (id_event, id_user)
);


////
DROP TYPE IF EXISTS teamrequest, teamrequest_status CASCADE;
CREATE TYPE teamrequest AS (
  id_team integer,
  id_user integer,
  status log_teamrequest_status,
  data_request text,
  created_at timestamptz,
  resolved_at timestamptz
);
CREATE TYPE teamrequest_status AS ENUM (
  'PENDING',
  'ACCEPTED',
  'DENIED',
  'CANCELED'
);
/*
  GETTERS
*/
DROP FUNCTION IF EXISTS getteamteamrequests CASCADE;
CREATE OR REPLACE FUNCTION getteamteamrequests(in_id_team integer, filter_id_user integer, filter_status teamrequest_status[], in_id_viewer integer) RETURNS SETOF teamrequest AS $$
BEGIN
  IF EXISTS (SELECT FROM teams WHERE teams.id=in_id_team AND teams.id_user=in_id_viewer) THEN
    IF filter_status IS NULL THEN
      RETURN QUERY
        SELECT teamrequests.id_team, teamrequests.id_user, NULL::log_teamrequest_status AS status, teamrequests.data_request, teamrequests.created_at, NULL::timestamptz AS resolved_at
          FROM teamrequests
          WHERE teamrequests.id_team=in_id_team AND (teamrequests.id_user IS NULL OR teamrequests.id_user=filter_id_user)
        UNION ALL
        SELECT log_teamrequests.id_team, log_teamrequests.id_user, log_teamrequests.status::log_teamrequest_status, log_teamrequests.data_request, log_teamrequests.created_at, log_teamrequests.resolved_at
          FROM log_teamrequests
          WHERE log_teamrequests.id_team=in_id_team AND log_teamrequests.status<>'CANCELED' AND (log_teamrequests.id_user IS NULL OR log_teamrequests.id_user=filter_id_user);
    ELSE
      IF 'PENDING'=ANY(filter_status) THEN
        RETURN QUERY
          SELECT teamrequests.id_team, teamrequests.id_user, NULL::log_teamrequest_status AS status, teamrequests.data_request, teamrequests.created_at, NULL::timestamptz AS resolved_at
            FROM teamrequests
            WHERE teamrequests.id_team=in_id_team AND (teamrequests.id_user IS NULL OR teamrequests.id_user=filter_id_user);
        IF array_length(filter_status,1)=1 THEN
          RETURN;
        END IF;
      END IF;
      RETURN QUERY
        SELECT log_teamrequests.id_team, log_teamrequests.id_user, log_teamrequests.status, log_teamrequests.data_request, log_teamrequests.created_at, log_teamrequests.resolved_at
          FROM log_teamrequests
          WHERE log_teamrequests.id_team=in_id_team AND log_teamrequests.status<>'CANCELED' AND (log_teamrequests.id_user IS NULL OR log_teamrequests.id_user=filter_id_user) AND log_teamrequests.status::text=ANY(filter_status::text[]);
    END IF;
  ELSE
    RAISE EXCEPTION USING MESSAGE='403, unauthorized content';
  END IF;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS getuserteamrequests CASCADE;
CREATE OR REPLACE FUNCTION getuserteamrequests(in_id_team integer, in_id_user integer, filter_status teamrequest_status[], in_id_viewer integer) RETURNS SETOF teamrequest AS $$
BEGIN
  IF EXISTS (SELECT FROM teams WHERE teams.id=in_id_team AND teams.id_user=in_id_viewer) THEN
    IF filter_status IS NULL THEN
      RETURN QUERY
        SELECT teamrequests.id_team, teamrequests.id_user, NULL::log_teamrequest_status AS status, teamrequests.data_request, teamrequests.created_at, NULL::timestamptz AS resolved_at
          FROM teamrequests
          WHERE teamrequests.id_team=in_id_team AND (teamrequests.id_user IS NULL OR teamrequests.id_user=in_id_user)
        UNION ALL
        SELECT log_teamrequests.id_team, log_teamrequests.id_user, log_teamrequests.status::log_teamrequest_status, log_teamrequests.data_request, log_teamrequests.created_at, log_teamrequests.resolved_at
          FROM log_teamrequests
          WHERE log_teamrequests.id_team=in_id_team AND log_teamrequests.status<>'CANCELED' AND (log_teamrequests.id_user IS NULL OR log_teamrequests.id_user=in_id_user);
    ELSE
      IF 'PENDING'=ANY(filter_status) THEN
        RETURN QUERY
          SELECT teamrequests.id_team, teamrequests.id_user, NULL::log_teamrequest_status AS status, teamrequests.data_request, teamrequests.created_at, NULL::timestamptz AS resolved_at
            FROM teamrequests
            WHERE teamrequests.id_team=in_id_team AND (teamrequests.id_user IS NULL OR teamrequests.id_user=in_id_user);
        IF array_length(filter_status,1)=1 THEN
          RETURN;
        END IF;
      END IF;
      RETURN QUERY
        SELECT log_teamrequests.id_team, log_teamrequests.id_user, log_teamrequests.status, log_teamrequests.data_request, log_teamrequests.created_at, log_teamrequests.resolved_at
          FROM log_teamrequests
          WHERE log_teamrequests.id_team=in_id_team AND log_teamrequests.status<>'CANCELED' AND (log_teamrequests.id_user IS NULL OR log_teamrequests.id_user=in_id_user) AND log_teamrequests.status::text=ANY(filter_status::text[]);
    END IF;
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
        WHERE teamrequests.id_team=in_id_team AND teamrequests.id_user=in_id_user;
  ELSE
    RAISE EXCEPTION USING MESSAGE='403, unauthorized content';
  END IF;
END;
$$ LANGUAGE plpgsql;

--VIEWER
DROP FUNCTION IF EXISTS getviewerteamrequests CASCADE;
CREATE OR REPLACE FUNCTION getviewerteamrequests(filter_id_team integer, filter_status teamrequest_status[], in_id_viewer integer) RETURNS SETOF teamrequest AS $$
BEGIN
  IF filter_status IS NULL THEN
    RETURN QUERY
      SELECT teamrequests.id_team, teamrequests.id_user, NULL::log_teamrequest_status AS status, teamrequests.data_request, teamrequests.created_at, NULL::timestamptz AS resolved_at
        FROM teamrequests
        WHERE (filter_id_team IS NULL OR teamrequests.id_team=filter_id_team) AND teamrequests.id_user=in_id_viewer
      UNION ALL
      SELECT log_teamrequests.id_team, log_teamrequests.id_user, log_teamrequests.status::log_teamrequest_status, log_teamrequests.data_request, log_teamrequests.created_at, log_teamrequests.resolved_at
        FROM log_teamrequests
        WHERE (filter_id_team IS NULL OR log_teamrequests.id_team=filter_id_team) AND log_teamrequests.id_user=in_id_viewer;
  ELSE
    IF 'PENDING'=ANY(filter_status) THEN
      RETURN QUERY
        SELECT teamrequests.id_team, teamrequests.id_user, NULL::log_teamrequest_status AS status, teamrequests.data_request, teamrequests.created_at, NULL::timestamptz AS resolved_at
          FROM teamrequests
          WHERE (filter_id_team IS NULL OR teamrequests.id_team=filter_id_team) AND teamrequests.id_user=in_id_viewer;
      IF array_length(filter_status,1)=1 THEN
        RETURN;
      END IF;
    END IF;
    RETURN QUERY
      SELECT log_teamrequests.id_team, log_teamrequests.id_user, log_teamrequests.status, log_teamrequests.data_request, log_teamrequests.created_at, log_teamrequests.resolved_at
        FROM log_teamrequests
        WHERE (filter_id_team IS NULL OR log_teamrequests.id_team=filter_id_team) AND log_teamrequests.id_user=in_id_viewer AND log_teamrequests.status::text=ANY(filter_status::text[]);
  END IF;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS getviewerteamrequest CASCADE;
CREATE OR REPLACE FUNCTION getviewerteamrequest(in_id_team integer, in_id_viewer integer, OUT out_request teamrequests) AS $$
BEGIN
  SELECT * INTO out_request
    FROM teamrequests
      WHERE teamrequests.id_team=in_id_team AND teamrequests.id_user=in_id_viewer;
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
      WHERE id_team=in_id_team AND id_user=in_id_user
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
      WHERE id_team=in_id_team AND id_user=in_id_user
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
    WHERE id_team=in_id_team AND id_user=in_id_viewer
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