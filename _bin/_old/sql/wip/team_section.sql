------------------------------
------ TEAM.sql
------------------------------
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
------------------------------
------ SECTION.sql
------------------------------
CREATE TABLE sections(
  id bigserial primary key,
  id_team integer references teams NOT NULL,
  UNIQUE(id_team, id)
);

CREATE TABLE sectionsmembers(
  id_section integer REFERENCES sections NOT NULL,
  id_user integer REFERENCES users NOT NULL,
  id_team integer REFERENCES teams NOT NULL,

  FOREIGN KEY(id_team, id_section) REFERENCES sections(id_team, id),
  FOREIGN KEY(id_team, id_user) REFERENCES teammembers(id_team, id_user),
  PRIMARY KEY(id_section, id_user)
);

CREATE TABLE log_sectionmembers(
  id_section integer REFERENCES sections NOT NULL,
  id_user integer REFERENCES users NOT NULL,
  was_kicked boolean NOT NULL DEFAULT FALSE,
  resolved_by integer REFERENCES users,
  joined_at timestamptz NOT NULL,
  leaved_at timestamptz NOT NULL DEFAULT NOW(),
  CHECK((was_kicked IS TRUE AND id_user <> resolved_by AND resolved_by IS NOT NULL)
    OR (was_kicked IS FALSE AND resolved_by IS NULL))
);

--REQUESTS
CREATE TABLE pending_sectionrequests(
  id bigserial PRIMARY KEY,
  id_section integer REFERENCES sections NOT NULL,
  id_user integer REFERENCES users NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),

  id_team_for_member integer REFERENCES teams,
  id_team_for_request integer REFERENCES teams,
  is_strict BOOLEAN NOT NULL DEFAULT FALSE,

  CHECK(
    (id_team_for_member IS NULL AND id_team_for_request IS NOT NULL) -- USER NOT TEAM MEMBER
    OR
    (id_team_for_member IS NOT NULL AND id_team_for_request IS NULL) -- USER IS TEAMMEMBER
  ),

  FOREIGN KEY(id_team_for_member, id_user) REFERENCES teammembers(id_team, id_user),
  FOREIGN KEY(id_team_for_member, id_section) REFERENCES sections(id_team, id),

  FOREIGN KEY(id_team_for_request, id_user) REFERENCES pending_teamrequests(id_team, id_user),
  FOREIGN KEY(id_team_for_request, id_section) REFERENCES sections(id_team, id),

  UNIQUE(id_section, id_user)
);
CREATE UNIQUE INDEX ON pending_sectionrequests(id_team_for_request, id_user) WHERE is_strict IS TRUE;

CREATE TABLE log_sectionrequests(
  id integer PRIMARY KEY,
  id_section integer REFERENCES sections NOT NULL,
  id_user integer REFERENCES users NOT NULL,
  status teamsectionrequest_status NOT NULL,
  resolved_by integer REFERENCES users,
  created_at timestamptz NOT NULL,
  resolved_at timestamptz NOT NULL DEFAULT NOW()
);