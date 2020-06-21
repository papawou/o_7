DROP EXTENSION pgcrypto;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DROP FUNCTION gen_custom_ulid() CASCADE;

CREATE OR REPLACE FUNCTION gen_custom_ulid() RETURNS uuid AS $$
DECLARE
    unix bit(43);
    random_bytes bytea = gen_random_bytes(11);
    ulid bytea = '\x00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00';
BEGIN
    unix := (EXTRACT(EPOCH FROM NOW())*1000)::bigint::bit(43);

    ulid := SET_BYTE(ulid, 0, (unix)::bit(8)::integer);
    ulid := SET_BYTE(ulid, 1, (unix << 8)::bit(8)::integer);
    ulid := SET_BYTE(ulid, 2, (unix << 16)::bit(8)::integer);
    ulid := SET_BYTE(ulid, 3, (unix << 24)::bit(8)::integer);
    ulid := SET_BYTE(ulid, 4, (unix << 32)::bit(8)::integer);
    ulid := SET_BYTE(ulid, 5, ((unix << 40)::bit(3)||GET_BYTE(random_bytes,0)::bit(5))::bit(8)::integer);
    ulid := SET_BYTE(ulid, 6, GET_BYTE(random_bytes, 1));
    ulid := SET_BYTE(ulid, 7, GET_BYTE(random_bytes, 2));
    ulid := SET_BYTE(ulid, 8, GET_BYTE(random_bytes, 3));
    ulid := SET_BYTE(ulid, 9, GET_BYTE(random_bytes, 4));
    ulid := SET_BYTE(ulid, 10, GET_BYTE(random_bytes, 5));
    ulid := SET_BYTE(ulid, 11, GET_BYTE(random_bytes, 6));
    ulid := SET_BYTE(ulid, 12, GET_BYTE(random_bytes, 7));
    ulid := SET_BYTE(ulid, 13, GET_BYTE(random_bytes, 8));
    ulid := SET_BYTE(ulid, 14, GET_BYTE(random_bytes, 9));
    ulid := SET_BYTE(ulid, 15, GET_BYTE(random_bytes, 10));

    RETURN encode(ulid,'hex');
END $$ LANGUAGE plpgsql VOLATILE PARALLEL SAFE;