#!/bin/bash
# scenarios/scenario-2-crash.sh - Test Docker CrashLoop remediation

set +e

echo "=========================================="
echo "Scenario 2: Docker CrashLoop Remediation"
echo "=========================================="
echo ""

# Verify Docker
if ! docker ps >/dev/null 2>&1; then
    echo "Error: Cannot connect to Docker"
    exit 1
fi

echo "✓ Docker is running"
echo ""

echo "[1/5] Creating container that crashes immediately..."

# Create container with a command that exits immediately
docker run -d \
    --name nginx-crash-test \
    --restart=always \
    nginx:alpine \
    sh -c "echo 'Starting...'; exit 1"

echo "✓ Container created: nginx-crash-test (will crash)"
echo ""

echo "[2/5] Waiting for crash loop to establish..."
sleep 10

# Check restart count
RESTART_COUNT=$(docker inspect nginx-crash-test --format='{{.RestartCount}}')
echo "Container restart count: $RESTART_COUNT"

if [ "$RESTART_COUNT" -gt 0 ]; then
    echo "✓ Container is in crash loop!"
else
    echo "⚠ Container hasn't crashed yet (waiting...)"
    sleep 10
fi

echo ""
echo "[3/5] Checking container status and logs..."

docker ps -a -f name=nginx-crash-test

echo ""
echo "Recent logs:"
docker logs nginx-crash-test --tail 10

echo ""
echo "[4/5] Triggering agent remediation..."

CONTAINER_ID=$(docker ps -aq -f name=nginx-crash-test)

ALERT_JSON=$(cat <<EOF
{
  "description": "Docker container is in CrashLoopBackOff - exits immediately",
  "container_id": "nginx-crash-test",
  "status": "CrashLoopBackOff"
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
echo "[5/5] Agent Decision Analysis..."

echo ""
echo "Expected Agent Behavior:"
echo "  1. Check container logs → sees 'exit 1'"
echo "  2. Analyze crash cause → broken command/config"
echo "  3. Decision: This requires manual intervention"
echo "  4. Action: Escalate to human (DO NOT auto-restart loop)"
echo ""

echo "Reasoning:"
echo "  - Crash loop with immediate exit = config/code issue"
echo "  - Auto-restart won't fix it (will crash again)"
echo "  - Needs human to fix container command/config"
echo ""

echo "=========================================="
echo "Scenario Complete!"
echo "=========================================="
echo ""

echo "Key Takeaway:"
echo "  Agent should NOT auto-remediate config issues"
echo "  It should escalate to humans instead"
echo ""

echo "Container is still crashing (expected):"
docker ps -a -f name=nginx-crash-test

echo ""
echo "Cleanup:"
echo "  docker stop nginx-crash-test && docker rm nginx-crash-test"
echo ""