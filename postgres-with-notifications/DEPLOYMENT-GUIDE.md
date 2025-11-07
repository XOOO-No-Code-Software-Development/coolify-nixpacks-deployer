# PostgreSQL with Notifications - Deployment Guide

## Quick Start

### 1. Build the Image on Coolify Server

SSH into your Coolify server and run:

```bash
# Navigate to the project directory
cd /path/to/coolify-nixpacks-deployer/postgres-with-notifications

# Build the image locally
bash build-postgres-image.sh
```

This will create the `xooo-postgres-notifications:16` image locally on the Coolify server.

### 2. Verify the Build

Check that the image was created successfully:

```bash
sudo docker images | grep xooo-postgres-notifications
```

You should see:
```
xooo-postgres-notifications   16      <image-id>   <size>   <time>
```

### 3. Test with a New Database

The image is now ready to use! When you create a new database through the platform, it will automatically:

1. Use the custom `xooo-postgres-notifications:16` image
2. Initialize with schema change notification triggers
3. Be ready to send notifications on any DDL changes

## What's Included

### Initialization Script

The image includes `/docker-entrypoint-initdb.d/init-schema-notifications.sql` which automatically:

- Creates `notify_schema_change()` function
- Sets up an event trigger for all DDL commands
- Logs successful initialization

### Notification Details

**Channel**: `schema_changed`

**Payload Format**:
```json
{
  "type": "ddl_command_end",
  "tag": "CREATE TABLE",
  "timestamp": "2025-11-07T12:34:56.789Z"
}
```

**Triggers On**:
- CREATE TABLE
- ALTER TABLE
- DROP TABLE
- CREATE INDEX
- DROP INDEX
- ALTER COLUMN
- And all other DDL commands

## Usage in Application Code

### Listening for Schema Changes

```typescript
import postgres from 'postgres'

const sql = postgres(DATABASE_URL)

// Start listening
await sql.listen('schema_changed', (payload) => {
  const event = JSON.parse(payload)
  console.log(`Schema changed: ${event.tag} at ${event.timestamp}`)
  
  // Your handler logic here
  // - Refresh schema cache
  // - Update UI
  // - Trigger re-sync
})

// Stop listening
await sql.unlisten('schema_changed')
```

### Example Use Cases

1. **Real-time Schema Cache Updates**
   ```typescript
   await sql.listen('schema_changed', async () => {
     await refreshSchemaCache()
   })
   ```

2. **UI Notifications**
   ```typescript
   await sql.listen('schema_changed', (payload) => {
     const event = JSON.parse(payload)
     notifyUser(`Database schema updated: ${event.tag}`)
   })
   ```

3. **Audit Logging**
   ```typescript
   await sql.listen('schema_changed', async (payload) => {
     const event = JSON.parse(payload)
     await logSchemaChange({
       operation: event.tag,
       timestamp: event.timestamp,
       user: getCurrentUser()
     })
   })
   ```

## Updated Files

The following files now use `xooo-postgres-notifications:16` by default:

1. **lib/coolify-client.ts**
   - `createPostgresDatabase()` default image parameter

2. **app/api/deployment/create/route.ts**
   - Database creation in deployment route

3. **lib/deployment-manager.ts**
   - DeploymentManager database creation

4. **test-database-creation.js**
   - Test script for database creation

## Troubleshooting

### Image Not Found Error

If you get "image not found" error:

1. Verify the image exists on Coolify server:
   ```bash
   sudo docker images xooo-postgres-notifications
   ```

2. If missing, rebuild:
   ```bash
   cd postgres-with-notifications
   bash build-postgres-image.sh
   ```

### Notifications Not Working

1. Check that the database was created with the custom image
2. Verify initialization logs in database container:
   ```bash
   sudo docker logs <database-container-id> | grep "Schema change notifications"
   ```
3. Should see: "✅ Schema change notifications initialized successfully"

### Testing Notifications

Connect to your database and test:

```sql
-- Start listening in one session
LISTEN schema_changed;

-- In another session, trigger a notification
CREATE TABLE test_table (id INT);

-- You should receive a notification in the first session
```

## Maintenance

### Updating the Init Script

1. Edit `init-schema-notifications.sql`
2. Rebuild the image:
   ```bash
   bash build-postgres-image.sh
   ```
3. New databases will use the updated script
4. Existing databases won't be affected (init only runs on first creation)

### Version Management

The image uses tag `16` (matching PostgreSQL 16). To create a new version:

1. Edit `build-postgres-image.sh` and change `IMAGE_TAG`
2. Update references in code to use new tag
3. Rebuild the image

## Security Notes

- The image is stored locally on Coolify server (not in public registry)
- No sensitive data in the image
- Notification payloads only contain DDL command metadata (no data)
- LISTEN/NOTIFY is session-based (notifications only go to connected clients)

## Performance

- Minimal overhead (triggers are lightweight)
- Notifications are asynchronous
- No performance impact on regular queries
- Only fires on DDL changes (not on data operations)

## Support

For issues or questions:
1. Check container logs
2. Verify image was built correctly
3. Test with manual `LISTEN`/`NOTIFY` in PostgreSQL
4. Review initialization script logs

## Related Documentation

- [Main README](./README.md) - Detailed feature documentation
- [PostgreSQL Event Triggers](https://www.postgresql.org/docs/current/event-triggers.html)
- [PostgreSQL LISTEN/NOTIFY](https://www.postgresql.org/docs/current/sql-listen.html)
