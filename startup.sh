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
    DB_URL="${DATABASE_URL}"
    
    # Extract database connection details
    DB_USER=$(echo $DB_URL | sed -n 's/.*:\/\/\([^:]*\):.*@.*/\1/p')
    DB_PASS=$(echo $DB_URL | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
    DB_HOST=$(echo $DB_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
    DB_PORT=$(echo $DB_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    DB_NAME=$(echo $DB_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')
    
    # Create pgAdmin config and data directories
    mkdir -p /tmp/pgadmin/data /tmp/pgadmin/sessions
    
    # Create config_local.py to override pgAdmin settings
    cat > /opt/venv/lib/python3.11/site-packages/pgadmin4/config_local.py << 'PYEOF'
import os
SERVER_MODE = False
MASTER_PASSWORD_REQUIRED = False
DEFAULT_SERVER = '0.0.0.0'
DEFAULT_SERVER_PORT = 8081
DATA_DIR = '/tmp/pgadmin/data'
LOG_FILE = '/tmp/pgadmin/pgadmin4.log'
SQLITE_PATH = '/tmp/pgadmin/data/pgadmin4.db'
SESSION_DB_PATH = '/tmp/pgadmin/sessions'
STORAGE_DIR = '/tmp/pgadmin/storage'
WTF_CSRF_ENABLED = False
PYEOF
    
    # Set pgAdmin environment variables for non-interactive setup
    export PGADMIN_SETUP_EMAIL="${PGADMIN_EMAIL:-admin@admin.com}"
    export PGADMIN_SETUP_PASSWORD="${PGADMIN_PASSWORD:-admin}"
    
    # Create servers.json for automatic connection
    cat > /tmp/pgadmin/servers.json << EOF
{
  "Servers": {
    "1": {
      "Name": "Chat Database",
      "Group": "Servers",
      "Host": "${DB_HOST}",
      "Port": ${DB_PORT},
      "MaintenanceDB": "${DB_NAME}",
      "Username": "${DB_USER}",
      "SSLMode": "disable",
      "PassFile": "/tmp/pgadmin/.pgpass"
    }
  }
}
EOF
    
    # Create .pgpass file for password storage
    echo "${DB_HOST}:${DB_PORT}:${DB_NAME}:${DB_USER}:${DB_PASS}" > /tmp/pgadmin/.pgpass
    chmod 600 /tmp/pgadmin/.pgpass
    
    # Initialize pgAdmin database with setup script
    cd /opt/venv/lib/python3.11/site-packages/pgadmin4
    python3 -c "
import sys
sys.path.insert(0, '.')
from pgadmin.setup import setup_db
from pgadmin import create_app
app = create_app()
with app.app_context():
    setup_db(app)
" 2>&1 | grep -v "NOTE:" | grep -v "Enter" || true
    
    # Load server configuration
    if [ -f /tmp/pgadmin/servers.json ]; then
        python3 setup.py --load-servers /tmp/pgadmin/servers.json --user "${PGADMIN_SETUP_EMAIL}" 2>&1 | grep -v "NOTE:" | grep -v "Enter" || true
    fi
    
    # Start pgAdmin on port 8081 using gunicorn
    cd /tmp/pgadmin
    gunicorn --bind 0.0.0.0:8081 --workers=1 --threads=25 --chdir /opt/venv/lib/python3.11/site-packages/pgadmin4 pgAdmin4:app &
    PGADMIN_PID=$!
    
    echo "✅ pgAdmin started on port 8081"
    echo "📊 Database UI: http://localhost:8081"
    echo "   Email: ${PGADMIN_DEFAULT_EMAIL}"
    echo "   Password: ${PGADMIN_DEFAULT_PASSWORD}"
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