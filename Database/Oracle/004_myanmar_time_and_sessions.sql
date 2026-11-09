-- Business time is Myanmar local time. Values retain the +06:30 offset.
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

ALTER SESSION SET TIME_ZONE = 'Asia/Yangon';

BEGIN
  FOR timestamp_column IN (
    SELECT table_name, column_name
    FROM user_tab_columns
    WHERE data_type LIKE 'TIMESTAMP%'
      AND data_type NOT LIKE '%TIME ZONE%'
    ORDER BY table_name, column_id
  ) LOOP
    EXECUTE IMMEDIATE
      'ALTER TABLE "' || timestamp_column.table_name || '" MODIFY ("' ||
      timestamp_column.column_name || '" TIMESTAMP(6) WITH TIME ZONE)';
  END LOOP;
END;
/

CREATE TABLE "USER_SESSIONS" (
  "ID"                  RAW(16)                         NOT NULL,
  "USER_ID"             RAW(16)                         NOT NULL,
  "REFRESH_TOKEN_HASH"  VARCHAR2(200 CHAR)              NOT NULL,
  "DEVICE_NAME"         VARCHAR2(1000 CHAR)             NULL,
  "CREATED_AT"          TIMESTAMP(6) WITH TIME ZONE     NOT NULL,
  "EXPIRES_AT"          TIMESTAMP(6) WITH TIME ZONE     NOT NULL,
  "REVOKED_AT"          TIMESTAMP(6) WITH TIME ZONE     NULL,
  CONSTRAINT "PK_USER_SESSIONS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_USER_SESSIONS_TOKEN" UNIQUE ("REFRESH_TOKEN_HASH"),
  CONSTRAINT "FK_USER_SESSIONS_USER" FOREIGN KEY ("USER_ID") REFERENCES "USERS" ("ID")
);

CREATE INDEX "IX_USER_SESSIONS_USER" ON "USER_SESSIONS" ("USER_ID");
CREATE INDEX "IX_USER_SESSIONS_EXPIRY" ON "USER_SESSIONS" ("EXPIRES_AT");

COMMIT;
