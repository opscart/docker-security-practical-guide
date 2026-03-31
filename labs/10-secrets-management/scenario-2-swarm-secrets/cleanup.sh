#!/bin/bash
echo "Cleaning up Scenario 2..."
#!/bin/bash

echo "Cleaning up Scenario 2: Swarm Secrets..."

# Remove stack
docker stack rm secrets-demo 2>/dev/null || true

# Wait for stack removal
echo "Waiting for stack removal..."
sleep 5

# Remove secrets
docker secret rm db_password 2>/dev/null || true
docker secret rm api_key 2>/dev/null || true

echo "Cleanup complete!"
echo ""
echo "Note: Swarm mode left active (safe for other scenarios)"
echo "To leave swarm: docker swarm leave --force"