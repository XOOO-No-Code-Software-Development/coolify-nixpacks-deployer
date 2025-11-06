#!/bin/bash
# Quick deployment script to build base image on Coolify server
# Run this on your LOCAL machine - it will SSH to Coolify and build

set -euo pipefail

COOLIFY_SERVER="xoooadminuser@xoooai"
REPO_URL="https://github.com/XOOO-No-Code-Software-Development/coolify-nixpacks-deployer.git"
WORK_DIR="/tmp/xooo-base-image-build"

echo "======================================"
echo "🚀 XOOO Base Image Remote Builder"
echo "======================================"
echo ""
echo "This script will:"
echo "1. SSH into your Coolify server"
echo "2. Clone/update the deployer repository"
echo "3. Build the base image"
echo "4. Clean up temporary files"
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 0
fi

echo ""
echo "🔗 Connecting to Coolify server..."

# Build script to run on remote server
REMOTE_SCRIPT=$(cat <<'EOF'
set -euo pipefail

WORK_DIR="/tmp/xooo-base-image-build"
REPO_URL="https://github.com/XOOO-No-Code-Software-Development/coolify-nixpacks-deployer.git"

echo ""
echo "📦 Setting up build environment..."

# Create work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Clone or update repository
if [ -d "coolify-nixpacks-deployer" ]; then
    echo "📥 Updating existing repository..."
    cd coolify-nixpacks-deployer
    git pull origin main
else
    echo "📥 Cloning repository..."
    git clone "$REPO_URL"
    cd coolify-nixpacks-deployer
fi

echo ""
echo "🔨 Building base image..."
cd base-image
chmod +x build-base-image.sh
bash build-base-image.sh

echo ""
echo "✅ Base image built successfully on Coolify server!"
echo ""
echo "🧹 Cleaning up..."
cd /
rm -rf "$WORK_DIR"

echo ""
echo "======================================"
echo "🎉 Setup complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Your base image is ready: xooo-backend-base:latest"
echo "2. Deploy a new backend from XOOO platform"
echo "3. Watch the deployment complete in ~12s instead of ~25s!"
echo ""
EOF
)

# Execute on remote server
ssh "$COOLIFY_SERVER" "bash -s" <<< "$REMOTE_SCRIPT"

echo ""
echo "✅ Done! Base image is ready on Coolify server."
echo ""
