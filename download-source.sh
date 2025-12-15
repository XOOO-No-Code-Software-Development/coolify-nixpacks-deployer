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
    cp -r empty_template/* . || {
      echo "❌ ERROR: Failed to copy empty_template files"
      exit 1
    }
    echo "✅ Empty template loaded successfully"
    
    # Verify package.json was copied
    if [ ! -f "package.json" ]; then
      echo "❌ ERROR: package.json not found after copying empty_template"
      ls -la
      exit 1
    fi
    echo "✅ Verified package.json exists"
    exit 0
  else
    echo "❌ ERROR: empty_template directory not found"
    echo "Current directory contents:"
    ls -la
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
  "$VERCEL_API_URL/v8/deployments/$DEPLOYMENT_ID/files")

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
  
  # Recursively extract all files from the tree structure
  # The Vercel API returns a hierarchical structure with directories and children
  FILES_LIST=$(echo "$FILES_RESPONSE" | jq -r '
    def walk_tree(path):
      # Only files have uid, so check for that instead of type
      if .uid then
        {name: (if path == "" then .name else (path + .name) end), uid: .uid}
      # If it has children, recurse into them
      elif .children then
        # Skip pda folder
        if .name == "pda" then
          empty
        else
          # Capture current directory name before iterating children
          . as $current |
          # Build new path with current directory name
          (if path == "" then ($current.name + "/") else (path + $current.name + "/") end) as $newpath |
          # Recurse into each child with the new path
          ($current.children[] | walk_tree($newpath))
        end
      else
        empty
      end;
    # Skip the top-level "src" directory - start directly from its children
    if .[0].name == "src" and .[0].children then
      .[0].children[] | walk_tree("")
    else
      .[] | walk_tree("")
    end
  ' | jq -s '.')
  
  # Count total files
  TOTAL_FILE_COUNT=$(echo "$FILES_LIST" | jq 'length' 2>/dev/null || echo "0")
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
  
  # Create temporary files for tracking
  PIDS_FILE=$(mktemp)
  FILES_TO_PROCESS=$(mktemp)
  
  # Save files list to temp file
  echo "$FILES_LIST" | jq -r '.[] | @json' > "$FILES_TO_PROCESS"
  
  # Parse file list and download each file in parallel
  while IFS= read -r file; do
    filename=$(echo "$file" | jq -r '.name')
    uid=$(echo "$file" | jq -r '.uid')
    
    # Skip if filename is empty
    if [ -z "$filename" ]; then
      continue
    fi
    
    # Download file in background
    (
      # Create directory if needed
      filedir=$(dirname "$filename")
      if [ "$filedir" != "." ]; then
        mkdir -p "$filedir"
      fi
      
      # Download file content and decode base64
      FILE_RESPONSE=$(curl -s \
        -H "Authorization: Bearer $VERCEL_TOKEN" \
        "$VERCEL_API_URL/v8/deployments/$DEPLOYMENT_ID/files/$uid")
      
      # Check if response contains data field
      if echo "$FILE_RESPONSE" | jq -e '.data' > /dev/null 2>&1; then
        # Extract base64 data and decode
        echo "$FILE_RESPONSE" | jq -r '.data' | base64 -d > "$filename"
        echo "✅ Downloaded: $filename"
      else
        echo "❌ Failed to download $filename: No .data field in response"
        echo "Response: $(echo "$FILE_RESPONSE" | head -c 200)"
      fi
    ) &
    
    # Store PID in file
    echo $! >> "$PIDS_FILE"
    
    # Limit concurrent downloads to 10 at a time
    PID_COUNT=$(wc -l < "$PIDS_FILE")
    if [ "$PID_COUNT" -ge 10 ]; then
      # Wait for these PIDs
      while read -r pid; do
        wait "$pid" 2>/dev/null || true
      done < "$PIDS_FILE"
      # Clear the file
      > "$PIDS_FILE"
    fi
  done < "$FILES_TO_PROCESS"
  
  # Wait for all remaining downloads to complete
  echo "⏳ Waiting for all downloads to complete..."
  while read -r pid; do
    wait "$pid" 2>/dev/null || true
  done < "$PIDS_FILE"
  
  # Clean up temporary files
  rm -f "$PIDS_FILE" "$FILES_TO_PROCESS"
  
  echo "✅ All files downloaded successfully!"
else
  echo "❌ ERROR: jq is not available"
  echo "jq is required for parsing JSON responses"
  exit 1
fi

# Clean up temporary files
rm -f /tmp/files_response.json

echo ""

# Install dependencies after initial download
if [ -f "package.json" ]; then
  echo "📦 Installing dependencies..."
  npm install
  echo "✅ Dependencies installed"
fi

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
