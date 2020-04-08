INSERT INTO games(name) VALUES('rocket league'), ('squad'), ('gears of war');
INSERT INTO platforms(name) VALUES ('ps4'),
                                   ('pc'),
                                   ('xbox one');
INSERT INTO game_platforms(id_game, id_platform, id_cross) VALUES (1,1,1),(1,2,1),(1,3,1),
                                                                  (2,1,null),(2,2,null),
                                                                  (3,1,null),(3,2,1),(3,3,1);
INSERT INTO users(name, password) VALUES('papawa', 'aknesjopa'),('test','test'),('zboub','test');