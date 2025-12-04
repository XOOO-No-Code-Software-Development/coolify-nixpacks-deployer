#!/bin/bash
set -e

echo "=================================================="
echo "Downloading deployment files from Vercel"
echo "=================================================="

# Check required environment variables
if [ -z "$PROJECT_ID" ] || [ -z "$CHAT_ID" ] || [ -z "$DEPLOYMENT_ID" ]; then
  echo "⚠️  No deployment configuration found"
  echo "📦 Using empty_template as default application"
  
  # Copy empty_template to root
  if [ -d "empty_template" ]; then
    echo "📂 Copying empty_template files..."
    cp -r empty_template/* .
    echo "✅ Empty template loaded successfully"
    exit 0
  else
    echo "❌ ERROR: empty_template directory not found"
    exit 1
  fi
fi

if [ -z "$VERCEL_TOKEN" ]; then
  echo "❌ ERROR: VERCEL_TOKEN environment variable not set"
  exit 1
fi

VERCEL_API_URL="${VERCEL_API_URL:-https://api.vercel.com}"

echo "📦 Project ID: $PROJECT_ID"
echo "💬 Chat ID: $CHAT_ID"
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
echo "✅ Download complete!"
echo ""
echo "📋 Downloaded files (root):"
ls -la | head -20 || echo "Unable to list files"
echo ""

if [ -d "backend" ]; then
  echo "📋 Downloaded files (backend):"
  ls -la backend | head -20 || echo "Unable to list backend files"
  echo ""
fi

echo "=================================================="
echo "Docker will now build and start your app"
echo "=================================================="
