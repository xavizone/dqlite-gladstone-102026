-- =============================================================================
-- Gladstone MRM | Bonus B1 - Cost controls | B1_teardown.sql (ADMIN)
-- Removes only Bonus B1 objects; the core lab keeps running.
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DQ_LITE_WH;
CALL GLADSTONE_DQ_LITE.ADMIN.B1_TEARDOWN();   -- unset cost tags on RIVERSIDE_ schemas, drop FINOPS (budgets + tags), drop DQ_LITE_RM_DEMO

REVOKE DATABASE ROLE SNOWFLAKE.BUDGET_CREATOR FROM ROLE DQ_LITE_ATTENDEE;
REVOKE DATABASE ROLE SNOWFLAKE.USAGE_VIEWER   FROM ROLE DQ_LITE_ATTENDEE;
REVOKE APPLYBUDGET ON WAREHOUSE DQ_LITE_WH FROM ROLE DQ_LITE_ATTENDEE;
REVOKE USAGE ON INTEGRATION DQ_LITE_EMAIL_INT FROM APPLICATION SNOWFLAKE;

SHOW SCHEMAS LIKE 'FINOPS' IN DATABASE GLADSTONE_DQ_LITE;   -- expect none
SHOW RESOURCE MONITORS LIKE 'DQ_LITE_RM_DEMO';              -- expect none
