CREATE TABLE users(
  id bigserial PRIMARY KEY,
  username VARCHAR(80) NOT NULL,

  --optional
  created_at timestamptz NOT NULL DEFAULT NOW()
);