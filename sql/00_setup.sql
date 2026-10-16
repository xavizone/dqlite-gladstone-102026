-- =============================================================================
-- Gladstone MRM | Data Quality HOL - LITE | 00_setup.sql
-- One operator (Riverside Leisure, fictional), one pipeline copy per attendee,
-- ONE shared role. Run once as ACCOUNTADMIN, top to bottom (~2 min + ~20 s per attendee).
--
-- Creates: warehouse DQ_LITE_WH, monitor DQ_LITE_RM, email integration DQ_LITE_EMAIL_INT,
--          roles DQ_LITE_ADMIN + DQ_LITE_ATTENDEE, database GLADSTONE_DQ_LITE with
--          ADMIN, DQ_COMMON, TEMPLATE and one RIVERSIDE_<NAME> schema per attendee.
-- No per-attendee roles and no change to anyone's default role or warehouse.
-- Attendees share one role, so they can see each other's schemas (synthetic data only).
-- Teardown: 99_teardown.sql
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------------------------
-- 0. Edit before running
-- ---------------------------------------------------------------------------
SET LAB_ADMIN_EMAIL = 'replace.me@gladstonesoftware.co.uk';   -- must be a VERIFIED Snowflake user email

-- ---------------------------------------------------------------------------
-- 1. Compute + spend cap
-- ---------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS DQ_LITE_WH
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE
  MIN_CLUSTER_COUNT = 1 MAX_CLUSTER_COUNT = 3 SCALING_POLICY = 'STANDARD'
  COMMENT = 'Gladstone DQ Lite - lab warehouse';
CREATE RESOURCE MONITOR IF NOT EXISTS DQ_LITE_RM
  WITH CREDIT_QUOTA = 20 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
  TRIGGERS ON 75 PERCENT DO NOTIFY ON 100 PERCENT DO SUSPEND;
ALTER WAREHOUSE DQ_LITE_WH SET RESOURCE_MONITOR = DQ_LITE_RM;
-- DMFs and serverless alerts run on serverless compute and are not covered by the monitor (see Bonus B1).

-- ---------------------------------------------------------------------------
-- 2. Email integration (data quality notifications)
-- ---------------------------------------------------------------------------
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS DQ_LITE_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ($LAB_ADMIN_EMAIL)
  COMMENT = 'Gladstone DQ Lite - data quality notifications';

-- ---------------------------------------------------------------------------
-- 3. Roles: one admin role, ONE attendee role for everyone
-- ---------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS DQ_LITE_ADMIN    COMMENT = 'Gladstone DQ Lite - facilitator';
CREATE ROLE IF NOT EXISTS DQ_LITE_ATTENDEE COMMENT = 'Gladstone DQ Lite - every attendee (owns RIVERSIDE_* schemas)';
GRANT ROLE DQ_LITE_ATTENDEE TO ROLE DQ_LITE_ADMIN;
GRANT ROLE DQ_LITE_ADMIN    TO ROLE SYSADMIN;

GRANT EXECUTE DATA METRIC FUNCTION ON ACCOUNT TO ROLE DQ_LITE_ATTENDEE;
GRANT MANAGE DATA QUALITY          ON ACCOUNT TO ROLE DQ_LITE_ATTENDEE;
GRANT EXECUTE TASK                 ON ACCOUNT TO ROLE DQ_LITE_ATTENDEE;
GRANT EXECUTE ALERT                ON ACCOUNT TO ROLE DQ_LITE_ATTENDEE;   -- incident-logging alert (Session 2)
GRANT DATABASE ROLE SNOWFLAKE.DATA_METRIC_USER                  TO ROLE DQ_LITE_ATTENDEE;
GRANT APPLICATION ROLE SNOWFLAKE.DATA_QUALITY_MONITORING_VIEWER TO ROLE DQ_LITE_ATTENDEE;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER                       TO ROLE DQ_LITE_ATTENDEE;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE                 TO ROLE DQ_LITE_ATTENDEE;

GRANT MANAGE DATA QUALITY ON ACCOUNT TO ROLE DQ_LITE_ADMIN;
GRANT APPLICATION ROLE SNOWFLAKE.DATA_QUALITY_MONITORING_ADMIN TO ROLE DQ_LITE_ADMIN;
GRANT USAGE ON INTEGRATION DQ_LITE_EMAIL_INT TO ROLE DQ_LITE_ADMIN;

GRANT USAGE, OPERATE ON WAREHOUSE DQ_LITE_WH TO ROLE DQ_LITE_ATTENDEE;
GRANT OWNERSHIP ON WAREHOUSE DQ_LITE_WH TO ROLE DQ_LITE_ADMIN COPY CURRENT GRANTS;

-- ---------------------------------------------------------------------------
-- 4. Lab database
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS GLADSTONE_DQ_LITE COMMENT = 'Gladstone MRM DQ Lite HOL - synthetic data only';
CREATE SCHEMA IF NOT EXISTS GLADSTONE_DQ_LITE.ADMIN     COMMENT = 'Facilitator procedures and logs';
CREATE SCHEMA IF NOT EXISTS GLADSTONE_DQ_LITE.DQ_COMMON COMMENT = 'Shared custom data metric functions';
CREATE SCHEMA IF NOT EXISTS GLADSTONE_DQ_LITE.TEMPLATE  COMMENT = 'Gold copy of Riverside Leisure (seed tables only)';
GRANT OWNERSHIP ON DATABASE GLADSTONE_DQ_LITE TO ROLE DQ_LITE_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL SCHEMAS IN DATABASE GLADSTONE_DQ_LITE TO ROLE DQ_LITE_ADMIN COPY CURRENT GRANTS;
GRANT USAGE ON DATABASE GLADSTONE_DQ_LITE         TO ROLE DQ_LITE_ATTENDEE;
GRANT USAGE ON SCHEMA GLADSTONE_DQ_LITE.DQ_COMMON TO ROLE DQ_LITE_ATTENDEE;
GRANT USAGE ON SCHEMA GLADSTONE_DQ_LITE.ADMIN     TO ROLE DQ_LITE_ATTENDEE;

-- Notifications are database-scoped; each attendee picks which checks notify.
USE ROLE DQ_LITE_ADMIN;
ALTER DATABASE GLADSTONE_DQ_LITE SET DATA_QUALITY_MONITORING_SETTINGS = $$
notification:
  enabled: TRUE
  integrations:
    - DQ_LITE_EMAIL_INT
  cooldown_hours: 1
  metadata_included: TRUE
$$;

-- ---------------------------------------------------------------------------
-- 5. Riverside Leisure seed data (synthetic, deterministic: HASH not RANDOM)
--    Nova layers: Bronze MEMBERS__ / SHARED__ / SYSTEM__, sync metadata, Silver REPORTING__ (per attendee)
-- ---------------------------------------------------------------------------
USE WAREHOUSE DQ_LITE_WH;
USE SCHEMA GLADSTONE_DQ_LITE.TEMPLATE;
SET OP = 'RIVERSIDE';

CREATE OR REPLACE TABLE SHARED__SITE (site_id VARCHAR, operator_id VARCHAR, site_name VARCHAR, town VARCHAR, _loaded_at TIMESTAMP_LTZ)
  COMMENT = 'Bronze SHARED: Riverside Leisure sites';
INSERT INTO SHARED__SITE SELECT column1, $OP, column2, column3, CURRENT_TIMESTAMP()
FROM VALUES ('S01','Riverside Leisure Centre','Oxford'), ('S02','Abbey Pool & Gym','Abingdon'), ('S03','Kingfisher Sports Hub','Banbury');

CREATE OR REPLACE TABLE SHARED__ACTIVITY (activity_id VARCHAR, operator_id VARCHAR, site_id VARCHAR, class_name VARCHAR,
  class_date DATE, capacity NUMBER, _loaded_at TIMESTAMP_LTZ) COMMENT = 'Bronze SHARED: scheduled classes';
INSERT INTO SHARED__ACTIVITY
SELECT 'A' || LPAD(seq::VARCHAR, 5, '0'), $OP, 'S0' || (1 + MOD(seq, 3)),
       DECODE(MOD(HASH(seq, 'cls'), 6), 0,'Spin',1,'Yoga',2,'Aqua Fit',3,'HIIT',4,'Pilates','Swim Lessons'),
       DATEADD(day, -MOD(seq, 28), CURRENT_DATE()), DECODE(MOD(HASH(seq, 'cap'), 3), 0, 12, 1, 20, 30), CURRENT_TIMESTAMP()
FROM (SELECT SEQ4() AS seq FROM TABLE(GENERATOR(ROWCOUNT => 600)));

CREATE OR REPLACE TABLE MEMBERS__MEMBER (
  member_id VARCHAR, operator_id VARCHAR, home_site_id VARCHAR, first_name VARCHAR, last_name VARCHAR,
  email VARCHAR, phone VARCHAR, date_of_birth DATE, postcode VARCHAR,
  status VARCHAR,            -- ACTIVE / FROZEN / CANCELLED (source-system status)
  joined_on DATE, left_on DATE, marketing_consent BOOLEAN,
  health_notes VARCHAR,      -- special-category data (synthetic), used in Bonus B2
  last_activity_at TIMESTAMP_LTZ, _batch_id VARCHAR, _loaded_at TIMESTAMP_LTZ
) COMMENT = 'Bronze MEMBERS: member master (synthetic personal data)';
INSERT INTO MEMBERS__MEMBER
WITH s AS (SELECT SEQ4() AS seq, ABS(HASH(SEQ4(), 'm')) AS h FROM TABLE(GENERATOR(ROWCOUNT => 2000)))
SELECT 'M-' || LPAD((1000 + seq)::VARCHAR, 5, '0'), $OP, 'S0' || (1 + MOD(h, 3)),
       DECODE(MOD(h, 10), 0,'Amelia',1,'Oliver',2,'Isla',3,'George',4,'Ava',5,'Harry',6,'Mia',7,'Noah',8,'Freya','Jack'),
       DECODE(MOD(FLOOR(h / 10), 10), 0,'Smith',1,'Jones',2,'Taylor',3,'Brown',4,'Williams',5,'Wilson',6,'Evans',7,'Thomas',8,'Roberts','Walker'),
       'member' || (1000 + seq) || '@example.co.uk', '07700 9' || LPAD(MOD(h, 100000)::VARCHAR, 5, '0'),
       DATEADD(day, -(6570 + MOD(h, 18250)), CURRENT_DATE()),
       DECODE(MOD(h, 4), 0,'OX1 ',1,'OX14 ',2,'OX16 ','OX4 ') || (1 + MOD(h, 9)) || 'AB',
       CASE WHEN MOD(h, 100) < 78 THEN 'ACTIVE' WHEN MOD(h, 100) < 84 THEN 'FROZEN' ELSE 'CANCELLED' END,
       DATEADD(day, -(30 + MOD(h, 1400)), CURRENT_DATE()),
       CASE WHEN MOD(h, 100) >= 84 THEN DATEADD(day, -MOD(h, 120), CURRENT_DATE()) END,
       MOD(h, 3) <> 0,
       CASE WHEN MOD(h, 25) = 0 THEN 'Asthma - inhaler on poolside' WHEN MOD(h, 31) = 0 THEN 'Recent knee surgery - low impact only' END,
       DATEADD(hour, -MOD(h, 24 * 60), CURRENT_TIMESTAMP()), 'B-SEED', CURRENT_TIMESTAMP()
FROM s;

CREATE OR REPLACE TABLE MEMBERS__MEMBERSHIP (membership_id VARCHAR, member_id VARCHAR, operator_id VARCHAR, plan_name VARCHAR,
  monthly_fee NUMBER(10,2), start_date DATE, end_date DATE, last_paid_on DATE, _loaded_at TIMESTAMP_LTZ)
  COMMENT = 'Bronze MEMBERS: membership contracts';
INSERT INTO MEMBERS__MEMBERSHIP
SELECT 'MS-' || SUBSTR(member_id, 3), member_id, operator_id,
       DECODE(MOD(ABS(HASH(member_id, 'p')), 3), 0,'Off-Peak',1,'Standard','Premium Plus'),
       DECODE(MOD(ABS(HASH(member_id, 'p')), 3), 0, 24.99, 1, 34.99, 49.99), joined_on, left_on,
       -- ~6% of ACTIVE members haven't paid in > 35 days: the "two definitions of active member" trap
       CASE WHEN status = 'ACTIVE' AND MOD(ABS(HASH(member_id, 'lp')), 100) < 6
              THEN DATEADD(day, -(40 + MOD(ABS(HASH(member_id, 'd')), 60)), CURRENT_DATE())
            WHEN status = 'ACTIVE' THEN DATEADD(day, -MOD(ABS(HASH(member_id, 'd')), 30), CURRENT_DATE())
            ELSE DATEADD(day, -(45 + MOD(ABS(HASH(member_id, 'd')), 200)), CURRENT_DATE()) END,
       CURRENT_TIMESTAMP()
FROM MEMBERS__MEMBER;

CREATE OR REPLACE TABLE SYSTEM__BOOKING (booking_id VARCHAR, operator_id VARCHAR, activity_id VARCHAR, member_id VARCHAR,
  booked_at TIMESTAMP_LTZ, _loaded_at TIMESTAMP_LTZ) COMMENT = 'Bronze SYSTEM: class bookings';
INSERT INTO SYSTEM__BOOKING
WITH s AS (SELECT SEQ4() AS seq, ABS(HASH(SEQ4(), 'b')) AS h FROM TABLE(GENERATOR(ROWCOUNT => 9000)))
SELECT 'BK-' || LPAD(seq::VARCHAR, 6, '0'), $OP, 'A' || LPAD(MOD(h, 600)::VARCHAR, 5, '0'),
       'M-' || LPAD((1000 + MOD(FLOOR(h / 600), 2000))::VARCHAR, 5, '0'),
       DATEADD(minute, -MOD(h, 28 * 24 * 60), CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
FROM s;

CREATE OR REPLACE TABLE SYSTEM__ATTENDANCE (attendance_id VARCHAR, operator_id VARCHAR, booking_id VARCHAR, member_id VARCHAR,
  checked_in_at TIMESTAMP_LTZ, _loaded_at TIMESTAMP_LTZ) COMMENT = 'Bronze SYSTEM: turnstile / class check-ins';
INSERT INTO SYSTEM__ATTENDANCE
SELECT 'AT-' || SUBSTR(booking_id, 4), operator_id, booking_id, member_id, DATEADD(minute, 5, booked_at), CURRENT_TIMESTAMP()
FROM SYSTEM__BOOKING WHERE MOD(ABS(HASH(booking_id, 'show')), 100) < 82;

CREATE OR REPLACE TABLE SYSTEM__PAYMENT (payment_id VARCHAR, operator_id VARCHAR, member_id VARCHAR, payment_date DATE,
  amount NUMBER(10,2),   -- always positive; direction comes from payment_type
  payment_type VARCHAR,  -- PAYMENT / REFUND
  _batch_id VARCHAR, _loaded_at TIMESTAMP_LTZ) COMMENT = 'Bronze SYSTEM: payments and refunds';
INSERT INTO SYSTEM__PAYMENT
WITH s AS (SELECT SEQ4() AS seq, ABS(HASH(SEQ4(), 'pay')) AS h FROM TABLE(GENERATOR(ROWCOUNT => 6000)))
SELECT 'PY-' || LPAD(seq::VARCHAR, 7, '0'), $OP, 'M-' || LPAD((1000 + MOD(h, 2000))::VARCHAR, 5, '0'),
       DATEADD(day, -MOD(seq, 28), CURRENT_DATE()), DECODE(MOD(h, 3), 0, 24.99, 1, 34.99, 49.99),
       IFF(MOD(h, 40) = 0, 'REFUND', 'PAYMENT'), 'B-SEED', CURRENT_TIMESTAMP()
FROM s;

CREATE OR REPLACE TABLE _SYNC_META__MERGE_BATCH (batch_id VARCHAR, operator_id VARCHAR, table_name VARCHAR, row_count NUMBER,
  loaded_at TIMESTAMP_LTZ) COMMENT = 'Sync metadata: one row per merge batch (stands in for Bifrost)';
INSERT INTO _SYNC_META__MERGE_BATCH SELECT 'B-SEED', $OP, column1, column2, CURRENT_TIMESTAMP()
FROM VALUES ('MEMBERS__MEMBER', 2000), ('SYSTEM__PAYMENT', 6000), ('SYSTEM__BOOKING', 9000);

-- Where the incident-logging alert writes (Session 2). Empty in the template.
CREATE OR REPLACE TABLE DQ_INCIDENTS (
  incident_id VARCHAR DEFAULT UUID_STRING(), opened_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
  table_name VARCHAR, metric_name VARCHAR, expectation_name VARCHAR, value VARCHAR, measured_at TIMESTAMP_LTZ
) COMMENT = 'Data quality incidents opened by the DQ_INCIDENT_ALERT';

-- ---------------------------------------------------------------------------
-- 6. Shared custom data metric functions (define once, attach anywhere)
-- ---------------------------------------------------------------------------
USE SCHEMA GLADSTONE_DQ_LITE.DQ_COMMON;
CREATE OR REPLACE DATA METRIC FUNCTION ACTIVE_BUT_LEFT(t TABLE(status VARCHAR, left_on DATE))
RETURNS NUMBER COMMENT = 'Members marked ACTIVE that have a leave date. Expect 0.'
AS $$ SELECT COUNT_IF(status = 'ACTIVE' AND left_on IS NOT NULL) FROM t $$;

CREATE OR REPLACE DATA METRIC FUNCTION REPORTING_LAG_SECONDS(silver TABLE(last_loaded_at TIMESTAMP_LTZ), bronze TABLE(_loaded_at TIMESTAMP_LTZ))
RETURNS NUMBER COMMENT = 'Seconds a REPORTING dynamic table trails its Bronze source. Expect < 300.'
AS $$ SELECT GREATEST(0, DATEDIFF(second, (SELECT MAX(last_loaded_at) FROM silver), (SELECT MAX(_loaded_at) FROM bronze))) $$;
GRANT USAGE ON ALL DATA METRIC FUNCTIONS IN SCHEMA GLADSTONE_DQ_LITE.DQ_COMMON TO ROLE DQ_LITE_ATTENDEE;

-- ---------------------------------------------------------------------------
-- 7. Facilitator procedures
-- ---------------------------------------------------------------------------
USE SCHEMA GLADSTONE_DQ_LITE.ADMIN;
CREATE TABLE IF NOT EXISTS ATTENDEES (short_name VARCHAR, user_name VARCHAR, schema_name VARCHAR,
  created_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());
CREATE TABLE IF NOT EXISTS FAULT_LOG (schema_name VARCHAR, fault_no NUMBER, fault_code VARCHAR, description VARCHAR,
  caught_by VARCHAR, injected_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

-- Simulated Bifrost merge: every minute a few payments, bookings and check-ins arrive.
CREATE OR REPLACE PROCEDURE BIFROST_MERGE(SCHEMA_NAME VARCHAR)
RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER
AS $$
DECLARE
  b  VARCHAR DEFAULT 'B-' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISSFF3');
  fq VARCHAR DEFAULT 'GLADSTONE_DQ_LITE.' || :SCHEMA_NAME;
BEGIN
  EXECUTE IMMEDIATE 'INSERT INTO ' || :fq || '.SYSTEM__PAYMENT
     SELECT ''PY-' || :b || '-'' || SEQ4(), ''RIVERSIDE'', ''M-'' || LPAD((1000 + UNIFORM(0, 1999, RANDOM()))::VARCHAR, 5, ''0''),
            CURRENT_DATE(), 34.99, ''PAYMENT'', ''' || :b || ''', CURRENT_TIMESTAMP() FROM TABLE(GENERATOR(ROWCOUNT => 15))';
  EXECUTE IMMEDIATE 'INSERT INTO ' || :fq || '.SYSTEM__BOOKING
     SELECT ''BK-' || :b || '-'' || SEQ4(), ''RIVERSIDE'', ''A'' || LPAD(UNIFORM(0, 599, RANDOM())::VARCHAR, 5, ''0''),
            ''M-'' || LPAD((1000 + UNIFORM(0, 1999, RANDOM()))::VARCHAR, 5, ''0''), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
     FROM TABLE(GENERATOR(ROWCOUNT => 10))';
  EXECUTE IMMEDIATE 'INSERT INTO ' || :fq || '.SYSTEM__ATTENDANCE
     SELECT ''AT-'' || SUBSTR(booking_id, 4), operator_id, booking_id, member_id, DATEADD(minute, 5, booked_at), CURRENT_TIMESTAMP()
     FROM ' || :fq || '.SYSTEM__BOOKING WHERE booking_id LIKE ''BK-' || :b || '-%''';
  EXECUTE IMMEDIATE 'INSERT INTO ' || :fq || '._SYNC_META__MERGE_BATCH
     SELECT ''' || :b || ''', ''RIVERSIDE'', column1, column2, CURRENT_TIMESTAMP() FROM VALUES (''SYSTEM__PAYMENT'', 15), (''SYSTEM__BOOKING'', 10)';
  RETURN :b;
END;
$$;
GRANT USAGE ON PROCEDURE BIFROST_MERGE(VARCHAR) TO ROLE DQ_LITE_ATTENDEE;

-- One attendee = one copy of the Riverside pipeline (schema RIVERSIDE_<NAME>), owned by the shared role.
CREATE OR REPLACE PROCEDURE ADD_ATTENDEE(SHORT_NAME VARCHAR, USER_NAME VARCHAR DEFAULT NULL)
RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER
AS $$
DECLARE
  nm  VARCHAR DEFAULT UPPER(REGEXP_REPLACE(:SHORT_NAME, '[^A-Za-z0-9_]', ''));
  sch VARCHAR;
  fq  VARCHAR;
  u   VARCHAR;
  cnt NUMBER DEFAULT 0;
  note VARCHAR DEFAULT '';
BEGIN
  sch := 'RIVERSIDE_' || :nm;
  fq  := 'GLADSTONE_DQ_LITE.' || :sch;
  EXECUTE IMMEDIATE 'CREATE OR REPLACE SCHEMA ' || :fq || ' CLONE GLADSTONE_DQ_LITE.TEMPLATE COMMENT = ''Riverside Leisure pipeline - ' || :nm || '''';

  EXECUTE IMMEDIATE 'CREATE OR REPLACE DYNAMIC TABLE ' || :fq || '.REPORTING__ACTIVE_MEMBERS
      TARGET_LAG = ''1 minute'' WAREHOUSE = DQ_LITE_WH REFRESH_MODE = INCREMENTAL
      COMMENT = ''Silver REPORTING: active members by site (status-based)''
    AS SELECT operator_id, home_site_id AS site_id, COUNT(*) AS member_rows,
              COUNT_IF(status = ''ACTIVE'') AS active_members, MAX(_loaded_at) AS last_loaded_at
       FROM ' || :fq || '.MEMBERS__MEMBER GROUP BY operator_id, home_site_id';
  EXECUTE IMMEDIATE 'CREATE OR REPLACE DYNAMIC TABLE ' || :fq || '.REPORTING__DAILY_REVENUE
      TARGET_LAG = ''1 minute'' WAREHOUSE = DQ_LITE_WH REFRESH_MODE = INCREMENTAL
      COMMENT = ''Silver REPORTING: net revenue per day''
    AS SELECT operator_id, payment_date, SUM(IFF(payment_type = ''REFUND'', -amount, amount)) AS net_revenue,
              COUNT_IF(payment_type = ''REFUND'') AS refunds, COUNT(*) AS transactions, MAX(_loaded_at) AS last_loaded_at
       FROM ' || :fq || '.SYSTEM__PAYMENT GROUP BY operator_id, payment_date';
  EXECUTE IMMEDIATE 'CREATE OR REPLACE DYNAMIC TABLE ' || :fq || '.REPORTING__CLASS_UTILISATION
      TARGET_LAG = ''1 minute'' WAREHOUSE = DQ_LITE_WH REFRESH_MODE = INCREMENTAL
      COMMENT = ''Silver REPORTING: class bookings, attendance and capacity''
    AS SELECT a.operator_id, a.site_id, a.activity_id, a.class_name, a.class_date, a.capacity,
              COUNT(b.booking_id) AS bookings, COUNT(t.attendance_id) AS attended, MAX(b._loaded_at) AS last_loaded_at
       FROM ' || :fq || '.SHARED__ACTIVITY a
       JOIN ' || :fq || '.SYSTEM__BOOKING b ON b.activity_id = a.activity_id
       LEFT JOIN ' || :fq || '.SYSTEM__ATTENDANCE t ON t.booking_id = b.booking_id
       GROUP BY a.operator_id, a.site_id, a.activity_id, a.class_name, a.class_date, a.capacity';

  EXECUTE IMMEDIATE 'CREATE OR REPLACE SEMANTIC VIEW ' || :fq || '.SV_RIVERSIDE_KPIS
    TABLES (
      am   AS ' || :fq || '.REPORTING__ACTIVE_MEMBERS   PRIMARY KEY (site_id),
      rev  AS ' || :fq || '.REPORTING__DAILY_REVENUE    PRIMARY KEY (payment_date),
      util AS ' || :fq || '.REPORTING__CLASS_UTILISATION PRIMARY KEY (activity_id),
      ms   AS ' || :fq || '.MEMBERS__MEMBERSHIP         PRIMARY KEY (membership_id))
    DIMENSIONS (
      am.site_id AS am.site_id COMMENT = ''Site'', rev.payment_date AS rev.payment_date COMMENT = ''Payment date'',
      util.class_date AS util.class_date COMMENT = ''Class date'', util.class_name AS util.class_name COMMENT = ''Class type'',
      util.class_site AS util.site_id COMMENT = ''Site of the class'', ms.plan_name AS ms.plan_name COMMENT = ''Membership plan'')
    METRICS (
      am.active_members AS SUM(am.active_members) WITH SYNONYMS = (''members'', ''active members'') COMMENT = ''Members whose source status is ACTIVE'',
      ms.paid_members_35d AS COUNT_IF(ms.last_paid_on >= DATEADD(day, -35, CURRENT_DATE())) COMMENT = ''Members who paid in the last 35 days (finance definition)'',
      rev.net_revenue AS SUM(rev.net_revenue) COMMENT = ''Payments minus refunds, GBP'',
      util.utilisation_pct AS DIV0(SUM(util.attended), SUM(util.capacity)) * 100 COMMENT = ''Attended places as a percentage of capacity'',
      util.no_show_rate AS DIV0(SUM(util.bookings) - SUM(util.attended), SUM(util.bookings)) * 100 COMMENT = ''Booked but did not attend, percent'')
    COMMENT = ''Nova Gold layer for Riverside Leisure''
    AI_SQL_GENERATION ''Unless the user says otherwise, "active members" means the active_members metric (source status).''
    AI_VERIFIED_QUERIES (
      vq_active_members AS (
        QUESTION ''How many active members do we have?''
        SQL ''SELECT COUNT_IF(last_paid_on >= DATEADD(day, -35, CURRENT_DATE())) AS active_members FROM ' || :fq || '.MEMBERS__MEMBERSHIP''))';

  EXECUTE IMMEDIATE 'CREATE OR REPLACE TASK ' || :fq || '.TSK_BIFROST_MERGE WAREHOUSE = DQ_LITE_WH SCHEDULE = ''1 MINUTE''
      COMMENT = ''Simulated Bifrost merge batch'' AS CALL GLADSTONE_DQ_LITE.ADMIN.BIFROST_MERGE(''' || :sch || ''')';

  -- The shared attendee role owns the schema and everything in it
  EXECUTE IMMEDIATE 'GRANT OWNERSHIP ON ALL TABLES IN SCHEMA ' || :fq || ' TO ROLE DQ_LITE_ATTENDEE COPY CURRENT GRANTS';
  EXECUTE IMMEDIATE 'GRANT OWNERSHIP ON ALL DYNAMIC TABLES IN SCHEMA ' || :fq || ' TO ROLE DQ_LITE_ATTENDEE COPY CURRENT GRANTS';
  EXECUTE IMMEDIATE 'GRANT OWNERSHIP ON ALL TASKS IN SCHEMA ' || :fq || ' TO ROLE DQ_LITE_ATTENDEE COPY CURRENT GRANTS';
  EXECUTE IMMEDIATE 'GRANT OWNERSHIP ON SEMANTIC VIEW ' || :fq || '.SV_RIVERSIDE_KPIS TO ROLE DQ_LITE_ATTENDEE COPY CURRENT GRANTS';
  EXECUTE IMMEDIATE 'GRANT OWNERSHIP ON SCHEMA ' || :fq || ' TO ROLE DQ_LITE_ATTENDEE COPY CURRENT GRANTS';
  EXECUTE IMMEDIATE 'ALTER TASK ' || :fq || '.TSK_BIFROST_MERGE RESUME';

  -- Optional: give a Snowflake user the shared role (no default role / warehouse changes)
  IF (:USER_NAME IS NOT NULL AND :USER_NAME <> '') THEN
    EXECUTE IMMEDIATE 'SHOW USERS LIKE ''' || REPLACE(REPLACE(:USER_NAME, '"', ''), '''', '') || '''';
    SELECT COUNT(*), MAX("name") INTO :cnt, :u FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE UPPER("name") = UPPER(:USER_NAME);
    IF (:cnt = 0) THEN
      note := ' | ERROR: user ' || :USER_NAME || ' not found - schema built, role not granted';
      u := NULL;
    ELSE
      EXECUTE IMMEDIATE 'GRANT ROLE DQ_LITE_ATTENDEE TO USER "' || :u || '"';
    END IF;
  END IF;
  DELETE FROM GLADSTONE_DQ_LITE.ADMIN.ATTENDEES WHERE short_name = :nm;
  INSERT INTO GLADSTONE_DQ_LITE.ADMIN.ATTENDEES (short_name, user_name, schema_name) VALUES (:nm, :u, :sch);
  RETURN 'Ready: ' || :fq || :note;
END;
$$;

-- '[{"name":"NIELS","user":"NJOHANSEN"}, {"name":"AMY"}]'  (user optional)
CREATE OR REPLACE PROCEDURE SETUP_ALL(ATTENDEE_LIST VARIANT)
RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER
AS $$
DECLARE
  done NUMBER DEFAULT 0;
  nm VARCHAR; u VARCHAR; res VARCHAR; errs VARCHAR DEFAULT '';
  c1 CURSOR FOR SELECT value:name::VARCHAR AS n, value:user::VARCHAR AS u FROM TABLE(FLATTEN(INPUT => PARSE_JSON(?)));
BEGIN
  OPEN c1 USING (TO_JSON(ATTENDEE_LIST));
  FOR r IN c1 DO
    nm := r.n;
    u := r.u;
    CALL GLADSTONE_DQ_LITE.ADMIN.ADD_ATTENDEE(:nm, :u) INTO :res;
    IF (CONTAINS(:res, 'ERROR')) THEN
      errs := errs || ' | ' || :nm || ': ' || :res;
    END IF;
    done := done + 1;
  END FOR;
  RETURN done || ' pipeline(s) ready' || IFF(errs = '', '', '. Check:' || errs);
END;
$$;

-- Faults are injected into EVERY attendee schema at once (or one name), one number at a time.
--   1 BIFROST_REPLAY  2 REFUND_SIGN_FLIP  3 MERGE_TASK_STALLED  4 STATUS_DRIFT  5 VOLUME_DROP (stretch)
CREATE OR REPLACE PROCEDURE INJECT(TARGET VARCHAR, FAULT_NO NUMBER)
RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER
AS $$
DECLARE
  n NUMBER DEFAULT 0;
  fq VARCHAR; sname VARCHAR; code VARCHAR; descr VARCHAR; caught VARCHAR;
  c1 CURSOR FOR SELECT schema_name FROM GLADSTONE_DQ_LITE.ADMIN.ATTENDEES
                WHERE ? = 'ALL' OR short_name = UPPER(?) OR schema_name = UPPER(?) ORDER BY short_name;
BEGIN
  code := DECODE(:FAULT_NO, 1,'BIFROST_REPLAY', 2,'REFUND_SIGN_FLIP', 3,'MERGE_TASK_STALLED', 4,'STATUS_DRIFT', 5,'VOLUME_DROP');
  IF (:code IS NULL) THEN
    RETURN 'Unknown fault number - use 1 to 5';
  END IF;
  OPEN c1 USING (TARGET, TARGET, TARGET);
  FOR r IN c1 DO
    sname := r.schema_name;
    fq := 'GLADSTONE_DQ_LITE.' || :sname;
    IF (:FAULT_NO = 1) THEN
      EXECUTE IMMEDIATE 'INSERT INTO ' || :fq || '.MEMBERS__MEMBER
         SELECT * REPLACE (''B-REPLAY-01'' AS _batch_id, CURRENT_TIMESTAMP() AS _loaded_at)
         FROM ' || :fq || '.MEMBERS__MEMBER WHERE status = ''ACTIVE'' ORDER BY member_id LIMIT 150';
      EXECUTE IMMEDIATE 'INSERT INTO ' || :fq || '._SYNC_META__MERGE_BATCH VALUES
         (''B-REPLAY-01'', ''RIVERSIDE'', ''MEMBERS__MEMBER'', 150, CURRENT_TIMESTAMP()),
         (''B-REPLAY-01'', ''RIVERSIDE'', ''MEMBERS__MEMBER'', 150, CURRENT_TIMESTAMP())';
      descr := 'Merge batch B-REPLAY-01 applied twice: 150 duplicate member rows; active members inflated';
      caught := 'no_duplicate_members (DUPLICATE_COUNT on MEMBERS__MEMBER.member_id)';
    ELSEIF (:FAULT_NO = 2) THEN
      EXECUTE IMMEDIATE 'INSERT INTO ' || :fq || '.SYSTEM__PAYMENT
         SELECT ''PY-NEG-'' || SEQ4(), ''RIVERSIDE'', ''M-'' || LPAD((1000 + SEQ4())::VARCHAR, 5, ''0''), CURRENT_DATE(),
                -250.00, ''PAYMENT'', ''B-SIGNBUG-01'', CURRENT_TIMESTAMP() FROM TABLE(GENERATOR(ROWCOUNT => 40))';
      descr := 'Refunds sent as negative PAYMENT rows (batch B-SIGNBUG-01); today''s net revenue collapses';
      caught := 'no_negative_amounts (NEGATIVE_COUNT on SYSTEM__PAYMENT.amount)';
    ELSEIF (:FAULT_NO = 3) THEN
      EXECUTE IMMEDIATE 'ALTER TASK ' || :fq || '.TSK_BIFROST_MERGE SUSPEND';
      descr := 'Bifrost merge task stopped: no new payments or bookings arrive';
      caught := 'payments_fresh_3min (FRESHNESS on SYSTEM__PAYMENT)';
    ELSEIF (:FAULT_NO = 4) THEN
      EXECUTE IMMEDIATE 'UPDATE ' || :fq || '.MEMBERS__MEMBER SET status = ''ACTIVE'', _batch_id = ''B-STATUS-01'',
         _loaded_at = CURRENT_TIMESTAMP() WHERE status = ''CANCELLED''';
      descr := 'Cancelled members re-sent as ACTIVE: Nova''s two active-member answers drift apart';
      caught := 'no_active_leavers (DQ_COMMON.ACTIVE_BUT_LEFT on MEMBERS__MEMBER)';
    ELSE
      EXECUTE IMMEDIATE 'DELETE FROM ' || :fq || '.SYSTEM__BOOKING WHERE booked_at >= DATEADD(day, -1, CURRENT_TIMESTAMP())';
      descr := 'Bookings from the last 24 hours missing (partial sync)';
      caught := 'ROW_COUNT anomaly detection on SYSTEM__BOOKING (needs ~2 weeks of history to flag)';
    END IF;
    INSERT INTO GLADSTONE_DQ_LITE.ADMIN.FAULT_LOG (schema_name, fault_no, fault_code, description, caught_by)
      VALUES (:sname, :FAULT_NO, :code, :descr, :caught);
    n := n + 1;
  END FOR;
  RETURN 'Fault ' || :FAULT_NO || ' (' || :code || ') injected into ' || n || ' pipeline(s)';
END;
$$;

CREATE OR REPLACE PROCEDURE RESET_ATTENDEE(SHORT_NAME VARCHAR)
RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER
AS $$
DECLARE
  u VARCHAR;
  res VARCHAR;
BEGIN
  SELECT MAX(user_name) INTO :u FROM GLADSTONE_DQ_LITE.ADMIN.ATTENDEES WHERE short_name = UPPER(:SHORT_NAME);
  DELETE FROM GLADSTONE_DQ_LITE.ADMIN.FAULT_LOG WHERE schema_name = 'RIVERSIDE_' || UPPER(:SHORT_NAME);
  CALL GLADSTONE_DQ_LITE.ADMIN.ADD_ATTENDEE(:SHORT_NAME, NULL) INTO :res;
  UPDATE GLADSTONE_DQ_LITE.ADMIN.ATTENDEES SET user_name = :u WHERE short_name = UPPER(:SHORT_NAME);
  RETURN :res || ' (fresh copy - checks removed, redo Session 2)';
END;
$$;

CREATE OR REPLACE PROCEDURE SUSPEND_ALL()
RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER
AS $$
DECLARE
  n NUMBER DEFAULT 0;
  dts ARRAY DEFAULT ARRAY_CONSTRUCT('REPORTING__ACTIVE_MEMBERS', 'REPORTING__DAILY_REVENUE', 'REPORTING__CLASS_UTILISATION');
  c1 CURSOR FOR SELECT schema_name FROM GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA
                WHERE schema_name LIKE 'RIVERSIDE\\_%' ESCAPE '\\' AND schema_name NOT LIKE '%\\_DCM' ESCAPE '\\';
BEGIN
  FOR r IN c1 DO
    EXECUTE IMMEDIATE 'ALTER TASK IF EXISTS GLADSTONE_DQ_LITE.' || r.schema_name || '.TSK_BIFROST_MERGE SUSPEND';
    EXECUTE IMMEDIATE 'ALTER TASK IF EXISTS GLADSTONE_DQ_LITE.' || r.schema_name || '.TSK_DQ_CIRCUIT_BREAKER SUSPEND';
    EXECUTE IMMEDIATE 'ALTER ALERT IF EXISTS GLADSTONE_DQ_LITE.' || r.schema_name || '.DQ_INCIDENT_ALERT SUSPEND';
    FOR i IN 0 TO ARRAY_SIZE(:dts) - 1 DO
      EXECUTE IMMEDIATE 'ALTER DYNAMIC TABLE IF EXISTS GLADSTONE_DQ_LITE.' || r.schema_name || '.' || GET(:dts, :i)::VARCHAR || ' SUSPEND';
    END FOR;
    n := n + 1;
  END FOR;
  ALTER DATABASE GLADSTONE_DQ_LITE UNSET DATA_QUALITY_MONITORING_SETTINGS;
  RETURN 'Suspended tasks, alerts and dynamic tables in ' || n || ' schema(s); notifications off';
END;
$$;

-- Facilitator views
CREATE OR REPLACE VIEW V_FAULTS AS
SELECT a.short_name, a.schema_name, f.fault_no, f.fault_code, f.description, f.caught_by, f.injected_at
FROM ATTENDEES a LEFT JOIN FAULT_LOG f ON f.schema_name = a.schema_name ORDER BY a.short_name, f.fault_no;

CREATE OR REPLACE VIEW V_ROOM_STATUS AS   -- who has checks on, and what is failing right now
WITH latest AS (
  SELECT s.table_schema, s.table_name, s.metric_name, s.expectation_name, s.expectation_violated, s.value, s.measurement_time
  FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS s
  JOIN GLADSTONE_DQ_LITE.INFORMATION_SCHEMA.SCHEMATA sc ON sc.schema_name = s.table_schema
  WHERE s.table_database = 'GLADSTONE_DQ_LITE' AND s.table_schema LIKE 'RIVERSIDE\\_%' ESCAPE '\\'
    AND s.measurement_time >= sc.created   -- ignore results from an earlier copy with the same name (reset / re-run)
  QUALIFY ROW_NUMBER() OVER (PARTITION BY table_schema, table_name, metric_name, expectation_name ORDER BY measurement_time DESC) = 1)
SELECT a.short_name, a.user_name, a.schema_name, COUNT(l.expectation_name) AS checks,
       COUNT_IF(l.expectation_violated) AS failing, ARRAY_AGG(DISTINCT IFF(l.expectation_violated, l.expectation_name, NULL)) AS failing_checks,
       MAX(l.measurement_time) AS last_measured
FROM ATTENDEES a LEFT JOIN latest l ON l.table_schema = a.schema_name
GROUP BY 1, 2, 3 ORDER BY 1;

-- ---------------------------------------------------------------------------
-- 8. Pre-flight checks (send the output to the facilitator)
-- ---------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;
SELECT CURRENT_ACCOUNT(), CURRENT_REGION(), SYSTEM$GET_SNOWFLAKE_PLATFORM_INFO();
SHOW DATA METRIC FUNCTIONS IN SCHEMA SNOWFLAKE.CORE;              -- DUPLICATE_COUNT, NEGATIVE_COUNT, FRESHNESS, ROW_COUNT ...
SHOW PARAMETERS LIKE 'CORTEX_ENABLED_CROSS_REGION' IN ACCOUNT;    -- CoCo Desktop needs cross-region inference

-- ---------------------------------------------------------------------------
-- 9. Create one pipeline per attendee (edit the list). "user" is optional and only grants the role.
-- ---------------------------------------------------------------------------
USE ROLE DQ_LITE_ADMIN;
USE WAREHOUSE DQ_LITE_WH;
-- CALL GLADSTONE_DQ_LITE.ADMIN.SETUP_ALL(PARSE_JSON('[{"name":"NIELS","user":"NJOHANSEN"},{"name":"AMY","user":"ASMITH"}]'));
-- Walk-in on the day:  CALL GLADSTONE_DQ_LITE.ADMIN.ADD_ATTENDEE('JOE', 'JBLOGGS');
-- (granting a role to a user needs ACCOUNTADMIN or SECURITYADMIN - run SETUP_ALL as ACCOUNTADMIN if you pass users)
