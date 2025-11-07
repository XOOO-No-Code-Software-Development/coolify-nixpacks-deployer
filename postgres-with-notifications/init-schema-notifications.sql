-- PostgreSQL Schema Change Notification Setup
-- This script automatically sets up real-time notifications for any DDL changes
-- (CREATE TABLE, ALTER TABLE, DROP TABLE, etc.)

-- Create notification function
-- This function sends a notification whenever a DDL command is executed
CREATE OR REPLACE FUNCTION notify_schema_change()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Send notification to 'schema_changed' channel with event details
  PERFORM pg_notify(
    'schema_changed',
    json_build_object(
      'type', TG_EVENT,           -- Event type (e.g., 'ddl_command_end')
      'tag', TG_TAG,              -- DDL command tag (e.g., 'CREATE TABLE', 'ALTER TABLE')
      'timestamp', now()::text    -- When the change happened
    )::text
  );
END;
$$;

-- Create event trigger
-- This trigger fires after any DDL command completes successfully
DROP EVENT TRIGGER IF EXISTS schema_change_trigger;
CREATE EVENT TRIGGER schema_change_trigger
  ON ddl_command_end
  EXECUTE FUNCTION notify_schema_change();

-- Log successful initialization
DO $$
BEGIN
  RAISE NOTICE '✅ Schema change notifications initialized successfully';
  RAISE NOTICE '📡 Clients can listen to the "schema_changed" channel';
END $$;
