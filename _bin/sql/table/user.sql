DROP TABLE IF EXISTS users, friendships, user_friends_request, follows, user_bans CASCADE;
DROP TYPE IF EXISTS user_friends_request_status CASCADE;
CREATE TABLE users(
  id bigserial PRIMARY KEY,
  name varchar NOT NULL,
  password varchar NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE friendships(
  id_userA integer REFERENCES users NOT NULL,
  id_userB integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_userA, id_userB),
  UNIQUE(id_userB, id_userA),
  check(id_userA < id_userB),
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE follows(
  id_follower integer REFERENCES users NOT NULL,
  id_following integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_follower, id_following),
  UNIQUE(id_following, id_follower),
  followed_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TYPE user_friends_request_status AS ENUM('WAITING_A', 'WAITING_B', 'DENIED_BY_A', 'DENIED_BY_B');
CREATE TABLE user_friends_request(
  id_userA integer REFERENCES users NOT NULL,
  id_userB integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_userA, id_userB),
  UNIQUE(id_userB, id_userA),
  CHECK(id_userA < id_userB),
  status user_friends_request_status NOT NULL
);

CREATE TABLE user_bans(
    id_userA integer REFERENCES users NOT NULL,
    id_userB integer REFERENCES users NOT NULL,
    PRIMARY KEY(id_userA, id_userB),
    UNIQUE(id_userB, id_userA),
    ban_resolved_at timestamptz NOT NULL,
    CHECK(ban_resolved_at > NOW())
);