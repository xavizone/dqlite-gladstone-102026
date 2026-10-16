import streamlit as st

from components import (doc_file, render_doc_download, render_real_world_examples,
                        render_references, render_sql_file)
from content import links as L

st.title("Lab setup (admin)")
st.markdown("For the Gladstone Snowflake admin. **One script, one call.** Everything lives in one database, one warehouse "
            "and two roles. Nobody's default role or warehouse is changed.")

st.markdown("#### :material/route: What, how and why")
w, h, y = st.columns(3)
with w.container(border=True, height="stretch"):
    st.markdown("##### What gets created")
    st.markdown("""
- Warehouse `DQ_LITE_WH` (XS, 1-3 clusters, auto-suspend 60s) + monitor `DQ_LITE_RM` (20 credits)
- Email integration `DQ_LITE_EMAIL_INT`
- Roles `DQ_LITE_ADMIN` and **one shared** `DQ_LITE_ATTENDEE`
- Database `GLADSTONE_DQ_LITE`: `ADMIN`, `DQ_COMMON`, `TEMPLATE`, and one `RIVERSIDE_<NAME>` per attendee
""")
with h.container(border=True, height="stretch"):
    st.markdown("##### How")
    st.markdown("""
1. `00_setup.sql` sections 1-8 - account objects, roles, Riverside seed data, procedures (~2 min)
2. `CALL SETUP_ALL(...)` - one zero-copy clone per attendee (~20 s each)
3. During the lab: `INJECT('ALL', n)` for faults 1-4
4. Afterwards: `99_teardown.sql`
""")
with y.container(border=True, height="stretch"):
    st.markdown("##### Why this design")
    st.markdown("""
- **One role for everyone**: one grant per user, nothing to restore later.
- **One schema per attendee**: each person attaches their own checks without clashing (a DMF can be attached to a column only once).
- **Zero-copy clones**: seconds to create, no storage until changed.
- One warehouse with a cap keeps cost bounded; DMFs are serverless.
""")

before, setup, walkins, during = st.tabs([
    ":material/event: Before the day", ":material/play_circle: Setup",
    ":material/person_add: Walk-ins", ":material/sports: During the session",
])

with before:
    st.markdown("#### Timeline")
    st.markdown(doc_file("FACILITATOR_RUNSHEET.md").split("\n", 1)[-1].split("\n## ")[0])
    c1, c2, c3 = st.columns(3)
    with c1:
        render_doc_download("ADMIN_PREFLIGHT_QUESTIONNAIRE.md", "Admin questionnaire")
    with c2:
        render_doc_download("ATTENDEE_ROSTER.csv", "Roster template (CSV)", mime="text/csv")
    with c3:
        render_doc_download("ATTENDEE_PREP.md", "Attendee prep sheet")
    st.markdown("#### Questionnaire")
    with st.container(border=True):
        st.markdown(doc_file("ADMIN_PREFLIGHT_QUESTIONNAIRE.md").split("\n", 1)[-1])

with setup:
    st.markdown("#### :material/checklist: Prerequisites")
    st.markdown("""
| Requirement | Why |
|---|---|
| **ACCOUNTADMIN** for setup and teardown | Creates roles, warehouse, monitor, integration; grants the lab role to users |
| **Enterprise Edition or higher** | Data metric functions, masking and row access |
| Attendee Snowflake **users** exist, with CoCo access | `SETUP_ALL` grants them `DQ_LITE_ATTENDEE` |
| Your **verified email** | Email integration for DQ notifications |
| A warehouse other than `DQ_LITE_WH` (e.g. `COMPUTE_WH`) | Used by teardown before dropping the lab warehouse |
| Bonus B3 only: attendees have Snowflake CLI 3.17+ | `snow dcm` commands |
""")
    st.markdown("##### 1. Run the setup script")
    st.caption("Edit `LAB_ADMIN_EMAIL` at the top first. Safe to re-run.")
    render_sql_file("00_setup.sql")
    st.markdown("##### 2. Create one pipeline per attendee")
    st.code("""USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DQ_LITE_WH;
CALL GLADSTONE_DQ_LITE.ADMIN.SETUP_ALL(PARSE_JSON('[
  {"name": "NIELS", "user": "NJOHANSEN"},
  {"name": "AMY",   "user": "ASMITH"}
]'));""", language="sql")
    st.markdown("""
- `name` = short name (letters, digits, underscore) - it names the schema `RIVERSIDE_<NAME>`. Tell each attendee theirs.
- `user` = Snowflake user name (optional). It only grants `DQ_LITE_ATTENDEE`. A user that can't be found is reported under **Check:**; the schema is still built - fix the name and `GRANT ROLE DQ_LITE_ATTENDEE TO USER <u>;`.
""")
    st.markdown("##### 3. Smoke test")
    st.code("""USE ROLE DQ_LITE_ATTENDEE; USE WAREHOUSE DQ_LITE_WH;
SHOW DYNAMIC TABLES IN SCHEMA GLADSTONE_DQ_LITE.RIVERSIDE_NIELS;   -- 3, refresh_mode INCREMENTAL
SELECT COUNT(*) FROM GLADSTONE_DQ_LITE.RIVERSIDE_NIELS._SYNC_META__MERGE_BATCH
 WHERE batch_id <> 'B-SEED';                                       -- grows every minute
SELECT * FROM SEMANTIC_VIEW(GLADSTONE_DQ_LITE.RIVERSIDE_NIELS.SV_RIVERSIDE_KPIS
  METRICS am.active_members, ms.paid_members_35d);                 -- 1598 and 1520
SELECT * FROM GLADSTONE_DQ_LITE.ADMIN.V_ROOM_STATUS;""", language="sql")

    st.markdown("#### :material/extension: Bonus labs")
    st.markdown("Each bonus has its own setup and teardown. Run setup only for the bonuses you offer - see each bonus page. "
                "B2 grants its two test roles to the users in `ADMIN.ATTENDEES`, so run it after `SETUP_ALL`.")

with walkins:
    st.markdown("""
| Situation | Action | Time |
|---|---|---|
| Has a Snowflake user | `CALL GLADSTONE_DQ_LITE.ADMIN.ADD_ATTENDEE('JOE', 'JBLOGGS');` | ~20 s |
| No Snowflake user | Pair with a neighbour | - |
| Arrives after faults were injected | `INJECT('JOE', n)` for each fault so far, after they finish Session 2 | ~1 s each |
| Broke their copy | `CALL GLADSTONE_DQ_LITE.ADMIN.RESET_ATTENDEE('NIELS');` - fresh copy, redo Session 2 | ~20 s |
""")
    st.info("The attendee types their name into the sidebar box. Every prompt in the guide then points at their schema.",
            icon=":material/info:")

with during:
    st.markdown("""
| When | Run | Effect |
|---|---|---|
| Minute 13 | `CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 1);` | Bifrost replay: 150 duplicate members |
| Minute 16 | `CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 2);` | 40 negative payments: today's revenue collapses |
| Minute 18 | `CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 3);` | Merge task suspended: freshness breaches after ~3 min |
| Minute 23 | `CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 4);` | Cancelled members re-sent as ACTIVE |
| Stretch | `CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 5);` | A day of bookings deleted (only anomaly detection would catch it) |
| Anytime | `SELECT * FROM GLADSTONE_DQ_LITE.ADMIN.V_ROOM_STATUS;` | Per attendee: checks attached, failing now |
| End | `CALL GLADSTONE_DQ_LITE.ADMIN.SUSPEND_ALL();` | Stops tasks, alerts and DTs; notifications off |
""")
    render_sql_file("10_inject.sql", ":material/bug_report: 10_inject.sql")
    render_sql_file("answer_key.sql", ":material/key: Answer key (Sessions 2-4)")

    st.markdown("#### :material/savings: Cost")
    st.markdown("""
- `DQ_LITE_WH` stays warm while merge tasks, alerts and 1-minute Dynamic Tables run. Run `SUSPEND_ALL()` when the session ends.
- DMFs run on serverless compute (not covered by the resource monitor); a 5-minute schedule on a few small tables per attendee is small. Check with `DATA_QUALITY_MONITORING_USAGE_HISTORY`.
""")

render_real_world_examples([
    {"title": "Repeatable training environment", "body": "The same script stands up a sandbox for new data engineers or for operator-facing demos."},
    {"title": "Template for operator onboarding", "body": "`ADD_ATTENDEE` is a small model of onboarding: clone, own, register - the checks then attach by prompt, by script or by DCM (Bonus B3)."},
])
render_references({
    "Docs": [L.DQ_SQL, L.DQ_NOTIFY, L.ALERTS, L.RES_MON, L.DT_OVERVIEW, L.TASKS, L.COCO],
})
