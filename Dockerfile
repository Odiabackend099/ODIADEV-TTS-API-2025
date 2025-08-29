# ODIADEV TTS API - Enhanced Dockerfile with Nigerian Voices
FROM python:3.11-slim

# Metadata
LABEL maintainer="ODIADEV Team"
LABEL description="Production-ready TTS API with Nigerian English voices"
LABEL version="1.0.0"

# Environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    TTS_CACHE_DIR=/app/cache \
    TTS_MODEL_DIR=/app/models

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Audio processing
    ffmpeg \
    libsndfile1 \
    # Build tools
    build-essential \
    gcc \
    g++ \
    # Network tools
    curl \
    wget \
    git \
    # System libraries for TTS
    espeak-ng \
    espeak-ng-data \
    libespeak-ng-dev \
    # Python dev headers
    python3-dev \
    # Clean up
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create application directories
WORKDIR /app
RUN mkdir -p /app/cache /app/models /app/logs /app/output

# Copy requirements first (for better caching)
COPY server/requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /app/requirements.txt

# Copy application code
COPY server/ /app/server/
COPY config/ /app/config/

# Copy voice configuration
COPY voices/ /app/voices/

# Copy TTS initialization script
COPY scripts/init_tts.py /app/init_tts.py

# Pre-download TTS models (this will cache them in the container)
RUN python /app/init_tts.py

# Copy health check script
COPY scripts/healthcheck.py /app/healthcheck.py

# Set proper permissions
RUN chmod +x /app/healthcheck.py && \
    chown -R nobody:nogroup /app/cache /app/models /app/logs /app/output

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash odiadev && \
    chown -R odiadev:odiadev /app

# Switch to non-root user
USER odiadev

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python /app/healthcheck.py

# Startup command
CMD ["uvicorn", "server.app:app", "--host", "0.0.0.0", "--port", "3000", "--workers", "1"]