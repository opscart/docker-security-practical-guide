# mcp-server/Dockerfile
# Multi-stage build for MCP server with Docker CLI

# ============================================================================
# STAGE 1: Builder - Install dependencies
# ============================================================================
FROM python:3.11-slim as builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies to /install directory
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ============================================================================
# STAGE 2: Runtime - Minimal image with Docker CLI
# ============================================================================
FROM python:3.11-slim

# Install Docker CLI (for container operations)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && apt-get remove -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user (Security pattern from Lab 03)
RUN groupadd -r mcp && useradd -r -g mcp -u 1000 mcp

# Add mcp user to docker group (for socket access)
RUN groupadd -f docker && usermod -aG docker mcp

# Create application directory
WORKDIR /app

# Copy installed dependencies from builder
COPY --from=builder /install /usr/local

# Copy application code
COPY server.py .

# Create log directory (writable)
RUN mkdir -p /var/log/mcp/audit && chown -R mcp:mcp /var/log/mcp

# Switch to non-root user
USER mcp

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:3000/health').raise_for_status()"

# Expose MCP port
EXPOSE 3000

# Run server
CMD ["python", "-u", "server.py"]