# Gladstone MRM | Data quality hands-on lab (Lite)

A simpler version of the Gladstone data quality lab: **one operator, one complaint, one shared role**.

Riverside Leisure (fictional) tells Customer Success that Nova shows too many active members and too little revenue.
In 30 minutes each attendee puts guards on their own copy of Riverside's pipeline, logs incidents with an alert,
contains bad data with a circuit breaker, and builds the health view CS checks first - using CoCo prompts
(with a Snowsight route for every step).

## What's in this folder

| Path | What |
|---|---|
| `sql/00_setup.sql` | Admin setup, run once as ACCOUNTADMIN: warehouse, monitor, email integration, 2 roles, database, Riverside seed data, procedures |
| `sql/10_inject.sql` | Facilitator: inject faults 1-4 (and 5 for stretch) into every attendee pipeline |
| `sql/answer_key.sql` | What CoCo should build in Sessions 2-4 |
| `sql/99_teardown.sql` | Removes everything, including bonus labs |
| `sql/bonus/` | B1 budgets, B2 governance + GDPR, B3 DCM Projects (setup, answer key, teardown each) |
| `workshop_guide/` | Streamlit guide (`streamlit run Workshop_Guide_Start.py`) |
| `ATTENDEE_PREP.md`, `ADMIN_PREFLIGHT_QUESTIONNAIRE.md`, `FACILITATOR_RUNSHEET.md`, `ATTENDEE_ROSTER.csv` | Hand-outs |
| `LEAVE_BEHIND.md` | One-page summary for after the session |

## Differences from the full lab

| | Full lab | Lite |
|---|---|---|
| Story | Each attendee is a different operator; fleet view across operators | One operator (Riverside) and its complaint |
| Roles | One role per attendee, optional default-role changes, spares | One shared role `DQ_LITE_ATTENDEE`, no user changes |
| Setup | 3 scripts + spares | 1 script + `SETUP_ALL` |
| Faults | 6, one per attendee | 4, the same for everyone, injected live |
| New | - | Incident-logging alert (`DQ_INCIDENTS`), `V_DQ_HEALTH`, self-closing breaker |

## Quick start (admin)

1. Edit `LAB_ADMIN_EMAIL` in `sql/00_setup.sql`, run it as ACCOUNTADMIN.
2. `CALL GLADSTONE_DQ_LITE.ADMIN.SETUP_ALL(PARSE_JSON('[{"name":"NIELS","user":"NJOHANSEN"}]'));`
3. During the lab, follow `FACILITATOR_RUNSHEET.md`.
4. Afterwards, run `sql/99_teardown.sql`.

All data is synthetic. Tested end to end on a Snowflake account in October 2026; confirm feature availability in
Azure UK South with the pre-flight checks (section 8 of `00_setup.sql`).
