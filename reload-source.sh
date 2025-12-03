#!/bin/bash

# Hot Reload Script
# Downloads specific version from v0 API and replaces local files
# Triggered by reload-service.py when platform calls /reload endpoint

set -e  # Exit on error

CHAT_ID="$1"
VERSION_ID="$2"

if [ -z "$CHAT_ID" ] || [ -z "$VERSION_ID" ]; then
  echo "❌ ERROR: CHAT_ID and VERSION_ID are required"
  echo "Usage: $0 <CHAT_ID> <VERSION_ID>"
  exit 1
fi

echo "=================================================="
echo "🔄 Hot Reload Triggered"
echo "📝 Chat ID: $CHAT_ID"
echo "🆔 Version ID: $VERSION_ID"
echo "=================================================="
echo ""

V0_API_KEY="${V0_API_KEY}"
V0_API_URL="${V0_API_URL:-https://api.v0.dev/v1}"

if [ -z "$V0_API_KEY" ]; then
  echo "❌ ERROR: V0_API_KEY is not set"
  exit 1
fi

# Fetch specific version details
echo "📥 Fetching version $VERSION_ID..."
VERSION_RESPONSE=$(curl -s -X GET \
  "${V0_API_URL}/chats/${CHAT_ID}/versions/${VERSION_ID}" \
  -H "Authorization: Bearer ${V0_API_KEY}" \
  -H "Content-Type: application/json")

if [ -z "$VERSION_RESPONSE" ]; then
  echo "❌ ERROR: Failed to fetch version details"
  exit 1
fi

# Check if response contains error
if echo "$VERSION_RESPONSE" | grep -q '"error"'; then
  echo "❌ ERROR: API returned error:"
  echo "$VERSION_RESPONSE" | jq -r '.error // .message // .'
  exit 1
fi

# Save response for debugging
echo "$VERSION_RESPONSE" > /tmp/version_response.json

# Check if jq is available
if command -v jq &> /dev/null; then
  # Extract backend files from version
  echo "📂 Extracting backend files..."
  echo "$VERSION_RESPONSE" | jq -r '.files[] | select(.name | startswith("backend/")) | @json' | while IFS= read -r file; do
    filename=$(echo "$file" | jq -r '.name')
    content=$(echo "$file" | jq -r '.content')
    
    # Remove 'backend/' prefix to flatten the structure
    target_filename="${filename#backend/}"
    
    # Create directory if needed
    filedir=$(dirname "$target_filename")
    if [ "$filedir" != "." ]; then
      mkdir -p "$filedir"
    fi
    
    # Write file content
    echo "$content" > "$target_filename"
    echo "✅ Updated: $target_filename"
  done
else
  echo "❌ ERROR: jq is not available"
  echo "jq is required for parsing JSON responses"
  exit 1
fi

# Clean up temporary file
rm -f /tmp/version_response.json

echo ""
echo "📋 Updated files:"
ls -la *.py 2>/dev/null || echo "No Python files found"
echo ""

# Install/update Python packages if requirements.txt exists
if [ -f "requirements.txt" ]; then
  echo "📦 Installing Python packages..."
  source /opt/venv/bin/activate
  pip install -q -r requirements.txt
  echo "✅ Packages installed"
else
  echo "ℹ️  No requirements.txt found, skipping package installation"
fi
echo ""
# Restart uvicorn to apply changes
echo "🔄 Restarting FastAPI application..."

# Find and kill uvicorn process with timeout
UVICORN_PROC=$(ps aux | grep "uvicorn main:app" | grep -v grep | awk '{print $2}' | head -1)
if [ ! -z "$UVICORN_PROC" ]; then
  echo "🔪 Killing old uvicorn (PID: $UVICORN_PROC)"
  kill -9 $UVICORN_PROC 2>/dev/null || true
  sleep 1
else
  echo "ℹ️  No existing uvicorn process found"
fi

# Restart uvicorn in the background (don't wait for it)
source /opt/venv/bin/activate
bash start-backend.sh &
NEW_UVICORN_PID=$!
echo "✅ Uvicorn restarted (new PID: $NEW_UVICORN_PID)"

# Update the PID file for tracking
echo $NEW_UVICORN_PID > /tmp/uvicorn.pid

# Don't wait for uvicorn to fully start - let it boot in background
echo ""
echo "✅ Reload complete! (uvicorn starting in background)"
echo "=================================================="

exit 0
