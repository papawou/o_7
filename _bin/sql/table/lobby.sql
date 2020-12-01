DROP TABLE IF EXISTS lobbys, lobby_slots, lobby_members, lobby_requests, lobby_invitations, lobby_invitations CASCADE;
DROP TYPE IF EXISTS lobby_privacy, lobby_request_status CASCADE;
/*
code_auth: can_invite
*/
CREATE TYPE lobby_privacy AS ENUM('PRIVATE','DEFAULT');
CREATE TABLE lobbys(
  id bigserial PRIMARY KEY,
  check_join boolean NOT NULL DEFAULT FALSE,
  privacy lobby_privacy NOT NULL DEFAULT 'DEFAULT'::lobby_privacy,

  id_owner integer REFERENCES users NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE lobby_slots(
  id_lobby integer REFERENCES lobbys ON DELETE CASCADE DEFERRABLE PRIMARY KEY,
  free_slots integer NOT NULL DEFAULT 1,
  max_slots integer NOT NULL DEFAULT 2,
  CHECK(0 <= free_slots  AND 1 < max_slots AND free_slots < max_slots)
);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_slots FOREIGN KEY(id) REFERENCES lobby_slots(id_lobby) DEFERRABLE;

CREATE TABLE lobby_members(
  id_lobby integer REFERENCES lobbys NOT NULL,
  id_user integer REFERENCES users NOT NULL UNIQUE,
  PRIMARY KEY(id_lobby, id_user),

	is_owner boolean NOT NULL DEFAULT FALSE,
  joined_at timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_owner FOREIGN KEY(id, id_owner) REFERENCES lobby_members(id_lobby, id_user) DEFERRABLE;

CREATE TYPE lobby_request_status AS ENUM('WAITING_USER', 'WAITING_LOBBY');
CREATE TABLE lobby_requests(
  id_user integer REFERENCES users NOT NULL,
  id_lobby integer REFERENCES lobbys NOT NULL,
  PRIMARY KEY(id_lobby, id_user),

  status lobby_request_status,
  created_at timestamptz NOT NULL DEFAULT NOW(),

  id_creator integer REFERENCES users, --means invit not request
  CHECK(id_creator<>id_user OR id_creator IS NULL)
);

CREATE TABLE lobby_invitations(
  id_creator integer REFERENCES users,
  id_target integer REFERENCES users,
  id_lobby integer REFERENCES lobbys ON DELETE CASCADE,
  PRIMARY KEY(id_creator, id_target),
  CHECK(id_creator<>id_target),
  FOREIGN KEY(id_lobby, id_creator) REFERENCES lobby_members(id_lobby, id_user) DEFERRABLE,
  FOREIGN KEY(id_lobby, id_target) REFERENCES lobby_requests(id_lobby, id_user) ON DELETE CASCADE
);
ALTER TABLE lobby_requests ADD CONSTRAINT fk_lobby_request_creator FOREIGN KEY(id_creator, id_user) REFERENCES lobby_invitations(id_creator, id_target) DEFERRABLE;

CREATE TABLE lobby_bans(
  id_lobby integer REFERENCES users NOT NULL,
  id_user integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_lobby, id_user),

  created_at timestamptz NOT NULL DEFAULT NOW(),
  ban_resolved_at timestamptz NOT NULL
);