-- Adds relational primary keys required by EF Core tracking.
-- The supplied schema declares ID as UNIQUE NOT NULL but does not declare primary keys.
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
  FOR table_record IN (
    SELECT table_name
    FROM user_tab_columns columns_with_id
    WHERE column_name = 'ID'
      AND NOT EXISTS (
        SELECT 1
        FROM user_constraints existing_pk
        WHERE existing_pk.table_name = columns_with_id.table_name
          AND existing_pk.constraint_type = 'P'
      )
    ORDER BY table_name
  ) LOOP
    EXECUTE IMMEDIATE
      'ALTER TABLE "' || table_record.table_name || '" ADD CONSTRAINT "PK_' ||
      SUBSTR(table_record.table_name, 1, 120) || '" PRIMARY KEY ("ID")';
  END LOOP;
END;
/

COMMIT;
