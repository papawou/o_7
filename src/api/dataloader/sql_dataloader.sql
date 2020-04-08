-- [Node, null]
SELECT row_to_json(game_platforms.*) as data
    FROM unnest(ARRAY[5,2]::integer[], ARRAY[3,2]::integer[]) WITH ORDINALITY key_id(id_game, id_platform)
    LEFT JOIN game_platforms ON game_platforms.id_game=key_id.id_game AND game_platforms.id_platform=key_id.id_platform
ORDER BY ordinality;

-- [[Node], []]
SELECT COALESCE(json_agg(game_platforms) FILTER (WHERE game_platforms.id_game IS NOT NULL), '[]') as data
    FROM unnest(ARRAY[1,5]::integer[]) WITH ORDINALITY key_id
    LEFT JOIN game_platforms ON game_platforms.id_game=key_id
GROUP BY ordinality, game_platforms.id_game ORDER BY ordinality;

-- [[id], []]
SELECT array_remove(array_agg(game_platforms.id_platform), null) as data
    FROM unnest(ARRAY[1,5]::integer[]) WITH ORDINALITY key_id
    LEFT JOIN game_platforms ON game_platforms.id_game=key_id
GROUP BY ordinality, game_platforms.id_game ORDER BY ordinality;