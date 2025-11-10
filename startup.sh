#!/bin/bash

# Function to handle shutdown
shutdown() {
    echo "Shutting down services..."
    kill $POSTGREST_PID $UVICORN_PID 2>/dev/null
    wait $POSTGREST_PID $UVICORN_PID 2>/dev/null
    exit 0
}

# Trap signals for graceful shutdown
trap shutdown SIGTERM SIGINT

# Activate virtual environment
source /opt/venv/bin/activate

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
    
    # Start PostgREST on port 3000 (redirect stderr to stdout)
    /usr/local/bin/postgrest /tmp/postgrest.conf 2>&1 &
    POSTGREST_PID=$!
    
    echo "✅ PostgREST started on port 3000"
    echo "📊 REST API: http://localhost:3000"
else
    echo "⚠️  DATABASE_URL not set, PostgREST will not be started"
fi

# Start the FastAPI application (redirect stderr to stdout)
echo "🚀 Starting FastAPI application..."
uvicorn main:app --host 0.0.0.0 --port 8000 2>&1 &
UVICORN_PID=$!

echo "✅ FastAPI started on port 8000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 API:       http://localhost:8000"
if [ ! -z "$DATABASE_URL" ]; then
    echo "📊 PostgREST: http://localhost:3000"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Monitor background processes and exit with their exit code if they fail
while true; do
    # Check if uvicorn is still running
    if ! kill -0 $UVICORN_PID 2>/dev/null; then
        wait $UVICORN_PID
        UVICORN_EXIT=$?
        echo "❌ FastAPI application exited with code $UVICORN_EXIT"
        
        # Kill PostgREST if it's running
        if [ ! -z "$POSTGREST_PID" ]; then
            kill $POSTGREST_PID 2>/dev/null
        fi
        
        exit $UVICORN_EXIT
    fi
    
    # Check if PostgREST is still running (only if it was started)
    if [ ! -z "$POSTGREST_PID" ] && ! kill -0 $POSTGREST_PID 2>/dev/null; then
        wait $POSTGREST_PID
        POSTGREST_EXIT=$?
        echo "❌ PostgREST exited with code $POSTGREST_EXIT"
        
        # Kill uvicorn
        kill $UVICORN_PID 2>/dev/null
        
        exit $POSTGREST_EXIT
    fi
    
    # Sleep briefly before checking again
    sleep 1
done