#!/bin/bash

echo "=============================================="
echo "🚀 Starting Application Deployment"
echo "=============================================="
echo "📅 Timestamp: $(date)"
echo "🐍 Python Version: $(python --version)"
echo "📦 Working Directory: $(pwd)"
echo "📋 Environment Variables:"
echo "  - CHAT_ID: $CHAT_ID"
echo "  - VERSION_ID: $VERSION_ID"
echo "  - V0_API_URL: $V0_API_URL"
echo "=============================================="

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source /opt/venv/bin/activate

echo "📦 Installed packages:"
pip list

echo "🔍 Checking main.py imports..."
python -c "
import sys
try:
    print('✅ Testing imports...')
    import main
    print('✅ All imports successful!')
except ImportError as e:
    print(f'❌ Import Error: {e}')
    print('📦 Missing dependencies detected!')
    print('💡 This is likely the cause of deployment failure.')
    sys.exit(1)
except Exception as e:
    print(f'❌ Other Error: {e}')
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ Import test failed - keeping container alive for debugging..."
    echo "🔧 You can check logs in Coolify to see the exact error"
    echo "⏰ Container will stay alive for 1 hour for debugging"
    sleep 3600
    exit 1
fi

echo "🚀 Starting uvicorn server..."
uvicorn main:app --host 0.0.0.0 --port 8000