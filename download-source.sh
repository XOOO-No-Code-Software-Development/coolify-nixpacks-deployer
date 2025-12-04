#!/bin/bash
set -e

echo "=================================================="
echo "Preparing source code"
echo "=================================================="

# Check required environment variables
if [ -z "$CHAT_ID" ]; then
  echo "❌ ERROR: CHAT_ID environment variable not set"
  exit 1
fi

echo "📦 Chat ID: $CHAT_ID"

# Check if V0_API_KEY is set
if [ -z "$V0_API_KEY" ]; then
  echo "❌ ERROR: V0_API_KEY environment variable not set"
  exit 1
fi

# Use custom V0_API_URL if set, otherwise use default
V0_API_URL="${V0_API_URL:-https://api.v0.dev/v1}"
echo "🌐 API URL: $V0_API_URL"

# Fetch chat details to get latest version
echo "⬇️  Fetching chat details to get latest version..."
CHAT_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
  -H "Authorization: Bearer $V0_API_KEY" \
  "$V0_API_URL/chats/$CHAT_ID")

# Extract HTTP status
HTTP_STATUS=$(echo "$CHAT_RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
CHAT_RESPONSE=$(echo "$CHAT_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

echo "� API Response Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" != "200" ]; then
  echo "❌ ERROR: Chat API request failed with status $HTTP_STATUS"
  echo "Response: $CHAT_RESPONSE"
  echo "⚠️  Falling back to initial backend template"
  VERSION_ID="initial"
else
  # Extract latest version ID using jq if available
  if command -v jq &> /dev/null; then
    VERSION_ID=$(echo "$CHAT_RESPONSE" | jq -r '.latestVersion.id // "initial"')
    echo "📦 Latest Version ID: $VERSION_ID"
  else
    echo "⚠️  jq not available, using initial template"
    VERSION_ID="initial"
  fi
fi
# Check if VERSION_ID is "initial" or not set
if [ "$VERSION_ID" = "initial" ] || [ "$VERSION_ID" = "null" ] || [ -z "$VERSION_ID" ]; then
  echo "🎯 Version is 'initial' - using default backend template"
  echo "📂 Moving backend template files to root directory..."
  
  # Move all files from backend/ to root
  if [ -d "backend" ]; then
    # Remove .DS_Store and other hidden files first
    find backend -name ".DS_Store" -delete
    mv backend/* .
    rm -rf backend
    echo "✅ Template files moved to root"
  fi
  
  echo "📋 Files in workspace:"
  ls -la
  echo ""
  echo "✅ Source code ready (using defaults)!"
  exit 0
fi

# For non-initial versions, fetch from API
echo "🎯 Version is '$VERSION_ID' - fetching from v0 API"

# Clean current directory (except this script, backend template, and .git)
echo "🧹 Cleaning workspace..."
find . -mindepth 1 -maxdepth 1 \
  ! -name 'download-source.sh' \
  ! -name 'backend' \
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
  
  # Check if we have backend files
  if [ "$BACKEND_FILE_COUNT" -eq 0 ]; then
    echo "⚠️  No backend files found in version"
    echo "🎯 Using default backend template instead"
    
    # Move template files from backend/ to root
    if [ -d "backend" ]; then
      echo "📂 Moving backend template files to root directory..."
      find backend -name ".DS_Store" -delete
      mv backend/* .
      rm -rf backend
      echo "✅ Template files moved to root"
    else
      echo "❌ ERROR: No backend template directory found"
      exit 1
    fi
  else
    # Remove template backend folder since we have backend files in version
    if [ -d "backend" ]; then
      echo "🗑️  Removing backend template (using version files instead)"
      rm -rf backend
    fi
    
    # Extract backend files from version
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
  fi
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
echo "Docker will now build your app"
echo "=================================================="
