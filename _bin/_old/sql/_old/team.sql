CREATE TABLE teams(
  id bigserial PRIMARY KEY,
  id_owner integer REFERENCES users NOT NULL,
  --OPTIONAL
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE teammembers(
  id_team integer REFERENCES teams NOT NULL,
  id_user integer REFERENCES users NOT NULL,
  --OPTIONAL
  joined_at timestamptz NOT NULL DEFAULT NOW(),

  PRIMARY KEY(id_team, id_user)
);

ALTER TABLE teams ADD FOREIGN KEY(id, id_owner) REFERENCES teammembers(id_team, id_user); --ENSURE TEAM.OWNER IS TEAMMEMBER

CREATE TABLE log_teammembers(
  id_team integer REFERENCES teams NOT NULL,
  id_user integer REFERENCES users NOT NULL,

  joined_at timestamptz NOT NULL,
  leaved_at timestamptz NOT NULL DEFAULT NOW(),

  --OPTIONAL
  was_kicked boolean NOT NULL DEFAULT FALSE,
  resolved_by integer REFERENCES users,
  CHECK((was_kicked IS TRUE AND id_user <> resolved_by AND resolved_by IS NOT NULL)
    OR (was_kicked IS FALSE AND resolved_by IS NULL))
);

--REQUESTS
CREATE TABLE pending_teamrequests(
  id bigserial PRIMARY KEY,
  id_team integer references teams NOT NULL,
  id_user integer references users NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE(id_team, id_user)
);

CREATE TABLE log_teamrequests(
  id integer PRIMARY KEY,
  id_team integer REFERENCES teams NOT NULL,
  id_user integer REFERENCES users NOT NULL,
  status teamsectionrequest_status NOT NULL,
  resolved_by integer REFERENCES users,
  created_at timestamptz NOT NULL,
  resolved_at timestamptz NOT NULL DEFAULT NOW()
);