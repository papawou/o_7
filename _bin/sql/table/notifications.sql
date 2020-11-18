/*
lobby_request
*invitation
--target
	NEW_INVITE
		lobby_invite_create
		lobby_manage_joinrequest_accept
--creator
	INVITE_REQUEST_DENIED
		lobby_manage_joinrequest_deny
	INVITE_REQUEST_ALLOWED
		lobby_manage_joinrequest_accept

*request
--target
	REQUEST_DENIED
	REQUEST_ACCEPTED

--lobby
	NEW_REQUEST
	NEW_INVITE
*/

--CREATE TYPE type_source AS ENUM ('LOBBY_REQUEST');
DROP TABLE IF EXISTS lobby_notifications CASCADE;
DROP TYPE IF EXISTS action_notification CASCADE;

CREATE TYPE action_notification AS ENUM ('NEW_INVITE');
CREATE TABLE lobby_notifications(
  id_consumer integer REFERENCES users NOT NULL,
  seen boolean NOT NULL DEFAULT FALSE,
  
  /*
  to lobby_invitation or lobby_users ?
  */
  --source_type action_notification,
  source_id integer NOT NULL, --as node id --LobbyUser__id_lobby-_id_viewer
  id_lobby integer NOT NULL,
  
  action action_notification NOT NULL,
  
  id_actor integer NOT NULL REFERENCES users, --[]
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

/*
CREATE TABLE lobby_notifications(
  ulid uuid,

	--logs stored in source
	action text,
	source_type integer,
	source_id integer,

	updated_at timestamptz,
	created_at timestamptz
);

CREATE TABLE lobby_notification_consumers(
  id_consumer integer REFERENCES users NOT NULL,
  id_notification integer REFERENCES lobby_notifications NOT NULL,
  PRIMARY KEY(id_consumer, id_notification),

	seen boolean NOT NULL DEFAULT FALSE,
  created_at timestamptz
);
*/