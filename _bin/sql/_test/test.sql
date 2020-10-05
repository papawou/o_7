CREATE TABLE json_test(
    id serial,
    PRIMARY KEY(id),
    jsoned json
);

INSERT INTO json_test(jsoned) VALUES('[{"test": 4}, {"testo": "rsdsds"}]')

SELECT '[{"test": 4}, {"testo": "rsdsds"}]'::jsonb||'[{"aada":2
}]';

SELECT json_build_array(jsonb_build_object('action',  'WAITING_LOBBY', 'created_by', 1, 'created_at', NOW()))
