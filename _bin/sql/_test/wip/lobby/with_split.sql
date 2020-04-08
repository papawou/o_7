DROP TABLE IF EXISTS lobbys, lobby_members, lobby_cvs, lobby_bans CASCADE;
CREATE TABLE lobbys(
    id bigserial PRIMARY KEY,

    created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE lobby_members(
  id_user integer REFERENCES users UNIQUE NOT NULL,
  id_lobby integer REFERENCES lobbys NOT NULL,
  PRIMARY KEY(id_lobby, id_user),

  joined_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE lobby_bans(
    id_user integer REFERENCES users NOT NULL,
    id_lobby integer REFERENCES lobbys NOT NULL,
    PRIMARY KEY(id_user, id_lobby),

    resolved_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT NOW(),

    banned_by integer REFERENCES users NOT NULL
);

CREATE TABLE auth_lobby(
  id_lobby integer REFERENCES lobbys NOT NULL,

  friends_is_moderator boolean NOT NULL DEFAULT FALSE,
  code_moderator json NOT NULL DEFAULT '{"can_ban": true}',
  code_member json NOT NULL DEFAULT '{"can_ban": false}'
);

CREATE TABLE auth_lobby_user(
  id_user integer REFERENCES users NOT NULL,
  id_lobby integer REFERENCES lobbys NOT NULL,
  PRIMARY KEY(id_user, id_lobby),

  fk_member integer REFERENCES users,
  CHECK(fk_member IS NOT NULL AND fk_member=id_user),
  FOREIGN KEY (fk_member, id_lobby) REFERENCES lobby_members(id_user, id_lobby),
  fk_ban integer REFERENCES users,
  CHECK(fk_ban IS NOT NULL AND fk_ban=id_user),
  FOREIGN KEY (fk_ban, id_lobby) REFERENCES lobby_bans(id_user, id_lobby),

  CHECK(fk_member::boolean + fk_ban::boolean <= 1),

  can_ban boolean,
  can_invite boolean,
  can_manage_invite boolean,

  jti integer NOT NULL DEFAULT 0
);