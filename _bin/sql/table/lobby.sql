DROP TABLE IF EXISTS lobbys, lobby_slots, lobby_users, lobby_invitations CASCADE;
DROP TYPE IF EXISTS lobby_privacy, lobby_active_joinrequest_status CASCADE;
/*
code_auth: can_invite
*/
CREATE TYPE lobby_privacy AS ENUM('PRIVATE','DEFAULT','FOLLOWER', 'FRIEND');
CREATE TABLE lobbys(
  id bigserial PRIMARY KEY,

  --id_game integer REFERENCES games NOT NULL,
  --id_platform integer REFERENCES platforms NOT NULL,
  --id_cross integer DEFAULT NULL,
  --FOREIGN KEY(id_game, id_platform) REFERENCES game_platform(id_game, id_platform),
  --FOREIGN KEY (id_game, id_platform, id_cross) REFERENCES game_platform(id_game, id_platform, id_cross),

  --PRIVACY
  check_join boolean NOT NULL DEFAULT FALSE,
  privacy lobby_privacy NOT NULL DEFAULT 'DEFAULT'::lobby_privacy,
  --exp_link varchar(5) NOT NULL DEFAULT 'AAAAA',
  --password varchar(255) DEFAULT NULL,

  --AUTHZ
  -- b0 = trusted_invite
  id_owner integer REFERENCES users NOT NULL UNIQUE,

  /* CONFIG
  --o7
  sound_mic integer DEFAULT NULL, -- 1 sound required, 2 sound+mic required
  CHECK((0 < sound_mic AND sound_mic < 3) OR sound_mic IS NULL),
  url_voice_chat VARCHAR(70) DEFAULT NULL,
  lang VARCHAR(3) DEFAULT NULL,
  --game_config
  game_config jsonb,
  */

  --meta
  --name varchar(50) ,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE lobby_slots(
  id_lobby integer REFERENCES lobbys ON DELETE CASCADE DEFERRABLE PRIMARY KEY,
  free_slots integer NOT NULL DEFAULT 1,
  max_slots integer NOT NULL DEFAULT 2,
  CHECK(0 <= free_slots  AND 1 < max_slots AND free_slots < max_slots)
);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_slots FOREIGN KEY(id) REFERENCES lobby_slots(id_lobby) DEFERRABLE;

CREATE TYPE lobby_active_joinrequest_status AS ENUM('WAITING_USER', 'WAITING_LOBBY', 'INV_WAITING_USER', 'INV_WAITING_LOBBY');
CREATE TABLE lobby_users(
  id_user integer REFERENCES users NOT NULL,
  id_lobby integer REFERENCES lobbys ON DELETE CASCADE NOT NULL,
  PRIMARY KEY(id_lobby, id_user),
  --member
  fk_member integer REFERENCES users UNIQUE,
  UNIQUE(id_lobby, fk_member),
  is_owner boolean,
  --default_perms integer,
  --authz integer,
  --specific_authz integer,
  --joined_at timestamptz,

  --lobby_joinrequest
  joinrequest_status lobby_active_joinrequest_status,
  --ban
  ban_resolved_at timestamptz,

  CHECK(((fk_member IS NOT NULL AND fk_member=id_user AND is_owner IS NOT NULL)
           AND joinrequest_status IS NULL AND (ban_resolved_at < NOW() OR ban_resolved_at IS NULL))
      OR (fk_member IS NULL AND is_owner IS NULL)),
  CHECK ((joinrequest_status IS NOT NULL AND (fk_member IS NULL AND (ban_resolved_at < NOW() OR ban_resolved_at IS NULL)))
      OR (joinrequest_status IS NULL)),
  CHECK((ban_resolved_at > NOW() AND joinrequest_status IS NULL AND fk_member IS NULL)
      OR(ban_resolved_at < NOW() OR ban_resolved_at IS NULL)),
  CHECK(ban_resolved_at IS NOT NULL OR fk_member IS NOT NULL OR joinrequest_status IS NOT NULL)
);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_owner FOREIGN KEY(id, id_owner) REFERENCES lobby_users(id_lobby, fk_member) DEFERRABLE;

/*
CREATE TYPE log_lobby_joinrequest_status AS ENUM('CANCELED_BY_USER', 'CONFIRMED_BY_USER', 'DENIED_BY_USER', 'CANCELED_BY_LOBBY', 'DENIED_BY_LOBBY');
CREATE TABLE log_lobby_joinrequests(
  id_user integer REFERENCES users NOT NULL,
  id_lobby integer REFERENCES lobbys NOT NULL,
  status log_lobby_joinrequest_status NOT NULL,
  resolved_at timestamptz NOT NULL DEFAULT NOW(),
  resolved_by integer REFERENCES users NOT NULL,
  CHECK((resolved_by=id_user AND status IN ('CANCELED_BY_USER', 'DENIED_BY_USER', 'CONFIRMED_BY_USER')) OR (resolved_by<>id_user AND status IN ('CANCELED_BY_LOBBY', 'DENIED_BY_LOBBY'))),
  history jsonb, --[{created_by , action , created_at }]
  created_at timestamptz,
  PRIMARY KEY(id_lobby, id_user, resolved_at)
);
*/

CREATE TABLE lobby_invitations(
  id_creator integer REFERENCES users,
  id_target integer REFERENCES users,
  id_lobby integer REFERENCES lobbys ON DELETE CASCADE,
  PRIMARY KEY(id_creator, id_target),
  FOREIGN KEY(id_creator, id_lobby) REFERENCES lobby_users(fk_member, id_lobby) DEFERRABLE,
  FOREIGN KEY(id_target, id_lobby) REFERENCES lobby_users(id_user, id_lobby) ON DELETE CASCADE
);