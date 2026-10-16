import streamlit as st

from components import (render_checkpoint, render_execution_context, render_explanation, render_fallback,
                        render_key_concepts, render_prompt, render_real_world_examples, render_references,
                        render_session_header, render_snowsight_route, render_technologies_used, render_what_why)
from content import links as L

render_session_header("Session 2", "Put guards on it", "8 min", "Checks with pass/fail rules, an email, and an incident log")
render_execution_context()
render_what_why(
    "Turn each thing that must always be true about Riverside's data into an **expectation** on a data metric function (DMF). "
    "Then make failures **tell someone**: an email for the critical checks, and an alert that writes every failure to `DQ_INCIDENTS`.",
    "This is the shift from reactive to proactive. The checks run serverless, next to the data, every few minutes. "
    "A bad Bifrost batch becomes an incident row and an email **before** the operator opens Nova.",
)

render_prompt("Prompt 2.1", "Guard the pipeline", """Set up data quality monitoring in {FQ_SCHEMA}. Run every check every 5 minutes.
On MEMBERS__MEMBER:
- no duplicate member_id (expect 0)
- no ACTIVE members with a leave date: use GLADSTONE_DQ_LITE.DQ_COMMON.ACTIVE_BUT_LEFT on (status, left_on) (expect 0)
On SYSTEM__PAYMENT:
- no negative amounts (expect 0)
- table updated in the last 3 minutes (FRESHNESS on the table itself, expect under 180 seconds)
On SYSTEM__ATTENDANCE:
- every booking_id exists in SYSTEM__BOOKING (referential integrity, expect 0 orphans)
On dynamic table REPORTING__DAILY_REVENUE:
- trails SYSTEM__PAYMENT by under 5 minutes: GLADSTONE_DQ_LITE.DQ_COMMON.REPORTING_LAG_SECONDS on (last_loaded_at) with SYSTEM__PAYMENT(_loaded_at) (expect under 300)
On SYSTEM__BOOKING:
- row count with anomaly detection turned on
Give each expectation a clear name. Show me the SQL before running it, then evaluate the single-table expectations now and show check, value and pass/fail.""")
render_snowsight_route([
    "Open **Catalog » Database Explorer** » `{SCHEMA}` » `MEMBERS__MEMBER` » **Data Quality** tab.",
    "Select **Monitor** » set the schedule to every 5 minutes.",
    "Add **Duplicate count** on `member_id` with the expectation *Value = 0*; add **Custom DMF** `DQ_COMMON.ACTIVE_BUT_LEFT` on `status, left_on`.",
    "Repeat on `SYSTEM__PAYMENT` (Negative count, Freshness), `SYSTEM__ATTENDANCE` (Referential integrity), `REPORTING__DAILY_REVENUE` (custom `REPORTING_LAG_SECONDS`) and `SYSTEM__BOOKING` (Row count with anomaly detection).",
], sql="""SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(REF_ENTITY_NAME => '{FQ_SCHEMA}.MEMBERS__MEMBER'));
SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(REF_ENTITY_NAME => '{FQ_SCHEMA}.SYSTEM__PAYMENT'));""")

render_prompt("Prompt 2.2", "Tell someone: email + incident log", """In {FQ_SCHEMA}:
1. Turn on data quality email notifications for the duplicate-member and negative-amount checks only (the database already has an email integration configured).
2. Create an alert DQ_INCIDENT_ALERT on warehouse DQ_LITE_WH that runs every minute. When any expectation in my schema is failing in SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS (measured in the last 30 minutes, and not before my schema was created - results of an earlier copy with the same name stay in that view) and has no row yet in DQ_INCIDENTS for that table, expectation and measurement, insert one row into DQ_INCIDENTS (table_name, metric_name, expectation_name, value, measured_at) - only the latest failing measurement per check.
3. Resume the alert and show me it is started.""")
render_snowsight_route([
    "Open `MEMBERS__MEMBER` » **Data Quality** » the duplicate check » **Notifications** » on. Repeat for negative amounts on `SYSTEM__PAYMENT`.",
    "Create the alert in a worksheet (below), then **Monitoring » Alerts** shows its state and history.",
], sql="""CREATE OR REPLACE ALERT {FQ_SCHEMA}.DQ_INCIDENT_ALERT
  WAREHOUSE = DQ_LITE_WH SCHEDULE = '1 MINUTE'
  IF (EXISTS (SELECT 1 FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS s
              WHERE s.table_database = 'GLADSTONE_DQ_LITE' AND s.table_schema = '{SCHEMA}'
      AND s.measurement_time >= (SELECT created FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = '{SCHEMA}') AND s.expectation_violated
                AND s.measurement_time > DATEADD(minute, -30, CURRENT_TIMESTAMP())
                AND NOT EXISTS (SELECT 1 FROM {FQ_SCHEMA}.DQ_INCIDENTS i
                                WHERE i.table_name = s.table_name AND i.expectation_name = s.expectation_name
                                  AND i.measured_at >= s.measurement_time)))
  THEN INSERT INTO {FQ_SCHEMA}.DQ_INCIDENTS (table_name, metric_name, expectation_name, value, measured_at)
       SELECT ... ;   -- same filter, latest row per check (see "Behind? Run this")
ALTER ALERT {FQ_SCHEMA}.DQ_INCIDENT_ALERT RESUME;""")

render_checkpoint("All expectations **pass** on clean data, two checks notify by email, and `DQ_INCIDENT_ALERT` is **started** "
                  "with `DQ_INCIDENTS` still empty. Tell the facilitator you're ready - faults go in next.",
                  "SHOW ALERTS IN SCHEMA {FQ_SCHEMA};\nSELECT COUNT(*) FROM {FQ_SCHEMA}.DQ_INCIDENTS;  -- 0")
render_explanation("Email, alert, or both?", """
**Data quality notifications** are built in: one setting per database, switched on per check. Good for the few checks
that should wake someone up. They have a cooldown, so you aren't flooded.

**An alert writing to `DQ_INCIDENTS`** gives you a record of every failure: when it opened, which check, what value.
That table is what Customer Success, a dashboard or a ticketing integration reads. Use both.

**Expectations vs anomaly detection:** expectations encode rules that must **always** hold and fail on the first bad run.
Anomaly detection (on `ROW_COUNT` / `FRESHNESS`) learns normal behaviour and needs about **two weeks** of history -
during the lab it shows `TRAINING_IN_PROGRESS`. Turn it on now so it's working in two weeks.
""")
render_fallback("""USE SCHEMA {FQ_SCHEMA};
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
  ON (booking_id, TABLE({FQ_SCHEMA}.SYSTEM__BOOKING(booking_id)))
  EXPECTATION no_orphan_checkins (VALUE = 0);
ALTER DYNAMIC TABLE REPORTING__DAILY_REVENUE ADD DATA METRIC FUNCTION GLADSTONE_DQ_LITE.DQ_COMMON.REPORTING_LAG_SECONDS
  ON (last_loaded_at, TABLE({FQ_SCHEMA}.SYSTEM__PAYMENT(_loaded_at)))
  EXPECTATION reporting_within_5min (VALUE < 300);
ALTER TABLE SYSTEM__BOOKING ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON () ANOMALY_DETECTION = TRUE;

ALTER TABLE MEMBERS__MEMBER MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (member_id)
  SET DATA_QUALITY_NOTIFICATION = TRUE;
ALTER TABLE SYSTEM__PAYMENT MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (amount)
  SET DATA_QUALITY_NOTIFICATION = TRUE;

CREATE OR REPLACE ALERT DQ_INCIDENT_ALERT
  WAREHOUSE = DQ_LITE_WH SCHEDULE = '1 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS s
    WHERE s.table_database = 'GLADSTONE_DQ_LITE' AND s.table_schema = '{SCHEMA}'
      AND s.measurement_time >= (SELECT created FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = '{SCHEMA}') AND s.expectation_violated
      AND s.measurement_time > DATEADD(minute, -30, CURRENT_TIMESTAMP())
      AND NOT EXISTS (SELECT 1 FROM {FQ_SCHEMA}.DQ_INCIDENTS i
                      WHERE i.table_name = s.table_name AND i.expectation_name = s.expectation_name
                        AND i.measured_at >= s.measurement_time)))
  THEN
    INSERT INTO {FQ_SCHEMA}.DQ_INCIDENTS (table_name, metric_name, expectation_name, value, measured_at)
    SELECT s.table_name, s.metric_name, s.expectation_name, s.value::VARCHAR, s.measurement_time
    FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS s
    WHERE s.table_database = 'GLADSTONE_DQ_LITE' AND s.table_schema = '{SCHEMA}'
      AND s.measurement_time >= (SELECT created FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = '{SCHEMA}') AND s.expectation_violated
      AND s.measurement_time > DATEADD(minute, -30, CURRENT_TIMESTAMP())
      AND NOT EXISTS (SELECT 1 FROM {FQ_SCHEMA}.DQ_INCIDENTS i
                      WHERE i.table_name = s.table_name AND i.expectation_name = s.expectation_name
                        AND i.measured_at >= s.measurement_time)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY s.table_name, s.expectation_name ORDER BY s.measurement_time DESC) = 1;
ALTER ALERT DQ_INCIDENT_ALERT RESUME;""")

render_technologies_used([
    {"name": "System and custom DMFs", "icon": "fact_check", "description": "DUPLICATE_COUNT, NEGATIVE_COUNT, FRESHNESS, REFERENTIAL_INTEGRITY_COUNT, ROW_COUNT + DQ_COMMON checks"},
    {"name": "Expectations + notifications", "icon": "notifications_active", "description": "Pass/fail rules; email on the critical ones"},
    {"name": "Alerts", "icon": "campaign", "description": "CREATE ALERT writes every new failure to DQ_INCIDENTS"},
])
render_key_concepts([
    {"term": "Data metric function (DMF)", "definition": "A function attached to a table or dynamic table that returns one number on a schedule. Runs on serverless compute."},
    {"term": "Expectation", "definition": "A rule on a DMF's value, e.g. `VALUE = 0`. Violations are recorded in `SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS`."},
    {"term": "Alert", "definition": "A scheduled condition (a query) and an action (SQL). Here: 'is any check newly failing?' then 'insert an incident row'."},
])

render_real_world_examples([
    {"title": "Replacing homegrown DATA_MONITORING_WH checks", "body": "Warehouse-scheduled checks become serverless DMFs with history, pass/fail and notifications built in."},
    {"title": "Bifrost sync SLAs", "body": "FRESHNESS and Bronze-to-REPORTING lag give CS and engineering one shared definition of \"late\"."},
    {"title": "Incidents into ServiceNow / Jira", "body": "`DQ_INCIDENTS` is the hand-off point: a webhook notification or a connector turns each row into a ticket."},
    {"title": "Payments integrity", "body": "NEGATIVE_COUNT catches sign bugs before revenue dashboards move."},
])
render_references({
    "Quickstarts": [L.QS_DQ, L.QS_DQM],
    "Docs": [L.DQ_SQL, L.DQ_EXPECT, L.DQ_CUSTOM, L.DQ_NOTIFY, L.ALERTS, L.DQ_ANOMALY],
})
