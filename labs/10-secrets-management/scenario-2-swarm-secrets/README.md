# Scenario 2: Docker Swarm Secrets

## Overview

Docker Swarm provides native secret management through encrypted secrets stored in the Swarm manager's Raft log and mounted as in-memory tmpfs filesystems in containers.

**Time:** 20 minutes (Tier 1)  
**Additional:** +15 minutes (Tier 2 - Linux VM for tmpfs verification)

## What You'll Learn

### Tier 1 (macOS/Windows/Linux)
- Create secrets from CLI and files
- Deploy services with secret mounts
- Verify secrets are NOT in docker inspect
- List and inspect secrets
- Remove secrets safely

### Tier 2 (Linux VM Only)
- Verify tmpfs in-memory storage
- Implement zero-downtime secret rotation
- Monitor secret access at kernel level

## Prerequisites

- Docker Swarm mode initialized
- Basic understanding of Docker services

## Key Concepts

### How Swarm Secrets Work

1. **Encrypted Storage:** Secrets stored encrypted in Raft log
2. **In-Memory Mount:** Secrets mounted as tmpfs at `/run/secrets/`
3. **No Disk Persistence:** Secrets never written to disk
4. **Access Control:** Only authorized services can access specific secrets
5. **TLS Transport:** Secrets encrypted in transit to worker nodes

### Security Properties

- ✅ Encrypted at rest (Raft log)
- ✅ Encrypted in transit (TLS)
- ✅ In-memory only (tmpfs, no disk)
- ✅ Access control (per-service permissions)
- ✅ Audit trail (Swarm events)

## Running the Demo

### Initialize Swarm (if not already done)

```bash
docker swarm init
```

### Run Tier 1 Demo

```bash
./demo.sh
```

This demonstrates:
1. Creating secrets from command line
2. Creating secrets from files
3. Deploying a service with secret access
4. Verifying secret content in container
5. Confirming secrets NOT in docker inspect
6. Listing and managing secrets

### Run Tier 2 Demo (Linux VM Only)

```bash
./demo-advanced.sh
```

This demonstrates:
1. tmpfs verification (secrets in RAM only)
2. Zero-downtime secret rotation
3. SIGHUP-based config reload

## What to Expect

### Creating Secrets

```bash
# From command line
$ docker secret create db_password -
ProductionPassword123
<Ctrl+D>

# From file
$ echo "sk-api-key-12345" | docker secret create api_key -

# List secrets
$ docker secret ls
ID           NAME          CREATED         UPDATED
abc123...    db_password   5 seconds ago   5 seconds ago
def456...    api_key       3 seconds ago   3 seconds ago
```

### Deploying with Secrets

```yaml
version: '3.8'
services:
  app:
    image: python:3.9-slim
    secrets:
      - db_password
      - api_key

secrets:
  db_password:
    external: true
  api_key:
    external: true
```

### Secret Mounting

Inside the container:
```bash
$ ls -la /run/secrets/
-r--r--r-- 1 root root 22 db_password
-r--r--r-- 1 root root 17 api_key

$ cat /run/secrets/db_password
ProductionPassword123
```

### Security Verification

```bash
# Secrets NOT visible in inspect
$ docker service inspect app --format '{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}'
[{"File":{"Name":"db_password","UID":"0","GID":"0","Mode":292},"SecretID":"abc123...","SecretName":"db_password"}]

# Secret VALUE is NOT exposed
```

## Comparison with Anti-Patterns

| Method | Visible in docker inspect? | Persisted to disk? | Encrypted? |
|--------|---------------------------|-------------------|------------|
| **ENV vars** | ✅ YES (INSECURE) | ✅ YES | ❌ NO |
| **Mounted files** | ✅ YES | ✅ YES | ❌ NO |
| **Swarm Secrets** | ❌ NO (metadata only) | ❌ NO (tmpfs) | ✅ YES |

## When to Use Swarm Secrets

### ✅ Good Use Cases
- Production deployments using Docker Swarm
- Rotating credentials (database passwords, API keys)
- Multi-service applications with shared secrets
- Compliance requirements (encrypted at rest/transit)

### ❌ Not Suitable For
- Single-node Docker (requires Swarm)
- Kubernetes deployments (use K8s secrets instead)
- Development environments (use .env with caution)
- Build-time secrets (use BuildKit secret mounts)

## Cleanup

```bash
./cleanup.sh
```

Removes:
- All demo services
- All demo secrets
- Leaves Swarm mode active (safe for other labs)

## Validation

```bash
./validate.sh
```

Checks:
1. Swarm mode is active
2. Secrets were created
3. Service deployed successfully
4. Secret mounted correctly in container

## Tier 2: Advanced Topics

See `demo-advanced.sh` for:
- tmpfs filesystem verification
- Zero-downtime rotation with SIGHUP
- Kernel-level secret access monitoring

## Next Steps

**Scenario 3** covers external secret management with HashiCorp Vault for:
- Dynamic secrets (auto-rotating credentials)
- Non-Swarm environments
- Advanced features (transit encryption, audit logging)

## References

- [Docker Secrets Documentation](https://docs.docker.com/engine/swarm/secrets/)
- [Swarm Mode Overview](https://docs.docker.com/engine/swarm/)
- [Secret Rotation Best Practices](https://docs.docker.com/engine/swarm/secrets/#example-rotate-a-secret)