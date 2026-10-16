import streamlit as st

from components import (render_checkpoint, render_execution_context, render_explanation, render_fallback,
                        render_prompt, render_real_world_examples, render_references, render_session_header,
                        render_snowsight_route, render_technologies_used, render_what_you_built, render_what_why)
from content import links as L
from content import story

render_session_header("Session 4", "Operate it", "8 min", "One health view, a semantic fault, and a recovery")
render_execution_context()
story.chapter(4)
story.ticket("s4")
render_what_why(
    "Build `V_DQ_HEALTH`, the one view Customer Success opens first: every check, OK or FAILING, and its incident history. "
    "Then catch fault 4, fix the data the way the source team would, and watch the breaker close by itself.",
    "Monitoring only pays off if someone looks at it. One view per operator, in plain terms, is how Gladstone moves from "
    "*the operator told us* to *we told the operator*.",
)

render_prompt("Prompt 4.1", "One health view", """In {FQ_SCHEMA}, create a view V_DQ_HEALTH with one row per expectation in my schema (use only results measured since the schema was created): table, expectation, metric, latest value, status ('OK' or 'FAILING'), last checked time, first incident time and number of incidents from DQ_INCIDENTS. Failing checks first.
Then show it, and tell me in two sentences whether Riverside's Nova numbers can be trusted right now.""")
render_snowsight_route([
    "Create the view in a worksheet (see *Behind? Run this*).",
    "**Governance & security » Data quality** gives the same picture account-wide; your view is the operator-specific one CS can share.",
], sql="SELECT * FROM {FQ_SCHEMA}.V_DQ_HEALTH;")

render_prompt("Prompt 4.2", "Fix it and watch it recover", """Riverside's source team has fixed the feed. Clean up {FQ_SCHEMA} the way they would:
1. delete the replayed member rows (batch B-REPLAY-01) and the negative payments (batch B-SIGNBUG-01)
2. set members from batch B-STATUS-01 back to CANCELLED
3. resume TSK_BIFROST_MERGE
Then evaluate every expectation now, and show me V_DQ_HEALTH and the circuit breaker's last return values until it reports CLOSED. Compare the active members and net revenue with my clean baseline from Session 1.""")
render_snowsight_route([
    "Run the fix in a worksheet; **Transformation » Tasks** » resume `TSK_BIFROST_MERGE`.",
    "Watch `TSK_DQ_CIRCUIT_BREAKER` run history flip to **CLOSED** (after the next scheduled check, up to 5 minutes).",
])

render_checkpoint("`V_DQ_HEALTH` showed **4 FAILING** checks including `NO_ACTIVE_LEAVERS` (292). After the fix every check is **OK**, "
                  "the breaker returns **CLOSED: Bronze clean**, REPORTING is running again, and `DQ_INCIDENTS` keeps the history.")
story.turn(4)
story.epilogue()
render_explanation("Why does reporting_within_5min fail after the fix?", """
While the breaker was OPEN, REPORTING was frozen on purpose, so it fell behind Bronze (about 500 seconds in the dry run).
The first check after the breaker closes measures that gap and fails once; the next run passes. The breaker only watches
**Bronze** checks, so this REPORTING check can never hold it open - otherwise it would freeze itself forever.
""")
render_explanation("Why fault 4 is the hardest one", """
Every row in the status-drift batch is well-formed: no duplicates, no nulls, no negative amounts. Only a **business rule**
catches it - *a member with a leave date can't be ACTIVE* - which is why `ACTIVE_BUT_LEFT` is a **custom** DMF defined
once in `DQ_COMMON`. The symptom in Nova is the two "active members" numbers drifting apart.
""")
render_fallback("""USE SCHEMA {FQ_SCHEMA};
CREATE OR REPLACE VIEW V_DQ_HEALTH AS
WITH latest AS (
  SELECT table_name, metric_name, expectation_name, value, expectation_violated, measurement_time
  FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS
  WHERE table_database = 'GLADSTONE_DQ_LITE' AND table_schema = '{SCHEMA}'
      AND measurement_time >= (SELECT created FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = '{SCHEMA}')
  QUALIFY ROW_NUMBER() OVER (PARTITION BY table_name, expectation_name ORDER BY measurement_time DESC) = 1)
SELECT l.table_name, l.expectation_name, l.metric_name, l.value,
       IFF(l.expectation_violated, 'FAILING', 'OK') AS status, l.measurement_time AS last_checked,
       (SELECT MIN(i.opened_at) FROM {FQ_SCHEMA}.DQ_INCIDENTS i
         WHERE i.table_name = l.table_name AND i.expectation_name = l.expectation_name) AS first_incident_at,
       (SELECT COUNT(*) FROM {FQ_SCHEMA}.DQ_INCIDENTS i
         WHERE i.table_name = l.table_name AND i.expectation_name = l.expectation_name) AS incidents
FROM latest l ORDER BY l.expectation_violated DESC, l.table_name;
SELECT * FROM V_DQ_HEALTH;

-- the fix
DELETE FROM MEMBERS__MEMBER WHERE _batch_id = 'B-REPLAY-01';
DELETE FROM SYSTEM__PAYMENT WHERE _batch_id = 'B-SIGNBUG-01';
UPDATE MEMBERS__MEMBER SET status = 'CANCELLED' WHERE _batch_id = 'B-STATUS-01';
ALTER TASK TSK_BIFROST_MERGE RESUME;
SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(REF_ENTITY_NAME => '{FQ_SCHEMA}.MEMBERS__MEMBER'));
SELECT state, scheduled_time, return_value
FROM TABLE(GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'TSK_DQ_CIRCUIT_BREAKER', RESULT_LIMIT => 5))
ORDER BY scheduled_time DESC;""")

render_technologies_used([
    {"name": "Custom DMF", "icon": "function", "description": "ACTIVE_BUT_LEFT: a business rule defined once, attached anywhere"},
    {"name": "Health view", "icon": "monitor_heart", "description": "Latest expectation status joined to the incident log"},
    {"name": "Self-healing breaker", "icon": "autorenew", "description": "Closes and resumes REPORTING once every Bronze check passes"},
])
render_what_you_built([
    "Seven expectations and an anomaly monitor on Riverside's Bronze and REPORTING tables",
    "Email notifications on the two critical checks",
    "`DQ_INCIDENT_ALERT` writing every new failure to `DQ_INCIDENTS`",
    "`TSK_DQ_CIRCUIT_BREAKER` pausing REPORTING while Bronze is failing",
    "`V_DQ_HEALTH`, the first thing Customer Success opens",
])

render_real_world_examples([
    {"title": "Before the operator calls", "body": "CS checks `V_DQ_HEALTH` each morning (or gets it as a digest - see Stretch) and calls the operator first."},
    {"title": "Post-incident review", "body": "`DQ_INCIDENTS` plus the breaker's return values give a timeline: when it broke, when it was contained, when it recovered."},
    {"title": "Every operator", "body": "The same view over every operator database is the *Rolling out* page: one template, many databases."},
])
render_references({
    "Quickstarts": [L.QS_DQ, L.QS_DQM],
    "Docs": [L.DQ_CUSTOM, L.DQ_EXPECT, L.DQ_DASH, L.TASK_RETURN],
})
