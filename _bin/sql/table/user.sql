DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users(
  id bigserial PRIMARY KEY,
  name varchar NOT NULL,
  password varchar NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW()
);