import streamlit as st

from components import (render_checkpoint, render_execution_context, render_explanation, render_fallback,
                        render_prompt, render_real_world_examples, render_references, render_session_header,
                        render_snowsight_route, render_technologies_used, render_what_why)
from content import links as L

render_session_header("Session 3", "Catch, explain, contain", "9 min", "A root cause from one prompt, and a circuit breaker")
render_execution_context()
st.warning("The facilitator is injecting **faults 1-3** into every pipeline (minutes 13, 16 and 18). Checks run every 5 minutes; "
           "your incident alert picks failures up within a minute after that. You can also ask CoCo to evaluate now.",
           title="Riverside's pipeline is about to break")
render_what_why(
    "Watch your guards fire, then ask CoCo what broke and why - the way Customer Success would. Then add a **circuit breaker** "
    "that pauses the REPORTING refresh while any Bronze check is failing, so no further bad batches reach Nova.",
    "Catching is half the job. Explaining it (which batch, which rows) and **containing** it (no more bad batches reach Nova) "
    "is what lets Customer Success tell the operator *\"we know, it's fixed\"* before they ring.",
)

render_prompt("Prompt 3.1", "What broke, and why?", """My operator Riverside says Nova shows too many active members and revenue looks too low. Investigate {FQ_SCHEMA}:
1. What's in DQ_INCIDENTS, and which expectations are failing right now? Evaluate now if results are older than 5 minutes.
2. For each failing check, show sample failing rows and the merge batch (_batch_id / _SYNC_META__MERGE_BATCH) that introduced them.
3. Is the pipeline running? Check TSK_BIFROST_MERGE state and run history.
4. Which Nova numbers in SV_RIVERSIDE_KPIS are affected, and by roughly how much compared to my clean baseline?
Give me a one-paragraph root cause I could send to the operator.""")
render_snowsight_route([
    "**Governance & security » Data quality**: open incidents across the account. Select a failing check » **Investigate** opens CoCo with the incident loaded.",
    "Open the failing table » **Data Quality** tab » select the check to see its value history.",
    "**Transformation » Tasks** » `TSK_BIFROST_MERGE` » **Run history** (suspended? no runs?).",
], sql="""SELECT * FROM {FQ_SCHEMA}.DQ_INCIDENTS ORDER BY opened_at;
SELECT table_name, metric_name, expectation_name, value, measurement_time
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS
WHERE table_database = 'GLADSTONE_DQ_LITE' AND table_schema = '{SCHEMA}'
      AND measurement_time >= (SELECT created FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = '{SCHEMA}') AND expectation_violated
QUALIFY ROW_NUMBER() OVER (PARTITION BY table_name, expectation_name ORDER BY measurement_time DESC) = 1;""")

render_prompt("Prompt 3.2", "Contain it: circuit breaker", """In {FQ_SCHEMA}, create a task TSK_DQ_CIRCUIT_BREAKER on warehouse DQ_LITE_WH that runs every minute:
- count the expectations on MEMBERS__MEMBER, SYSTEM__PAYMENT and SYSTEM__ATTENDANCE whose LATEST result in SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS (measured since my schema was created) is violated
- if any: suspend dynamic tables REPORTING__ACTIVE_MEMBERS and REPORTING__DAILY_REVENUE, and set the task return value to 'OPEN: <n> failing Bronze check(s)'
- otherwise resume them and return 'CLOSED: Bronze clean'
Build the return message in a variable first, then pass that variable to SYSTEM$SET_RETURN_VALUE. Resume the task, then show its last runs and the dynamic tables' scheduling state.""")
render_snowsight_route([
    "Create the task in a worksheet (see *Behind? Run this*), then **Transformation » Tasks** » `TSK_DQ_CIRCUIT_BREAKER` » **Run history** shows each return value.",
    "**Transformation » Dynamic tables**: the two REPORTING tables show **Suspended** while the breaker is OPEN.",
], sql="""SELECT state, scheduled_time, return_value
FROM TABLE(GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'TSK_DQ_CIRCUIT_BREAKER', RESULT_LIMIT => 5))
ORDER BY scheduled_time DESC;
SHOW DYNAMIC TABLES IN SCHEMA {FQ_SCHEMA};""")

render_checkpoint("`DQ_INCIDENTS` has rows for **duplicates (150)**, **negative amounts (40)** and **freshness (over 180 s)**. "
                  "The breaker returns **OPEN** and both REPORTING tables are **SUSPENDED**: nothing new reaches Nova until Bronze is clean.")
render_explanation("What each fault looks like", """
| If CoCo finds... | It's the... | Notice |
|---|---|---|
| `DUPLICATE_COUNT(member_id)` = 150, batch `B-REPLAY-01` applied twice | Bifrost replay | Active members inflated by 150 |
| `NEGATIVE_COUNT(amount)` = 40, batch `B-SIGNBUG-01` | Refund sign flip | Today's net revenue drops by £10,000 |
| `FRESHNESS` over 180 s, task SUSPENDED | Merge task stalled | REPORTING lag stays **0**: REPORTING isn't behind its source - the **source** stopped. That's why you need both checks. |
""")
render_explanation("Nova already shows the bad revenue - why?", """
In the lab, REPORTING refreshes every **minute** but the checks run every **5 minutes**, so the first bad batch reaches
REPORTING before any check fails. The breaker then stops it getting worse, but it can't undo that first refresh.

To stop a bad batch **before** it publishes, run the Bronze checks on change and make REPORTING wait for them:
- `DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES'` on the Bronze tables Bifrost writes to, and
- REPORTING with `TARGET_LAG = DOWNSTREAM` (or a lag longer than the check), refreshed by the breaker task only when
  every Bronze check passes (`ALTER DYNAMIC TABLE ... REFRESH`).
""")
render_explanation("Why pause REPORTING instead of deleting the bad rows?", """
Containment and repair are different jobs. The breaker is automatic and safe: it stops further bad batches reaching Nova **now**,
without guessing which rows to delete. The repair (Session 4) is a deliberate fix by the source team, and the breaker
closes by itself on its next run once every Bronze check passes.
""")
render_fallback("""USE SCHEMA {FQ_SCHEMA};
SELECT * FROM DQ_INCIDENTS ORDER BY opened_at;
SELECT * FROM TABLE(SYSTEM$DATA_METRIC_SCAN(
  REF_ENTITY_NAME => '{FQ_SCHEMA}.MEMBERS__MEMBER',
  METRIC_NAME => 'SNOWFLAKE.CORE.DUPLICATE_COUNT', ARGUMENT_NAME => 'member_id')) LIMIT 20;
SELECT batch_id, table_name, COUNT(*) AS times_applied FROM _SYNC_META__MERGE_BATCH GROUP BY 1, 2 HAVING COUNT(*) > 1;
SELECT _batch_id, COUNT(*), SUM(amount) FROM SYSTEM__PAYMENT WHERE amount < 0 GROUP BY 1;
SHOW TASKS LIKE 'TSK_BIFROST_MERGE';

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
    WHERE table_database = 'GLADSTONE_DQ_LITE' AND table_schema = '{SCHEMA}'
      AND measurement_time >= (SELECT created FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = '{SCHEMA}')
      AND table_name IN ('MEMBERS__MEMBER', 'SYSTEM__PAYMENT', 'SYSTEM__ATTENDANCE')
    QUALIFY ROW_NUMBER() OVER (PARTITION BY table_name, expectation_name ORDER BY measurement_time DESC) = 1)
  WHERE expectation_violated;
  IF (bad > 0) THEN
    ALTER DYNAMIC TABLE {FQ_SCHEMA}.REPORTING__ACTIVE_MEMBERS SUSPEND;
    ALTER DYNAMIC TABLE {FQ_SCHEMA}.REPORTING__DAILY_REVENUE SUSPEND;
    msg := 'OPEN: ' || :bad || ' failing Bronze check(s) - REPORTING refresh paused';
    CALL SYSTEM$SET_RETURN_VALUE(:msg);
  ELSE
    ALTER DYNAMIC TABLE {FQ_SCHEMA}.REPORTING__ACTIVE_MEMBERS RESUME;
    ALTER DYNAMIC TABLE {FQ_SCHEMA}.REPORTING__DAILY_REVENUE RESUME;
    CALL SYSTEM$SET_RETURN_VALUE('CLOSED: Bronze clean');
  END IF;
END;
$$;
ALTER TASK TSK_DQ_CIRCUIT_BREAKER RESUME;""")

render_technologies_used([
    {"name": "DQ results + incident log", "icon": "table_view", "description": "SNOWFLAKE.LOCAL expectation status and your DQ_INCIDENTS table"},
    {"name": "SYSTEM$DATA_METRIC_SCAN", "icon": "search", "description": "Returns the rows that made a system DMF fail"},
    {"name": "Tasks + Dynamic Tables", "icon": "power_settings_new", "description": "A task suspends and resumes REPORTING; SYSTEM$SET_RETURN_VALUE records why"},
])

render_real_world_examples([
    {"title": "CS escalation in five minutes", "body": "The one-paragraph root cause from Prompt 3.1 is what goes back to the operator - with the batch id and the fix."},
    {"title": "Stop bad data at Silver", "body": "The breaker pattern keeps the Nova Portal on yesterday's correct numbers rather than today's wrong ones."},
    {"title": "Bifrost incident review", "body": "Batch-level evidence (`_SYNC_META`) shows whether a replay hit one operator or many."},
])
render_references({
    "Quickstarts": [L.QS_DQ, L.QS_COCO_DE],
    "Docs": [L.DQ_DASH, L.DQ_SCAN, L.TASK_HISTORY, L.TASK_RETURN, L.DT_MONITOR],
})
