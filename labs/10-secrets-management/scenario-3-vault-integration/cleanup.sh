#!/bin/bash

echo "Cleaning up Scenario 3: Vault Integration..."

cd examples/dev-mode

# Stop and remove containers
docker compose down -v 2>/dev/null || true

# Remove any standalone Vault container
docker rm -f vault-dev 2>/dev/null || true
docker rm -f vault-demo-app 2>/dev/null || true

cd ../..

echo "Cleanup complete!"
echo ""
echo "Note: Vault dev mode uses in-memory storage"
echo "All secrets are automatically lost when container stops"