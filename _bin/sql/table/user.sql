DROP TABLE IF EXISTS users, friends, friend_requests, follows, user_bans CASCADE;
DROP TYPE IF EXISTS friend_request_status CASCADE;

CREATE TABLE users(
  id bigserial PRIMARY KEY,
  name varchar NOT NULL,
  password varchar NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

/*
--table user_user: a_following, b_following, both_following, friends, pending_request_friend, block
CREATE TYPE follow_status AS ENUM('A_FOLLOWING', 'B_FOLLOWING', 'BOTH_FOLLOWING')
CREATE TABLE user_user(
  id_usera integer REFERENCES users NOT NULL,
  id_userb integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_usera, id_userb),
  UNIQUE(id_userb, id_usera),
  friend_status  friend_status,
  follow_status follow_status
);
*/
CREATE TABLE follows(
  id_follower integer REFERENCES users NOT NULL,
  id_following integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_follower, id_following),
  UNIQUE(id_following, id_follower),
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE friends(
  id_usera integer REFERENCES users NOT NULL,
  id_userb integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_usera, id_userb),
  UNIQUE(id_userb, id_usera),
  CHECK(id_usera < id_userb),
  FOREIGN KEY(id_usera, id_userb) REFERENCES follows,
  FOREIGN KEY(id_userb, id_usera) REFERENCES follows,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TYPE friend_request_status AS ENUM('WAITING', 'DELAYED');
CREATE TABLE friend_requests(
  id_usera integer REFERENCES users NOT NULL,
  id_userb integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_usera, id_userb),
  UNIQUE(id_userb, id_usera),
  CHECK(id_usera < id_userb),
  created_by integer REFERENCES users NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE user_bans(
  id_usera integer REFERENCES users NOT NULL,
  id_userb integer REFERENCES users NOT NULL,
  PRIMARY KEY(id_usera, id_userb),
  UNIQUE(id_userb, id_usera),
  created_by integer REFERENCES users NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW()
);