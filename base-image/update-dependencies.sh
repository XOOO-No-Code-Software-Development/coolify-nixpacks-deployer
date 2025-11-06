#!/bin/bash
# Update dependencies in the XOOO backend base image
# This script helps maintain the base image with latest dependency versions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"

echo "======================================"
echo "🔄 XOOO Base Image Dependency Updater"
echo "======================================"
echo ""

# Check if requirements.txt exists
if [ ! -f "${REQUIREMENTS_FILE}" ]; then
    echo "❌ Error: requirements.txt not found"
    exit 1
fi

echo "📋 Current dependencies:"
cat "${REQUIREMENTS_FILE}"
echo ""

# Show options
echo "What would you like to do?"
echo ""
echo "1) Add a new dependency"
echo "2) Update dependency version"
echo "3) Remove a dependency"
echo "4) Check for available updates"
echo "5) Rebuild base image with current dependencies"
echo "6) Exit"
echo ""

read -p "Enter your choice (1-6): " -n 1 -r
echo ""
echo ""

case $REPLY in
    1)
        echo "📦 Add new dependency"
        echo ""
        read -p "Package name: " package_name
        read -p "Version (or press Enter for latest): " package_version
        
        if [ -z "$package_version" ]; then
            new_line="$package_name"
        else
            new_line="${package_name}==${package_version}"
        fi
        
        echo "$new_line" >> "${REQUIREMENTS_FILE}"
        echo "✅ Added: $new_line"
        echo ""
        echo "Would you like to rebuild the base image now?"
        read -p "(y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bash "${SCRIPT_DIR}/build-base-image.sh"
        fi
        ;;
        
    2)
        echo "🔄 Update dependency version"
        echo ""
        read -p "Package name to update: " package_name
        read -p "New version: " new_version
        
        if grep -q "^${package_name}==" "${REQUIREMENTS_FILE}"; then
            # Using different delimiters for sed to avoid issues with special characters
            sed -i.bak "s|^${package_name}==.*|${package_name}==${new_version}|" "${REQUIREMENTS_FILE}"
            rm "${REQUIREMENTS_FILE}.bak"
            echo "✅ Updated ${package_name} to version ${new_version}"
            echo ""
            echo "Would you like to rebuild the base image now?"
            read -p "(y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                bash "${SCRIPT_DIR}/build-base-image.sh"
            fi
        else
            echo "❌ Package ${package_name} not found in requirements.txt"
        fi
        ;;
        
    3)
        echo "🗑️  Remove dependency"
        echo ""
        read -p "Package name to remove: " package_name
        
        if grep -q "^${package_name}" "${REQUIREMENTS_FILE}"; then
            grep -v "^${package_name}" "${REQUIREMENTS_FILE}" > "${REQUIREMENTS_FILE}.tmp"
            mv "${REQUIREMENTS_FILE}.tmp" "${REQUIREMENTS_FILE}"
            echo "✅ Removed ${package_name}"
            echo ""
            echo "Would you like to rebuild the base image now?"
            read -p "(y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                bash "${SCRIPT_DIR}/build-base-image.sh"
            fi
        else
            echo "❌ Package ${package_name} not found in requirements.txt"
        fi
        ;;
        
    4)
        echo "🔍 Checking for available updates..."
        echo ""
        echo "This requires pip-outdated or pip list --outdated"
        echo "Installing pip-outdated in temporary venv..."
        
        temp_venv=$(mktemp -d)
        python3 -m venv "$temp_venv"
        source "$temp_venv/bin/activate"
        
        pip install --quiet -r "${REQUIREMENTS_FILE}"
        echo ""
        echo "📊 Outdated packages:"
        pip list --outdated
        
        deactivate
        rm -rf "$temp_venv"
        ;;
        
    5)
        echo "🔨 Rebuilding base image..."
        bash "${SCRIPT_DIR}/build-base-image.sh"
        ;;
        
    6)
        echo "👋 Goodbye!"
        exit 0
        ;;
        
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Done!"
echo ""
echo "💡 Tip: Don't forget to commit and push changes to the repository:"
echo "   git add ${REQUIREMENTS_FILE}"
echo "   git commit -m 'Update base image dependencies'"
echo "   git push origin main"
echo ""
