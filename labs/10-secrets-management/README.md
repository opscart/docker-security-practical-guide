# Lab 10: Docker Secrets Management

> **Production-grade secrets management from anti-patterns to enterprise solutions**

Learn how to identify secret leakage vectors, implement Docker Swarm native secrets, integrate external secret managers, secure build-time credentials, and prevent accidental secret commits through automated scanning.

**Time:** 90 minutes (Tier 1) | Additional 60+ minutes (Tier 2 - Linux VM)  
**Level:** Production Security  
**Prerequisites:** Docker Desktop or Docker Engine, Git

---

## Overview

This lab covers the complete lifecycle of secrets management in Docker environments:
- **Anti-patterns** that leak secrets in production
- **Native Docker solutions** (Swarm secrets)
- **External secret managers** (HashiCorp Vault)
- **Build-time security** (BuildKit secret mounts)
- **Detection and prevention** (GitLeaks, CI/CD integration)

### What Makes This Different

Most secrets management tutorials focus on single solutions. This lab teaches you to recognize the problem first (anti-patterns), then implement multiple complementary solutions that work together in production environments.

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/opscart/docker-security-practical-guide.git
cd docker-security-practical-guide/labs/10-secrets-management

# Run full setup (initializes Docker Swarm if needed)
./setup.sh

# Jump to any scenario
cd scenario-1-antipatterns && ./demo.sh
cd scenario-2-swarm-secrets && ./demo.sh
cd scenario-3-vault-integration && ./demo.sh
cd scenario-4-buildkit-secrets && ./demo.sh
cd scenario-5-secret-scanning && ./demo.sh
```

---

## Lab Structure

### Tier 1: Core Scenarios (macOS/Windows/Linux Compatible)

**[Scenario 1: Anti-Patterns](./scenario-1-antipatterns/)** — 15 minutes
- Hardcoded secrets visible in `docker history`
- Environment variables exposed in `docker inspect`
- Build arguments persisting in image layers
- Mounted files with insecure permissions
- Git history leaks (permanent even after deletion)

**[Scenario 2: Docker Swarm Secrets](./scenario-2-swarm-secrets/)** — 20 minutes
- Create and manage secrets via Swarm CLI
- Deploy services with in-memory secret mounts
- Verify encryption and tmpfs isolation
- Compare with ENV var anti-patterns

**[Scenario 3: HashiCorp Vault Integration](./scenario-3-vault-integration/)** — 25 minutes
- Run Vault in dev mode (Docker Desktop compatible)
- Store and retrieve secrets via CLI and API
- Application runtime integration
- Centralized secret management patterns

**[Scenario 4: BuildKit Secret Mounts](./scenario-4-buildkit-secrets/)** — 15 minutes
- Pass secrets to builds without ARG leakage
- Access private registries during build (npm, pip, SSH)
- Multi-stage builds with secret isolation
- Verify secrets never persist in final image

**[Scenario 5: Secret Scanning](./scenario-5-secret-scanning/)** — 15 minutes
- Scan repositories with GitLeaks
- Detect secrets in git history
- Set up pre-commit hooks
- Integrate scanning in CI/CD (GitHub Actions, Azure DevOps)

### Tier 2: Advanced Deep-Dive (Linux VM Required)

**Scenario 1+: Memory Forensics**
- Extract secrets from process memory with gdb
- Demonstrate why environment variables are unsafe
- Core dump analysis and string extraction

**Scenario 2+: Production Swarm Secrets**
- tmpfs verification (prove in-memory only)
- Zero-downtime secret rotation with SIGHUP
- Multi-service secret sharing patterns

**Scenario 3+: Production Vault**
- TLS-enabled Vault deployment
- Dynamic database credentials
- Audit logging and compliance reporting
- High-availability configuration

**Scenario 6: Audit & Compliance** (Tier 2 Only)
- Vault audit log analysis
- Docker events monitoring for secret access
- PCI-DSS compliance reporting
- Automated security documentation

---

## Prerequisites

### Tier 1 (All Scenarios 1-5)
- **Docker Desktop** (macOS/Windows) or **Docker Engine** (Linux)
- **Docker Compose** v2.0+
- **Git**
- **8GB RAM** recommended
- **Network access** for pulling images

### Tier 2 (Advanced Scenarios)
- **Linux VM** (Ubuntu 24.04 recommended)
- **Root access** for kernel-level operations
- **gdb**, **strace**, **auditd** packages
- See [TIER2-VM-SETUP.md](./TIER2-VM-SETUP.md) for details

---

## Learning Objectives

By the end of this lab, you will:

1. **Identify** five common secret leakage vectors in containerized applications
2. **Implement** Docker Swarm secrets with encrypted storage and tmpfs mounts
3. **Integrate** HashiCorp Vault for centralized, dynamic secret management
4. **Secure** build-time credentials using BuildKit secret mounts
5. **Prevent** secret commits using GitLeaks, pre-commit hooks, and CI/CD gates
6. **Understand** why secrets in git are permanent (even after deletion)
7. **Compare** native vs external secret management solutions
8. **Generate** detection rules for runtime secret access (Tier 2)

---

## Key Concepts

### Secret Leakage Vectors

1. **Hardcoded Secrets** - Embedded in source code, visible in docker history
2. **Environment Variables** - Exposed via docker inspect, process listings, logs
3. **Build Arguments** - Persist in image layers, visible in metadata
4. **File Permissions** - World-readable secrets in mounted volumes
5. **Git History** - Permanent record, survives file deletion

### Secret Management Solutions

| Solution | Use Case | Encryption | Rotation | Scope |
|----------|----------|------------|----------|-------|
| **Swarm Secrets** | Docker-native, simple deployments | At rest + in transit | Manual | Swarm services |
| **Vault** | Multi-platform, dynamic secrets | At rest + in transit | Automatic | Any application |
| **BuildKit Mounts** | Build-time only | N/A (ephemeral) | N/A | Image builds |
| **Secret Scanning** | Prevention, detection | N/A | N/A | Git repositories |

### Why Multiple Solutions?

Production environments layer these approaches:
- **BuildKit** for build-time credentials (npm tokens, SSH keys)
- **Swarm Secrets** for simple Docker deployments
- **Vault** for complex multi-service architectures
- **GitLeaks** for all environments (prevention layer)

---

## Tools Used

| Tool | Purpose | Scenario |
|------|---------|----------|
| **Docker Swarm** | Native secret management | 2 |
| **HashiCorp Vault** | External secret manager | 3 |
| **BuildKit** | Build-time secret injection | 4 |
| **GitLeaks** | Secret scanning | 5 |
| **gdb** (Tier 2) | Memory forensics | 1+ |
| **Falco** (Tier 2) | Runtime monitoring | 6 |

---

## Scenario Details

### [Scenario 1: Anti-Patterns](./scenario-1-antipatterns/)

**Problem:** Developers embed secrets in ways that seem convenient but create permanent security exposures.

**Demonstrations:**
1. Hardcoded API keys in Dockerfile → `docker history` reveals plaintext
2. ENV vars in compose → `docker inspect` exposes to any user with Docker access
3. Build ARGs → Persist in image metadata, visible to anyone with the image
4. Volume-mounted secrets → Wrong permissions = world-readable
5. Git commits → Secrets in history remain after file deletion

**Key Insight:** Each anti-pattern has a specific attack vector. Understanding *how* they leak is prerequisite to fixing them.

---

### [Scenario 2: Docker Swarm Secrets](./scenario-2-swarm-secrets/)

**Solution:** Docker's native secret management with encrypted storage and in-memory delivery.

**How it works:**
1. Secrets stored encrypted in Swarm's distributed state (etcd/raft)
2. Decrypted only on nodes running services that need them
3. Mounted as in-memory tmpfs at `/run/secrets/`
4. Never written to disk
5. Only service containers can read them

**Comparison:**
- ENV vars: `docker inspect` shows VALUE
- Swarm secrets: `docker inspect` shows NAME only

**Limitations:** Requires Swarm mode, manual rotation, Docker-only

---

### [Scenario 3: HashiCorp Vault Integration](./scenario-3-vault-integration/)

**Solution:** Centralized secret manager with dynamic credentials, audit logging, and fine-grained access control.

**Tier 1 (Dev Mode):**
- HTTP-based Vault container
- CLI and API secret storage/retrieval
- Application integration patterns
- Token-based authentication

**Tier 2 (Production):**
- TLS encryption
- Dynamic database credentials (secrets that auto-expire)
- Audit logging for compliance
- High-availability deployment

**When to use Vault over Swarm:**
- Multi-platform deployments (Docker + VMs + K8s)
- Dynamic secret generation (DB passwords that rotate)
- Audit requirements (PCI-DSS, SOC 2)
- Centralized secret management across teams

---

### [Scenario 4: BuildKit Secret Mounts](./scenario-4-buildkit-secrets/)
 
**Solution:** Pass secrets to builds without embedding them in image layers.
 
**Use Cases:**
1. Private npm/pip registry access during `npm install`
2. SSH keys for cloning private git repos
3. API tokens for downloading artifacts
4. Multi-stage builds where secrets only needed in build stage
 
**Security Properties:**
- Secrets available only during specific RUN instruction
- Never written to image layers
- Not visible in `docker history`
- Automatically removed after build completes
 
**Example:**
```dockerfile
FROM node:18.20.5-alpine3.20
WORKDIR /app
COPY package.json* ./
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
  npm ci --only=production && \
  npm cache clean --force
COPY app.js ./
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app
USER nodejs
CMD ["node", "app.js"]
```
**Build:**
```bash
docker build --secret id=npmrc,src=$HOME/.npmrc -t app .
```
 
**Key Insight:** BuildKit secrets are ephemeral by design. They exist only during the RUN instruction, then disappear - can't leak because they never persist.
 
---

### [Scenario 5: Secret Scanning](./scenario-5-secret-scanning/)

**Solution:** Automated detection of accidentally committed secrets.

**Prevention Layers:**
1. **Pre-commit hooks** - Block commits containing secrets locally
2. **CI/CD scanning** - Fail builds if secrets detected
3. **Periodic audits** - Scheduled repository scans
4. **Custom rules** - Company-specific secret patterns

**GitLeaks Detection:**
- AWS keys: `AKIA[0-9A-Z]{16}`
- GitHub tokens: `ghp_[a-zA-Z0-9]{36}`
- Stripe keys: `sk_live_[a-zA-Z0-9]{99}`
- Generic high-entropy strings

**Critical Fact:** Secrets in git history are permanent. Even after file deletion, they remain in commit history. Always rotate secrets if found.

---

## Common Questions

**Q: Why not just use environment variables?**  
A: ENV vars are visible to any process in the container, appear in `docker inspect` output, get logged by many debugging tools, and are inherited by child processes. They're convenient but not secure.

**Q: Can I use Swarm secrets without full Swarm mode?**  
A: No. Swarm secrets require `docker swarm init`. For single-node deployments, this is fine — you get the secret management benefits without clustering complexity.

**Q: Should I use Vault or Swarm secrets in production?**  
A: Both. Use BuildKit for build secrets, Swarm for simple Docker services, Vault when you need dynamic secrets, audit logs, or multi-platform support.

**Q: How do I remove secrets from git history?**  
A: You can rewrite history with `git filter-branch` or `BFG Repo-Cleaner`, but assume the secret is compromised. Always rotate it.

**Q: What's the difference between Tier 1 and Tier 2?**  
A: Tier 1 runs on Docker Desktop (macOS/Windows/Linux). Tier 2 requires a Linux VM for kernel-level operations like memory forensics, auditd integration, and production Vault with TLS.

---

## Troubleshooting

### Swarm Init Fails
```bash
# Check if already initialized
docker info | grep Swarm

# Force leave and reinit
docker swarm leave --force
docker swarm init
```

### Vault Not Starting
```bash
# Check logs
docker logs vault-dev

# Verify environment
echo $VAULT_ADDR
echo $VAULT_TOKEN
```

### GitLeaks Not Detecting Secrets
- Patterns must match default rules or custom `.gitleaks.toml`
- Ensure secrets are in tracked files (not .gitignored)
- Use `--verbose` flag for debugging

### BuildKit Not Available
```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1

# Or set in daemon.json
echo '{"features": {"buildkit": true}}' | sudo tee /etc/docker/daemon.json
```

---

## Cleanup

Each scenario has its own cleanup script:
```bash
cd scenario-X-name
./cleanup.sh
```

Clean all scenarios at once:
```bash
# From lab root
./cleanup-all.sh
```

---

## Next Steps

1. **Complete all Tier 1 scenarios** in sequence (1→2→3→4→5)
2. **Read [TIER2-VM-SETUP.md](./TIER2-VM-SETUP.md)** for advanced scenarios
3. **Implement in your projects:**
   - Add pre-commit hooks (Scenario 5)
   - Use BuildKit mounts in CI/CD (Scenario 4)
   - Deploy Vault for centralized secrets (Scenario 3)
4. **Write DZone article** using your learnings as evidence
5. **Contribute back:** Found improvements? Open a PR!

---

## References

- [Docker Secrets Documentation](https://docs.docker.com/engine/swarm/secrets/)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [BuildKit Secret Mounts](https://docs.docker.com/build/building/secrets/)
- [GitLeaks](https://github.com/gitleaks/gitleaks)
- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

---

## Production Context

This lab was built from experience managing 8+ production AKS clusters for Fortune 500 pharmaceutical and retail clients where:
- Secrets rotation windows are measured in minutes
- Compliance audits require cryptographic proof of access controls
- Git history leaks are permanent regulatory violations
- BuildKit secret mounts are mandatory for all CI/CD pipelines

Every pattern in this lab has been tested in production environments, not just documented from vendor materials.

---

**Author:** [Shamsher Khan](https://opscart.com/shamsher-khan-devops-engineer/) | Senior DevOps Engineer  
**Repository:** [github.com/opscart/docker-security-practical-guide](https://github.com/opscart/docker-security-practical-guide)  
**Related:** [Lab 09 - Runtime Escape](../09-runtime-escape/) | [Lab 11 - Secrets Tier 2 (Planned)](../11-secrets-tier2/)