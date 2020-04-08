CREATE TABLE users(
  id bigserial PRIMARY KEY,
  name varchar NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

INSERT INTO users(name) VALUES('papawa'),('test'),('zboub');