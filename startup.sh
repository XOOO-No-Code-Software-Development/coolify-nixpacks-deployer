#!/bin/bash

# Function to handle shutdown
shutdown() {
    echo "Shutting down services..."
    kill $PGADMIN_PID $POSTGREST_PID $UVICORN_PID 2>/dev/null
    wait $PGADMIN_PID $POSTGREST_PID $UVICORN_PID 2>/dev/null
    exit 0
}

# Trap signals for graceful shutdown
trap shutdown SIGTERM SIGINT

# Activate virtual environment
source /opt/venv/bin/activate

# Start pgAdmin in the background if DATABASE_URL is set
if [ ! -z "$DATABASE_URL" ]; then
    echo "🗄️  Starting pgAdmin..."
    
    # Parse DATABASE_URL to extract connection details
    # Format: postgresql://user:pass@host:port/dbname
    DB_USER=$(echo $DATABASE_URL | sed -n 's/.*:\/\/\([^:]*\):.*@.*/\1/p')
    DB_PASS=$(echo $DATABASE_URL | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
    DB_HOST=$(echo $DATABASE_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
    DB_PORT=$(echo $DATABASE_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    DB_NAME=$(echo $DATABASE_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')
    
    # Set pgAdmin environment variables FIRST (before any initialization)
    # These must be set before pgAdmin starts to avoid interactive prompts
    export PGADMIN_DEFAULT_EMAIL="${PGADMIN_EMAIL:-admin@admin.com}"
    export PGADMIN_DEFAULT_PASSWORD="${PGADMIN_PASSWORD:-admin}"
    export PGADMIN_SERVER_JSON_FILE="/var/lib/pgadmin/servers.json"
    export PGADMIN_LISTEN_PORT=8081
    export PGADMIN_DISABLE_POSTFIX=1
    
    # Create pgAdmin working directory
    mkdir -p /var/lib/pgadmin
    
    # Create servers.json for automatic server pre-loading
    # Based on: https://www.pgadmin.org/docs/pgadmin4/latest/import_export_servers.html#json-format
    cat > /var/lib/pgadmin/servers.json << 'EOF'
{
  "Servers": {
    "1": {
      "Name": "Chat Database",
      "Group": "Servers",
      "Host": "DB_HOST_PLACEHOLDER",
      "Port": DB_PORT_PLACEHOLDER,
      "MaintenanceDB": "DB_NAME_PLACEHOLDER",
      "Username": "DB_USER_PLACEHOLDER",
      "SSLMode": "prefer",
      "ConnectionParameters": {
        "sslmode": "prefer",
        "connect_timeout": 10
      }
    }
  }
}
EOF
    
    # Replace placeholders with actual values
    sed -i "s/DB_HOST_PLACEHOLDER/${DB_HOST}/g" /var/lib/pgadmin/servers.json
    sed -i "s/DB_PORT_PLACEHOLDER/${DB_PORT}/g" /var/lib/pgadmin/servers.json
    sed -i "s/DB_NAME_PLACEHOLDER/${DB_NAME}/g" /var/lib/pgadmin/servers.json
    sed -i "s/DB_USER_PLACEHOLDER/${DB_USER}/g" /var/lib/pgadmin/servers.json
    
    # Create .pgpass file for password storage (PostgreSQL standard)
    # Format: hostname:port:database:username:password
    mkdir -p /var/lib/pgadmin/storage
    echo "${DB_HOST}:${DB_PORT}:${DB_NAME}:${DB_USER}:${DB_PASS}" > /var/lib/pgadmin/storage/.pgpass
    chmod 600 /var/lib/pgadmin/storage/.pgpass
    
    # Create config_local.py to configure pgAdmin for non-interactive setup
    cat > /opt/venv/lib/python3.11/site-packages/pgadmin4/config_local.py << 'PYEOF'
# Custom configuration for containerized deployment
import os

# Server mode with non-interactive setup
SERVER_MODE = True
MASTER_PASSWORD_REQUIRED = False

# Use environment variables for initial user setup
DEFAULT_SERVER = '0.0.0.0'

# Override paths to use /var/lib/pgadmin
DATA_DIR = '/var/lib/pgadmin'
LOG_FILE = '/var/lib/pgadmin/pgadmin4.log'
SQLITE_PATH = '/var/lib/pgadmin/pgadmin4.db'
SESSION_DB_PATH = '/var/lib/pgadmin/sessions'
STORAGE_DIR = '/var/lib/pgadmin/storage'

# Security settings
WTF_CSRF_CHECK_DEFAULT = False
WTF_CSRF_ENABLED = False
PYEOF
    
    echo "📋 pgAdmin configuration:"
    echo "   Login: ${PGADMIN_DEFAULT_EMAIL}"
    echo "   Password: ${PGADMIN_DEFAULT_PASSWORD}"
    echo "   Server config: ${PGADMIN_SERVER_JSON_FILE}"
    echo ""
    echo "📋 Database server to be pre-loaded:"
    echo "   Name: Chat Database"
    echo "   Host: ${DB_HOST}"
    echo "   Port: ${DB_PORT}"
    echo "   Database: ${DB_NAME}"
    echo "   User: ${DB_USER}"
    
    # Start pgAdmin using gunicorn
    cd /var/lib/pgadmin
    gunicorn --bind 0.0.0.0:8081 \
             --workers=1 \
             --threads=25 \
             --timeout=60 \
             --chdir /opt/venv/lib/python3.11/site-packages/pgadmin4 \
             pgAdmin4:app &
    PGADMIN_PID=$!
    
    echo "✅ pgAdmin started on port 8081"
    echo "   Access at: https://[chatid].demo.xooo.io:8081"
    echo "   Server 'Chat Database' will be available after first login"
else
    echo "⚠️  DATABASE_URL not set, pgAdmin will not be started"
fi

# Start PostgREST if DATABASE_URL is set
if [ ! -z "$DATABASE_URL" ]; then
    echo "🗄️  Starting PostgREST REST API..."
    
    # Parse DATABASE_URL to extract connection details
    # Format: postgresql://user:pass@host:port/dbname
    DB_URI="${DATABASE_URL}"
    if [[ "$DB_URI" != *"sslmode="* ]]; then
        DB_URI="${DB_URI}?sslmode=disable"
    fi
    
    # Create PostgREST config file
    cat > /tmp/postgrest.conf << EOF
db-uri = "${DB_URI}"
db-anon-role = "postgres"
db-schema = "public"
server-host = "0.0.0.0"
server-port = 3000
EOF
    
    # Start PostgREST on port 3000
    /usr/local/bin/postgrest /tmp/postgrest.conf &
    POSTGREST_PID=$!
    
    echo "✅ PostgREST started on port 3000"
    echo "📊 REST API: http://localhost:3000"
else
    echo "⚠️  DATABASE_URL not set, PostgREST will not be started"
fi

# Start the FastAPI application
echo "🚀 Starting FastAPI application..."
uvicorn main:app --host 0.0.0.0 --port 8000 &
UVICORN_PID=$!

echo "✅ FastAPI started on port 8000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 API:       http://localhost:8000"
if [ ! -z "$DATABASE_URL" ]; then
    echo "🗄️  pgAdmin:   http://localhost:8081"
    echo "🔌 PostgREST: http://localhost:3000"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Wait for all background processes
wait