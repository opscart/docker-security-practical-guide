#!/bin/bash
# scenarios/scenario-3-exit.sh - Test Docker exit code remediation

set +e

echo "=========================================="
echo "Scenario 3: Docker Exit Code Remediation"
echo "=========================================="
echo ""

# Verify Docker
if ! docker ps >/dev/null 2>&1; then
    echo "Error: Cannot connect to Docker"
    exit 1
fi

echo "✓ Docker is running"
echo ""

echo "[1/5] Creating container with temporary failure..."

# Create container that exits with error code but could recover on restart
docker run -d \
    --name nginx-exit-test \
    nginx:alpine \
    sh -c "echo 'Application starting...'; echo 'Error: Database connection failed'; exit 1"

echo "✓ Container created: nginx-exit-test"
echo ""

echo "[2/5] Waiting for container to exit..."
sleep 5

# Check exit status
EXIT_CODE=$(docker inspect nginx-exit-test --format='{{.State.ExitCode}}')
CONTAINER_STATUS=$(docker inspect nginx-exit-test --format='{{.State.Status}}')

echo "Container status: $CONTAINER_STATUS"
echo "Exit code: $EXIT_CODE"
echo ""

echo "[3/5] Checking container logs..."

docker logs nginx-exit-test

echo ""
echo "[4/5] Triggering agent remediation..."

ALERT_JSON=$(cat <<EOF
{
  "description": "Docker container exited with error code 1",
  "container_id": "nginx-exit-test",
  "status": "exited"
}
EOF
)

echo "Alert being sent to agent:"
echo "$ALERT_JSON" | jq . 2>/dev/null || echo "$ALERT_JSON"
echo ""

docker exec -e TEST_ALERT="$ALERT_JSON" remediation-agent python -c "
import os, json, sys
sys.path.insert(0, '/app')
from agent import handle_alert

alert = json.loads(os.environ['TEST_ALERT'])
print('[SCENARIO] Processing alert via agent...')
result = handle_alert(alert)
print('[SCENARIO] Agent finished processing')
" 2>&1

echo ""
echo "[5/5] Verifying agent decision..."

# Check if container was restarted
NEW_STATUS=$(docker inspect nginx-exit-test --format='{{.State.Status}}')

echo ""
echo "Container status after agent decision: $NEW_STATUS"

if [ "$NEW_STATUS" = "running" ]; then
    echo "✓ Agent restarted the container"
    echo "  (Good for temporary failures like network issues)"
else
    echo "✓ Agent escalated to human"
    echo "  (Good for persistent issues like config errors)"
fi

echo ""
echo "=========================================="
echo "Scenario Complete!"
echo "=========================================="
echo ""

echo "Expected Agent Behavior:"
echo "  - Check logs to understand failure"
echo "  - If error looks temporary (network, startup race): restart_container"
echo "  - If error looks persistent (config, code bug): escalate to human"
echo ""

echo "Final container state:"
docker ps -a -f name=nginx-exit-test

echo ""
echo "Cleanup:"
echo "  docker stop nginx-exit-test 2>/dev/null && docker rm nginx-exit-test"
echo ""