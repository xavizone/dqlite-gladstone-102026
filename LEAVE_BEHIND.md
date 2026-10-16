# Gladstone MRM | Data quality lab (Lite) | Leave-behind

## The pattern: catch, explain, contain, operate

| Step | What you built | Snowflake feature |
|---|---|---|
| Guard | Expectations on Bronze and REPORTING: duplicates, negative amounts, freshness, referential integrity, a business rule, Bronze-to-REPORTING lag; row-count anomaly detection | Data metric functions (system + custom), expectations |
| Tell someone | Email on the critical checks; an alert that writes every failure to `DQ_INCIDENTS` | DQ notifications, `CREATE ALERT` |
| Explain | Failing rows, the merge batch that caused them, task health, Nova impact | DQ results views, `SYSTEM$DATA_METRIC_SCAN`, task history, semantic view |
| Contain | A circuit breaker that freezes REPORTING while Bronze is failing, and closes by itself | Tasks, Dynamic Tables, `SYSTEM$SET_RETURN_VALUE` |
| Operate | `V_DQ_HEALTH`: every check, OK/FAILING, incident history | Views over `SNOWFLAKE.LOCAL` |

## The four faults and what caught them

| Fault | Nova symptom | Check |
|---|---|---|
| Bifrost replayed a merge batch | +150 active members | `DUPLICATE_COUNT(member_id) = 0` |
| Refunds as negative payments | Today's revenue down £10,000 | `NEGATIVE_COUNT(amount) = 0` |
| Sync task stopped | Nothing new arriving | `FRESHNESS < 180` seconds |
| Cancelled members re-sent as ACTIVE | Two "active members" answers drift apart | Custom `ACTIVE_BUT_LEFT = 0` |

## Next steps for Gladstone

1. Pick five invariants per Bronze table that must always hold; turn them into expectations in one operator database.
2. Put the checks in a DCM project (Bonus B3) so every new operator gets them on its first deploy.
3. Replace the 5-minute lab schedule with `TRIGGER_ON_CHANGES` on Bifrost-written tables.
4. One account-level alert writing a central incident table, read by Customer Success each morning.
5. A circuit breaker per operator in front of the REPORTING tables Nova reads.
