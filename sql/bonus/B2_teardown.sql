-- =============================================================================
-- Gladstone MRM | Bonus B2 - Data governance + GDPR | B2_teardown.sql (ADMIN)
-- Removes only Bonus B2 objects; the core lab keeps running.
-- Attendee-created objects inside RIVERSIDE_ schemas (PII_TYPE tag, masking/row access policies,
-- SAR_EXPORT / ERASE_MEMBER procs) are detached here and dropped with the database in 99_teardown.sql.
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DQ_LITE_WH;

CALL GLADSTONE_DQ_LITE.ADMIN.B2_UNSET_ALL();   -- detach row access / masking / projection policies,
                                              -- drop erasure DMFs, reset retention, drop GOVERNANCE schema

REVOKE APPLY MASKING POLICY    ON ACCOUNT FROM ROLE DQ_LITE_ATTENDEE;
REVOKE APPLY ROW ACCESS POLICY ON ACCOUNT FROM ROLE DQ_LITE_ATTENDEE;
REVOKE APPLY TAG               ON ACCOUNT FROM ROLE DQ_LITE_ATTENDEE;
REVOKE DATABASE ROLE SNOWFLAKE.CLASSIFICATION_ADMIN FROM ROLE DQ_LITE_ATTENDEE;
DROP ROLE IF EXISTS DQ_LITE_PII_READER;
DROP ROLE IF EXISTS DQ_LITE_SITE_VIEWER;

-- Verify
SHOW SCHEMAS LIKE 'GOVERNANCE' IN DATABASE GLADSTONE_DQ_LITE;   -- expect none
SHOW ROLES LIKE 'DQ_LITE_PII_READER';                            -- expect none
-- GDPR note: rows changed by ERASE_MEMBER remain recoverable through Time Travel for the table's
-- retention period and then Fail-safe (7 days, permanent tables). This is synthetic data.
