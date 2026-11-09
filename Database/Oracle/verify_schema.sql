SET PAGESIZE 100
SET LINESIZE 200

SELECT 'TABLES' metric, COUNT(*) value FROM user_tables
UNION ALL
SELECT 'PRIMARY_KEYS', COUNT(*) FROM user_constraints WHERE constraint_type = 'P'
UNION ALL
SELECT 'FOREIGN_KEYS', COUNT(*) FROM user_constraints WHERE constraint_type = 'R'
UNION ALL
SELECT 'TIMESTAMP_WITH_TIME_ZONE', COUNT(*) FROM user_tab_columns WHERE data_type LIKE 'TIMESTAMP%TIME ZONE%';

SELECT SESSIONTIMEZONE session_time_zone,
       CURRENT_TIMESTAMP current_myanmar_time
FROM dual;

SELECT table_name
FROM user_tables table_without_pk
WHERE NOT EXISTS (
  SELECT 1
  FROM user_constraints primary_key
  WHERE primary_key.table_name = table_without_pk.table_name
    AND primary_key.constraint_type = 'P'
)
ORDER BY table_name;
