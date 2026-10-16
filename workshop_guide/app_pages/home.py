from pathlib import Path

import streamlit as st

from components import render_real_world_examples, render_references
from content import links as L

_STATIC = Path(__file__).parent.parent / "static"

with st.container(horizontal=True, vertical_alignment="center", gap="large"):
    st.image(str(_STATIC / "gladstone_logo.jpg"), width=110, alt="Gladstone logo")
    st.image(str(_STATIC / "snowflake_full_logo.png"), width=180, alt="Snowflake logo")

st.title("Catch it before the operator does")
st.markdown("One operator's complaint, and how to use Snowflake data quality to catch problems **before** they reach Nova - "
            "using only prompts in **CoCo**.")
st.space("small")

c1, c2, c3, c4 = st.columns(4)
c1.metric("Core lab", "30 min", help="Sessions 1-4")
c2.metric("Prompts", "8 core", help="Plus stretch and bonus prompts")
c3.metric("Faults", "4", help="Injected live, the same for everyone")
c4.metric("Bonus labs", "3", help="Budgets, governance + GDPR, DCM DevOps")

st.space("medium")
st.markdown("#### :material/support_agent: The complaint")
with st.container(border=True):
    st.markdown("""
**Riverside Leisure** (a fictional operator with three sites in Oxfordshire) rings Customer Success:

> *"Nova says we have more active members than our front desk can count, and today's revenue looks far too low."*

The answer came from Nova's semantic view, reading REPORTING Dynamic Tables, built from Bronze tables that
Bifrost merges in from Riverside's Azure SQL. Something upstream broke.

Today Gladstone finds out **when the operator rings**. This lab turns that around: the checks fire first,
an incident is logged, the REPORTING refresh is paused, and Customer Success already knows the cause.
""")

st.markdown("#### :material/route: What, how and why")
w, h, y = st.columns(3)
with w.container(border=True, height="stretch"):
    st.markdown("##### :material/flag: What")
    st.markdown("""
Everyone works on **their own copy of Riverside's pipeline**. In 30 minutes you:
1. reproduce the complaint,
2. put guards (checks with pass/fail rules) on the pipeline, with alerts and an incident log,
3. watch live faults get caught, explained and contained,
4. build the one health view Customer Success checks first.
""")
with h.container(border=True, height="stretch"):
    st.markdown("##### :material/terminal: How")
    st.markdown("""
- **Prompts only**, in **CoCo Desktop or CoCo CLI**. CoCo shows the SQL before running it.
- Every step also shows **how to do it in Snowsight**.
- Synthetic data in **your own schema** `RIVERSIDE_<NAME>`. Everyone uses one role, `DQ_LITE_ATTENDEE`.
""")
with y.container(border=True, height="stretch"):
    st.markdown("##### :material/lightbulb: Why this approach")
    st.markdown("""
- It mirrors **Nova's real layers**: Bronze MEMBERS / SHARED / SYSTEM, REPORTING Dynamic Tables, and a semantic view.
- Native **data metric functions** are serverless - a replacement path for homegrown `DATA_MONITORING_WH` checks.
- What you build for one operator is a template: the *Rolling out* page shows how it reaches every operator database.
""")

st.markdown("#### :material/account_tree: Riverside's pipeline")
st.graphviz_chart("""
digraph {
  rankdir=LR; node [shape=box, style="rounded,filled", fillcolor="#F0F4F8", color="#29B5E8", fontname="Helvetica"];
  src [label="Riverside Azure SQL\\n(source)"];
  task [label="TSK_BIFROST_MERGE\\n(simulated Bifrost, 1 min)"];
  bronze [label="Bronze\\nMEMBERS__* / SHARED__* / SYSTEM__*"];
  dt [label="Silver REPORTING\\nDynamic Tables"];
  sv [label="Gold\\nSV_RIVERSIDE_KPIS"];
  nova [label="Nova answer"];
  dq [label="Guards: data metric functions\\n+ expectations", fillcolor="#E3F5FC"];
  inc [label="Alert -> DQ_INCIDENTS\\n+ email", fillcolor="#E3F5FC"];
  cb [label="Circuit breaker\\n(freeze REPORTING)", fillcolor="#E3F5FC"];
  src -> task -> bronze -> dt -> sv -> nova;
  dq -> bronze [style=dashed, arrowhead=none]; dq -> dt [style=dashed, arrowhead=none];
  dq -> inc [style=dashed]; dq -> cb [style=dashed]; cb -> dt [style=dashed, label="suspend"];
}
""", alt="Diagram of Riverside's pipeline: source, merge task, Bronze, REPORTING dynamic tables, semantic view, Nova; guards on Bronze and REPORTING feed an incident alert and a circuit breaker that freezes REPORTING")

st.markdown("#### :material/checklist: From reactive to proactive")
st.markdown("""
| Today | After this lab | Session |
|---|---|---|
| The operator notices wrong numbers | A check fails within minutes of the bad batch | 2-3 |
| CS opens a ticket and waits for engineering | An incident row and an email already say which check, table and batch | 2-3 |
| Wrong numbers keep flowing into Nova | A circuit breaker pauses REPORTING until Bronze is clean | 3 |
| Root cause found by hand | CoCo follows the evidence and writes the explanation | 3 |
| No single view of pipeline health | `V_DQ_HEALTH`: every check, OK/FAILING, incidents | 4 |
""")

render_real_world_examples([
    {"title": "Before a Nova answer reaches an operator", "body": "Guards on the Bronze tables Bifrost writes to, so a bad sync is caught at Bronze - and, with checks run on change, held back before the Nova Portal refreshes."},
    {"title": "Customer Success escalations", "body": "\"Nova gave me the wrong number\" is answered from the incident log and a five-minute CoCo root cause, often before the call."},
    {"title": "Onboarding a new operator", "body": "The same checks attach to the new operator database on day one, so the first Bifrost sync is already guarded."},
    {"title": "GCP-to-Azure migration", "body": "The same checks prove the migrated operator data matches before cut-over."},
])
render_references({
    "Quickstarts": [L.QS_DQ, L.QS_COCO_DESKTOP, L.QS_COCO_CLI],
    "Docs": [L.DQ_INTRO, L.DT_OVERVIEW, L.SV_OVERVIEW, L.COCO],
})
