DROP TABLE IF EXISTS users, lobbys, lobby_users, lobby_members_test_fk CASCADE;

CREATE TABLE users(
    id serial PRIMARY KEY,
    name varchar
);

INSERT INTO users(name) VALUES('test'), ('testo');

CREATE TABLE lobbys(
    id bigserial PRIMARY KEY
);

--WITH BOOLEAN COLUMN
CREATE TABLE lobby_users(
  id_user integer REFERENCES users NOT NULL,
  id_lobby integer REFERENCES lobbys NOT NULL,
  PRIMARY KEY(id_lobby, id_user),

  --member
  is_member boolean NOT NULL DEFAULT FALSE,
  UNIQUE (id_user, id_lobby, is_member)
);
CREATE UNIQUE INDEX lobby_members ON lobby_users(id_user) WHERE is_member IS TRUE;

CREATE TABLE lobby_members_test_fk(
    id_user integer REFERENCES users NOT NULL,
    id_lobby integer REFERENCES lobbys NOT NULL,
    is_member boolean NOT NULL DEFAULT TRUE,
    FOREIGN KEY(id_lobby, id_user, is_member) REFERENCES lobby_users(id_lobby, id_user, is_member)
);

--WITH ID COLUMN CONTEXT
CREATE TABLE lobby_users(
    id_user integer REFERENCES users NOT NULL,
    id_lobby integer REFERENCES lobbys NOT NULL,
    PRIMARY KEY(id_lobby, id_user),

    --member
    fk_member integer REFERENCES users UNIQUE,
    CHECK(fk_member IS NOT NULL AND fk_member=id_user)
);

CREATE TABLE lobby_members_test_fk(
  id_user integer REFERENCES users NOT NULL,
  id_lobby integer REFERENCES lobbys NOT NULL,
  FOREIGN KEY(id_user, id_lobby) REFERENCES lobby_users(id_user, id_lobby),
  FOREIGN KEY(id_user) REFERENCES lobby_users(fk_member)
);

--SAVED
CREATE TABLE lobby_users(
  id_lobby integer REFERENCES lobbys NOT NULL,
  id_user integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_lobby, id_user),

  --member
  fk_member integer REFERENCES users UNIQUE NOT NULL, --user can be 1:1 lobby_members
  id_cv integer REFERENCES lobby_cvs,
  FOREIGN KEY(id_lobby, id_cv) REFERENCES lobby_cvs(id_lobby, id),
  joined_at timestamptz,
  UNIQUE(id_lobby, fk_member), --PRIMARY KEY lobby_members

  --auth
  --is_member boolean
  ban_resolved_at timestamptz,
  can_code integer, --cup
  can_cached_code integer, --cup + rp
  updated_at timestamptz NOT NULL,
  jti uuid NOT NULL,

  CHECK((fk_member=id_user AND ban_resolved_at < NOW() AND joined_at IS NOT NULL) --user is member
    OR (fk_member IS NULL AND joined_at IS NULL AND id_cv IS NULL)) --user is not member
);