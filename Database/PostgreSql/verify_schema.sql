\pset pager off
SET TIME ZONE 'Asia/Yangon';

SELECT 'TABLES' AS metric, COUNT(*)::bigint AS value
FROM information_schema.tables WHERE table_schema = current_schema() AND table_type = 'BASE TABLE'
UNION ALL SELECT 'PRIMARY_KEYS', COUNT(*) FROM pg_constraint WHERE contype = 'p' AND connamespace = current_schema()::regnamespace
UNION ALL SELECT 'FOREIGN_KEYS', COUNT(*) FROM pg_constraint WHERE contype = 'f' AND connamespace = current_schema()::regnamespace
UNION ALL SELECT 'UNIQUE_CONSTRAINTS', COUNT(*) FROM pg_constraint WHERE contype = 'u' AND connamespace = current_schema()::regnamespace
ORDER BY metric;

SELECT current_setting('TimeZone') AS session_time_zone, CURRENT_TIMESTAMP AS current_myanmar_time;

SELECT table_name AS table_without_primary_key
FROM information_schema.tables t
WHERE t.table_schema = current_schema() AND t.table_type = 'BASE TABLE'
  AND NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    WHERE c.conrelid = format('%I.%I', t.table_schema, t.table_name)::regclass
      AND c.contype = 'p'
  )
ORDER BY table_name;

SELECT
  (SELECT COUNT(*) FROM "MENUS") AS menus,
  (SELECT COUNT(*) FROM "UNITS") AS units,
  (SELECT COUNT(*) FROM "MEAL_TYPES") AS meal_types,
  (SELECT COUNT(*) FROM "PAYMENT_METHODS") AS payment_methods;

SELECT
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = current_schema() AND table_name = 'USERS' AND column_name = 'USERNAME'
  ) AS users_has_username,
  to_regclass(format('%I.%I', current_schema(), 'AUTH_SESSIONS')) IS NOT NULL AS auth_sessions_exists,
  (SELECT COUNT(*) FROM "ROLES" WHERE "CODE" IN ('ADMIN', 'USER', 'SUPER_ADMIN') AND "IS_ACTIVE") AS active_auth_roles,
  to_regclass(format('%I.%I', current_schema(), 'ADMIN_ACCOUNT_REQUESTS')) IS NOT NULL AS admin_account_requests_exists,
  to_regclass(format('%I.%I', current_schema(), 'AUTH_EMAIL_CHALLENGES')) IS NOT NULL AS auth_email_challenges_exists,
  (SELECT COUNT(*)
   FROM "USERS" u
   WHERE u."ACCOUNT_STATUS" = 'ACTIVE'
     AND u."PASSWORD_HASH" IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM "USER_ROLES" ur
       INNER JOIN "ROLES" r ON r."ID" = ur."ROLE_ID"
       WHERE ur."USER_ID" = u."ID" AND ur."IS_ACTIVE" AND r."IS_ACTIVE" AND r."CODE" = 'ADMIN')
     AND EXISTS (
       SELECT 1
       FROM "USER_ROLES" ur
       INNER JOIN "ROLES" r ON r."ID" = ur."ROLE_ID"
       WHERE ur."USER_ID" = u."ID" AND ur."IS_ACTIVE" AND r."IS_ACTIVE" AND r."CODE" = 'SUPER_ADMIN')) AS active_master_admins;
