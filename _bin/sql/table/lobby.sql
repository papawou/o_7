DROP TABLE IF EXISTS lobbys, lobby_slots, lobby_users, lobby_invitations, lobby_requests CASCADE;

CREATE TABLE lobbys(
  id bigserial PRIMARY KEY,
  id_owner integer REFERENCES users NOT NULL
);

CREATE TABLE lobby_slots(
  id_lobby integer PRIMARY KEY REFERENCES lobbys,
  free_slots integer NOT NULL DEFAULT 1,
  max_slots integer NOT NULL DEFAULT 2
);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_slots FOREIGN KEY(id) REFERENCES lobby_slots(id_lobby) DEFERRABLE;

CREATE TABLE lobby_members(
  id_lobby integer REFERENCES lobbys,
  id_user integer REFERENCES users,
  PRIMARY KEY(id_lobby, id_user)
);

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