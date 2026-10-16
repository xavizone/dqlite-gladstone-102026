-- =============================================================================
-- Gladstone MRM | Data Quality HOL - LITE | 99_teardown.sql
-- Removes EVERYTHING the Lite lab created (core + bonus labs). Run as ACCOUNTADMIN. Safe to re-run.
-- Nobody's default role or warehouse was changed, so there is nothing to restore.
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DQ_LITE_WH;

-- 1. Bonus labs (each step is skipped if that bonus was not set up)
EXECUTE IMMEDIATE $$
BEGIN
  IF (EXISTS (SELECT 1 FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.PROCEDURES WHERE procedure_schema = 'ADMIN' AND procedure_name = 'B3_TEARDOWN_ALL')) THEN
    CALL GLADSTONE_DQ_LITE.ADMIN.B3_TEARDOWN_ALL();
  END IF;
  IF (EXISTS (SELECT 1 FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.PROCEDURES WHERE procedure_schema = 'ADMIN' AND procedure_name = 'B2_UNSET_ALL')) THEN
    CALL GLADSTONE_DQ_LITE.ADMIN.B2_UNSET_ALL();
  END IF;
  IF (EXISTS (SELECT 1 FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.PROCEDURES WHERE procedure_schema = 'ADMIN' AND procedure_name = 'B1_TEARDOWN')) THEN
    CALL GLADSTONE_DQ_LITE.ADMIN.B1_TEARDOWN();
  END IF;
  RETURN 'bonus cleanup done';
END;
$$;
DROP RESOURCE MONITOR IF EXISTS DQ_LITE_RM_DEMO;

-- 2. Stop compute (tasks, alerts, dynamic tables, notifications)
CALL GLADSTONE_DQ_LITE.ADMIN.SUSPEND_ALL();

-- 3. The lab database: template, every RIVERSIDE_* schema, DMFs, alerts, semantic views, agents, budgets
DROP DATABASE IF EXISTS GLADSTONE_DQ_LITE;

-- 4. Account objects
USE WAREHOUSE COMPUTE_WH;   -- any warehouse other than DQ_LITE_WH; edit if needed
DROP WAREHOUSE IF EXISTS DQ_LITE_WH;
DROP RESOURCE MONITOR IF EXISTS DQ_LITE_RM;
DROP NOTIFICATION INTEGRATION IF EXISTS DQ_LITE_EMAIL_INT;

-- 5. Roles named DQ_LITE_* (admin, attendee, bonus roles)
SHOW ROLES LIKE 'DQ_LITE_%';
EXECUTE IMMEDIATE $$
DECLARE
  n NUMBER DEFAULT 0;
  c1 CURSOR FOR SELECT "name" AS role_name FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-1)));
BEGIN
  FOR r IN c1 DO
    EXECUTE IMMEDIATE 'DROP ROLE IF EXISTS "' || r.role_name || '"';
    n := n + 1;
  END FOR;
  RETURN n || ' role(s) dropped';
END;
$$;

-- 6. Verify: every statement returns zero rows
SHOW DATABASES LIKE 'GLADSTONE_DQ_LITE';
SHOW WAREHOUSES LIKE 'DQ_LITE_%';
SHOW RESOURCE MONITORS LIKE 'DQ_LITE_%';
SHOW INTEGRATIONS LIKE 'DQ_LITE_%';
SHOW ROLES LIKE 'DQ_LITE_%';
-- Dropped data stays in Time Travel / Fail-safe for the retention period, then is purged (synthetic data).
