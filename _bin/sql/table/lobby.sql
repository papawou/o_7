DROP TABLE IF EXISTS lobbys, lobby_users, lobby_cvs CASCADE;
/*
code_roles: is_owner is_moderator
code_auth: can_kick can_invite
*/
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

CREATE TABLE lobby_users(
  id_lobby integer REFERENCES lobbys NOT NULL,
  id_user integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_user, id_lobby),

  --/member
  fk_member integer REFERENCES users UNIQUE,
  CHECK(fk_member=id_user),

  id_cv integer REFERENCES lobby_cvs,
  FOREIGN KEY (id_lobby, id_cv) REFERENCES lobby_cvs(id_lobby, id),
  joined_at timestamptz,
  --\member
  --auth
  ban_resolved_at timestamptz,

  bit_roles integer NOT NULL DEFAULT 0,
  bit_auth integer NOT NULL DEFAULT 0, --Specific Permissions User
  cbit_auth integer NOT NULL DEFAULT 0, --SPU & roles_auth

  CHECK((fk_member IS NOT NULL AND ban_resolved_at < NOW() --IS MEMBER
             AND joined_at IS NOT NULL)
      OR(ban_resolved_at >= NOW() AND fk_member IS NULL --IS BANNED
             AND id_cv IS NULL
             AND joined_at IS NULL))
  --DELETE IF fk_member IS NULL AND ban_resolved_at < NOW() cronJOB ?
);
CREATE UNIQUE INDEX lobby_members ON lobby_users(id_lobby, fk_member);
ALTER TABLE lobbys ADD CONSTRAINT fk_lobby_owner FOREIGN KEY(id, id_owner) REFERENCES lobby_users(id_lobby, fk_member) DEFERRABLE;

CREATE OR REPLACE FUNCTION check_lobby_user() RETURNS trigger AS $$
    BEGIN
        IF(NEW.ban_resolved_at < NOW()) THEN
            NEW.ban_resolved_at = NULL;
        END IF;
        IF(NEW.ban_resolved_at IS NULL AND NEW.fk_member IS NULL) THEN
            DELETE FROM lobby_users WHERE id_user=NEW.id_user AND id_lobby=NEW.id_lobby;
            RETURN NULL;
        END IF;
        IF(NEW.fk_member IS NOT NULL AND NEW.ban_resolved_at > NOW()) THEN
            RAISE EXCEPTION 'lobby_user is banned';
        END IF;

        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_lobbys_users_is_banned BEFORE UPDATE OF fk_member, ban_resolved_at ON lobby_users
    FOR EACH ROW EXECUTE FUNCTION check_lobby_user();