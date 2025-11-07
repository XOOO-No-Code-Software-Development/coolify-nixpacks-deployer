# PostgreSQL with Schema Change Notifications

Custom PostgreSQL 16 Alpine image that automatically sets up real-time schema change notifications.

## Features

- **Base**: PostgreSQL 16 Alpine (lightweight and secure)
- **Auto-initialization**: Automatically sets up notification triggers on first database creation
- **Real-time DDL notifications**: Get notified of any schema changes (CREATE/ALTER/DROP TABLE, etc.)
- **Zero configuration**: Works out of the box, no manual setup required

## What Gets Installed

When a database is created with this image, it automatically:

1. Creates a `notify_schema_change()` function that sends notifications
2. Sets up an event trigger that fires on all DDL commands
3. Sends notifications to the `schema_changed` PostgreSQL channel

## Building the Image

### On Coolify Server (via SSH)

```bash
cd /path/to/coolify-nixpacks-deployer/postgres-with-notifications
bash build-postgres-image.sh
```

The script will:
- Build the image as `xooo-postgres-notifications:16`
- Store it locally on the Coolify server (not in a registry)
- Verify the installation

### Manual Build (Alternative)

```bash
sudo docker build -t xooo-postgres-notifications:16 .
```

## Using the Image

### In Coolify API (via code)

Update your database creation to use the custom image:

```typescript
const database = await coolifyClient.createPostgresDatabase({
  projectUuid: PROJECT_UUID,
  name: 'my-database',
  postgres_user: 'postgres',
  postgres_password: 'secure_password',
  postgres_db: 'mydb',
  image: 'xooo-postgres-notifications:16', // Use local custom image
  instantDeploy: true,
})
```

### Listening for Schema Changes

In your Node.js application:

```typescript
import postgres from 'postgres'

const sql = postgres(DATABASE_URL)

// Listen for schema change notifications
await sql.listen('schema_changed', (payload) => {
  const data = JSON.parse(payload)
  console.log('Schema changed!', {
    type: data.type,       // 'ddl_command_end'
    tag: data.tag,         // 'CREATE TABLE', 'ALTER TABLE', etc.
    timestamp: data.timestamp
  })
  
  // Handle the schema change
  // - Refresh your schema cache
  // - Update UI
  // - Trigger re-sync
  // etc.
})
```

## What Triggers Notifications

The following DDL commands will trigger notifications:

- `CREATE TABLE`
- `ALTER TABLE`
- `DROP TABLE`
- `CREATE INDEX`
- `DROP INDEX`
- `ALTER COLUMN`
- `ADD CONSTRAINT`
- `DROP CONSTRAINT`
- And any other DDL command

## Notification Payload

Each notification contains:

```json
{
  "type": "ddl_command_end",
  "tag": "CREATE TABLE",
  "timestamp": "2025-11-07 12:34:56.789+00"
}
```

## Files

- `Dockerfile` - Image definition based on postgres:16-alpine
- `init-schema-notifications.sql` - SQL script that sets up notifications
- `build-postgres-image.sh` - Build script for Coolify server
- `README.md` - This file

## How It Works

1. PostgreSQL Docker images execute any `.sql` files in `/docker-entrypoint-initdb.d/` on first initialization
2. Our `init-schema-notifications.sql` is copied to that directory
3. When Coolify creates a new database container, PostgreSQL automatically runs the init script
4. The event trigger and notification function are set up automatically

## Advantages Over Post-Creation Setup

✅ **No race conditions** - Set up before any tables are created  
✅ **Automatic** - No separate initialization API call needed  
✅ **Reliable** - Runs as part of PostgreSQL's initialization process  
✅ **Idempotent** - Safe to rebuild databases, won't fail if already exists  
✅ **Local storage** - No external registry needed, faster pulls

## Rebuilding

To rebuild the image (e.g., after updating the init script):

```bash
bash build-postgres-image.sh
```

The script will ask for confirmation before rebuilding.

## Verification

After building, verify the image:

```bash
# Check image exists
sudo docker images xooo-postgres-notifications

# Check init script is included
sudo docker run --rm xooo-postgres-notifications:16 \
  ls -lh /docker-entrypoint-initdb.d/

# Test database creation (optional - creates temp container)
sudo docker run --rm -e POSTGRES_PASSWORD=test xooo-postgres-notifications:16
```

## Integration

This image is used by:
- `lib/coolify-client.ts` - Database creation with custom image
- `lib/deployment-manager.ts` - Deployment flow with database setup

## Related Documentation

- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres)
- [PostgreSQL Event Triggers](https://www.postgresql.org/docs/current/event-trigger-definition.html)
- [PostgreSQL LISTEN/NOTIFY](https://www.postgresql.org/docs/current/sql-notify.html)
