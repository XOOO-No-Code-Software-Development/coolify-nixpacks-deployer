#!/bin/bash
# Build PostgreSQL with Notifications Image on Coolify Server
# This script should be run on the Coolify server via SSH

set -euo pipefail

# Configuration
IMAGE_NAME="xooo-postgres-notifications"
IMAGE_TAG="16"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "🐘 Building PostgreSQL with Notifications"
echo "======================================"
echo ""
echo "📦 Image: ${FULL_IMAGE_NAME}"
echo "📁 Build directory: ${BUILD_DIR}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed or not in PATH"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "${BUILD_DIR}/Dockerfile" ]; then
    echo "❌ Error: Dockerfile not found in ${BUILD_DIR}"
    echo "Please run this script from the postgres-with-notifications directory"
    exit 1
fi

# Check if init script exists
if [ ! -f "${BUILD_DIR}/init-schema-notifications.sql" ]; then
    echo "❌ Error: init-schema-notifications.sql not found in ${BUILD_DIR}"
    exit 1
fi

echo "✅ All required files found"
echo ""

# Check if image already exists
if sudo docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${FULL_IMAGE_NAME}$"; then
    echo "⚠️  Image ${FULL_IMAGE_NAME} already exists"
    echo ""
    read -p "Do you want to rebuild it? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Build cancelled"
        exit 0
    fi
    echo ""
fi

echo "🔨 Starting build process..."
echo ""

# Build the image
sudo docker build \
    --progress=plain \
    --tag "${FULL_IMAGE_NAME}" \
    --file "${BUILD_DIR}/Dockerfile" \
    "${BUILD_DIR}"

echo ""
echo "======================================"
echo "✅ Build completed successfully!"
echo "======================================"
echo ""

# Show image details
echo "📊 Image details:"
sudo docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
echo ""

# Verify the image
echo "🔍 Verifying image..."
echo ""
echo "PostgreSQL version:"
sudo docker run --rm "${FULL_IMAGE_NAME}" postgres --version
echo ""

# Test that the init script is present
echo "Checking initialization script:"
if sudo docker run --rm "${FULL_IMAGE_NAME}" ls -lh /docker-entrypoint-initdb.d/init-schema-notifications.sql; then
    echo "✅ Initialization script installed correctly"
else
    echo "⚠️  Initialization script not found"
fi

echo ""
echo "======================================"
echo "🎉 PostgreSQL image is ready to use!"
echo "======================================"
echo ""
echo "Image name: ${FULL_IMAGE_NAME}"
echo ""
echo "Next steps:"
echo "1. Update your database creation code to use: ${FULL_IMAGE_NAME}"
echo "2. When a new database is created, it will automatically:"
echo "   - Set up schema change notifications"
echo "   - Listen for DDL commands (CREATE/ALTER/DROP TABLE)"
echo "   - Send notifications to 'schema_changed' channel"
echo ""
echo "3. In your application, connect and listen:"
echo "   await sql.listen('schema_changed', (payload) => { ... })"
echo ""
echo "To rebuild this image in the future, run:"
echo "  bash $(basename "${BASH_SOURCE[0]}")"
echo ""
