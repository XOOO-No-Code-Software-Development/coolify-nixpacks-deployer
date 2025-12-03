#!/bin/bash

# Function to handle shutdown
shutdown() {
    echo "Shutting down services..."
    kill $RELOAD_SERVICE_PID $POSTGREST_PID $UVICORN_PID 2>/dev/null
    wait $RELOAD_SERVICE_PID $POSTGREST_PID $UVICORN_PID 2>/dev/null
    exit 0
}

# Trap signals for graceful shutdown
trap shutdown SIGTERM SIGINT

# Activate virtual environment
source /opt/venv/bin/activate

# Initial source download (only on first boot)
if [ ! -f "main.py" ]; then
  echo "📦 First boot - downloading initial source..."
  bash download-source.sh
fi

# Start System Reload Service (port 9000) - INDEPENDENT OF USER CODE
echo "🔧 Starting System Reload Service on port 9000..."
python3 reload-service.py 2>&1 | while IFS= read -r line; do echo "[HOTRELOAD] $line"; done &
RELOAD_SERVICE_PID=$!
echo "✅ Reload Service started (PID: $RELOAD_SERVICE_PID)"

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
    cat > /tmp/postgrest.conf << PGCONF
db-uri = "${DB_URI}"
db-anon-role = "postgres"
db-schema = "public"
server-host = "0.0.0.0"
server-port = 3000
PGCONF
    
    # Start PostgREST on port 3000 with log prefix
    /usr/local/bin/postgrest /tmp/postgrest.conf 2>&1 | while IFS= read -r line; do echo "[POSTGREST] $line"; done &
    POSTGREST_PID=$!
    
    echo "✅ PostgREST started on port 3000"
    echo "📊 REST API: http://localhost:3000"
else
    echo "⚠️  DATABASE_URL not set, PostgREST will not be started"
fi

# Start User's FastAPI application WITHOUT auto-reload
# Reload will be triggered manually via reload-service.py
# This approach:
# - Avoids "too many open files" error
# - Gives us full control over when reload happens
# - Reload is triggered by platform via HTTP call to port 9000
echo "🚀 Starting User's FastAPI application..."
bash start-backend.sh &
UVICORN_PID=$!

echo "✅ User's Backend started on port 8000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 User API:      http://localhost:8000"
echo "🔧 Reload Service: http://localhost:9000"
if [ ! -z "$DATABASE_URL" ]; then
    echo "📊 PostgREST:     http://localhost:3000"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ℹ️  Hot reload: Managed by reload service on port 9000"
echo ""
echo "📋 Log Filters Available:"
echo "   - [HOTRELOAD] - Reload service logs"
echo "   - [POSTGREST] - Database REST API logs"
echo "   - [BACKEND]   - User's FastAPI application logs"

# Wait for all background processes
wait
