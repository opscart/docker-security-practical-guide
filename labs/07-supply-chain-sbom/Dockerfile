# Sample Dockerfile for Lab 07 SBOM demonstrations
# This is a simple Node.js application used to demonstrate SBOM generation

FROM node:18.20.5-alpine3.20 AS base

# Add metadata labels
LABEL org.opencontainers.image.title="Sample App for SBOM Demo"
LABEL org.opencontainers.image.description="Simple Node.js app for demonstrating SBOM generation"
LABEL org.opencontainers.image.vendor="OpscartLabs"
LABEL org.opencontainers.image.version="1.0.0"

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code
COPY server.js ./

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application
CMD ["node", "server.js"]