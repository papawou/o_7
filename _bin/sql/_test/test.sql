INSERT INTO


/*
CREATE TABLE lobbys(
    id bigserial PRIMARY KEY,
    id_owner integer REFERENCES users NOT NULL,

    id_game integer REFERENCES games NOT NULL,
    id_platform integer REFERENCES platforms NOT NULL,
    id_cross integer DEFAULT NULL,
    FOREIGN KEY(id_game, id_platform) REFERENCES game_platforms(id_game, id_platform),
    FOREIGN KEY (id_game, id_platform, id_cross) REFERENCES game_platforms(id_game, id_platform, id_cross),

    max_size integer NOT NULL,
    CHECK(max_size > 1),
    size integer NOT NULL,
    CHECK(0 <= size AND size <= max_size),

    bit_auth_moderator integer NOT NULL DEFAULT 3,
    bit_auth_member integer NOT NULL DEFAULT 1,

    created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE lobby_cvs(
    id bigserial PRIMARY KEY,
    id_lobby integer REFERENCES lobbys NOT NULL,
    UNIQUE(id_lobby, id)
);

CREATE TABLE auth_lobby_user(
  id_lobby integer REFERENCES lobbys NOT NULL,
  id_user integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_lobby, id_user),

  is_member boolean NOT NULL DEFAULT FALSE,
  is_owner boolean NOT NULL DEFAULT FALSE,
  is_moderator boolean NOT NULL DEFAULT FALSE,

  is_banned timestamptz DEFAULT NULL,

  updated_at timestamptz NOT NULL DEFAULT NOW(),
  jti integer NOT NULL DEFAULT 0
);

CREATE TABLE lobby_members(
  id_lobby integer REFERENCES lobbys NOT NULL,
  id_user integer REFERENCES users NOT NULL UNIQUE,
  PRIMARY KEY(id_lobby, id_user),

  id_cv integer REFERENCES lobby_cvs,
  FOREIGN KEY (id_lobby, id_cv) REFERENCES lobby_cvs(id_lobby, id),
  joined_at timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_owner FOREIGN KEY(id, id_owner) REFERENCES lobby_members(id_lobby, id_user) DEFERRABLE;

*/