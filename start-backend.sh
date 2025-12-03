#!/bin/bash
# Helper script to start backend with log prefix
source /opt/venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000 --log-level info 2>&1 | while IFS= read -r line; do echo "[BACKEND] $line"; done
