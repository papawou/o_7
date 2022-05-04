INSERT INTO games(name) VALUES('rocket league'), ('squad'), ('gears of war');
INSERT INTO platforms(name) VALUES ('ps4'),
                                   ('pc'),
                                   ('xbox one');
INSERT INTO game_platform(id_game, id_platform, id_cross) VALUES (1,1,1),(1,2,1),(1,3,1),
                                                                  (2,1,null),(2,2,null),
                                                                  (3,1,null),(3,2,1),(3,3,1);
INSERT INTO users(name, password) VALUES('papawa', 'test'),('test','test'),('zboub','test'),('testo', 'test');


INSERT INTO follows
    (id_follower, id_following)
VALUES
    (1,2),
    (1,3),
    (1,4),
    (2,4),
    (2,1),
    (3,1),
    (4,1),
    (4,2);

INSERT INTO friends
    (id_usera, id_userb)
VALUES
    (1,2),
    (1,3),
    (1,4),
    (2,4);