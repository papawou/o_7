DROP TABLE IF EXISTS lobbys, lobby_slots, lobby_members, lobby_invitations, lobby_requests CASCADE;

CREATE TABLE lobbys(
  id bigserial PRIMARY KEY,
  id_owner integer REFERENCES users NOT NULL,
  filter_join boolean NOT NULL DEFAULT FALSE
);

CREATE TABLE lobby_slots(
  id_lobby integer PRIMARY KEY REFERENCES lobbys ON DELETE CASCADE,
  free_slots integer NOT NULL DEFAULT 1,
  max_slots integer NOT NULL DEFAULT 2,
  CHECK(max_slots >= 2 AND free_slots <= max_slots AND free_slots >= 0)
);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_slots FOREIGN KEY(id) REFERENCES lobby_slots DEFERRABLE;

CREATE TABLE lobby_members(
  id_lobby integer REFERENCES lobbys ON DELETE CASCADE,
  id_user integer REFERENCES users UNIQUE,
  PRIMARY KEY(id_lobby, id_user)
);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_owner FOREIGN KEY(id, id_owner) REFERENCES lobby_members DEFERRABLE;

CREATE TABLE lobby_invitations(
  id_lobby integer REFERENCES lobbys ON DELETE CASCADE,
  id_target integer REFERENCES users,
  id_creator integer REFERENCES users,
  PRIMARY KEY(id_lobby, id_target, id_creator),
  FOREIGN KEY (id_lobby, id_creator) REFERENCES lobby_members ON DELETE CASCADE
);

DROP TYPE lobby_request_status;
CREATE TYPE lobby_request_status AS ENUM ('wait_lobby', 'wait_user', 'inv_wait_lobby');
CREATE TABLE lobby_requests(
  id_lobby integer REFERENCES lobbys ON DELETE CASCADE,
  id_user integer REFERENCES users,
  PRIMARY KEY(id_lobby, id_user),
  status lobby_request_status NOT NULL DEFAULT 'wait_lobby',
  id_creator integer REFERENCES users,
  FOREIGN KEY(id_lobby, id_creator) REFERENCES lobby_members,
  FOREIGN KEY(id_lobby, id_user, id_creator) REFERENCES lobby_invitations,
  CHECK (id_creator IS NULL AND (status = 'wait_lobby') OR (id_creator IS NOT NULL AND status  ='inv_wait_lobby'))
);


/*
CREATE TABLE lobby_bans(
  id_lobby integer REFERENCES lobbys,
  id_user integer REFERENCES users,
  PRIMARY KEY(id_lobby, id_user)
);

CREATE TABLE lobby_invitations(
  id_lobby integer REFERENCES lobbys,
  id_user integer REFERENCES users,
  id_creator integer REFERENCES users,
  PRIMARY KEY(id_lobby, id_creator, id_user)
);

CREATE TABLE lobby_requests(
  id_lobby integer REFERENCES lobbys,
  id_user integer REFERENCES users,
  PRIMARY KEY (id_lobby, id_user),
  id_creator integer REFERENCES users,
  CHECK(id_user IS DISTINCT FROM id_creator),
  FOREIGN KEY(id_lobby, id_user, id_creator) REFERENCES lobby_invitations,
  status boolean
);
 */