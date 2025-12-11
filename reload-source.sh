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
  
  # Stop Next.js server BEFORE cleaning files to prevent restart loop
  echo "🛑 Stopping Next.js server for reload..."
  touch /tmp/reload_in_progress  # Signal to startup.sh to not restart yet
  pkill -f "next dev" || true
  
  # Stop Backend if it's running (using PID file for precision)
  echo "🛑 Stopping Backend for reload..."
  if [ -f /tmp/fastapi.pid ]; then
    BACKEND_PID=$(cat /tmp/fastapi.pid)
    if kill -0 $BACKEND_PID 2>/dev/null; then
      echo "   Killing backend process $BACKEND_PID"
      kill $BACKEND_PID 2>/dev/null || true
    else
      echo "   Backend process $BACKEND_PID not running"
    fi
    rm -f /tmp/fastapi.pid
  else
    echo "   No PID file found, backend may not be running"
  fi
  
  sleep 2
  
  # Clean existing files (preserve system files, node_modules, and specific folders)
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
    ! -name 'node_modules' \
    ! -name 'components' \
    ! -name 'public' \
    ! -name 'styles' \
    ! -name 'package.json' \
    ! -name 'test-*.sh' \
    -exec rm -rf {} + 2>/dev/null || true
  
  # Clean components folder but preserve components/ui
  if [ -d "components" ]; then
    echo "🧹 Cleaning components folder (preserving ui)..."
    find components -mindepth 1 -maxdepth 1 \
      ! -name 'ui' \
      -exec rm -rf {} + 2>/dev/null || true
  fi
  
  # Extract and download files
  echo "📂 Downloading deployment files..."
  
  # Create temporary files for tracking
  PIDS_FILE=$(mktemp)
  FILES_TO_PROCESS=$(mktemp)
  DOWNLOAD_LOG=$(mktemp)
  SKIP_LOG=$(mktemp)
  
  # Save files list to temp file
  echo "$FILES_LIST" | jq -r '.[] | @json' > "$FILES_TO_PROCESS"
  
  # Count files to download vs skip
  TOTAL_FILES=0
  SKIPPED_FILES=0
  DOWNLOADED_FILES=0
  
  # Parse file list and download each file in parallel
  while IFS= read -r file; do
    filename=$(echo "$file" | jq -r '.name')
    uid=$(echo "$file" | jq -r '.uid')
    
    # Skip if filename is empty
    if [ -z "$filename" ]; then
      continue
    fi
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    # Skip components/ui files if they already exist
    if [[ "$filename" == components/ui/* ]] && [ -f "$filename" ]; then
      echo "$filename" >> "$SKIP_LOG"
      SKIPPED_FILES=$((SKIPPED_FILES + 1))
      continue
    fi
    
    # Skip public folder files if they already exist
    if [[ "$filename" == public/* ]] && [ -f "$filename" ]; then
      echo "$filename" >> "$SKIP_LOG"
      SKIPPED_FILES=$((SKIPPED_FILES + 1))
      continue
    fi
    
    # Skip styles folder files if they already exist
    if [[ "$filename" == styles/* ]] && [ -f "$filename" ]; then
      echo "$filename" >> "$SKIP_LOG"
      SKIPPED_FILES=$((SKIPPED_FILES + 1))
      continue
    fi
    
    # Special handling for package.json - backup old version to detect changes
    if [[ "$filename" == "package.json" ]] && [ -f "$filename" ]; then
      cp "$filename" "$filename.bak"
    fi
    
    # Special handling for backend/requirements.txt - backup old version to detect changes
    if [[ "$filename" == "backend/requirements.txt" ]] && [ -f "$filename" ]; then
      cp "$filename" "$filename.bak"
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
      
      # Extract base64 data and decode
      echo "$FILE_RESPONSE" | jq -r '.data' | base64 -d > "$filename"
      
      # Log to file (background processes can't reliably echo to stdout)
      echo "✅ Downloaded: $filename" >> "$DOWNLOAD_LOG"
    ) &
    
    # Store PID in file
    echo $! >> "$PIDS_FILE"
    DOWNLOADED_FILES=$((DOWNLOADED_FILES + 1))
    
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
  
  # Show download summary and logs
  echo ""
  echo "📊 Download Summary:"
  echo "   Total files: $TOTAL_FILES"
  echo "   Skipped: $SKIPPED_FILES"
  echo "   Downloaded: $DOWNLOADED_FILES"
  echo ""
  
  # Display skipped files if any
  if [ -f "$SKIP_LOG" ] && [ -s "$SKIP_LOG" ]; then
    echo "⏭️  Skipped files (already exist):"
    cat "$SKIP_LOG" | head -n 10
    SKIP_COUNT=$(wc -l < "$SKIP_LOG")
    if [ "$SKIP_COUNT" -gt 10 ]; then
      echo "   ... and $((SKIP_COUNT - 10)) more"
    fi
    echo ""
  fi
  
  # Display download log if it exists and has content
  if [ -f "$DOWNLOAD_LOG" ] && [ -s "$DOWNLOAD_LOG" ]; then
    echo "📥 Downloaded files:"
    cat "$DOWNLOAD_LOG"
    echo ""
  fi
  
  # Check if package.json actually changed by comparing with backup
  PACKAGE_JSON_CHANGED=false
  if [ -f "package.json" ] && [ -f "package.json.bak" ]; then
    if ! cmp -s "package.json" "package.json.bak"; then
      PACKAGE_JSON_CHANGED=true
    fi
    rm -f "package.json.bak"
  elif [ -f "package.json" ] && [ ! -f "package.json.bak" ]; then
    # No backup means this is first time, so consider it changed
    PACKAGE_JSON_CHANGED=true
  fi
  
  # Check if backend/requirements.txt changed by comparing with backup
  REQUIREMENTS_TXT_CHANGED=false
  if [ -f "backend/requirements.txt" ] && [ -f "backend/requirements.txt.bak" ]; then
    if ! cmp -s "backend/requirements.txt" "backend/requirements.txt.bak"; then
      REQUIREMENTS_TXT_CHANGED=true
    fi
    rm -f "backend/requirements.txt.bak"
  elif [ -f "backend/requirements.txt" ] && [ ! -f "backend/requirements.txt.bak" ]; then
    # No backup means this is first time, so consider it changed
    REQUIREMENTS_TXT_CHANGED=true
  fi
  
  # Clean up temporary files
  rm -f "$PIDS_FILE" "$FILES_TO_PROCESS" "$DOWNLOAD_LOG" "$SKIP_LOG"
  
  echo "✅ All files processed successfully!"
else
  echo "❌ ERROR: jq is not available"
  echo "jq is required for parsing JSON responses"
  exit 1
fi

# Clean up temporary files
rm -f /tmp/files_response.json

echo ""

# Reinstall dependencies only if package.json changed
if [ "$PACKAGE_JSON_CHANGED" = true ]; then
  echo "📦 Package.json changed - installing dependencies..."
  npm install --prefer-offline
  echo "✅ Dependencies installed"
else
  echo "📦 Package.json unchanged - skipping npm install"
fi

echo ""

# Install Python dependencies only if backend/requirements.txt changed
if [ "$REQUIREMENTS_TXT_CHANGED" = true ]; then
  echo "🐍 Requirements.txt changed - installing Python dependencies..."
  
  # Activate virtual environment if it exists (Nix environment requires this)
  if [ -d "/opt/venv" ]; then
    source /opt/venv/bin/activate
  fi
  
  cd backend
  pip install --no-cache-dir -r requirements.txt
  cd ..
  echo "✅ Python dependencies installed"
else
  echo "🐍 Requirements.txt unchanged - skipping pip install"
fi

echo ""
echo "✅ Reload complete!"
echo "🔥 Next.js and Backend will restart with updated code"
echo ""
echo "=================================================="

# Remove lock file at the very end to allow Next.js restart
# This ensures all our output is printed before Next.js floods the logs
rm -f /tmp/reload_in_progress
