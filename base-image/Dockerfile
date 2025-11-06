# XOOO Backend Base Image
# Pre-installs all common dependencies to speed up deployments
# Based on the nixpacks Ubuntu image with Python 3.11

FROM ghcr.io/railwayapp/nixpacks:ubuntu-1745885067

LABEL org.opencontainers.image.source="https://github.com/XOOO-No-Code-Software-Development/xooo-ai-platform"
LABEL org.opencontainers.image.description="XOOO Backend Base Image with Python 3.11, FastAPI, and PostgREST"
LABEL org.opencontainers.image.version="1.0.0"

# Set shell options for better error handling
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

WORKDIR /app/

# ============================================
# LAYER 1: Install Nix packages
# ============================================
COPY base-image/nixpkgs-config.nix /tmp/nixpkgs-config.nix
RUN nix-env -if /tmp/nixpkgs-config.nix && \
    nix-collect-garbage -d && \
    rm /tmp/nixpkgs-config.nix

# ============================================
# LAYER 2: Install system packages (curl, wget)
# ============================================
RUN sudo apt-get update && \
    sudo apt-get install -y --no-install-recommends \
        curl \
        wget \
        ca-certificates && \
    sudo apt-get clean && \
    sudo rm -rf /var/lib/apt/lists/*

# ============================================
# LAYER 3: Set Python environment variables
# ============================================
ENV PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PYTHONHASHSEED=random \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_DEFAULT_TIMEOUT=100

# ============================================
# LAYER 4: Create Python virtual environment
# ============================================
RUN python -m venv /opt/venv

# ============================================
# LAYER 5: Install Python dependencies
# ============================================
COPY base-image/requirements.txt /tmp/requirements.txt

RUN . /opt/venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# ============================================
# LAYER 6: Install PostgREST
# ============================================
RUN wget -O /tmp/postgrest.tar.xz \
        https://github.com/PostgREST/postgrest/releases/download/v12.2.3/postgrest-v12.2.3-linux-static-x64.tar.xz && \
    tar -xJf /tmp/postgrest.tar.xz -C /tmp && \
    mv /tmp/postgrest /usr/local/bin/postgrest && \
    chmod +x /usr/local/bin/postgrest && \
    rm /tmp/postgrest.tar.xz

# ============================================
# LAYER 7: Verify installations
# ============================================
RUN . /opt/venv/bin/activate && \
    python --version && \
    pip --version && \
    pip list && \
    postgrest --version && \
    echo "✅ Base image built successfully!"

# Set entrypoint back to bash
ENTRYPOINT ["/bin/bash", "-l", "-c"]

# Default working directory for applications
WORKDIR /app/

# Add activation to bash profile so venv is always active
RUN echo 'source /opt/venv/bin/activate' >> /root/.bashrc
