#!/bin/bash
echo "Scenario 2: Swarm Secrets Demo (Tier 1)"
#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Scenario 2: Docker Swarm Secrets${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check Swarm status
if ! docker info | grep -q "Swarm: active"; then
    echo -e "${RED}Error: Docker Swarm not initialized${NC}"
    echo "Run: docker swarm init"
    exit 1
fi

echo -e "${GREEN}✓ Docker Swarm is active${NC}"
echo ""

# Step 1: Create secrets
echo -e "${YELLOW}[1/5] Creating Secrets${NC}"
echo "Creating database password secret..."

# Create db_password secret
echo "ProductionPassword123" | docker secret create db_password - 2>/dev/null || echo "Secret db_password already exists"

# Create api_key secret
echo "sk-api-key-12345678" | docker secret create api_key - 2>/dev/null || echo "Secret api_key already exists"

echo ""
echo "Secrets created:"
docker secret ls
echo ""

echo "Press ENTER to continue..."
read

# Step 2: Deploy service with secrets
echo -e "${YELLOW}[2/5] Deploying Service with Secrets${NC}"
echo "Deploying app service with secret access..."
echo ""

# Deploy stack
docker stack deploy -c docker-compose.yml secrets-demo

echo ""
echo "Waiting for service to start..."
sleep 5

# Get service info
docker service ls | grep secrets-demo
echo ""

echo "Press ENTER to continue..."
read

# Step 3: Verify secret access in container
echo -e "${YELLOW}[3/5] Verifying Secret Access${NC}"
echo "Checking secrets inside container..."
echo ""

# Get container ID
CONTAINER_ID=$(docker ps --filter "name=secrets-demo_app" --format "{{.ID}}" | head -1)

if [ -z "$CONTAINER_ID" ]; then
    echo -e "${RED}Error: Container not running yet. Wait a moment and try again.${NC}"
else
    echo "Container ID: $CONTAINER_ID"
    echo ""
    
    echo "Listing /run/secrets/ directory:"
    docker exec $CONTAINER_ID ls -la /run/secrets/
    echo ""
    
    echo "Reading secret content:"
    echo -e "${GREEN}db_password:${NC}"
    docker exec $CONTAINER_ID cat /run/secrets/db_password
    echo ""
    echo -e "${GREEN}api_key:${NC}"
    docker exec $CONTAINER_ID cat /run/secrets/api_key
    echo ""
fi

echo "Press ENTER to continue..."
read

# Step 4: Verify secrets NOT in docker inspect
echo -e "${YELLOW}[4/5] Security Verification${NC}"
echo "Checking docker inspect (secrets should NOT be visible)..."
echo ""

SERVICE_NAME="secrets-demo_app"

echo "Service secrets configuration:"
docker service inspect $SERVICE_NAME --format '{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}' | jq .
echo ""

echo -e "${GREEN}✓ Notice: Secret METADATA is visible (names, IDs)${NC}"
echo -e "${GREEN}✓ But secret VALUES are NOT exposed${NC}"
echo ""

echo "Compare with environment variables (from Scenario 1):"
echo "ENV vars would show: PASSWORD=ProductionPassword123"
echo "Swarm secrets show: Only metadata, no values"
echo ""

echo "Press ENTER to continue..."
read

# Step 5: Secret management
echo -e "${YELLOW}[5/5] Secret Management${NC}"
echo "Inspecting secret metadata..."
echo ""

docker secret inspect db_password --format '{{json .}}' | jq .
echo ""

echo "Secret rotation (advanced topic - see demo-advanced.sh):"
echo "1. Create new secret version: db_password_v2"
echo "2. Update service to use new secret"
echo "3. Remove old secret after grace period"
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Summary: Swarm Secrets Demo Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "✓ Created secrets from CLI"
echo "✓ Deployed service with secret access"
echo "✓ Verified secrets mounted at /run/secrets/"
echo "✓ Confirmed secrets NOT in docker inspect"
echo "✓ Demonstrated secret management"
echo ""
echo -e "${YELLOW}Key Insight:${NC} Swarm secrets are encrypted, in-memory,"
echo "and never appear in docker inspect output."
echo ""
echo "Run ./cleanup.sh to remove demo artifacts."
echo ""
echo -e "${YELLOW}Next:${NC} Scenario 3 shows Vault for non-Swarm environments"
echo "and dynamic secrets with automatic rotation."