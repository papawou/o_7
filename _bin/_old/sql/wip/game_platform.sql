DROP TABLE IF EXISTS games, platforms, gameplatform CASCADE;

CREATE TABLE games(
  id bigserial PRIMARY KEY,
  name varchar NOT NULL
);

CREATE TABLE platforms (
  id bigserial PRIMARY KEY,
  name varchar NOT NULL
);

CREATE TABLE gameplatform(
  id_game integer REFERENCES games NOT NULL,
  id_platform integer REFERENCES platforms NOT NULL,
  --cross_id
  PRIMARY KEY(id_game, id_platform)
);

INSERT INTO games(name) VALUES ('overwatch'), ('squad'), ('rocket league');
INSERT INTO platforms(name) VALUES ('pc'), ('ps4'), ('xbox one');

INSERT INTO gameplatform
    (id_game, id_platform)
VALUES
    (1,1),(1,2),(1,3),
    (2,1),
    (3,1),(3,2),(3,3);