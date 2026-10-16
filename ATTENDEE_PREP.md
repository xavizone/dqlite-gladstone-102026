# Gladstone MRM | Data quality lab (Lite) | Before you start

30 minutes, hands-on, in Gladstone's own Snowflake account. Please do the first section a day before.

## Things to do

**The day before (10 minutes)**

1. **Log in to Snowflake** (`GLADSTONESOFTWARE`) in a browser with your usual sign-in (SSO or MFA). If it fails, tell your admin now, not on the day.
2. **Install and sign in to CoCo** - CoCo Desktop or the CoCo CLI. Either works for every step. Connect it to `GLADSTONESOFTWARE`.
   Step-by-step instructions, download links and fixes are on the guide's **Install CoCo Desktop and CLI** page
   (Desktop: https://www.snowflake.com/en/product/snowflake-coco/downloads/ - CLI: `curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh | sh`).
3. **Run this test prompt in CoCo:** *"What is my current user, role and warehouse? Run select current_user(), current_role(), current_warehouse()."* If you get an answer back, CoCo is working.
4. **Confirm your name** with the facilitator (for example `NIELS`). It names your schema `RIVERSIDE_<NAME>`. Everyone uses the same role, `DQ_LITE_ATTENDEE`.
5. **Bonus B3 only (optional):** install Snowflake CLI 3.17 or later (`snow --version`) and make sure you can reach GitHub.

**On the day (5 minutes before)**

1. Open the lab guide and type your name into the sidebar box. Every prompt updates to your schema.
2. Follow **Getting started**: set role `DQ_LITE_ATTENDEE` and warehouse `DQ_LITE_WH`, then run the check prompt.
3. Not on the attendee list? Tell the facilitator. A new copy of the pipeline takes about 20 seconds.

## Things to know

- **One operator, one complaint.** Riverside Leisure (fictional, three sites in Oxfordshire) says Nova's active members are too high and revenue too low. You'll guard its pipeline so the next problem is caught before the operator notices.
- **You get your own copy.** Your schema `RIVERSIDE_<NAME>` is your own copy of Riverside's pipeline. Everyone shares one role, so you *can* see other schemas - only work in yours.
- **The data is synthetic.** Members, bookings, payments and check-ins are generated for the lab. No real member data is used.
- **Gladstone's names.** Bronze tables use the Bifrost layout (`MEMBERS__*`, `SHARED__*`, `SYSTEM__*`, `_SYNC_META__*`); Silver is `REPORTING__*` Dynamic Tables; Gold is the semantic view Nova answers from.
- **CoCo first, Snowsight always.** Every step is a CoCo prompt. Each one also has a *Do it in Snowsight* route and a *Behind? Run this* box with the exact SQL.
- **Read before you approve.** CoCo shows the SQL before running it. You're working in Gladstone's real account, so read it and approve deliberately.
- **Things will break on purpose.** From minute 13 the facilitator injects realistic faults into everyone's pipeline at once (a replayed merge batch, refunds with the wrong sign, a stalled sync, cancelled members re-sent as active).
- **Cost is capped.** One shared warehouse with a 20-credit resource monitor.

## What to expect

| Minutes | Session | You will |
|---|---|---|
| 0-5 | 1. The complaint | Map the pipeline and reproduce the operator's two numbers |
| 5-13 | 2. Put guards on it | Add checks with pass/fail rules, an email and an incident-logging alert - all pass on clean data |
| 13-22 | 3. Catch, explain, contain | Watch the faults get caught, let CoCo find the cause, and freeze REPORTING with a circuit breaker |
| 22-30 | 4. Operate it | Build the health view Customer Success opens first, fix the data and watch it recover |

- **Short waits are normal.** Scheduled checks run every 5 minutes. The guide shows how to evaluate on demand.
- **CoCo's output varies.** The same prompt can produce slightly different SQL or wording. The checkpoint under each step says what "good" looks like.
- **Falling behind is fine.** Every section has a catch-up box, and the facilitator can reset your copy in seconds.
- **Afterwards:** the guide stays online, with stretch and bonus labs (budgets, GDPR and governance, DevOps with DCM). Your schema is kept until the admin runs teardown.
