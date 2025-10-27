#!/bin/bash

# Activate virtual environment
source /opt/venv/bin/activate

# Start the application (validation already done during build)
uvicorn main:app --host 0.0.0.0 --port 8000