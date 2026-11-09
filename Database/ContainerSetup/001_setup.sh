#!/bin/bash
set -euo pipefail

if [[ -z "${APP_USER_PASSWORD:-}" ]]; then
  echo "APP_USER_PASSWORD is required." >&2
  exit 1
fi

sqlplus -s / as sysdba <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
ALTER SESSION SET CONTAINER = ${ORACLE_PDB};
DECLARE
  user_count PLS_INTEGER;
BEGIN
  SELECT COUNT(*) INTO user_count FROM dba_users WHERE username = 'MEAL_PLANNER';
  IF user_count = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER MEAL_PLANNER IDENTIFIED BY "${APP_USER_PASSWORD}" DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS';
    EXECUTE IMMEDIATE 'GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE TO MEAL_PLANNER';
  END IF;
END;
/
EXIT
SQL

sqlplus -s /nolog <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
CONNECT MEAL_PLANNER/"${APP_USER_PASSWORD}"@localhost:1521/${ORACLE_PDB}
@/opt/oracle/scripts/custom/001_schema.sql
@/opt/oracle/scripts/custom/002_primary_keys.sql
@/opt/oracle/scripts/custom/003_foreign_key_indexes.sql
@/opt/oracle/scripts/custom/004_myanmar_time_and_sessions.sql
@/opt/oracle/scripts/custom/005_seed_reference_data.sql
@/opt/oracle/scripts/custom/verify_schema.sql
EXIT
SQL
