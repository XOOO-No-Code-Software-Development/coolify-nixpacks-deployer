#!/bin/bash

# Function to handle shutdown
shutdown() {
    echo "Shutting down services..."
    kill $PGWEB_PID $POSTGREST_PID $UVICORN_PID 2>/dev/null
    wait $PGWEB_PID $POSTGREST_PID $UVICORN_PID 2>/dev/null
    exit 0
}

# Trap signals for graceful shutdown
trap shutdown SIGTERM SIGINT

# Activate virtual environment
source /opt/venv/bin/activate

# Start pgweb in the background if DATABASE_URL is set
if [ ! -z "$DATABASE_URL" ]; then
    echo "🗄️  Starting pgweb database interface..."
    
    # Set pgweb configuration
    # Add sslmode=disable to the DATABASE_URL if it doesn't have SSL params
    if [[ "$DATABASE_URL" != *"sslmode="* ]]; then
        export PGWEB_DATABASE_URL="${DATABASE_URL}?sslmode=disable"
    else
        export PGWEB_DATABASE_URL="$DATABASE_URL"
    fi
    
    export PGWEB_URL_PREFIX="/pgweb"
    export PGWEB_SESSIONS="true"
    export PGWEB_LOCK_SESSION="false"
    
    # Optional: Set basic auth if credentials are provided
    if [ ! -z "$PGWEB_AUTH_USER" ] && [ ! -z "$PGWEB_AUTH_PASS" ]; then
        echo "🔒 pgweb authentication enabled"
    fi
    
    # Start pgweb on port 8081
    /usr/local/bin/pgweb --bind=0.0.0.0 --listen=8081 &
    PGWEB_PID=$!
    
    echo "✅ pgweb started on port 8081 (accessible at /pgweb)"
    echo "📊 Database interface: http://localhost:8081"
else
    echo "⚠️  DATABASE_URL not set, pgweb will not be started"
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
    echo "🗄️  pgweb:     http://localhost:8081"
    echo "🔌 PostgREST: http://localhost:3000"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Wait for all background processes
wait