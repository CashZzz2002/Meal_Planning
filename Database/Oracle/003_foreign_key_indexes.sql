-- Adds an index for every foreign-key column set. Duplicate column-list indexes are skipped.
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
  index_number PLS_INTEGER := 0;
  column_list VARCHAR2(32767);
BEGIN
  FOR foreign_key IN (
    SELECT table_name, constraint_name
    FROM user_constraints
    WHERE constraint_type = 'R'
    ORDER BY table_name, constraint_name
  ) LOOP
    SELECT LISTAGG('"' || column_name || '"', ',') WITHIN GROUP (ORDER BY position)
    INTO column_list
    FROM user_cons_columns
    WHERE constraint_name = foreign_key.constraint_name;

    index_number := index_number + 1;
    BEGIN
      EXECUTE IMMEDIATE
        'CREATE INDEX "IX_FK_' || TO_CHAR(index_number, 'FM000') || '" ON "' ||
        foreign_key.table_name || '" (' || column_list || ')';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -1408 THEN
          RAISE;
        END IF;
    END;
  END LOOP;
END;
/

COMMIT;
