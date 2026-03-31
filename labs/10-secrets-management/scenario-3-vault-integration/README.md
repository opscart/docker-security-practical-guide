# Scenario 3: HashiCorp Vault Integration

## Overview

HashiCorp Vault provides centralized secret management with advanced features like dynamic secrets, lease management, and comprehensive audit logging. Unlike Docker Swarm secrets, Vault works in any environment (Swarm, Kubernetes, standalone Docker, VMs).

**Time:** 25 minutes (Tier 1 - Dev Mode)  
**Additional:** +20 minutes (Tier 2 - Production Vault)

## What You'll Learn

### Tier 1 (macOS/Windows/Linux)
- Run Vault in dev mode (containerized)
- Store and retrieve static secrets
- Inject secrets into applications at runtime
- Use Vault CLI and HTTP API
- Understand Vault authentication (tokens)

### Tier 2 (Linux VM - Production)
- Configure Vault with TLS encryption
- Enable audit logging
- Set up dynamic database secrets (auto-rotating credentials)
- Implement AppRole authentication
- Production-grade Vault configuration

## Prerequisites

- Docker and Docker Compose
- Basic understanding of environment variables
- `curl` and `jq` installed

## Key Concepts

### How Vault Works

1. **Centralized Storage:** All secrets stored in Vault server
2. **Runtime Injection:** Apps fetch secrets at startup (not baked into images)
3. **Dynamic Secrets:** Vault generates short-lived credentials on-demand
4. **Lease Management:** Secrets have TTL and can be renewed or revoked
5. **Audit Trail:** Every secret access logged

### Vault vs Docker Swarm Secrets

| Feature | Docker Swarm Secrets | HashiCorp Vault |
|---------|---------------------|-----------------|
| **Environment** | Swarm only | Any (Docker, K8s, VMs) |
| **Dynamic Secrets** | ❌ No | ✅ Yes (DB, AWS, SSH) |
| **Audit Logging** | Basic (events) | Comprehensive (all ops) |
| **Secret Rotation** | Manual | Automatic (dynamic) |
| **Complexity** | Low | Medium-High |
| **Best For** | Swarm deployments | Enterprise, multi-platform |

## Running the Demo

### Tier 1: Dev Mode (macOS Compatible)

```bash
./demo.sh
```

This demonstrates:
1. Starting Vault in dev mode (in-memory, unsealed)
2. Storing secrets via CLI
3. Retrieving secrets via API
4. Application reading secrets at startup
5. Secret versioning

### Tier 2: Production Setup (Linux VM)

```bash
./demo-advanced.sh
```

This demonstrates:
1. Vault with TLS encryption
2. File-based storage backend
3. Vault unsealing process
4. Dynamic database secrets
5. Comprehensive audit logging

## Dev Mode Example

### Starting Vault

```bash
docker run -d --name vault-dev \
  -p 8200:8200 \
  -e VAULT_DEV_ROOT_TOKEN_ID=myroot \
  hashicorp/vault:latest
```

### Storing Secrets

```bash
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='myroot'

# Store database credentials
vault kv put secret/db \
  username=dbuser \
  password=SuperSecret123

# Store API key
vault kv put secret/api \
  key=sk-1234567890
```

### Reading Secrets

```bash
# Via CLI
vault kv get secret/db

# Via API
curl -H "X-Vault-Token: myroot" \
  http://localhost:8200/v1/secret/data/db | jq .
```

### Application Integration

```python
import hvac
import os

client = hvac.Client(
    url='http://vault:8200',
    token=os.environ['VAULT_TOKEN']
)

# Read secret
secret = client.secrets.kv.v2.read_secret_version(path='db')
username = secret['data']['data']['username']
password = secret['data']['data']['password']

print(f"Connecting to DB as {username}")
```

## Dynamic Secrets (Tier 2)

Vault can generate database credentials on-demand:

```bash
# Configure database connection
vault write database/config/mydb \
  plugin_name=postgresql-database-plugin \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/mydb"

# Create role with TTL
vault write database/roles/app-role \
  db_name=mydb \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';" \
  default_ttl=1h \
  max_ttl=24h

# Request credentials (auto-generated)
vault read database/creds/app-role
# Returns:
#   username: v-root-app-role-x8f9g2h1
#   password: A1B2C3D4E5F6G7H8
```

**Key Benefit:** Credentials rotate automatically, compromised creds expire quickly.

## Security Features

### Encryption
- ✅ TLS for all communication (production)
- ✅ Secrets encrypted at rest
- ✅ Encrypted in transit

### Access Control
- ✅ Token-based authentication
- ✅ AppRole for applications
- ✅ Policies for fine-grained permissions
- ✅ Namespaces for multi-tenancy

### Audit & Compliance
- ✅ Comprehensive audit logs
- ✅ Secret access tracking
- ✅ Lease tracking and revocation
- ✅ Meets SOC 2, PCI-DSS requirements

## When to Use Vault

### ✅ Good Use Cases
- Multi-environment deployments (dev, staging, prod)
- Non-Swarm environments (Kubernetes, VMs, cloud)
- Need for dynamic secrets (database, cloud credentials)
- Compliance requirements (audit logging)
- Centralized secret management across teams

### ❌ Not Suitable For
- Simple single-app deployments (use Swarm secrets)
- Build-time secrets (use BuildKit secret mounts)
- Very small teams without ops expertise
- Air-gapped environments without HA requirements

## Production Considerations

### High Availability
- 3+ Vault servers with Raft consensus
- Load balancer for failover
- Automated unsealing (cloud KMS)

### Storage Backend
- Production: Consul, Raft, or cloud storage
- Dev: In-memory (data lost on restart)

### Unsealing
- Shamir's Secret Sharing (5 keys, threshold 3)
- Auto-unseal with cloud KMS (AWS, Azure, GCP)

### Monitoring
- Health checks: `/v1/sys/health`
- Metrics: Prometheus integration
- Audit logs: Syslog, file, socket

## Cleanup

```bash
./cleanup.sh
```

Removes:
- Vault dev container
- All demo secrets
- Temporary configuration files

## Validation

```bash
./validate.sh
```

Checks:
1. Vault container running
2. Vault API accessible
3. Secrets stored successfully
4. Application can read secrets

## Tier 2: Production Setup

See `examples/production/` for:
- `vault-config.hcl` - Production Vault configuration
- TLS certificate generation
- AppRole authentication setup
- Dynamic database secret configuration
- Audit log analysis

## Next Steps

**Scenario 4** covers BuildKit secret mounts for build-time secrets that never persist in Docker images.

## References

- [Vault Documentation](https://www.vaultproject.io/docs)
- [Vault API Reference](https://www.vaultproject.io/api-docs)
- [Dynamic Secrets](https://www.vaultproject.io/docs/secrets/databases)
- [Vault Best Practices](https://www.vaultproject.io/docs/internals/security)
- [Production Hardening](https://learn.hashicorp.com/tutorials/vault/production-hardening)

## Common Issues

### Issue: Vault sealed on restart
```bash
# Dev mode auto-unseals
# Production requires manual unseal or auto-unseal with KMS
vault operator unseal <key-1>
vault operator unseal <key-2>
vault operator unseal <key-3>
```

### Issue: Permission denied
```bash
# Check token has proper policy
vault token lookup
vault policy read <policy-name>
```

### Issue: Secret not found
```bash
# Check secret path and KV version
vault kv get secret/myapp  # KV v2
vault kv get -mount=secret myapp  # Explicit mount
```