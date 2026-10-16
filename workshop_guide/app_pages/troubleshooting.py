import streamlit as st

from components import render_real_world_examples, fill, render_references
from content import links as L

st.title("Troubleshooting")
st.markdown("Problems seen in the dry run and how to fix them.")

issues = [
    ("Expectations show no results yet",
     "Scheduled checks run every 5 minutes. Evaluate immediately:",
     "SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(REF_ENTITY_NAME => '{FQ_SCHEMA}.MEMBERS__MEMBER'));"),
    ("Anomaly detection says TRAINING_IN_PROGRESS",
     "Expected. It needs about two weeks of results before it flags anomalies. Expectations do the detecting in this lab.", None),
    ("'Object does not exist or not authorized'",
     "Check you are on the lab role and pointing at your own schema:",
     "SELECT CURRENT_ROLE(), CURRENT_SECONDARY_ROLES();  -- expect {ROLE}\nUSE SCHEMA {FQ_SCHEMA};"),
    ("Someone changed my schema",
     "Everyone shares one role, so anyone *can* change any lab schema. Prompts always name your schema in full - "
     "if a prompt was run against the wrong schema, ask the facilitator to reset yours.", None),
    ("Old failures show up after a reset",
     "The results view keeps rows by schema name, including from an earlier copy of your schema. The lab's queries only "
     "count results measured since your schema was created - add the same filter to any query you write:",
     "AND measurement_time >= (SELECT created FROM {DB}.INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = '{SCHEMA}')"),
    ("DQ_INCIDENTS stays empty",
     "The alert reads the scheduled results, so it fires within a minute after the next 5-minute check. "
     "`EVALUATE` results are not written there. Check the alert is started and has no errors:",
     "SHOW ALERTS IN SCHEMA {FQ_SCHEMA};\nSELECT name, state, sql_error_message, scheduled_time\n"
     "FROM TABLE({DB}.INFORMATION_SCHEMA.ALERT_HISTORY(SCHEDULED_TIME_RANGE_START => DATEADD(hour, -1, CURRENT_TIMESTAMP())))\n"
     "ORDER BY scheduled_time DESC LIMIT 10;"),
    ("Masked values when you expected real ones (B2)",
     "Masking follows the roles in your session. Run with the privacy role as a secondary role:",
     "USE SECONDARY ROLES DQ_LITE_PII_READER;"),
    ("Unexpected rows visible (or missing) after B2",
     "Secondary roles may still be on. Turn them off to test a single role:",
     "USE SECONDARY ROLES NONE;"),
    ("A check is 'already associated'",
     "The same DMF can be attached to the same column once. Modify it instead:",
     "ALTER TABLE {FQ_SCHEMA}.MEMBERS__MEMBER MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (member_id) ADD EXPECTATION ...;"),
    ("Circuit breaker never closes",
     "It must only watch Bronze checks. If it watches a REPORTING check, freezing REPORTING keeps it failing. Check its return value:",
     "SELECT state, return_value FROM TABLE({DB}.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'TSK_DQ_CIRCUIT_BREAKER', RESULT_LIMIT => 5));"),
    ("Dynamic table fell back to FULL refresh",
     "A non-deterministic function such as CURRENT_TIMESTAMP in the definition forces full refresh. Check:",
     "SHOW DYNAMIC TABLES IN SCHEMA {FQ_SCHEMA};  -- refresh_mode should be INCREMENTAL"),
    ("Everything is broken - start again",
     "Ask the facilitator to reset your pipeline (re-clones it in seconds). You'll redo Session 2.", None),
]
for title, body, sql in issues:
    with st.expander(f":material/help: {title}"):
        st.markdown(body)
        if sql:
            st.code(fill(sql), language="sql")

render_real_world_examples([
    {"title": "Rollout runbook", "body": "These fixes become the runbook when the checks are rolled out to every operator database."},
    {"title": "Least privilege in production", "body": "The lab shares one role for simplicity. In production each operator database gets its own read and admin roles."},
])
render_references({"Docs": [L.DQ_EXPECT, L.DQ_ANOMALY, L.TAG_MASK, L.DT_MONITOR, L.TASK_HISTORY]})
