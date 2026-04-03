# File: examples/2-npm-registry/Dockerfile
# BuildKit Secret Mount - NPM Private Registry Authentication
# Demonstrates: Secure credential handling during build without leaking to image

# Pin to specific Node.js version for reproducibility and security
FROM node:18.20.5-alpine3.20

WORKDIR /app

# Copy package files
COPY package.json* ./

# Install dependencies using secret .npmrc
# The .npmrc is ONLY available during this RUN - ephemeral by design
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
  echo "Installing with authenticated npm registry..." && \
  npm install --only=production && \
  npm cache clean --force && \
  echo "Installed successfully!" && \
  echo "Note: .npmrc is NOT in final image"

# Copy application code
COPY app.js ./

# Create non-root user for runtime security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Start application
CMD ["node", "app.js"]