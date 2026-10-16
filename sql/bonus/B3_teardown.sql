-- =============================================================================
-- Gladstone MRM | Bonus B3 - DevOps with DCM Projects | B3_teardown.sql (ADMIN)
-- Removes only Bonus B3 objects; the core lab keeps running.
-- (snow dcm drop removes only project metadata; dropping the schema removes the project
--  and every object it deployed.)
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DQ_LITE_WH;

CALL GLADSTONE_DQ_LITE.ADMIN.B3_TEARDOWN_ALL();

SHOW SCHEMAS LIKE 'RIVERSIDE_%_DCM' IN DATABASE GLADSTONE_DQ_LITE;   -- expect none
-- Local project folders on attendee laptops are not touched.
