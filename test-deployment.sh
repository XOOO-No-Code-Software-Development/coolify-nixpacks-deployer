#!/bin/bash
set -e

echo "=================================================="
echo "Testing Deployment Script"
echo "=================================================="

# Load environment variables from .env.local
if [ ! -f "../.env.local" ]; then
  echo "❌ ERROR: .env.local not found in parent directory"
  exit 1
fi

echo "📦 Loading environment variables from .env.local..."
export $(cat ../.env.local | grep -E "^(V0_API_KEY|V0_API_URL|COOLIFY_|DATABASE_)" | xargs)

# Set test parameters
export CHAT_ID="gR8PJTuP6vB"
export VERSION_ID="b_ODMNkm2riEq"

echo "🧪 Test Parameters:"
echo "   CHAT_ID: $CHAT_ID"
echo "   VERSION_ID: $VERSION_ID"
echo "   V0_API_URL: ${V0_API_URL:-https://api.v0.dev/v1}"
echo ""

# Create a temporary test directory
TEST_DIR=$(mktemp -d)
echo "📁 Creating test directory: $TEST_DIR"

# Copy necessary files to test directory
cp download-source.sh "$TEST_DIR/"
cp -r backend "$TEST_DIR/"

cd "$TEST_DIR"

echo ""
echo "=================================================="
echo "Running download-source.sh"
echo "=================================================="

# Run the download script
bash download-source.sh

echo ""
echo "=================================================="
echo "Test Results"
echo "=================================================="

# Check if files were created
FILE_COUNT=$(find . -type f | wc -l)
echo "✅ Total files created: $FILE_COUNT"

echo ""
echo "📋 Directory structure:"
find . -type f | head -20

echo ""
echo "📋 Main files:"
if [ -f "main.py" ]; then
  echo "   ✅ main.py exists ($(wc -l < main.py) lines)"
else
  echo "   ❌ main.py missing"
fi

if [ -f "requirements.txt" ]; then
  echo "   ✅ requirements.txt exists"
  cat requirements.txt
else
  echo "   ❌ requirements.txt missing"
fi

echo ""
echo "🧹 Cleaning up test directory: $TEST_DIR"
rm -rf "$TEST_DIR"

echo ""
echo "=================================================="
echo "✅ Test completed successfully!"
echo "=================================================="
