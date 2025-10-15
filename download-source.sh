#!/bin/bash
set -e

echo "=================================================="
echo "Downloading source code from ZIP URL"
echo "=================================================="

# Check if SOURCE_URL is set
if [ -z "$SOURCE_URL" ]; then
  echo "❌ ERROR: SOURCE_URL environment variable not set"
  exit 1
fi

echo "📦 Source URL: $SOURCE_URL"

# Clean current directory (except this script and .git)
echo "🧹 Cleaning workspace..."
find . -mindepth 1 -maxdepth 1 \
  ! -name 'download-source.sh' \
  ! -name '.git' \
  ! -name '.gitignore' \
  ! -name 'README.md' \
  -exec rm -rf {} +

# Download the zip file
echo "⬇️  Downloading source code..."
curl -L -f -o source.zip "$SOURCE_URL"

# Extract zip
echo "📂 Extracting files..."
unzip -q source.zip

# Handle nested directory structure (GitHub/GitLab create wrapper folders)
extracted_dir=$(find . -mindepth 1 -maxdepth 1 -type d ! -name '.git' | head -n 1)

if [ -n "$extracted_dir" ]; then
  echo "📁 Moving contents from: $extracted_dir"
  # Move all files to current directory
  shopt -s dotglob
  mv "$extracted_dir"/* . 2>/dev/null || true
  rmdir "$extracted_dir" 2>/dev/null || true
fi

# Clean up
rm -f source.zip

echo "✅ Source code ready!"
echo ""
echo "📋 Files in workspace:"
ls -la

echo ""
echo "=================================================="
echo "Nixpacks will now auto-detect and build your app"
echo "=================================================="
