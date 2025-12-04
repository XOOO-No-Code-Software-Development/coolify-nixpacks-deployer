#!/bin/bash#!/bin/bash

set -eset -e



echo "=================================================="echo "=================================================="

echo "Downloading deployment files from Vercel"echo "Preparing source code"

echo "=================================================="echo "=================================================="



# Check required environment variables# Check required environment variables

if [ -z "$PROJECT_ID" ] || [ -z "$CHAT_ID" ] || [ -z "$DEPLOYMENT_ID" ]; thenif [ -z "$CHAT_ID" ]; then

  echo "❌ ERROR: PROJECT_ID, CHAT_ID, and DEPLOYMENT_ID environment variables required"  echo "❌ ERROR: CHAT_ID environment variable not set"

  exit 1  exit 1

fifi



if [ -z "$VERCEL_TOKEN" ]; thenecho "📦 Chat ID: $CHAT_ID"

  echo "❌ ERROR: VERCEL_TOKEN environment variable not set"

  exit 1# Check if V0_API_KEY is set

fiif [ -z "$V0_API_KEY" ]; then

  echo "❌ ERROR: V0_API_KEY environment variable not set"

VERCEL_API_URL="${VERCEL_API_URL:-https://api.vercel.com}"  exit 1

fi

echo "📦 Project ID: $PROJECT_ID"

echo "💬 Chat ID: $CHAT_ID"# Use custom V0_API_URL if set, otherwise use default

echo "🚀 Deployment ID: $DEPLOYMENT_ID"V0_API_URL="${V0_API_URL:-https://api.v0.dev/v1}"

echo "🌐 API URL: $VERCEL_API_URL"echo "🌐 API URL: $V0_API_URL"

echo ""

# Fetch chat details to get latest version

# Step 1: Get deployment files list from Vercel APIecho "⬇️  Fetching chat details to get latest version..."

echo "⬇️  Fetching deployment file list..."CHAT_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \

FILES_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \  -H "Authorization: Bearer $V0_API_KEY" \

  -H "Authorization: Bearer $VERCEL_TOKEN" \  "$V0_API_URL/chats/$CHAT_ID")

  "$VERCEL_API_URL/v6/deployments/$DEPLOYMENT_ID/files")

# Extract HTTP status

# Extract HTTP statusHTTP_STATUS=$(echo "$CHAT_RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)

HTTP_STATUS=$(echo "$FILES_RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)CHAT_RESPONSE=$(echo "$CHAT_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

FILES_RESPONSE=$(echo "$FILES_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

echo "� API Response Status: $HTTP_STATUS"

echo "📡 API Response Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" != "200" ]; then

if [ "$HTTP_STATUS" != "200" ]; then  echo "❌ ERROR: Chat API request failed with status $HTTP_STATUS"

  echo "❌ ERROR: API request failed with status $HTTP_STATUS"  echo "Response: $CHAT_RESPONSE"

  echo "Response: $FILES_RESPONSE"  echo "⚠️  Falling back to initial backend template"

  exit 1  VERSION_ID="initial"

fielse

  # Extract latest version ID using jq if available

# Save response to temporary file for processing  if command -v jq &> /dev/null; then

echo "$FILES_RESPONSE" > /tmp/files_response.json    VERSION_ID=$(echo "$CHAT_RESPONSE" | jq -r '.latestVersion.id // "initial"')

    echo "📦 Latest Version ID: $VERSION_ID"

# Extract file list using jq  else

if command -v jq &> /dev/null; then    echo "⚠️  jq not available, using initial template"

  echo "📂 Extracting file list using jq..."    VERSION_ID="initial"

    fi

  # Count total filesfi

  TOTAL_FILE_COUNT=$(echo "$FILES_RESPONSE" | jq '.files | length' 2>/dev/null || echo "0")# Check if VERSION_ID is "initial" or not set

  echo "📊 Found $TOTAL_FILE_COUNT total files"if [ "$VERSION_ID" = "initial" ] || [ "$VERSION_ID" = "null" ] || [ -z "$VERSION_ID" ]; then

    echo "🎯 Version is 'initial' - using default backend template"

  if [ "$TOTAL_FILE_COUNT" -eq 0 ]; then  echo "📂 Moving backend template files to root directory..."

    echo "⚠️  No files found in deployment"  

    exit 1  # Move all files from backend/ to root

  fi  if [ -d "backend" ]; then

      # Remove .DS_Store and other hidden files first

  # Clean existing files (preserve system files)    find backend -name ".DS_Store" -delete

  echo "🧹 Removing old deployment files..."    mv backend/* .

  find . -mindepth 1 -maxdepth 1 \    rm -rf backend

    ! -name 'reload-source.sh' \    echo "✅ Template files moved to root"

    ! -name 'reload-service.py' \  fi

    ! -name 'download-source.sh' \  

    ! -name 'startup.sh' \  echo "📋 Files in workspace:"

    ! -name 'nixpacks.toml' \  ls -la

    ! -name 'start-with-download.sh' \  echo ""

    ! -name '.git' \  echo "✅ Source code ready (using defaults)!"

    ! -name '.gitignore' \  exit 0

    ! -name 'README.md' \fi

    ! -name 'base-image' \

    ! -name 'test-*.sh' \# For non-initial versions, fetch from API

    -exec rm -rf {} + 2>/dev/null || trueecho "🎯 Version is '$VERSION_ID' - fetching from v0 API"

  

  # Extract and download files# Clean current directory (except this script, backend template, and .git)

  echo "📂 Downloading deployment files..."echo "🧹 Cleaning workspace..."

  find . -mindepth 1 -maxdepth 1 \

  # Parse file list and download each file  ! -name 'download-source.sh' \

  echo "$FILES_RESPONSE" | jq -r '.files[] | @json' | while IFS= read -r file; do  ! -name 'backend' \

    filename=$(echo "$file" | jq -r '.name')  ! -name '.git' \

    uid=$(echo "$file" | jq -r '.uid')  ! -name '.gitignore' \

      ! -name 'README.md' \

    echo "⬇️  Downloading: $filename"  ! -name 'nixpacks.toml' \

      ! -name 'start-with-download.sh' \

    # Download file content  -exec rm -rf {} +

    FILE_CONTENT=$(curl -s \

      -H "Authorization: Bearer $VERCEL_TOKEN" \# Fetch version files from v0 API

      "$VERCEL_API_URL/v6/deployments/$DEPLOYMENT_ID/files/$uid")echo "⬇️  Fetching version files from v0 API..."

    echo "🌐 Making API request to: $V0_API_URL/chats/$CHAT_ID/versions/$VERSION_ID"

    # Create directory if neededVERSION_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" -H "Authorization: Bearer $V0_API_KEY" \

    filedir=$(dirname "$filename")  "$V0_API_URL/chats/$CHAT_ID/versions/$VERSION_ID?includeDefaultFiles=true")

    if [ "$filedir" != "." ]; then

      mkdir -p "$filedir"# Extract HTTP status code

    fiHTTP_STATUS=$(echo "$VERSION_RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)

    # Remove status line from response

    # Write file contentVERSION_RESPONSE=$(echo "$VERSION_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

    echo "$FILE_CONTENT" > "$filename"

    echo "✅ Downloaded: $filename"echo "📡 API Response Status: $HTTP_STATUS"

  done

elseif [ "$HTTP_STATUS" != "200" ]; then

  echo "❌ ERROR: jq is not available"  echo "❌ ERROR: Version API request failed with status $HTTP_STATUS"

  echo "jq is required for parsing JSON responses"  echo "Response: $VERSION_RESPONSE"

  exit 1  exit 1

fifi



# Clean up temporary files# Save response to temporary file for processing

rm -f /tmp/files_response.jsonecho "$VERSION_RESPONSE" > /tmp/version_response.json



echo ""# Extract and create files using jq if available, otherwise use grep/sed

echo "✅ Download complete!"if command -v jq &> /dev/null; then

echo ""  echo "📂 Extracting files using jq..."

echo "📋 Downloaded files (root):"  

ls -la | head -20 || echo "Unable to list files"  # Count total files

echo ""  TOTAL_FILE_COUNT=$(echo "$VERSION_RESPONSE" | jq '.files | length')

  echo "📊 Found $TOTAL_FILE_COUNT total files"

if [ -d "backend" ]; then  

  echo "📋 Downloaded files (backend):"  # Filter and count backend files only

  ls -la backend | head -20 || echo "Unable to list backend files"  BACKEND_FILE_COUNT=$(echo "$VERSION_RESPONSE" | jq '[.files[] | select(.name | startswith("backend/"))] | length')

  echo ""  echo "📊 Found $BACKEND_FILE_COUNT backend files (filtering out non-backend files)"

fi  

  # Check if we have backend files

echo "=================================================="  if [ "$BACKEND_FILE_COUNT" -eq 0 ]; then

echo "Docker will now build and start your app"    echo "⚠️  No backend files found in version"

echo "=================================================="    echo "🎯 Using default backend template instead"

    
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
