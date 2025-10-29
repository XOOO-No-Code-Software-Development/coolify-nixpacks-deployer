#!/bin/bash

# Function to handle shutdown
shutdown() {
    echo "Shutting down services..."
    kill $PGWEB_PID $UVICORN_PID 2>/dev/null
    wait $PGWEB_PID $UVICORN_PID 2>/dev/null
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
    export PGWEB_DATABASE_URL="$DATABASE_URL"
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

# Start the FastAPI application
echo "🚀 Starting FastAPI application..."
uvicorn main:app --host 0.0.0.0 --port 8000 &
UVICORN_PID=$!

echo "✅ FastAPI started on port 8000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 API:      http://localhost:8000"
if [ ! -z "$DATABASE_URL" ]; then
    echo "🗄️  pgweb:    http://localhost:8081"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Wait for all background processes
wait