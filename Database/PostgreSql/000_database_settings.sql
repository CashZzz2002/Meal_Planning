-- Keep every new database session's display/input timezone in Myanmar local time.
DO $$
BEGIN
  EXECUTE format('ALTER DATABASE %I SET timezone TO %L', current_database(), 'Asia/Yangon');
  EXECUTE format('ALTER ROLE %I SET timezone TO %L', current_user, 'Asia/Yangon');
END
$$;
