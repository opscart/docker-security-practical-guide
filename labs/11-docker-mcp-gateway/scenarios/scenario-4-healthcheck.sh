#!/bin/bash
# scenarios/scenario-4-healthcheck.sh - Test Docker health check failure remediation

set +e

echo "=========================================="
echo "Scenario 4: Health Check Failure Remediation"
echo "=========================================="
echo ""

# Verify Docker
if ! docker ps >/dev/null 2>&1; then
    echo "Error: Cannot connect to Docker"
    exit 1
fi

echo "✓ Docker is running"
echo ""

echo "[1/5] Creating container with health check..."

# Create nginx container with health check that will fail
docker run -d \
    --name nginx-health-test \
    --health-cmd="curl -f http://localhost/health || exit 1" \
    --health-interval=5s \
    --health-timeout=3s \
    --health-retries=3 \
    nginx:alpine

echo "✓ Container created: nginx-health-test"
echo ""

echo "[2/5] Waiting for initial health check to start..."
sleep 8

# Check initial health status (should be unhealthy since /health doesn't exist)
HEALTH_STATUS=$(docker inspect nginx-health-test --format='{{.State.Health.Status}}')
echo "Initial health status: $HEALTH_STATUS"

if [ "$HEALTH_STATUS" = "starting" ]; then
    echo "Waiting for health check to fail..."
    sleep 15
    HEALTH_STATUS=$(docker inspect nginx-health-test --format='{{.State.Health.Status}}')
fi

echo ""
echo "[3/5] Verifying unhealthy status..."

echo "Current health status: $HEALTH_STATUS"

if [ "$HEALTH_STATUS" = "unhealthy" ]; then
    echo "✓ Container is unhealthy (as expected)"
else
    echo "⚠ Container health status: $HEALTH_STATUS (expected: unhealthy)"
fi

# Show health check logs
echo ""
echo "Health check failures:"
docker inspect nginx-health-test --format='{{range .State.Health.Log}}{{.Output}}{{end}}' | tail -3

echo ""
echo "[4/5] Triggering agent remediation..."

CONTAINER_ID=$(docker ps -aq -f name=nginx-health-test)

ALERT_JSON=$(cat <<EOF
{
  "description": "Docker container failing health checks - running but unhealthy",
  "container_id": "nginx-health-test",
  "status": "unhealthy"
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

sleep 5

# Check if container was restarted
RESTART_COUNT=$(docker inspect nginx-health-test --format='{{.RestartCount}}')
NEW_STATUS=$(docker inspect nginx-health-test --format='{{.State.Status}}')

echo ""
echo "Container status after agent action:"
echo "  Status: $NEW_STATUS"
echo "  Restart count: $RESTART_COUNT"

if [ "$RESTART_COUNT" -gt 0 ]; then
    echo "✓ Agent restarted the unhealthy container"
    echo "  (Appropriate action for health check failures)"
else
    echo "⚠ Container not restarted"
    echo "  (Check agent decision logs)"
fi

echo ""
echo "=========================================="
echo "Scenario Complete!"
echo "=========================================="
echo ""

echo "Expected Agent Behavior:"
echo "  1. Check container logs"
echo "  2. See health check failures (curl to /health endpoint)"
echo "  3. Decision: Container running but unhealthy = temporary issue"
echo "  4. Action: restart_container to recover"
echo ""

echo "Why Restart for Health Check Failures?"
echo "  - Container is running but not serving traffic"
echo "  - Could be app deadlock, memory leak, or stuck state"
echo "  - Restart often fixes transient issues"
echo "  - If restart doesn't help → escalate on next failure"
echo ""

echo "Final container state:"
docker ps -a -f name=nginx-health-test
echo ""
docker inspect nginx-health-test --format='Health Status: {{.State.Health.Status}}'

echo ""
echo "Cleanup:"
echo "  docker stop nginx-health-test && docker rm nginx-health-test"
echo ""