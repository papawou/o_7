SELECT lobby_create(1,5,true, 'DEFAULT',1,0,0);

SELECT lobby_join(4, 1);
SELECT lobby_leave(4, 1);

SELECT lobby_user_joinrequest_deny(2,4);

SELECT lobby_manage_joinrequest_accept(1,3,1);
SELECT lobby_manage_joinrequest_deny(2,1,1);

SELECT lobby_invite_create(1,1,3);
SELECT lobby_invite_cancel(4,1,3);