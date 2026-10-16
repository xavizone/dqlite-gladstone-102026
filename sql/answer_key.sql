-- =============================================================================
-- Gladstone MRM | Data Quality HOL - LITE | answer_key.sql
-- What CoCo is expected to generate in Sessions 2-4 (also the "Behind? run this" fallback).
-- Replace RIVERSIDE_NIELS with your schema. Run as role DQ_LITE_ATTENDEE.
-- =============================================================================
USE ROLE DQ_LITE_ATTENDEE;
USE WAREHOUSE DQ_LITE_WH;
USE SCHEMA GLADSTONE_DQ_LITE.RIVERSIDE_NIELS;

-- ---------------------------------------------------------------------------
-- Session 2.1  Guards: expectations = rules that must always hold
--              (5 MINUTE for the lab; production: TRIGGER_ON_CHANGES on Bronze tables Bifrost writes to)
-- ---------------------------------------------------------------------------
ALTER TABLE MEMBERS__MEMBER    SET DATA_METRIC_SCHEDULE = '5 MINUTE';
ALTER TABLE SYSTEM__PAYMENT    SET DATA_METRIC_SCHEDULE = '5 MINUTE';
ALTER TABLE SYSTEM__ATTENDANCE SET DATA_METRIC_SCHEDULE = '5 MINUTE';
ALTER TABLE SYSTEM__BOOKING    SET DATA_METRIC_SCHEDULE = '5 MINUTE';
ALTER DYNAMIC TABLE REPORTING__DAILY_REVENUE SET DATA_METRIC_SCHEDULE = '5 MINUTE';

ALTER TABLE MEMBERS__MEMBER ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (member_id)
  EXPECTATION no_duplicate_members (VALUE = 0);
ALTER TABLE MEMBERS__MEMBER ADD DATA METRIC FUNCTION GLADSTONE_DQ_LITE.DQ_COMMON.ACTIVE_BUT_LEFT ON (status, left_on)
  EXPECTATION no_active_leavers (VALUE = 0);
ALTER TABLE SYSTEM__PAYMENT ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (amount)
  EXPECTATION no_negative_amounts (VALUE = 0);
ALTER TABLE SYSTEM__PAYMENT ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON ()
  EXPECTATION payments_fresh_3min (VALUE < 180);
ALTER TABLE SYSTEM__ATTENDANCE ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.REFERENTIAL_INTEGRITY_COUNT
  ON (booking_id, TABLE(GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.SYSTEM__BOOKING(booking_id)))
  EXPECTATION no_orphan_checkins (VALUE = 0);
ALTER DYNAMIC TABLE REPORTING__DAILY_REVENUE ADD DATA METRIC FUNCTION GLADSTONE_DQ_LITE.DQ_COMMON.REPORTING_LAG_SECONDS
  ON (last_loaded_at, TABLE(GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.SYSTEM__PAYMENT(_loaded_at)))
  EXPECTATION reporting_within_5min (VALUE < 300);

-- Unknown unknowns: volume with anomaly detection (learns a baseline; ~2 weeks of history before it flags)
ALTER TABLE SYSTEM__BOOKING ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON () ANOMALY_DETECTION = TRUE;

-- Run every single-table expectation now instead of waiting for the schedule
SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(REF_ENTITY_NAME => 'GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.MEMBERS__MEMBER'));
SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(REF_ENTITY_NAME => 'GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.SYSTEM__PAYMENT'));

-- ---------------------------------------------------------------------------
-- Session 2.2  Tell someone: an email for the critical checks + an incident log for everything
-- ---------------------------------------------------------------------------
ALTER TABLE MEMBERS__MEMBER MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (member_id)
  SET DATA_QUALITY_NOTIFICATION = TRUE;
ALTER TABLE SYSTEM__PAYMENT MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (amount)
  SET DATA_QUALITY_NOTIFICATION = TRUE;

-- Alert: every minute, log each failing measurement as an incident row (one row per check per failed run)
CREATE OR REPLACE ALERT DQ_INCIDENT_ALERT
  WAREHOUSE = DQ_LITE_WH
  SCHEDULE = '1 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS s
    WHERE s.table_database = 'GLADSTONE_DQ_LITE' AND s.table_schema = 'RIVERSIDE_NIELS'
      AND s.measurement_time >= (SELECT created FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = 'RIVERSIDE_NIELS') AND s.expectation_violated
      AND s.measurement_time > DATEADD(minute, -30, CURRENT_TIMESTAMP())
      AND NOT EXISTS (SELECT 1 FROM GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.DQ_INCIDENTS i
                      WHERE i.table_name = s.table_name AND i.expectation_name = s.expectation_name
                        AND i.measured_at >= s.measurement_time)))
  THEN
    INSERT INTO GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.DQ_INCIDENTS (table_name, metric_name, expectation_name, value, measured_at)
    SELECT s.table_name, s.metric_name, s.expectation_name, s.value::VARCHAR, s.measurement_time
    FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS s
    WHERE s.table_database = 'GLADSTONE_DQ_LITE' AND s.table_schema = 'RIVERSIDE_NIELS'
      AND s.measurement_time >= (SELECT created FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = 'RIVERSIDE_NIELS') AND s.expectation_violated
      AND s.measurement_time > DATEADD(minute, -30, CURRENT_TIMESTAMP())
      AND NOT EXISTS (SELECT 1 FROM GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.DQ_INCIDENTS i
                      WHERE i.table_name = s.table_name AND i.expectation_name = s.expectation_name
                        AND i.measured_at >= s.measurement_time)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY s.table_name, s.expectation_name ORDER BY s.measurement_time DESC) = 1;
ALTER ALERT DQ_INCIDENT_ALERT RESUME;

-- ---------------------------------------------------------------------------
-- Session 3  Catch, explain, contain
-- ---------------------------------------------------------------------------
-- What is failing right now?
SELECT table_name, metric_name, expectation_name, value, measurement_time
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS
WHERE table_database = 'GLADSTONE_DQ_LITE' AND table_schema = 'RIVERSIDE_NIELS'
      AND measurement_time >= (SELECT created FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = 'RIVERSIDE_NIELS') AND expectation_violated
QUALIFY ROW_NUMBER() OVER (PARTITION BY table_name, expectation_name ORDER BY measurement_time DESC) = 1;

-- Which rows? Which batch?
SELECT * FROM TABLE(SYSTEM$DATA_METRIC_SCAN(
  REF_ENTITY_NAME => 'GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.MEMBERS__MEMBER',
  METRIC_NAME => 'SNOWFLAKE.CORE.DUPLICATE_COUNT', ARGUMENT_NAME => 'member_id')) LIMIT 20;
SELECT batch_id, table_name, COUNT(*) AS times_applied FROM _SYNC_META__MERGE_BATCH GROUP BY 1, 2 HAVING COUNT(*) > 1;
SELECT _batch_id, COUNT(*), SUM(amount) FROM SYSTEM__PAYMENT WHERE amount < 0 GROUP BY 1;

-- Is the pipeline running?
SELECT name, state, scheduled_time, completed_time FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'TSK_BIFROST_MERGE', RESULT_LIMIT => 10))
ORDER BY scheduled_time DESC;
SHOW TASKS LIKE 'TSK_BIFROST_MERGE';

-- Contain: circuit breaker freezes REPORTING while any Bronze rule is broken, resumes when clean
CREATE OR REPLACE TASK TSK_DQ_CIRCUIT_BREAKER
  WAREHOUSE = DQ_LITE_WH SCHEDULE = '1 MINUTE'
AS
EXECUTE IMMEDIATE $$
DECLARE
  bad NUMBER;
  msg VARCHAR;
BEGIN
  SELECT COUNT(*) INTO :bad FROM (
    SELECT expectation_violated FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS
    WHERE table_database = 'GLADSTONE_DQ_LITE' AND table_schema = 'RIVERSIDE_NIELS'
      AND measurement_time >= (SELECT created FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = 'RIVERSIDE_NIELS')
      AND table_name IN ('MEMBERS__MEMBER', 'SYSTEM__PAYMENT', 'SYSTEM__ATTENDANCE')
    QUALIFY ROW_NUMBER() OVER (PARTITION BY table_name, expectation_name ORDER BY measurement_time DESC) = 1)
  WHERE expectation_violated;
  IF (bad > 0) THEN
    ALTER DYNAMIC TABLE GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.REPORTING__ACTIVE_MEMBERS SUSPEND;
    ALTER DYNAMIC TABLE GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.REPORTING__DAILY_REVENUE SUSPEND;
    -- SYSTEM$SET_RETURN_VALUE needs a plain variable or literal, not an expression
    msg := 'OPEN: ' || :bad || ' failing Bronze check(s) - REPORTING refresh paused';
    CALL SYSTEM$SET_RETURN_VALUE(:msg);
  ELSE
    ALTER DYNAMIC TABLE GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.REPORTING__ACTIVE_MEMBERS RESUME;
    ALTER DYNAMIC TABLE GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.REPORTING__DAILY_REVENUE RESUME;
    CALL SYSTEM$SET_RETURN_VALUE('CLOSED: Bronze clean');
  END IF;
END;
$$;
ALTER TASK TSK_DQ_CIRCUIT_BREAKER RESUME;

-- ---------------------------------------------------------------------------
-- Session 4  Operate it: one health view Customer Success checks before the operator calls
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW V_DQ_HEALTH AS
WITH latest AS (
  SELECT table_name, metric_name, expectation_name, value, expectation_violated, measurement_time
  FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS
  WHERE table_database = 'GLADSTONE_DQ_LITE' AND table_schema = 'RIVERSIDE_NIELS'
      AND measurement_time >= (SELECT created FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = 'RIVERSIDE_NIELS')
  QUALIFY ROW_NUMBER() OVER (PARTITION BY table_name, expectation_name ORDER BY measurement_time DESC) = 1)
SELECT l.table_name, l.expectation_name, l.metric_name, l.value,
       IFF(l.expectation_violated, 'FAILING', 'OK') AS status, l.measurement_time AS last_checked,
       (SELECT MIN(i.opened_at) FROM GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.DQ_INCIDENTS i
         WHERE i.table_name = l.table_name AND i.expectation_name = l.expectation_name) AS first_incident_at,
       (SELECT COUNT(*) FROM GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.DQ_INCIDENTS i
         WHERE i.table_name = l.table_name AND i.expectation_name = l.expectation_name) AS incidents
FROM latest l ORDER BY l.expectation_violated DESC, l.table_name;

SELECT * FROM V_DQ_HEALTH;
SELECT * FROM DQ_INCIDENTS ORDER BY opened_at;

-- Fix the data (what the source team would do), then watch the breaker close on its next run
DELETE FROM MEMBERS__MEMBER WHERE _batch_id = 'B-REPLAY-01';
DELETE FROM SYSTEM__PAYMENT WHERE _batch_id = 'B-SIGNBUG-01';
ALTER TASK TSK_BIFROST_MERGE RESUME;
UPDATE MEMBERS__MEMBER SET status = 'CANCELLED' WHERE _batch_id = 'B-STATUS-01';
SELECT name, state, scheduled_time, return_value
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'TSK_DQ_CIRCUIT_BREAKER', RESULT_LIMIT => 5)) ORDER BY scheduled_time DESC;
