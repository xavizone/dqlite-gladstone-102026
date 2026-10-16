-- =============================================================================
-- Gladstone MRM | Data Quality HOL - LITE | 10_inject.sql (facilitator)
-- Inject one fault at a time into EVERY attendee pipeline. Run as DQ_LITE_ADMIN.
-- =============================================================================
USE ROLE DQ_LITE_ADMIN;
USE WAREHOUSE DQ_LITE_WH;

-- Minute 13 (start of Session 3)
CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 1);   -- Bifrost replay: 150 duplicate members
-- Minute 16
CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 2);   -- Refunds as negative payments: revenue collapses
-- Minute 18
CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 3);   -- Merge task stalls: freshness breaches after ~3 minutes
-- Minute 23 (Session 4)
CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 4);   -- Cancelled members re-sent as ACTIVE
-- Stretch
-- CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('ALL', 5); -- Volume drop: only anomaly detection would catch it (needs history)

-- One attendee only (late joiner):   CALL GLADSTONE_DQ_LITE.ADMIN.INJECT('NIELS', 1);

-- Facilitator views
SELECT * FROM GLADSTONE_DQ_LITE.ADMIN.V_FAULTS;        -- what was injected where, and which check should catch it
SELECT * FROM GLADSTONE_DQ_LITE.ADMIN.V_ROOM_STATUS;   -- per attendee: checks attached, failing now
