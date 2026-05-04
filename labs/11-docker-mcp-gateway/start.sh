#!/bin/bash
# start.sh - Start all MCP agentic platform services

set -e

echo "=========================================="
echo "Starting MCP Agentic Platform"
echo "=========================================="
echo ""

# Check .env exists
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    echo "Run ./setup.sh first"
    exit 1
fi

# Check secrets exist
if [ ! -f security-pipeline/auth/secrets/mcp_api_key.txt ]; then
    echo "Error: Secrets not generated"
    echo "Run ./setup.sh first"
    exit 1
fi

# Check Minikube
if ! minikube status >/dev/null 2>&1; then
    echo "Warning: Minikube not running"
    echo "Start it with: cd kubernetes && ./setup-minikube.sh"
    echo ""
fi

echo "[1/3] Building Docker images..."
docker-compose build

echo ""
echo "[2/3] Starting services..."
docker-compose up -d

echo ""
echo "[3/3] Waiting for services to be healthy..."

# Wait for health checks
for i in {1..30}; do
    if docker-compose ps | grep -q "unhealthy"; then
        echo -n "."
        sleep 2
    else
        break
    fi
done

echo ""
echo ""
echo "=========================================="
echo "All Services Running!"
echo "=========================================="
echo ""

docker-compose ps

echo ""
echo "Service URLs:"
echo "  MCP Server: http://localhost:3000"
echo "  Health Check: http://localhost:3000/health"
echo ""
echo "Logs:"
echo "  docker-compose logs -f mcp-server"
echo "  docker-compose logs -f agent"
echo ""
echo "Next:"
echo "  cd scenarios && ./scenario-1-oom.sh"
echo ""