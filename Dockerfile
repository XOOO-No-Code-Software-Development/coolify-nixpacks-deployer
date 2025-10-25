# Use Python 3.11 slim image for faster builds
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    wget \
    bash \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy only the download script and backend template first
COPY download-source.sh ./
COPY backend ./backend

# Download/prepare source code (uses backend template for "initial" or fetches from API)
RUN bash download-source.sh

# Create virtual environment and install uvicorn
RUN python -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install --no-cache-dir uvicorn

# Install requirements if they exist
RUN . /opt/venv/bin/activate && \
    if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Set environment variables
ENV PATH="/opt/venv/bin:$PATH"

# Expose port
EXPOSE 8000

# Start command
CMD ["/bin/bash", "-c", ". /opt/venv/bin/activate && uvicorn main:app --host 0.0.0.0 --port 8000"]
