/*CREATE TABLE lobby_users(
  id_lobby integer,
  id_user integer,
  PRIMARY KEY(id_lobby, id_user),
  tableoid integer
);

CREATE TABLE lobby_members(
  id_lobby integer,
  id_user integer,
  PRIMARY KEY(id_lobby, id_user, tableoid),
  FOREIGN KEY(id_lobby, id_user, tableoid) REFERENCES lobby_users(id_lobby, id_user, tableoid)
);
*/

CREATE TABLE testouil(
  id_lobby integer GENERATED ALWAYS AS (1) STORED PRIMARY KEY
);