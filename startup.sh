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
python3 reload-service.py 2>&1 &
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
    
    # Start PostgREST on port 3000 (redirect stderr to stdout)
    /usr/local/bin/postgrest /tmp/postgrest.conf 2>&1 &
    POSTGREST_PID=$!
    
    echo "✅ PostgREST started on port 3000"
    echo "📊 REST API: http://localhost:3000"
else
    echo "⚠️  DATABASE_URL not set, PostgREST will not be started"
fi

# Start User's FastAPI application with hot reload using polling
# Use --reload-dir to limit watching to specific directories
# Use --reload-delay to add small delay before reload
echo "🚀 Starting User's FastAPI application with hot reload..."
uvicorn main:app \
  --host 0.0.0.0 \
  --port 8000 \
  --reload \
  --reload-dir /app/backend \
  --reload-delay 2 \
  --log-level info 2>&1 &
UVICORN_PID=$!

echo "✅ User's Backend started on port 8000 (hot reload enabled)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 User API:      http://localhost:8000"
echo "🔧 Reload Service: http://localhost:9000"
if [ ! -z "$DATABASE_URL" ]; then
    echo "📊 PostgREST:     http://localhost:3000"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Wait for all background processes
wait
