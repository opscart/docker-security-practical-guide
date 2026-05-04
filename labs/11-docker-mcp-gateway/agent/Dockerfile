# agent/Dockerfile
# Multi-stage build for AutoGen agent

# ============================================================================
# STAGE 1: Builder
# ============================================================================
FROM python:3.11-slim as builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ============================================================================
# STAGE 2: Runtime
# ============================================================================
FROM python:3.11-slim

# Create non-root user
RUN groupadd -r agent && useradd -r -g agent -u 1000 agent

WORKDIR /app

# Copy installed dependencies
COPY --from=builder /install /usr/local

# Copy application code
COPY agent.py .

# Create log directory
RUN mkdir -p /var/log/agent/audit && chown -R agent:agent /var/log/agent

# Create ready file directory
RUN mkdir -p /tmp && chown -R agent:agent /tmp

# Switch to non-root user
USER agent

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
    CMD python -c "import os; exit(0 if os.path.exists('/tmp/agent_ready') else 1)"

# Run agent
CMD ["python", "-u", "agent.py"]
