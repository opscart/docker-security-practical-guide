# Scenario 4: BuildKit Secret Mounts

## Overview

BuildKit secret mounts allow you to pass secrets to Docker builds without persisting them in image layers. Unlike ARG (which leaks in docker history), secret mounts are only available during build and never appear in the final image.

**Time:** 15 minutes  
**Requirements:** BuildKit enabled (default in Docker Desktop 18.09+)

## What You'll Learn

- Pass secrets to builds without ARG leakage
- Access private npm/pip/gem registries during build
- Use SSH keys for private git repos during build
- Implement multi-stage builds with secret isolation
- Verify secrets don't persist in final image

## Prerequisites

- Docker Desktop 18.09+ (BuildKit enabled by default)
- Basic understanding of Dockerfiles

## The Problem with ARG

### Anti-Pattern (from Scenario 1)

```dockerfile
# BAD: Secret visible in docker history
ARG NPM_TOKEN
RUN echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > .npmrc
RUN npm install
```

**Result:** `NPM_TOKEN` visible in `docker history` forever.

## The Solution: BuildKit Secrets

### Secure Pattern

```dockerfile
# GOOD: Secret not in image
RUN --mount=type=secret,id=npm_token \
  NPM_TOKEN=$(cat /run/secrets/npm_token) && \
  echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > .npmrc && \
  npm install && \
  rm .npmrc
```

**Build command:**
```bash
docker build --secret id=npm_token,src=.npmrc .
```

**Result:** Secret only available during RUN, not in final image or history.

## Running the Demo

```bash
./demo.sh
```

This demonstrates:
1. Basic secret mount (API token)
2. Private npm registry access
3. SSH key for private git repo
4. Multi-stage build with secrets

## Key Concepts

### How Secret Mounts Work

1. **Mount Point:** Secrets available at `/run/secrets/<id>` during build
2. **Temporary:** Only available for that RUN instruction
3. **No Persistence:** Never written to image layers
4. **Build-Time Only:** Not available in final container

### Secret Mount Syntax

```dockerfile
RUN --mount=type=secret,id=<secret_id>[,target=<path>] \
  command-using-secret
```

**Parameters:**
- `id` - Secret identifier (matches build command)
- `target` - Optional custom mount path (default: /run/secrets/<id>)
- `required` - Optional: fail build if secret missing (default: true)

### Build Command

```bash
# From file
docker build --secret id=mysecret,src=./secret.txt .

# From environment variable
docker build --secret id=mysecret,env=MY_SECRET_VAR .

# From stdin
echo "secret-value" | docker build --secret id=mysecret .
```

## Example 1: Basic Secret

**Dockerfile:**
```dockerfile
FROM alpine:3.20.3

RUN --mount=type=secret,id=api_token \
  API_TOKEN=$(cat /run/secrets/api_token) && \
  echo "Using token: ${API_TOKEN:0:8}***" && \
  echo "Token would be used for API calls here"
```

**Build:**
```bash
echo "sk-1234567890abcdef" > secret.txt
docker build --secret id=api_token,src=secret.txt -t app:latest .
rm secret.txt
```

**Verify:**
```bash
docker history app:latest  # Secret NOT visible
docker run app:latest cat /run/secrets/api_token  # File does NOT exist
```

## Example 2: Private npm Registry

**Dockerfile:**
```dockerfile
FROM node:18.20.5-alpine3.20
WORKDIR /app
COPY package.json* ./
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
  npm install --only=production && \
  npm cache clean --force

COPY app.js ./
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app
USER nodejs
CMD ["node", "app.js"]
```

**Note:** This example uses `npm install` for simplicity. For production applications with `package-lock.json`, use `npm ci` for deterministic builds.

**Build:**
```bash
docker build --secret id=npmrc,src=.npmrc -t myapp:latest .
```

**Key Point:** `.npmrc` with token never persists in image.

## Example 3: SSH Key for Private Git Repo

**Dockerfile:**
```dockerfile
FROM alpine:3.20.3
RUN apk add --no-cache git openssh-client

# Clone private repo using SSH key
RUN --mount=type=ssh \
  --mount=type=secret,id=known_hosts,target=/root/.ssh/known_hosts \
  git clone git@github.com:myorg/private-repo.git
```

**Build:**
```bash
# Start SSH agent and add key
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa

# Build with SSH forwarding
docker build --ssh default --secret id=known_hosts,src=~/.ssh/known_hosts .
```

## Example 4: Multi-Stage with Secrets

**Dockerfile:**
```dockerfile
# Build stage - uses secrets
FROM node:18.20.5-alpine3.20 AS builder
WORKDIR /app

COPY package.json .
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
  npm install --production

COPY . .
RUN npm run build

# Final stage - no secrets
FROM nginx:1.27.2-alpine3.20
COPY --from=builder /app/dist /usr/share/nginx/html

# Verify: No .npmrc in final image
RUN test ! -f /root/.npmrc || exit 1
```

**Benefit:** Build dependencies installed securely, final image is clean.

## Security Comparison

| Method | Persists in Image? | Visible in History? | Best For |
|--------|-------------------|-------------------|----------|
| **ARG** | ✅ YES (bad) | ✅ YES (bad) | Public config only |
| **ENV** | ✅ YES (bad) | ✅ YES (bad) | Runtime secrets only |
| **BuildKit Secrets** | ❌ NO (good) | ❌ NO (good) | Build-time secrets |
| **Multi-stage + Secrets** | ❌ NO (good) | ❌ NO (good) | Production builds |

## When to Use BuildKit Secrets

### ✅ Good Use Cases
- Private package registries (npm, pip, gem, maven)
- Private git repositories during build
- API tokens for build-time services
- Certificates for build-time authentication
- License keys for build tools

### ❌ Not Suitable For
- Runtime secrets (use Vault, Swarm secrets)
- Configuration that should be in ENV vars
- Public dependencies (no secrets needed)

## Common Patterns

### Pattern 1: Private npm Registry

```dockerfile
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
  npm install
```

### Pattern 2: Private Python Package Index

```dockerfile
RUN --mount=type=secret,id=pip_conf,target=/root/.pip/pip.conf \
  pip install -r requirements.txt
```

### Pattern 3: Private Docker Registry

```dockerfile
RUN --mount=type=secret,id=docker_config,target=/root/.docker/config.json \
  docker pull private-registry.com/base-image
```

### Pattern 4: Download from Authenticated URL

```dockerfile
RUN --mount=type=secret,id=api_token \
  TOKEN=$(cat /run/secrets/api_token) && \
  curl -H "Authorization: Bearer $TOKEN" \
    https://api.example.com/artifact -o artifact
```

## Cleanup

```bash
./cleanup.sh
```

Removes:
- All demo images
- Temporary secret files

## Validation

```bash
./validate.sh
```

Checks:
1. BuildKit available
2. Secret mounts work
3. Secrets not in final image
4. Secrets not in docker history

## Next Steps

**Scenario 5** covers secret scanning to detect leaked secrets in code repositories and CI/CD pipelines.

## References

- [Docker BuildKit Documentation](https://docs.docker.com/build/buildkit/)
- [BuildKit Secret Mounts](https://docs.docker.com/build/building/secrets/)
- [Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [BuildKit Cache](https://docs.docker.com/build/cache/)

## Common Issues

### Issue: BuildKit not enabled
```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1

# Or use buildx (recommended)
docker buildx build --secret id=mysecret,src=file.txt .
```

### Issue: Secret file not found
```bash
# Verify file exists and path is correct
ls -la secret.txt
docker build --secret id=mysecret,src=./secret.txt .
```

### Issue: Permission denied reading secret
```bash
# Check file permissions
chmod 600 secret.txt
```

## Key Takeaways

1. **Never use ARG for secrets** - always visible in docker history
2. **BuildKit secrets are build-time only** - not for runtime
3. **Multi-stage builds** - combine with secrets for clean final images
4. **Secret files are temporary** - only available during RUN instruction
5. **Verify final image** - always check secrets didn't leak