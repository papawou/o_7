DROP TABLE IF EXISTS lobbys, lobby_slots, lobby_members, lobby_cvs, lobby_invitations, lobby_bans, lobby_join_requests, lobby_invitations CASCADE;
DROP TYPE IF EXISTS lobby_privacy, lobby_join_request_status, lobby_invitation_status CASCADE;
/*
code_auth: can_invite
*/
CREATE TYPE lobby_privacy AS ENUM('PRIVATE','GUEST','FOLLOWER', 'FRIEND');
CREATE TABLE lobbys(
    id bigserial PRIMARY KEY,

    id_game integer REFERENCES games NOT NULL,
    id_platform integer REFERENCES platforms NOT NULL,
    id_cross integer DEFAULT NULL,
    FOREIGN KEY(id_game, id_platform) REFERENCES game_platforms(id_game, id_platform),
    FOREIGN KEY (id_game, id_platform, id_cross) REFERENCES game_platforms(id_game, id_platform, id_cross),
    --PRIVACY
    check_join boolean NOT NULL DEFAULT FALSE,
    privacy lobby_privacy NOT NULL DEFAULT 'GUEST'::lobby_privacy,
    exp_link varchar(5) NOT NULL DEFAULT 'AAAAA',
    --AUTH
    id_owner integer REFERENCES users NOT NULL,
    auth_default integer NOT NULL DEFAULT 1,
    auth_friend integer NOT NULL DEFAULT 1,
    auth_follower integer NOT NULL DEFAULT 1,

    created_at timestamptz NOT NULL DEFAULT NOW()
);
CREATE TABLE lobby_slots(
    id_lobby integer REFERENCES lobbys PRIMARY KEY,
    free_slots integer NOT NULL DEFAULT 1,
    max_slots integer NOT NULL DEFAULT 2,
    CHECK(0 <= free_slots  AND 1 < max_slots AND free_slots < max_slots)
);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_slots FOREIGN KEY(id) REFERENCES lobby_slots(id_lobby) DEFERRABLE;

CREATE TABLE lobby_members(
  id_lobby integer REFERENCES lobbys NOT NULL,
  id_user integer REFERENCES users NOT NULL UNIQUE,
  PRIMARY KEY(id_lobby, id_user),

  is_owner boolean NOT NULL DEFAULT FALSE, --cached_value
  UNIQUE(id_lobby, is_owner),

  allowed_perms integer NOT NULL DEFAULT 1,
  specific_perms integer NOT NULL DEFAULT 0,
  cached_perms integer NOT NULL DEFAULT 0,

  joined_at timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_owner FOREIGN KEY(id, id_owner) REFERENCES lobby_members(id_lobby, id_user) DEFERRABLE;

CREATE TABLE lobby_bans(
  id_lobby integer REFERENCES lobbys NOT NULL,
  id_user integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_lobby, id_user),
  ban_resolved_at timestamptz NOT NULL DEFAULT NOW(),
  created_by integer REFERENCES users NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TYPE lobby_join_request_status AS ENUM('WAITING_LOBBY', 'WAITING_USER', 'DENIED_BY_LOBBY');
CREATE TABLE lobby_join_requests(
    id_lobby integer REFERENCES lobbys NOT NULL,
    id_user integer REFERENCES users NOT NULL,
    PRIMARY KEY(id_lobby, id_user),
    status lobby_join_request_status NOT NULL DEFAULT 'WAITING_LOBBY'::lobby_join_request_status,
    created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE lobby_invitations(
    id_user integer REFERENCES users NOT NULL,
    created_by integer REFERENCES users NOT NULL,
    PRIMARY KEY(id_user,created_by),
    UNIQUE(id_user,created_by),
    id_lobby integer REFERENCES lobbys NOT NULL,
    created_at timestamptz NOT NULL DEFAULT NOW()
);