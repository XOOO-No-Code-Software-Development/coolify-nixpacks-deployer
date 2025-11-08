#!/bin/bash
# Build XOOO Backend Base Image on Coolify Server
# This script should be run on the Coolify server via SSH

set -euo pipefail

# Configuration
IMAGE_NAME="xooo-backend-base"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "🐳 Building XOOO Backend Base Image"
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
    echo "Please run this script from the base-image directory"
    exit 1
fi

# Check if requirements.txt exists
if [ ! -f "${BUILD_DIR}/requirements.txt" ]; then
    echo "❌ Error: requirements.txt not found in ${BUILD_DIR}"
    exit 1
fi

# Check if nixpkgs-config.nix exists
if [ ! -f "${BUILD_DIR}/nixpkgs-config.nix" ]; then
    echo "❌ Error: nixpkgs-config.nix not found in ${BUILD_DIR}"
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
    "${BUILD_DIR}/.."

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
echo "Python and pip:"
sudo docker run --rm "${FULL_IMAGE_NAME}" "python --version && pip --version"
echo ""
echo "Installed packages:"
sudo docker run --rm "${FULL_IMAGE_NAME}" "pip list"
echo ""
echo "PostgREST:"
if sudo docker run --rm "${FULL_IMAGE_NAME}" "test -f /usr/local/bin/postgrest && /usr/local/bin/postgrest --version"; then
    echo "✅ PostgREST installed correctly"
else
    echo "⚠️  PostgREST not found or not executable"
fi

echo ""
echo "======================================"
echo "🎉 Base image is ready to use!"
echo "======================================"
echo ""

# Create a dummy container to keep the image from being pruned
echo "🔒 Creating protection container to prevent cleanup..."
if sudo docker ps -a --format '{{.Names}}' | grep -q '^xooo-base-keeper$'; then
    echo "   Protection container already exists"
else
    sudo docker create --name xooo-base-keeper "${FULL_IMAGE_NAME}" echo "keeper"
    echo "   ✅ Protection container created"
fi
echo ""

echo "Next steps:"
echo "1. Update nixpacks.toml to use this base image"
echo "2. Deploy your application - it will use the base image automatically"
echo "3. Enjoy faster deployments! ⚡"
echo ""
echo "To rebuild this image in the future, run:"
echo "  bash $(basename "${BASH_SOURCE[0]}")"
echo ""
