# Gladstone MRM | Data quality lab (Lite) | Facilitator run sheet

| When | Who | What |
|---|---|---|
| T-5 | Facilitator | Send the questionnaire email (`ADMIN_PREFLIGHT_QUESTIONNAIRE.md`) and the attendee prep sheet (`ATTENDEE_PREP.md`) |
| T-3 | Admin | Run `sql/00_setup.sql` sections 1-8 as ACCOUNTADMIN (edit `LAB_ADMIN_EMAIL` first) |
| T-3 | Admin | `CALL GLADSTONE_DQ_LITE.ADMIN.SETUP_ALL(PARSE_JSON('[{"name":"NIELS","user":"NJOHANSEN"}, ...]'));` - fix any "Check:" lines |
| T-1 | Facilitator + 1-2 attendees | 15-minute dry run: Getting started + Session 2 on one schema, then `RESET_ATTENDEE` |
| T-0, -15 min | Facilitator | `SELECT * FROM GLADSTONE_DQ_LITE.ADMIN.V_ROOM_STATUS;` - every attendee listed |
| Minute 13 | Facilitator | `CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 1);` (Bifrost replay) |
| Minute 16 | Facilitator | `CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 2);` (refund sign flip) |
| Minute 18 | Facilitator | `CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 3);` (merge task stalled) |
| Minute 23 | Facilitator | `CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 4);` (status drift) |
| During | Facilitator | `V_ROOM_STATUS` shows who has checks on and what is failing; `V_FAULTS` shows what was injected |
| After | Admin | Run `sql/99_teardown.sql` on the agreed date |

## Walk-ins

| Situation | Do this |
|---|---|
| Has a Snowflake user | `CALL GLADSTONE_DQ_LITE.ADMIN.ADD_ATTENDEE('JOE', 'JBLOGGS');` (as ACCOUNTADMIN or SECURITYADMIN, about 20 s). If faults are already in: `INJECT('JOE', n)` for each one so far |
| No Snowflake user | Pair with a neighbour |
| Broke their copy | `CALL GLADSTONE_DQ_LITE.ADMIN.RESET_ATTENDEE('NIELS');` - fresh copy; they redo Session 2 using the catch-up boxes |

## Say this (story script)

Cast: **Sam** (operator ops manager), **Priya** (Gladstone Customer Success), **you** (on-call data engineer). Read the line, then let the room work. Same words as the chapter cards in the guide.

| When | Say |
|---|---|
| Minute 0 (opener, 60 s) | "Riverside Leisure rang us this morning: Nova says too many members and too little revenue. Today you're the on-call engineer. In 30 minutes we'll go from the operator telling us, to us telling the operator." |
| Start of chapter 1: The complaint | "First, find where those two numbers come from - and write down what they say on a good day." |
| Start of chapter 2: Guard | "Nothing is broken yet. Put guards on the pipeline now, so the next problem logs itself." |
| Start of chapter 3: Catch and contain | "I'm breaking Riverside's feed now. Watch your incident log - then tell me what happened before Sam calls." |
| Start of chapter 4: Operate | "One more fault, and Priya needs one place to look. Build it, fix the data, and watch it heal." |
| Close | Read the epilogue on the last session page aloud. |
