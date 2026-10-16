-- =============================================================================
-- Gladstone MRM | Bonus B3 - DevOps with DCM Projects | B3_setup.sql (ADMIN, run once)
-- Pre-creates one empty schema per operator, RIVERSIDE_<NAME>_DCM, owned by the shared DQ_LITE_ATTENDEE role.
-- The attendee's DCM project lives in it and deploys objects into it.
-- Attendees therefore never need CREATE SCHEMA on the lab database.
-- Attendee machine prerequisites: Snowflake CLI (snow) 3.17+ and git.
-- Teardown: B3_teardown.sql (standalone) or 99_teardown.sql (everything)
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DQ_LITE_WH;

USE ROLE DQ_LITE_ADMIN;
CREATE OR REPLACE PROCEDURE GLADSTONE_DQ_LITE.ADMIN.B3_SETUP_ALL()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
  n NUMBER DEFAULT 0;
  sch VARCHAR;
  rl VARCHAR;
  c1 CURSOR FOR SELECT short_name FROM GLADSTONE_DQ_LITE.ADMIN.ATTENDEES;
BEGIN
  FOR r IN c1 DO
    sch := 'GLADSTONE_DQ_LITE.RIVERSIDE_' || r.short_name || '_DCM';
    rl  := 'DQ_LITE_ATTENDEE';
    EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS ' || :sch || ' COMMENT = ''Bonus B3: operator pipeline managed by DCM''';
    EXECUTE IMMEDIATE 'GRANT OWNERSHIP ON SCHEMA ' || :sch || ' TO ROLE ' || :rl || ' COPY CURRENT GRANTS';
    n := n + 1;
  END FOR;
  RETURN n || ' DCM schema(s) ready';
END;
$$;

CREATE OR REPLACE PROCEDURE GLADSTONE_DQ_LITE.ADMIN.B3_TEARDOWN_ALL()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
  n NUMBER DEFAULT 0;
  c1 CURSOR FOR SELECT schema_name FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA
                WHERE schema_name LIKE 'RIVERSIDE\\_%\\_DCM' ESCAPE '\\';
BEGIN
  FOR r IN c1 DO
    -- Dropping the schema drops the DCM project object AND every object it deployed
    EXECUTE IMMEDIATE 'DROP SCHEMA IF EXISTS GLADSTONE_DQ_LITE.' || r.schema_name || ' CASCADE';
    n := n + 1;
  END FOR;
  RETURN 'Bonus B3 removed: ' || n || ' DCM schema(s) dropped';
END;
$$;

USE ROLE ACCOUNTADMIN;
CALL GLADSTONE_DQ_LITE.ADMIN.B3_SETUP_ALL();
-- Schema owners can create DCM projects in their own schema. If your account requires an explicit grant:
-- GRANT CREATE DCM PROJECT ON SCHEMA GLADSTONE_DQ_LITE.RIVERSIDE_<NAME>_DCM TO ROLE DQ_LITE_<NAME>;
SHOW SCHEMAS LIKE 'RIVERSIDE_%_DCM' IN DATABASE GLADSTONE_DQ_LITE;
