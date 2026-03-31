# Scenario 1: Secret Anti-Patterns — What NOT to Do

## Overview

This scenario demonstrates 5 common ways developers accidentally leak secrets in Docker containers. Each example shows the vulnerability and how to detect it.

**Time:** 15 minutes

**Learning Objectives:**
- Identify 5 secret leakage vectors in Docker
- Use docker inspect, docker history, and process inspection to find secrets
- Understand why each pattern is dangerous
- Recognize these patterns in real codebases

## The 5 Anti-Patterns

### 1. **Hardcoded Secrets in Dockerfiles**
Embedding credentials directly in the Dockerfile.

**Risk:** Secrets persist in image layers forever, visible via `docker history`.

### 2. **Environment Variables**
Passing secrets as ENV vars in docker-compose or docker run.

**Risk:** Visible in `docker inspect`, process lists, and container metadata.

### 3. **Build Arguments (ARG)**
Using ARG to pass secrets during image build.

**Risk:** Visible in `docker history` and image metadata.

### 4. **Mounted Secret Files with Wrong Permissions**
Mounting host files containing secrets with 0644 permissions.

**Risk:** Readable by any process in the container, logged in Docker events.

### 5. **Secrets Committed to Git**
Accidentally committing `.env` or secret files to version control.

**Risk:** Permanent exposure in git history, even after file deletion.

## Running the Demo

### Prerequisites
- Docker Desktop running
- Basic understanding of Docker commands

### Execute All Anti-Patterns
```bash
cd scenario-1-antipatterns
chmod +x demo.sh
./demo.sh
```

The script will:
1. Build images with hardcoded secrets
2. Run containers with environment variable secrets
3. Demonstrate how to extract secrets from each anti-pattern
4. Show detection commands for each vulnerability

### Expected Output

You'll see:
- Secrets visible in `docker history`
- Secrets visible in `docker inspect`
- Secrets visible in process environment variables
- Secrets visible in mounted files
- Secrets visible in git history

## Detection Commands

After running the demo, verify secrets leaked:
```bash
# Anti-Pattern 1: Check image history
docker history lab10-hardcoded:latest | grep -i password

# Anti-Pattern 2: Check environment variables
docker inspect lab10-envvars | jq '.[].Config.Env'

# Anti-Pattern 3: Check build arguments
docker history lab10-buildargs:latest | grep ARG

# Anti-Pattern 4: Check mounted files
docker exec lab10-volumes cat /run/secrets/api_key.txt

# Anti-Pattern 5: Check git history
cd examples/5-git-history && git log --all --full-history -- leaked_secret.txt
```

## What You Should See

### Anti-Pattern 1 Output:
<missing>      271 B     RUN echo "DB_PASSWORD=SuperSecret123" >> /app/config

### Anti-Pattern 2 Output:
```json
{
  "Env": [
    "DATABASE_PASSWORD=ProductionPassword123",
    "API_KEY=sk-1234567890abcdef"
  ]
}
```

### Anti-Pattern 3 Output:
<missing>      0 B       ARG SECRET_TOKEN=ghp_1234567890abcdefghij

### Anti-Pattern 4 Output:
sk-prod-9876543210fedcba

### Anti-Pattern 5 Output:

commit abc123def456...
Added API credentials for testing
+API_SECRET=secret_key_here

## Why These Patterns Are Dangerous

### 1. Hardcoded Secrets
- **Persist forever** in image layers
- Visible to anyone with image access
- Can't be rotated without rebuilding image
- Exposed in Docker Hub/registry if pushed

### 2. Environment Variables
- Visible in `docker inspect`
- Visible in `/proc/<pid>/environ`
- Logged by orchestrators (Docker events, K8s logs)
- Inherited by child processes

### 3. Build Arguments
- Visible in `docker history`
- Stored in image metadata
- Leak through layer caching
- Visible in build logs

### 4. Mounted Files (Wrong Permissions)
- Readable by all container processes
- Visible in Docker volume listings
- Logged in Docker events
- No rotation mechanism

### 5. Git History
- **Permanent** even after file deletion
- Accessible to anyone with repo access
- Visible in forks and mirrors
- Requires force-push to remove (breaks history)

## Real-World Examples

### Example 1: Hardcoded AWS Keys
```dockerfile
# DON'T DO THIS
FROM python:3.9
ENV AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
ENV AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

**Impact:** If image is pushed to Docker Hub, keys are public.

### Example 2: Database Password in Compose
```yaml
# DON'T DO THIS
services:
  app:
    environment:
      - DB_PASSWORD=prod_password_2024
```

**Impact:** Anyone with `docker inspect` access sees the password.

### Example 3: Private Key in Git
```bash
# File accidentally committed: .env
DATABASE_URL=postgresql://admin:SuperSecret@db:5432/prod
STRIPE_SECRET_KEY=sk_live_51...
```

**Impact:** Permanent exposure in git history.

## Cleanup
```bash
./cleanup.sh
```

This removes:
- All demo containers
- All demo images
- Temporary files created during demo

## Validation
```bash
./validate.sh
```

Checks:
1. All 5 anti-patterns are detectable
2. Secrets are visible via documented commands
3. Images and containers are properly tagged

## Next Steps

**Scenario 2** shows the correct way to handle secrets using Docker Swarm native secrets.

**Key Takeaway:** Never store secrets in images, environment variables, or git. Use Docker secrets (Scenario 2) or external secret managers (Scenario 3).

## References

- [OWASP: Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [Docker Security: Secrets](https://docs.docker.com/engine/swarm/secrets/)
- [GitGuardian: Secrets Detection](https://www.gitguardian.com/)