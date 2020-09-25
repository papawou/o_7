DROP TABLE IF EXISTS lobbys, lobby_slots, lobby_users, lobby_invitations CASCADE;
DROP TYPE IF EXISTS lobby_privacy, lobby_join_request_status CASCADE;
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

CREATE TYPE lobby_active_joinrequest_status AS ENUM('WAITING_USER', 'WAITING_LOBBY');
CREATE TABLE lobby_users(
    id_user integer REFERENCES users NOT NULL,
    id_lobby integer REFERENCES lobbys NOT NULL,
    PRIMARY KEY(id_lobby, id_user),
    --member
    fk_member integer REFERENCES users UNIQUE,
    is_owner boolean NOT NULL DEFAULT FALSE,
    cached_perms integer,
    --lobby_join_request
    status lobby_active_joinrequest_status,
    history json, --WAITING_LOBBY to WAITING_USER
    created_at timestamptz,
    --ban
    ban_resolved_at timestamptz
);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_owner FOREIGN KEY(id, id_owner) REFERENCES lobby_users(id_lobby, fk_member) DEFERRABLE;

CREATE TYPE lobby_log_joinrequest_status AS ENUM('CANCELED_BY_USER', 'CONFIRMED_BY_USER', 'DENIED_BY_USER', 'CANCELED_BY_LOBBY', 'DENIED_BY_LOBBY');
CREATE TABLE log_lobby_requests(
  id_user integer REFERENCES users NOT NULL,
  id_lobby integer REFERENCES lobbys NOT NULL,
  status lobby_log_joinrequest_status NOT NULL,
  resolved_at timestamptz NOT NULL DEFAULT NOW(),
  resolved_by integer REFERENCES users NOT NULL,
  CHECK((resolved_by=id_user AND ('CANCELED_BY_USER' OR 'DENIED_BY_USER' OR 'CONFIRMED_BY_USER')) OR (resolved_by<>id_user AND('CANCELED_BY_LOBBY' OR 'DENIED_BY_LOBBY'))),
  log_history json --{chat: [{sended_at: timestamptz, data: text}], actions: [{created_by: , action: , created_at: }]}
);