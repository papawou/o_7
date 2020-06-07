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

/*
WAITING_USER --to member OR DENIED_BY_USER
WAITING_LOBBY --to WAITING_USER OR DENIED_BY_LOBBY
DENIED_BY_USER --stop transact
DENIED_BY_LOBBY --stop transact
--invite
WAITING_CONFIRM_LOBBY --to WAITING_USER OR DENIED_CONFIRM //invitation hidden
DENIED_CONFIRM --delete lobby_join_request and delete lobby_invitations

confirm = check_join


*/

CREATE TYPE lobby_join_request_status AS ENUM('WAITING_CONFIRM_LOBBY', 'WAITING_LOBBY', 'WAITING_USER', 'DENIED_BY_USER', 'DENIED_BY_LOBBY');
CREATE TABLE lobby_users(
    id_user integer REFERENCES users NOT NULL,
    id_lobby integer REFERENCES lobbys NOT NULL,
    PRIMARY KEY(id_user, id_lobby),
    --member
    fk_member integer REFERENCES users UNIQUE,
    CHECK(id_user=fk_member),
    UNIQUE(id_lobby, fk_member),
    is_owner boolean NOT NULL DEFAULT FALSE,
    allowed_perms integer NOT NULL DEFAULT 1,
    specific_perms integer NOT NULL DEFAULT 0,
    cached_perms integer NOT NULL DEFAULT 0,
    --ban
    ban_resolved_at timestamptz,
    --invitation/lobby_join_request
    status lobby_join_request_status,
    created_by integer REFERENCES users NOT NULL,
    last_attempt timestamptz
);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_owner FOREIGN KEY(id, id_owner) REFERENCES lobby_users(id_lobby, fk_member) DEFERRABLE;