/*
  GETTERS
*/
DROP FUNCTION IF EXISTS getlogteammembers CASCADE;
CREATE OR REPLACE FUNCTION getlogteammembers(in_id_team integer, in_id_user integer, filter_reason log_teammember_reason[]) RETURNS SETOF log_teammembers AS $$
BEGIN
  RETURN QUERY
    SELECT * FROM log_teammembers
      WHERE (in_id_team IS NULL OR log_teammembers.id_team=in_id_team)
        AND (in_id_user IS NULL OR log_teammembers.id_user=in_id_user)
        AND (cardinality(filter_reason)=0 OR log_teammembers.reason::text=ANY(filter_reason::text[]));
END;
$$ LANGUAGE plpgsql;