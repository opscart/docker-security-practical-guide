# File: examples/2-npm-registry/Dockerfile
FROM node:18-alpine
 
WORKDIR /app
 
# Copy package.json
COPY package.json* ./
 
# Install dependencies using secret .npmrc
# The .npmrc is ONLY available during this RUN
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
  echo "Installing with authenticated npm registry..." && \
  npm install && \
  echo "Installed successfully!" && \
  echo "Note: .npmrc is NOT in final image"
 
# Copy application code
COPY app.js ./
 
CMD ["node", "app.js"]