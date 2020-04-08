DROP TABLE IF EXISTS events, eventmembers, eventrequests CASCADE;
DROP TYPE IF EXISTS eventrequest_status CASCADE;

CREATE TABLE events(
 id bigserial PRIMARY KEY,
 id_game integer REFERENCES games NOT NULL,
 id_platform integer REFERENCES platforms NOT NULL,

 size integer NOT NULL,
 current_size integer NOT NULL DEFAULT 0,
 CHECK(size > 1 AND current_size <= size),

 need_request boolean NOT NULL,

 FOREIGN KEY(id_game, id_platform) REFERENCES gameplatform(id_game, id_platform),

 is_log boolean DEFAULT false NOT NULL,

 UNIQUE(is_log, id),
 UNIQUE(need_request, id)
);

CREATE TABLE eventmembers(
 id_event integer NOT NULL REFERENCES events DEFERRABLE INITIALLY IMMEDIATE,
 id_user integer NOT NULL REFERENCES users,
 is_log boolean NOT NULL DEFAULT false,

 PRIMARY KEY(id_event, id_user),
 FOREIGN KEY(id_event, is_log) REFERENCES events(id, is_log) ON UPDATE CASCADE DEFERRABLE INITIALLY IMMEDIATE
);

CREATE TYPE eventrequest_status AS ENUM('ACCEPTED','DENIED','PENDING','CANCELED');
CREATE TABLE eventrequests(
 id bigserial PRIMARY KEY,

 id_event integer REFERENCES events NOT NULL,
 id_user integer REFERENCES users NOT NULL,
 status eventrequest_status NOT NULL DEFAULT 'PENDING',

 UNIQUE(id_event, id_user),

 need_request boolean NOT NULL DEFAULT true,
 is_log boolean NOT NULL DEFAULT false,

 CHECK(is_log IS false AND need_request IS true),
 FOREIGN KEY(id_event, is_log) REFERENCES events(id, is_log) DEFERRABLE INITIALLY DEFERRED,
 FOREIGN KEY(id_event, need_request) REFERENCES events(id, need_request) DEFERRABLE INITIALLY DEFERRED
);