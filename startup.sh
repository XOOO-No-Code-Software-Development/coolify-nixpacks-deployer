#!/bin/bash

# Function to handle shutdown
shutdown() {
    echo "Shutting down services..."
    kill $RELOAD_SERVICE_PID $NEXTJS_PID $UVICORN_PID 2>/dev/null
    wait $RELOAD_SERVICE_PID $NEXTJS_PID $UVICORN_PID 2>/dev/null
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
python3 reload-service.py 2>&1 &
RELOAD_SERVICE_PID=$!
echo "✅ Reload Service started (PID: $RELOAD_SERVICE_PID)"

# Start Next.js Frontend (port 3000) from root directory
echo "🎨 Starting Next.js Frontend..."
if [ -f "package.json" ]; then
    # Start Next.js in production mode
    npm run start 2>&1 &
    NEXTJS_PID=$!
    echo "✅ Next.js Frontend started on port 3000 (PID: $NEXTJS_PID)"
else
    echo "⚠️  package.json not found, skipping Next.js startup"
    NEXTJS_PID=""
fi

# Start Python FastAPI Backend (port 8000) from backend folder
echo "🚀 Starting Python FastAPI Backend..."
if [ -d "backend" ] && [ -f "backend/main.py" ]; then
    # Activate virtual environment if it exists
    if [ -d "/opt/venv" ]; then
        source /opt/venv/bin/activate
    fi
    
    # Start FastAPI without reload (we have our own reload service)
    cd backend
    uvicorn main:app --host 0.0.0.0 --port 8000 2>&1 &
    UVICORN_PID=$!
    cd ..
    echo "✅ Python Backend started on port 8000 (PID: $UVICORN_PID)"
else
    echo "⚠️  backend/main.py not found, skipping Python backend startup"
    UVICORN_PID=""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Frontend (Next.js): http://localhost:3000"
echo "🔧 Backend API (FastAPI): http://localhost:8000"
echo "🔄 Reload Service: http://localhost:9000"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Wait for all background processes
wait
