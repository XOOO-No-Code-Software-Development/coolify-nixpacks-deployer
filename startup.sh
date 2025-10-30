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
    
    # Set pgAdmin environment variables for non-interactive setup
    export PGADMIN_SETUP_EMAIL="${PGADMIN_EMAIL:-admin@admin.com}"
    export PGADMIN_SETUP_PASSWORD="${PGADMIN_PASSWORD:-admin}"
    
    # Create pgAdmin working directory
    mkdir -p /var/lib/pgadmin
    
    # Create servers.json at the DEFAULT location where pgAdmin looks for it
    # When installed via pip, pgAdmin looks for servers.json in /pgadmin4/ directory
    mkdir -p /pgadmin4
    cat > /pgadmin4/servers.json << 'EOF'
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
    sed -i "s/DB_HOST_PLACEHOLDER/${DB_HOST}/g" /pgadmin4/servers.json
    sed -i "s/DB_PORT_PLACEHOLDER/${DB_PORT}/g" /pgadmin4/servers.json
    sed -i "s/DB_NAME_PLACEHOLDER/${DB_NAME}/g" /pgadmin4/servers.json
    sed -i "s/DB_USER_PLACEHOLDER/${DB_USER}/g" /pgadmin4/servers.json
    
    # Create .pgpass file for password storage (PostgreSQL standard)
    # Format: hostname:port:database:username:password
    mkdir -p /var/lib/pgadmin/storage
    echo "${DB_HOST}:${DB_PORT}:${DB_NAME}:${DB_USER}:${DB_PASS}" > /var/lib/pgadmin/storage/.pgpass
    chmod 600 /var/lib/pgadmin/storage/.pgpass
    
    # Create config_local.py to configure pgAdmin for non-interactive pip installation
    cat > /opt/venv/lib/python3.11/site-packages/pgadmin4/config_local.py << 'PYEOF'
# Custom configuration for pip-based installation
import os

# Server mode with non-interactive setup
SERVER_MODE = True
MASTER_PASSWORD_REQUIRED = False

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
    echo "   Login: ${PGADMIN_SETUP_EMAIL}"
    echo "   Password: ${PGADMIN_SETUP_PASSWORD}"
    echo "   Servers file: /pgadmin4/servers.json"
    echo ""
    echo "📋 Database server to be pre-loaded:"
    echo "   Name: Chat Database"
    echo "   Host: ${DB_HOST}"
    echo "   Port: ${DB_PORT}"
    echo "   Database: ${DB_NAME}"
    echo "   User: ${DB_USER}"
    
    # Pre-initialize the pgAdmin database to avoid interactive prompts during gunicorn startup
    # This creates the SQLite database and runs migrations non-interactively
    echo "🔧 Pre-initializing pgAdmin database..."
    cd /opt/venv/lib/python3.11/site-packages/pgadmin4
    python - <<'PYINIT'
import os
import sys

# Set up environment
os.environ['SERVER_MODE'] = 'True'

# Import pgAdmin modules
try:
    from pgadmin import create_app
    from pgadmin.model import db, User, Server, ServerGroup
    from werkzeug.security import generate_password_hash
    
    print("Creating pgAdmin app...")
    app = create_app()
    
    with app.app_context():
        # Check if user already exists
        email = os.environ.get('PGADMIN_SETUP_EMAIL', 'admin@admin.com')
        user = User.query.filter_by(email=email).first()
        
        if not user:
            print(f"Creating initial user: {email}")
            password = os.environ.get('PGADMIN_SETUP_PASSWORD', 'admin')
            
            user = User(
                email=email,
                active=True,
                password=generate_password_hash(password)
            )
            db.session.add(user)
            db.session.commit()
            print("✓ User created successfully")
        else:
            print(f"✓ User {email} already exists")
    
    print("✓ pgAdmin database initialized")
    sys.exit(0)
    
except Exception as e:
    print(f"✗ Initialization failed: {e}")
    # Don't exit with error - let gunicorn try to initialize
    sys.exit(0)
PYINIT
    
    # Start pgAdmin using gunicorn
    echo "🚀 Starting pgAdmin with gunicorn..."
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