#!/bin/bash
set -e

echo "=================================================="
echo "Reloading backend source code"
echo "=================================================="

# Parse inputs from arguments
CHAT_ID="${1}"
VERSION_ID="${2}"

# Validate required inputs
if [ -z "$CHAT_ID" ] || [ -z "$VERSION_ID" ]; then
  echo "❌ ERROR: CHAT_ID and VERSION_ID required"
  echo "Usage: bash reload-source.sh <CHAT_ID> <VERSION_ID>"
  exit 1
fi

# Validate API credentials
if [ -z "$V0_API_KEY" ]; then
  echo "❌ ERROR: V0_API_KEY environment variable not set"
  exit 1
fi

V0_API_URL="${V0_API_URL:-https://api.v0.dev/v1}"

echo "🔄 Reloading backend for chat: $CHAT_ID"
echo "📦 Version: $VERSION_ID"
echo "🌐 API URL: $V0_API_URL"
echo ""

# Fetch version files from v0 API
echo "⬇️  Fetching version $VERSION_ID..."
VERSION_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
  -H "Authorization: Bearer $V0_API_KEY" \
  "$V0_API_URL/chats/$CHAT_ID/versions/$VERSION_ID?includeDefaultFiles=true")

# Extract HTTP status
HTTP_STATUS=$(echo "$VERSION_RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
VERSION_RESPONSE=$(echo "$VERSION_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

echo "📡 API Response Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" != "200" ]; then
  echo "❌ ERROR: API request failed with status $HTTP_STATUS"
  echo "Response: $VERSION_RESPONSE"
  exit 1
fi

# Save response to temporary file for processing
echo "$VERSION_RESPONSE" > /tmp/version_response.json

# Extract and create files using jq if available
if command -v jq &> /dev/null; then
  echo "📂 Extracting files using jq..."
  
  # Count total files
  TOTAL_FILE_COUNT=$(echo "$VERSION_RESPONSE" | jq '.files | length')
  echo "📊 Found $TOTAL_FILE_COUNT total files"
  
  # Filter and count backend files only
  BACKEND_FILE_COUNT=$(echo "$VERSION_RESPONSE" | jq '[.files[] | select(.name | startswith("backend/"))] | length')
  echo "📊 Found $BACKEND_FILE_COUNT backend files (filtering out non-backend files)"
  
  # Check if we have backend files
  if [ "$BACKEND_FILE_COUNT" -eq 0 ]; then
    echo "⚠️  No backend files found in version"
    exit 1
  fi
  
  # Clean existing backend files (preserve system files)
  echo "🧹 Removing old backend files..."
  find . -mindepth 1 -maxdepth 1 \
    ! -name 'reload-source.sh' \
    ! -name 'reload-service.py' \
    ! -name 'download-source.sh' \
    ! -name 'startup.sh' \
    ! -name 'nixpacks.toml' \
    ! -name 'start-with-download.sh' \
    ! -name '.git' \
    ! -name '.gitignore' \
    ! -name 'README.md' \
    ! -name 'backend' \
    ! -name 'base-image' \
    ! -name 'test-*.sh' \
    -exec rm -rf {} + 2>/dev/null || true
  
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
echo "✅ Reload complete!"
echo "🔥 Uvicorn will auto-detect file changes and reload"
echo ""
echo "📋 Updated files:"
ls -la *.py 2>/dev/null || echo "No Python files found"
echo ""
echo "=================================================="
