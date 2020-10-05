CREATE TYPE group_privacy AS ENUM ('PUBLIC', 'PRIVATE');
CREATE TABLE groups(
  id bigserial PRIMARY KEY,
  name VARCHAR(50),
  description VARCHAR(255),

  id_game integer REFERENCES games DEFAULT NULL,
  id_platform integer REFERENCES platforms DEFAULT NULL,
  id_cross integer DEFAULT NULL,
  FOREIGN KEY(id_game, id_platform) REFERENCES game_platform(id_game, id_platform),
  FOREIGN KEY (id_game, id_platform, id_cross) REFERENCES game_platform(id_game, id_platform, id_cross),

  privacy group_privacy NOT NULL DEFAULT 'PUBLIC',

  id_owner integer REFERENCES users NOT NULL,
  FOREIGN KEY(id, id_owner) REFERENCES group_members(id_group, id_user)
);

CREATE TABLE group_members(
  id_user integer REFERENCES users NOT NULL,
  id_group integer REFERENCES groups NOT NULL,
  PRIMARY KEY(id_user, id_group),
  joined_at timestamptz
);

CREATE TABLE group_bans(
  id_user integer REFERENCES users NOT NULL,
  id_group integer REFERENCES groups NOT NULL,
  created_at timestamptz,
  created_by integer REFERENCES users
);

CREATE TABLE group_invitations(
  id_user integer REFERENCES users NOT NULL,
  id_group integer REFERENCES groups NOT NULL,
  created_by integer REFERENCES users NOT NULL
);

--invited & join_request
CREATE TYPE group_joinrequest_status AS ENUM ('WAITING_USER', 'WAITING_LOBBY', 'WAITING_CONFIRM_INVIT')
CREATE TABLE group_joinrequest_invitation(
  id_user integer REFERENCES users NOT NULL,
  id_group integer REFERENCES groups NOT NULL,
  status
);
/*
 team -> virtual_brand + group ?
 group: place where everyone can post on wall
 user / virtual_brand: place where only owner can post on wall, referencing others with tags ?
 */