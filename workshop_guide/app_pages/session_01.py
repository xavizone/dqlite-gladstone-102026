import streamlit as st

from components import (render_checkpoint, render_execution_context, render_explanation, render_fallback,
                        render_prompt, render_real_world_examples, render_references, render_session_header,
                        render_snowsight_route, render_technologies_used, render_what_why)
from content import links as L
from content import story

render_session_header("Session 1", "The complaint", "5 min", "Your mental model of Riverside's Nova pipeline")
render_execution_context()
story.chapter(1)
with st.container(border=True):
    st.markdown(""":material/support_agent: **Riverside Leisure, on the phone to Customer Success:**
*"Nova says we have more active members than our front desk can count, and today's revenue looks far too low."*""")
render_what_why(
    "Ask CoCo to map Riverside's pipeline end to end, then reproduce the two numbers the operator is asking about.",
    "Before you can guard a pipeline you need to know where a number comes from: which Bronze tables, which "
    "REPORTING Dynamic Table, which semantic-view metric. Every investigation starts here.",
)

render_prompt("Prompt 1.1", "Map the pipeline", """In {FQ_SCHEMA}, explain the data pipeline end to end:
- which tables are Bronze (MEMBERS__, SHARED__, SYSTEM__ prefixes) and what _SYNC_META__MERGE_BATCH records
- what task TSK_BIFROST_MERGE does and how often it runs
- what each REPORTING__ dynamic table computes, its target lag, refresh mode, and which Bronze tables feed it
- what semantic view SV_RIVERSIDE_KPIS exposes (metrics and verified queries)
Draw the lineage as a simple left-to-right diagram. Do not change anything.""")
render_snowsight_route([
    "**Catalog » Database Explorer** » `GLADSTONE_DQ_LITE` » `{SCHEMA}`.",
    "Open `REPORTING__DAILY_REVENUE` » **Lineage** tab to see its upstream Bronze table.",
    "**Transformation » Dynamic tables**: target lag, refresh mode and refresh history.",
    "**Transformation » Tasks** » `TSK_BIFROST_MERGE` » **Run history**.",
    "**AI & ML » Cortex Analyst** » `SV_RIVERSIDE_KPIS` to browse metrics and verified queries.",
], sql="""USE SCHEMA {FQ_SCHEMA};
SHOW DYNAMIC TABLES;   -- target_lag, refresh_mode, scheduling_state
SHOW TASKS;
DESCRIBE SEMANTIC VIEW SV_RIVERSIDE_KPIS;""")

render_prompt("Prompt 1.2", "Reproduce the operator's numbers", """Using semantic view {FQ_SCHEMA}.SV_RIVERSIDE_KPIS, answer the operator's two questions:
1. How many active members do we have?
2. What was net revenue for each of the last 3 days?
Show which metric or verified query you used. If "active members" can be calculated two ways in this semantic view, show both numbers side by side and explain the difference. Save these as my "clean" baseline.""")
render_snowsight_route([
    "**AI & ML » Cortex Analyst** » open `SV_RIVERSIDE_KPIS` » **Playground** and ask the same questions.",
    "Note which answer uses the verified query `vq_active_members`.",
], sql="""SELECT * FROM SEMANTIC_VIEW({FQ_SCHEMA}.SV_RIVERSIDE_KPIS
  METRICS am.active_members, ms.paid_members_35d);
SELECT * FROM SEMANTIC_VIEW({FQ_SCHEMA}.SV_RIVERSIDE_KPIS
  DIMENSIONS rev.payment_date METRICS rev.net_revenue)
WHERE payment_date >= CURRENT_DATE() - 2 ORDER BY payment_date;""")

render_checkpoint("On clean data you see **1,598 active members** by status and **1,520** paid in the last 35 days, "
                  "plus a net revenue figure per day. Note them: in Session 3 they move.")
story.turn(1)
render_explanation("Why two answers for active members?", """
`am.active_members` counts members whose **source status** is `ACTIVE`. The verified query (`vq_active_members`) uses the
**finance definition**: members who **paid in the last 35 days**. About 6% of ACTIVE members haven't paid for longer,
so the two differ even on clean data. When an operator says "Nova is wrong", first check **which definition** answered.
""")
render_fallback("""USE SCHEMA {FQ_SCHEMA};
SHOW DYNAMIC TABLES;
SHOW TASKS;
SELECT * FROM SEMANTIC_VIEW(SV_RIVERSIDE_KPIS METRICS am.active_members, ms.paid_members_35d);
SELECT * FROM SEMANTIC_VIEW(SV_RIVERSIDE_KPIS DIMENSIONS rev.payment_date METRICS rev.net_revenue)
WHERE payment_date >= CURRENT_DATE() - 2 ORDER BY payment_date;""")

render_technologies_used([
    {"name": "Dynamic Tables", "icon": "sync", "description": "REPORTING layer, incremental refresh, 1-minute target lag"},
    {"name": "Tasks", "icon": "schedule", "description": "TSK_BIFROST_MERGE simulates the Bifrost merge every minute"},
    {"name": "Semantic view", "icon": "schema", "description": "Gold layer Nova answers from, with a verified query"},
])

render_real_world_examples([
    {"title": "Customer Success first response", "body": "Before escalating to engineering, CS asks CoCo to map the operator's pipeline and which definition Nova used."},
    {"title": "Onboarding a data engineer", "body": "A new joiner gets a plain-English map of any operator database in minutes, from live metadata."},
])
render_references({
    "Quickstarts": [L.QS_SV, L.QS_DT],
    "Docs": [L.LINEAGE, L.DT_MONITOR, L.SV_CREATE],
})
