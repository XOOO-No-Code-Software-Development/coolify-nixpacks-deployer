#!/bin/bash
set -e

echo "=================================================="
echo "Downloading source code from v0 API"
echo "=================================================="

# Check required environment variables
if [ -z "$CHAT_ID" ]; then
  echo "❌ ERROR: CHAT_ID environment variable not set"
  exit 1
fi

if [ -z "$VERSION_ID" ]; then
  echo "❌ ERROR: VERSION_ID environment variable not set"
  exit 1
fi

if [ -z "$V0_API_KEY" ]; then
  echo "❌ ERROR: V0_API_KEY environment variable not set"
  exit 1
fi

# Use custom V0_API_URL if set, otherwise use default
V0_API_URL="${V0_API_URL:-https://api.v0.dev/v1}"

echo "📦 Chat ID: $CHAT_ID"
echo "📦 Version ID: $VERSION_ID"
echo "🌐 API URL: $V0_API_URL"

# Use the provided VERSION_ID directly (no "latest" resolution needed)
echo "� Using version ID: $VERSION_ID"

# Clean current directory (except this script and .git)
echo "🧹 Cleaning workspace..."
find . -mindepth 1 -maxdepth 1 \
  ! -name 'download-source.sh' \
  ! -name '.git' \
  ! -name '.gitignore' \
  ! -name 'README.md' \
  ! -name 'nixpacks.toml' \
  ! -name 'start-with-download.sh' \
  -exec rm -rf {} +

# Fetch version files from v0 API
echo "⬇️  Fetching version files from v0 API..."
echo "🌐 Making API request to: $V0_API_URL/chats/$CHAT_ID/versions/$VERSION_ID"
VERSION_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" -H "Authorization: Bearer $V0_API_KEY" \
  "$V0_API_URL/chats/$CHAT_ID/versions/$VERSION_ID?includeDefaultFiles=true")

# Extract HTTP status code
HTTP_STATUS=$(echo "$VERSION_RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
# Remove status line from response
VERSION_RESPONSE=$(echo "$VERSION_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

echo "📡 API Response Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" != "200" ]; then
  echo "❌ ERROR: Version API request failed with status $HTTP_STATUS"
  echo "Response: $VERSION_RESPONSE"
  exit 1
fi

# Save response to temporary file for processing
echo "$VERSION_RESPONSE" > /tmp/version_response.json

# Extract and create files using jq if available, otherwise use grep/sed
if command -v jq &> /dev/null; then
  echo "📂 Extracting files using jq..."
  
  # Count total files
  TOTAL_FILE_COUNT=$(echo "$VERSION_RESPONSE" | jq '.files | length')
  echo "📊 Found $TOTAL_FILE_COUNT total files"
  
  # Filter and count backend files only
  BACKEND_FILE_COUNT=$(echo "$VERSION_RESPONSE" | jq '[.files[] | select(.name | startswith("backend/"))] | length')
  echo "📊 Found $BACKEND_FILE_COUNT backend files (filtering out non-backend files)"
  
  # Extract only backend files
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
    echo "✅ Created: $target_filename"
  done
else
  echo "📂 Extracting files using grep/sed (jq not available)..."
  
  # This is a fallback method - less robust but works without jq
  # Extract only backend files by filtering for files that start with "backend/"
  echo "$VERSION_RESPONSE" | grep -o '"name":"backend/[^"]*","content":"[^"]*"' | while IFS= read -r pair; do
    filename=$(echo "$pair" | sed 's/.*"name":"\([^"]*\)".*/\1/')
    content=$(echo "$pair" | sed 's/.*"content":"\([^"]*\)".*/\1/')
    
    # Remove 'backend/' prefix to flatten the structure
    target_filename="${filename#backend/}"
    
    # Decode escaped content (basic unescape)
    content=$(echo -e "$content")
    
    # Create directory if needed
    filedir=$(dirname "$target_filename")
    if [ "$filedir" != "." ]; then
      mkdir -p "$filedir"
    fi
    
    # Write file content
    echo "$content" > "$target_filename"
    echo "✅ Created: $target_filename"
  done
fi

# Clean up temporary file
rm -f /tmp/version_response.json

echo "✅ Source code ready!"
echo ""
echo "📋 Files in workspace:"
ls -la

echo ""
echo "=================================================="
echo "Nixpacks will now auto-detect and build your app"
echo "=================================================="
