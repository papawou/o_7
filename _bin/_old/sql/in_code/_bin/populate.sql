--INSERT INTO
INSERT INTO users
    (name, password)
VALUES
    ('papawa', 'aknesjopa'),
    ('test', 'test'),
    ('prout', 'prout');

INSERT INTO games
    (name)
VALUES
    ('overwatch'), ('squad'), ('undefined');

INSERT INTO platforms
    (name)
VALUES
    ('ps4'), ('ps3'), ('xbox one'), ('pc'), ('xbox 360');

INSERT INTO gameplatform
    (id_game, id_platform)
VALUES
    (1,1), (1,3), (1,4),
    (2,4);