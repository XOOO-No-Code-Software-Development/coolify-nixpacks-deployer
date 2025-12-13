#!/bin/bash

# Increase file descriptor limit for Next.js/Turbopack file watching
# Default is often 1024, which is too low for large projects
ulimit -n 65536 || echo "⚠️  Could not increase file descriptor limit"

# Function to handle shutdown
shutdown() {
    echo "Shutting down services..."
    kill $RELOAD_SERVICE_PID $NEXTJS_PID $UVICORN_PID $POSTGREST_PID 2>/dev/null
    wait $RELOAD_SERVICE_PID $NEXTJS_PID $UVICORN_PID $POSTGREST_PID 2>/dev/null
    exit 0
}

# Trap signals for graceful shutdown
trap shutdown SIGTERM SIGINT

# Initial source download (only on first boot)
if [ ! -f "package.json" ]; then
  echo "📦 First boot - downloading initial source..."
  
  # Check if we have deployment configuration
  if [ -z "$PROJECT_ID" ] || [ -z "$CHAT_ID" ] || [ -z "$DEPLOYMENT_ID" ]; then
    echo "⚠️  No deployment configuration found"
    echo "📦 Using empty_template as default application"
    
    # Copy empty_template to root
    if [ -d "empty_template" ]; then
      echo "📂 Copying empty_template files..."
      cp -r empty_template/* .
      echo "✅ Empty template loaded successfully"
    else
      echo "❌ ERROR: empty_template directory not found"
      exit 1
    fi
  else
    # Download from Vercel API
    bash download-source.sh
  fi
fi

# Start System Reload Service (port 9000) - INDEPENDENT OF USER CODE
echo "🔧 Starting System Reload Service on port 9000..."
python3 -u reload-service.py 2>&1 | sed -u 's/^/[Reload Service] /' &
RELOAD_SERVICE_PID=$!
echo "✅ Reload Service started (PID: $RELOAD_SERVICE_PID)"

# Start Next.js Frontend (port 3000) from root directory
echo "🎨 Starting Next.js Frontend..."
if [ -f "package.json" ]; then
    echo "🔥 Starting Next.js in development mode with hot reload..."
    # Start Next.js in a loop so it auto-restarts on reload
    (
        while true; do
            # Wait if reload is in progress
            while [ -f /tmp/reload_in_progress ]; do
                sleep 1
            done
            
            echo "[Next.js] Starting server..."
            PORT=3000 NODE_ENV= npm run dev 2>&1 | sed -u 's/^/[Next.js] /'
            echo "[Next.js] Server stopped. Restarting in 2 seconds..."
            sleep 2
        done
    ) &
    NEXTJS_PID=$!
    echo "✅ Next.js Frontend started in dev mode on port 3000 (PID: $NEXTJS_PID)"
else
    echo "⚠️  package.json not found, skipping Next.js startup"
    NEXTJS_PID=""
fi

# Start Python FastAPI Backend (port 8000) from backend folder
echo "🚀 Starting Python FastAPI Backend monitor..."
# Always start the loop, even if backend doesn't exist yet
# It will wait for backend to appear (e.g., after first reload)
(
    # Activate virtual environment if it exists
    if [ -d "/opt/venv" ]; then
        source /opt/venv/bin/activate
    fi
    
    while true; do
        # Wait if reload is in progress
        while [ -f /tmp/reload_in_progress ]; do
            echo "[BACKEND] Waiting for reload to complete..."
            sleep 1
        done
        
        # Check if backend/main.py exists
        if [ ! -f "backend/main.py" ]; then
            # Only log once when first checking, then wait silently
            if [ ! -f /tmp/fastapi_waiting ]; then
                echo "[BACKEND] ⚠️  backend/main.py not found, waiting..."
                touch /tmp/fastapi_waiting
            fi
            sleep 5
            continue
        fi
        
        # Backend exists, clear waiting flag and start server
        rm -f /tmp/fastapi_waiting
        echo "[BACKEND] Starting server..."
        cd backend
        
        # Start uvicorn in background and capture its PID
        # Redirect to a file, then tail it with prefix in a separate process
        uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/uvicorn.log 2>&1 &
        UVICORN_PID=$!
        echo $UVICORN_PID > /tmp/fastapi.pid
        
        # Tail the log file and add prefix
        tail -f /tmp/uvicorn.log 2>/dev/null | sed -u 's/^/[BACKEND] /' &
        TAIL_PID=$!
        
        # Wait for uvicorn to exit
        wait $UVICORN_PID 2>/dev/null || true
        EXIT_CODE=$?
        
        # Clean up
        kill $TAIL_PID 2>/dev/null || true
        rm -f /tmp/fastapi.pid
        
        cd ..
        echo "[BACKEND] Server stopped (exit code: $EXIT_CODE). Restarting in 2 seconds..."
        sleep 2
    done
) &
UVICORN_PID=$!
echo "✅ Python Backend monitor started (PID: $UVICORN_PID)"

# Start PostgREST (port 3001) if DATABASE_URL is provided
echo "🗄️  Starting PostgREST..."
if [ -n "$DATABASE_URL" ]; then
    # Create PostgREST config
    cat > /tmp/postgrest.conf << EOF
db-uri = "$DATABASE_URL"
db-schemas = "public"
db-anon-role = "postgres"
server-host = "0.0.0.0"
server-port = 3001
EOF
    
    # Start PostgREST
    /usr/local/bin/postgrest /tmp/postgrest.conf 2>&1 | sed -u 's/^/[PostgREST] /' &
    POSTGREST_PID=$!
    echo "✅ PostgREST started on port 3001 (PID: $POSTGREST_PID)"
else
    echo "⚠️  DATABASE_URL not set, skipping PostgREST startup"
    POSTGREST_PID=""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Frontend (Next.js): http://localhost:3000"
echo "🔧 Backend API (FastAPI): http://localhost:8000"
echo "🔄 Reload Service: http://localhost:9000"
echo "🗄️  PostgREST API: http://localhost:3001"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Wait for all background processes
wait
