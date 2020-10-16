/*
GROUP
 - join
 - leave

invitations
  creator
    - create
    - cancel
  target
    - accept
    - decline
  group
    - accept
    - decline
*/
DROP TABLE IF EXISTS groups, group_members, group_bans CASCADE;
DROP TYPE group_privacy CASCADE;
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

  check_join boolean NOT NULL DEFAULT FALSE,
  privacy group_privacy NOT NULL DEFAULT 'PUBLIC',

  id_owner integer REFERENCES users NOT NULL
);

CREATE TABLE group_members(
  id_user integer REFERENCES users NOT NULL,
  id_group integer REFERENCES groups NOT NULL,
  PRIMARY KEY(id_user, id_group),

  is_owner boolean NOT NULL DEFAULT FALSE,
  joined_at timestamptz
);
ALTER TABLE groups ADD CONSTRAINT fk_group_owner FOREIGN KEY(id, id_owner) REFERENCES group_members(id_group, id_user) DEFERRABLE;

CREATE TABLE group_bans(
  id_user integer REFERENCES users NOT NULL,
  id_group integer REFERENCES groups NOT NULL,
  created_at timestamptz,
  created_by integer REFERENCES users
);

CREATE TABLE group_invitations(
  id_user integer REFERENCES users NOT NULL,
  id_group integer REFERENCES groups NOT NULL,
  created_by integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_user, created_by),
  FOREIGN KEY(id_user, id_group)
);

CREATE TYPE group_joinrequest_status AS ENUM ('WAITING_USER', 'WAITING_LOBBY');
CREATE TABLE group_joinrequest_invitation(
  id_user integer REFERENCES users NOT NULL,
  id_group integer REFERENCES groups NOT NULL,
  status group_joinrequest_status NOT NULL,
  created_by integer REFERENCES users NOT NULL
);

/*
user_join
    check_request ?
        join_request
            - lobby need confirm
        : join
invite_user
    check_request  & !trusted_invite ?
        invitation_request
            - lobby need confirm
        : invite
*/
*/