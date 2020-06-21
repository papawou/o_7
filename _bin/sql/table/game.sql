DROP TABLE IF EXISTS games, platforms, game_platforms CASCADE;

CREATE TABLE games(
    id serial PRIMARY KEY,
    name varchar(25)
);

CREATE TABLE platforms(
    id serial PRIMARY KEY,
    name varchar(50)
);

CREATE TABLE game_platforms(
    id_game integer REFERENCES games NOT NULL,
    id_platform integer REFERENCES platforms NOT NULL,
    id_cross integer DEFAULT NULL,
    PRIMARY KEY (id_game, id_platform),
    UNIQUE(id_game, id_platform, id_cross)
);
