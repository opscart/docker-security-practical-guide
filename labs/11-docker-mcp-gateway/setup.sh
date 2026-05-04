#!/bin/bash
# setup.sh - Initial lab setup

set -e

echo "=========================================="
echo "Lab 11 Setup: MCP Agentic Platform"
echo "=========================================="
echo ""

# Check prerequisites
echo "[1/6] Checking prerequisites..."

command -v docker >/dev/null 2>&1 || { echo "Error: docker not found"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "Error: docker-compose not found"; exit 1; }
command -v minikube >/dev/null 2>&1 || { echo "Error: minikube not found. Run: brew install minikube"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl not found"; exit 1; }

echo "✓ All prerequisites installed"
echo ""

# Check for .env file
echo "[2/6] Checking configuration..."

if [ ! -f .env ]; then
    echo "Creating .env from template..."
    cp .env.example .env
    echo ""
    echo "⚠️  IMPORTANT: Edit .env and add your OPENAI_API_KEY"
    echo ""
    echo "Get your API key from: https://platform.openai.com/api-keys"
    echo ""
    read -p "Press Enter after you've added your OPENAI_API_KEY to .env..."
fi

# Source .env to check API key
source .env

if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" == "your-openai-api-key-here" ]; then
    echo "Error: OPENAI_API_KEY not set in .env"
    echo "Edit .env and add your OpenAI API key"
    exit 1
fi

echo "✓ Configuration complete"
echo ""

# Generate secrets
echo "[3/6] Generating secrets..."

mkdir -p security-pipeline/auth/secrets

# Generate MCP API key (32 bytes, hex encoded)
openssl rand -hex 32 > security-pipeline/auth/secrets/mcp_api_key.txt

# Agent key is same as MCP key (they share authentication)
cp security-pipeline/auth/secrets/mcp_api_key.txt security-pipeline/auth/secrets/agent_key.txt

echo "✓ Secrets generated"
echo ""

# Create directories
echo "[4/6] Creating directories..."

mkdir -p monitoring/audit-logs
mkdir -p kubernetes/test-pods

echo "✓ Directories created"
echo ""

# Pull base images
echo "[5/6] Pulling Docker base images..."

docker pull python:3.11-slim
docker pull redis:7-alpine

echo "✓ Base images pulled"
echo ""

# Verify Minikube
echo "[6/6] Verifying Minikube..."

if minikube status >/dev/null 2>&1; then
    echo "✓ Minikube is running"
else
    echo "Minikube not running. Start it with:"
    echo "  cd kubernetes && ./setup-minikube.sh"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Start Minikube: cd kubernetes && ./setup-minikube.sh"
echo "2. Start services: ./start.sh"
echo "3. Run test: cd scenarios && ./scenario-1-oom.sh"
echo ""