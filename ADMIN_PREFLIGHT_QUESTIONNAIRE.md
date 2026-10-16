# Gladstone MRM | Data quality lab (Lite) | Admin preflight questionnaire

For the Gladstone Snowflake admin. The Lite lab needs one role and no per-user changes, so this list is short.
Items marked **T-5** are needed five working days before the lab; the rest by T-3.

## 1. Access and identity

| # | Question | Why we ask | When |
|---|---|---|---|
| 1 | Who will run setup, and do they have ACCOUNTADMIN (or SYSADMIN plus SECURITYADMIN)? | Setup creates two roles, a warehouse, a resource monitor and an email integration, and grants account-level privileges | **T-5** |
| 2 | Attendees' exact Snowflake user names (fill in `ATTENDEE_ROSTER.csv`)? | Only used to grant the one lab role, `DQ_LITE_ATTENDEE`. Nobody's default role or warehouse is changed | **T-5** |
| 3 | Is it acceptable that attendees share one role and can see each other's lab schemas? | Simplifies setup; all lab data is synthetic. If not, use the full lab (one role per attendee) | T-3 |

## 2. CoCo and Cortex readiness (Azure UK South)

| # | Question | Why we ask | When |
|---|---|---|---|
| 4 | Is CoCo Desktop or CLI installed and signed in for each attendee? Who approves installs? | CoCo is the primary route; installs can take days to approve. The Windows *User installer* needs no admin rights | **T-5** |
| 5 | What is `CORTEX_ENABLED_CROSS_REGION` set to, and does your data policy allow cross-region inference? | CoCo Desktop needs cross-region inference; some models are not hosted in UK South | **T-5** |
| 6 | Can you run section 8 (pre-flight checks) of `sql/00_setup.sql` on its own - it is read-only - and send us the output? | Confirms region, system DMFs and the cross-region setting before setup | **T-5** |

## 3. Account settings

| # | Question | Why we ask | When |
|---|---|---|---|
| 7 | Are there account-level resource monitors or warehouse limits that could conflict with `DQ_LITE_RM` (20 credits)? | Avoids the lab warehouse being suspended mid-session | T-3 |
| 8 | Is the account Enterprise Edition or higher? | DMFs, masking and row access (Bonus B2) need it | T-3 |
| 9 | Which email address should lab notifications go to? It must be a verified email on a Snowflake user. | Replaces `LAB_ADMIN_EMAIL` in `00_setup.sql` | **T-5** |

## 4. Bonus labs and logistics

| # | Question | Why we ask | When |
|---|---|---|---|
| 10 | B3: can attendees install Snowflake CLI 3.17+ and reach GitHub? | `snow dcm` runs from the CLI; otherwise run B3 as a demo | T-3 |
| 11 | Are the names `GLADSTONE_DQ_LITE`, `DQ_LITE_*` and `RIVERSIDE_*` acceptable? | Avoids a rename on the day | T-3 |
| 12 | When should teardown run, and who signs off? | Bounds cost and data retention | T-3 |

## Copy-paste email (T-5)

> Subject: Data quality lab - five quick questions before setup
>
> Hi,
>
> Ahead of the data quality lab on <date>, could you help with five things so setup takes ten minutes?
>
> 1. Who will run the setup script, and do they have ACCOUNTADMIN?
> 2. The attendees' exact Snowflake user names (template attached: ATTENDEE_ROSTER.csv).
> 3. Is CoCo Desktop or CLI installed for each attendee, and who approves installs?
> 4. The value of `CORTEX_ENABLED_CROSS_REGION`, plus the output of section 8 (pre-flight checks) of `00_setup.sql` - three read-only statements.
> 5. A verified email address for lab notifications.
>
> Thanks,
> <name>
