#!/bin/bash
set -e

echo "=================================================="
echo "Reloading source code from Vercel deployment"
echo "=================================================="

# Parse inputs from arguments
PROJECT_ID="${1}"
CHAT_ID="${2}"
DEPLOYMENT_ID="${3}"

# Validate required inputs
if [ -z "$PROJECT_ID" ] || [ -z "$CHAT_ID" ] || [ -z "$DEPLOYMENT_ID" ]; then
  echo "❌ ERROR: PROJECT_ID, CHAT_ID, and DEPLOYMENT_ID required"
  echo "Usage: bash reload-source.sh <PROJECT_ID> <CHAT_ID> <DEPLOYMENT_ID>"
  exit 1
fi

# Validate API credentials
if [ -z "$VERCEL_TOKEN" ]; then
  echo "❌ ERROR: VERCEL_TOKEN environment variable not set"
  exit 1
fi

VERCEL_API_URL="${VERCEL_API_URL:-https://api.vercel.com}"

echo "🔄 Reloading deployment for chat: $CHAT_ID"
echo "📦 Project ID: $PROJECT_ID"
echo "🚀 Deployment ID: $DEPLOYMENT_ID"
echo "🌐 API URL: $VERCEL_API_URL"
echo ""

# Step 1: Get deployment files list from Vercel API
echo "⬇️  Fetching deployment file list..."
FILES_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  "$VERCEL_API_URL/v6/deployments/$DEPLOYMENT_ID/files")

# Extract HTTP status
HTTP_STATUS=$(echo "$FILES_RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
FILES_RESPONSE=$(echo "$FILES_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

echo "📡 API Response Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" != "200" ]; then
  echo "❌ ERROR: API request failed with status $HTTP_STATUS"
  echo "Response: $FILES_RESPONSE"
  exit 1
fi

# Save response to temporary file for processing
echo "$FILES_RESPONSE" > /tmp/files_response.json

# Extract file list using jq
if command -v jq &> /dev/null; then
  echo "📂 Extracting file list using jq..."
  
  # Count total files
  TOTAL_FILE_COUNT=$(echo "$FILES_RESPONSE" | jq '.files | length' 2>/dev/null || echo "0")
  echo "📊 Found $TOTAL_FILE_COUNT total files"
  
  if [ "$TOTAL_FILE_COUNT" -eq 0 ]; then
    echo "⚠️  No files found in deployment"
    exit 1
  fi
  
  # Clean existing files (preserve system files)
  echo "🧹 Removing old deployment files..."
  find . -mindepth 1 -maxdepth 1 \
    ! -name 'reload-source.sh' \
    ! -name 'reload-service.py' \
    ! -name 'download-source.sh' \
    ! -name 'startup.sh' \
    ! -name 'nixpacks.toml' \
    ! -name 'start-with-download.sh' \
    ! -name 'start-backend.sh' \
    ! -name '.git' \
    ! -name '.gitignore' \
    ! -name 'README.md' \
    ! -name 'base-image' \
    ! -name 'empty_template' \
    ! -name 'test-*.sh' \
    -exec rm -rf {} + 2>/dev/null || true
  
  # Extract and download files
  echo "📂 Downloading deployment files..."
  
  # Parse file list and download each file
  echo "$FILES_RESPONSE" | jq -r '.files[] | @json' | while IFS= read -r file; do
    filename=$(echo "$file" | jq -r '.name')
    uid=$(echo "$file" | jq -r '.uid')
    
    echo "⬇️  Downloading: $filename"
    
    # Download file content
    FILE_CONTENT=$(curl -s \
      -H "Authorization: Bearer $VERCEL_TOKEN" \
      "$VERCEL_API_URL/v6/deployments/$DEPLOYMENT_ID/files/$uid")
    
    # Create directory if needed
    filedir=$(dirname "$filename")
    if [ "$filedir" != "." ]; then
      mkdir -p "$filedir"
    fi
    
    # Write file content
    echo "$FILE_CONTENT" > "$filename"
    echo "✅ Downloaded: $filename"
  done
else
  echo "❌ ERROR: jq is not available"
  echo "jq is required for parsing JSON responses"
  exit 1
fi

# Clean up temporary files
rm -f /tmp/files_response.json

echo ""
echo "✅ Reload complete!"
echo "🔥 Services will auto-detect file changes and reload"
echo ""
echo "📋 Downloaded files:"
ls -la 2>/dev/null | head -20 || echo "Unable to list files"
echo ""
echo "=================================================="
