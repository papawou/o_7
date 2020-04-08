--RESET
DROP TABLE IF EXISTS
    users,
    teams, teammembers, log_teammembers, teamrequests, log_teamrequests,
    games, platforms, gameplatform
CASCADE;
DROP TYPE IF EXISTS log_teamrequest_status, log_teammember_reason
CASCADE;
-- USERS
CREATE TABLE users (
    id bigserial PRIMARY KEY,

    name varchar(80) NOT NULL,
    password varchar(80) NOT NULL,

    data_user text,
    
    created_at timestamptz NOT NULL DEFAULT NOW()
);

-- GAMES
CREATE TABLE games (
    id bigserial PRIMARY KEY,
    name varchar(80)
);

CREATE TABLE platforms (
    id bigserial PRIMARY KEY,
    name varchar(80)
);

CREATE TABLE gameplatform (
    id_game integer references games NOT NULL,
    id_platform integer references platforms NOT NULL,

    PRIMARY KEY(id_game, id_platform)
);

-- TEAMS
CREATE TABLE teams (
    id bigserial PRIMARY KEY,
    id_user integer references users NOT NULL,

    name varchar(80) NOT NULL,
    data_team text,

    created_at timestamptz NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX ON teams((lower(name)));
--TEAM MEMBERS
CREATE TABLE teammembers (
    id_team integer references teams NOT NULL,
    id_user integer references users NOT NULL,

    data_member text,

    joined_at timestamptz NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id_team, id_user)
);
    --log
CREATE TYPE log_teammember_reason AS ENUM ('LEAVED', 'KICKED');
CREATE TABLE log_teammembers (
    id_team integer references teams NOT NULL,
    id_user integer references users NOT NULL,

    data_member text,

    reason log_teammember_reason NOT NULL DEFAULT 'LEAVED',

    joined_at timestamptz NOT NULL,
    leaved_at timestamptz NOT NULL DEFAULT NOW(),
    PRIMARY KEY(id_team, id_user, joined_at)
);
--TEAMS REQUESTS
CREATE TABLE teamrequests (
    id_team integer references teams NOT NULL,
    id_user integer references users NOT NULL,

    data_request text,

    created_at timestamptz NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id_team, id_user)
);
    --log
CREATE TYPE log_teamrequest_status AS ENUM ('CANCELED', 'ACCEPTED', 'DENIED');
CREATE TABLE log_teamrequests (
    id_team integer references teams NOT NULL,
    id_user integer references users NOT NULL,

    data_request text,

    status log_teamrequest_status NOT NULL DEFAULT 'CANCELED',

    created_at timestamptz NOT NULL,
    resolved_at timestamptz NOT NULL DEFAULT NOW(),
    PRIMARY KEY(id_team, id_user, created_at)
);