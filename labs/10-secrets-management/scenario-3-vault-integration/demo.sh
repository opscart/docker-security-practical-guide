#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Scenario 3: HashiCorp Vault Integration${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

cd examples/dev-mode

# Step 1: Start Vault
echo -e "${YELLOW}[1/5] Starting Vault in Dev Mode${NC}"
echo "Launching Vault container..."
echo ""

docker compose up -d

echo "Waiting for Vault to be ready..."
sleep 5

# Check Vault status
if curl -s http://localhost:8200/v1/sys/health > /dev/null; then
    echo -e "${GREEN}✓ Vault is running${NC}"
else
    echo -e "${RED}✗ Vault failed to start${NC}"
    exit 1
fi

echo ""
echo "Vault Web UI: http://localhost:8200/ui"
echo "Root Token: myroot"
echo ""

echo "Press ENTER to continue..."
read

# Step 2: Store secrets
echo -e "${YELLOW}[2/5] Storing Secrets in Vault${NC}"
echo "Using Vault CLI to store secrets..."
echo ""

# Store database credentials (with both VAULT_ADDR and VAULT_TOKEN)
docker exec -e VAULT_ADDR='http://127.0.0.1:8200' -e VAULT_TOKEN='myroot' vault-dev \
  vault kv put secret/db \
  username=dbadmin \
  password=ProductionPassword123 \
  host=postgres.example.com \
  port=5432

echo -e "${GREEN}✓ Database credentials stored${NC}"
echo ""

# Store API key
docker exec -e VAULT_ADDR='http://127.0.0.1:8200' -e VAULT_TOKEN='myroot' vault-dev \
  vault kv put secret/api \
  key=sk-1234567890abcdef \
  endpoint=https://api.example.com

echo -e "${GREEN}✓ API credentials stored${NC}"
echo ""

echo "Press ENTER to continue..."
read

# Step 3: Retrieve secrets
echo -e "${YELLOW}[3/5] Retrieving Secrets${NC}"
echo "Reading secrets via Vault CLI..."
echo ""

echo "Database credentials:"
docker exec -e VAULT_ADDR='http://127.0.0.1:8200' -e VAULT_TOKEN='myroot' vault-dev \
  vault kv get secret/db
echo ""

echo "API credentials:"
docker exec -e VAULT_ADDR='http://127.0.0.1:8200' -e VAULT_TOKEN='myroot' vault-dev \
  vault kv get secret/api
echo ""

echo "Press ENTER to continue..."
read

# Step 4: API access
echo -e "${YELLOW}[4/5] Accessing Secrets via HTTP API${NC}"
echo "Using curl to fetch secrets (how apps do it)..."
echo ""

echo "GET /v1/secret/data/db:"
curl -s -H "X-Vault-Token: myroot" \
  http://localhost:8200/v1/secret/data/db | jq '.data.data'
echo ""

echo "GET /v1/secret/data/api:"
curl -s -H "X-Vault-Token: myroot" \
  http://localhost:8200/v1/secret/data/api | jq '.data.data'
echo ""

echo "Press ENTER to continue..."
read

# Step 5: Application integration
echo -e "${YELLOW}[5/5] Application Integration${NC}"
echo "Checking demo app that reads secrets from Vault..."
echo ""

echo "Application logs:"
docker logs vault-demo-app 2>&1 | tail -25
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Summary: Vault Dev Mode Demo Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "✓ Vault running in dev mode"
echo "✓ Secrets stored via CLI"
echo "✓ Secrets retrieved via CLI"
echo "✓ Secrets accessed via HTTP API"
echo "✓ Application integrated with Vault"
echo ""
echo -e "${YELLOW}Key Differences from Swarm Secrets:${NC}"
echo "  - Works in any environment (not just Swarm)"
echo "  - Centralized (multiple apps share one Vault)"
echo "  - API-driven (apps fetch secrets at runtime)"
echo "  - Versioned (secret history tracked)"
echo ""
echo -e "${YELLOW}Dev Mode Limitations:${NC}"
echo "  - In-memory storage (data lost on restart)"
echo "  - Single instance (no HA)"
echo "  - Auto-unsealed (not production-safe)"
echo "  - HTTP only (no TLS)"
echo ""
echo "Run ./cleanup.sh to remove demo artifacts."
echo ""
echo -e "${YELLOW}Next:${NC} See demo-advanced.sh for production Vault with:"
echo "  - TLS encryption"
echo "  - File-based storage"
echo "  - Dynamic database secrets"
echo "  - Audit logging"