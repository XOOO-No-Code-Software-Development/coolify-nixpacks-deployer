#!/bin/bash#!/bin/bash



# Function to handle shutdown# Function to handle shutdown

shutdown() {shutdown() {

    echo "Shutting down services..."    echo "Shutting down services..."

    kill $RELOAD_SERVICE_PID $NEXTJS_PID $UVICORN_PID 2>/dev/null    kill $RELOAD_SERVICE_PID $POSTGREST_PID $UVICORN_PID 2>/dev/null

    wait $RELOAD_SERVICE_PID $NEXTJS_PID $UVICORN_PID 2>/dev/null    wait $RELOAD_SERVICE_PID $POSTGREST_PID $UVICORN_PID 2>/dev/null

    exit 0    exit 0

}}



# Trap signals for graceful shutdown# Trap signals for graceful shutdown

trap shutdown SIGTERM SIGINTtrap shutdown SIGTERM SIGINT



# Initial source download (only on first boot)# Activate virtual environment

if [ ! -f "package.json" ]; thensource /opt/venv/bin/activate

  echo "📦 First boot - downloading initial source..."

  bash download-source.sh# Initial source download (only on first boot)

fiif [ ! -f "main.py" ]; then

  echo "📦 First boot - downloading initial source..."

# Start System Reload Service (port 9000) - INDEPENDENT OF USER CODE  bash download-source.sh

echo "🔧 Starting System Reload Service on port 9000..."fi

python3 reload-service.py 2>&1 &

RELOAD_SERVICE_PID=$!# Start System Reload Service (port 9000) - INDEPENDENT OF USER CODE

echo "✅ Reload Service started (PID: $RELOAD_SERVICE_PID)"echo "🔧 Starting System Reload Service on port 9000..."

python3 reload-service.py 2>&1 &

# Start Next.js Frontend (port 3000) from root directoryRELOAD_SERVICE_PID=$!

echo "🎨 Starting Next.js Frontend..."echo "✅ Reload Service started (PID: $RELOAD_SERVICE_PID)"

if [ -f "package.json" ]; then

    # Install dependencies if node_modules doesn't exist# Start PostgREST if DATABASE_URL is set

    if [ ! -d "node_modules" ]; thenif [ ! -z "$DATABASE_URL" ]; then

        echo "📦 Installing Next.js dependencies..."    echo "🗄️  Starting PostgREST REST API..."

        npm install    

    fi    # Parse DATABASE_URL to extract connection details

        # Format: postgresql://user:pass@host:port/dbname

    # Build Next.js app if .next doesn't exist    DB_URI="${DATABASE_URL}"

    if [ ! -d ".next" ]; then    if [[ "$DB_URI" != *"sslmode="* ]]; then

        echo "🔨 Building Next.js app..."        DB_URI="${DB_URI}?sslmode=disable"

        npm run build    fi

    fi    

        # Create PostgREST config file

    # Start Next.js in production mode    cat > /tmp/postgrest.conf << EOF

    npm run start 2>&1 &db-uri = "${DB_URI}"

    NEXTJS_PID=$!db-anon-role = "postgres"

    echo "✅ Next.js Frontend started on port 3000 (PID: $NEXTJS_PID)"db-schema = "public"

elseserver-host = "0.0.0.0"

    echo "⚠️  package.json not found, skipping Next.js startup"server-port = 3000

    NEXTJS_PID=""EOF

fi    

    # Start PostgREST on port 3000 (redirect stderr to stdout)

# Start Python FastAPI Backend (port 8000) from backend folder    /usr/local/bin/postgrest /tmp/postgrest.conf 2>&1 &

echo "🚀 Starting Python FastAPI Backend..."    POSTGREST_PID=$!

if [ -d "backend" ] && [ -f "backend/main.py" ]; then    

    # Activate virtual environment if it exists    echo "✅ PostgREST started on port 3000"

    if [ -d "/opt/venv" ]; then    echo "📊 REST API: http://localhost:3000"

        source /opt/venv/bin/activateelse

    fi    echo "⚠️  DATABASE_URL not set, PostgREST will not be started"

    fi

    # Install backend dependencies if requirements.txt exists

    if [ -f "backend/requirements.txt" ]; then# Start User's FastAPI application with hot reload (redirect stderr to stdout)

        echo "📦 Installing Python dependencies..."echo "🚀 Starting User's FastAPI application with hot reload..."

        pip install -q -r backend/requirements.txtuvicorn main:app --host 0.0.0.0 --port 8000 --reload 2>&1 &

    fiUVICORN_PID=$!

    

    # Start FastAPI with hot reloadecho "✅ User's Backend started on port 8000 (hot reload enabled)"

    cd backendecho "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    uvicorn main:app --host 0.0.0.0 --port 8000 --reload 2>&1 &echo "🌐 User API:      http://localhost:8000"

    UVICORN_PID=$!echo "🔧 Reload Service: http://localhost:9000"

    cd ..if [ ! -z "$DATABASE_URL" ]; then

    echo "✅ Python Backend started on port 8000 (PID: $UVICORN_PID)"    echo "📊 PostgREST:     http://localhost:3000"

elsefi

    echo "⚠️  backend/main.py not found, skipping Python backend startup"echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    UVICORN_PID=""

fi# Wait for all background processes

wait
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Frontend (Next.js): http://localhost:3000"
echo "🔧 Backend API (FastAPI): http://localhost:8000"
echo "🔄 Reload Service: http://localhost:9000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Wait for all background processes
wait
