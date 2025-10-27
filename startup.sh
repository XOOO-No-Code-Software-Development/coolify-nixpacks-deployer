#!/bin/bash

# Activate virtual environment
source /opt/venv/bin/activate

# Test application startup - catch all errors
python -c "
import sys
try:
    import main
    # Try to create the FastAPI app to catch configuration errors
    app = main.app
except Exception as e:
    print(f'❌ Error: {e}')
    print(f'❌ Error Type: {type(e).__name__}')
    import traceback
    print('❌ Full traceback:')
    traceback.print_exc()
    sys.exit(1)
" 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Application startup test failed - keeping container alive for debugging..."
    sleep 3600
    exit 1
fi

# Start the application - if it fails, show the error and keep container alive
uvicorn main:app --host 0.0.0.0 --port 8000 || {
    echo "❌ uvicorn failed to start - keeping container alive for debugging..."
    sleep 3600
    exit 1
}