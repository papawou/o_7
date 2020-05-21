DROP TABLE IF EXISTS users, user_user CASCADE;
DROP TYPE IF EXISTS status_user_user CASCADE;
CREATE TABLE users(
  id bigserial PRIMARY KEY,
  name varchar NOT NULL,
  password varchar NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TYPE status_user_user AS ENUM('FRIEND', 'FOLLOWER');
CREATE TABLE user_user(
  id_user integer REFERENCES users NOT NULL,
  id_target integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_user, id_target),
  status status_user_user NOT NULL
);