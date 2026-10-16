import streamlit as st

from components import render_real_world_examples, render_references
from content import links as L

st.title("Agenda")
st.markdown("30 minutes, one operator, one pipeline copy each. The facilitator injects faults live during Sessions 3 and 4.")

st.markdown("""
| Time | Section | You do (in CoCo) | Snowflake capability |
|---|---|---|---|
| 0-5 | **1. The complaint** | Map the pipeline; reproduce the operator's two numbers | Lineage, Dynamic Tables, Tasks, semantic view |
| 5-13 | **2. Put guards on it** | Expectations on Bronze and REPORTING; email + incident alert | Data metric functions, expectations, notifications, alerts |
| 13 | *Facilitator injects faults 1-3* | - | - |
| 13-22 | **3. Catch, explain, contain** | "What broke, why, and stop it reaching Nova" | DQ results, failing rows, task history, circuit breaker |
| 22-30 | **4. Operate it** | Health view, fault 4, fix and watch it recover | Views, incident log, `SYSTEM$SET_RETURN_VALUE` |
""")

with st.container(border=True):
    st.markdown("""
**Faster than the room?** Go to **Stretch**: put a Cortex Agent on top of your semantic view, schedule a daily digest,
or see why a volume drop needs anomaly detection.

**After the session:** three bonus labs, each with its own setup and teardown - **B1** budgets and resource monitors,
**B2** governance plus GDPR, **B3** DevOps with DCM Projects.
""")

st.markdown("#### :material/bug_report: The faults")
st.caption("Injected into everyone's pipeline at the same time, so the room sees the same thing.")
st.markdown("""
| # | When | What happened (in Nova terms) | What the operator sees | Caught by |
|---|---|---|---|---|
| 1 | Minute 13 | Bifrost applied the same merge batch twice | More active members than the front desk | `no_duplicate_members` |
| 2 | Minute 16 | Refunds arrived as negative payments | Today's revenue far too low | `no_negative_amounts` |
| 3 | Minute 18 | The sync task stopped | Nothing new since this morning | `payments_fresh_3min` |
| 4 | Minute 23 | Cancelled members re-sent as ACTIVE | Two different "active members" answers | `no_active_leavers` |
| 5 | Stretch | A day of bookings went missing | Utilisation drops | Anomaly detection on `ROW_COUNT` |
""")

render_real_world_examples([
    {"title": "A real triage rota", "body": "These are the failure modes of any CDC pipeline: duplicate, late, wrong sign, semantic drift, missing volume. Each one maps to one check."},
    {"title": "Operator-facing SLAs", "body": "Freshness and completeness expectations become the evidence behind \"Nova data is never more than N minutes old\"."},
])
render_references({
    "Quickstarts": [L.QS_DQ, L.QS_DT],
    "Docs": [L.DQ_EXPECT, L.ALERTS, L.TASKS],
})
