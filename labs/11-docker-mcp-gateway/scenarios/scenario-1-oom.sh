#!/bin/bash
# scenarios/scenario-1-oom.sh - Test Docker OOMKilled remediation

set +e  # Don't exit on errors (OOM is expected to fail)

echo "=========================================="
echo "Scenario 1: Docker OOMKilled Remediation"
echo "=========================================="
echo ""

# Verify Docker
if ! docker ps >/dev/null 2>&1; then
    echo "Error: Cannot connect to Docker"
    exit 1
fi

echo "✓ Docker is running"
echo ""

echo "[1/5] Creating test container with low memory limit..."

# Create container with 50MB memory limit
docker run -d \
    --name nginx-oom-test \
    --memory="50m" \
    --memory-swap="500m" \
    nginx:alpine

echo "✓ Container created: nginx-oom-test"
echo ""

echo "[2/5] Waiting for container to start..."
sleep 3

# Verify container is running
CONTAINER_STATUS=$(docker inspect nginx-oom-test --format='{{.State.Status}}')
echo "Container status: $CONTAINER_STATUS"
echo ""

echo "[3/5] Triggering OOM condition..."

# Install stress tool and trigger OOM
docker exec nginx-oom-test sh -c "apk add --no-cache stress-ng >/dev/null 2>&1 && stress-ng --vm 1 --vm-bytes 100M --timeout 10s" 2>&1 || echo "(OOM expected)"

echo ""
echo "Waiting for OOM to occur..."
sleep 5

# Check if container was OOMKilled
EXIT_CODE=$(docker inspect nginx-oom-test --format='{{.State.ExitCode}}')
OOM_KILLED=$(docker inspect nginx-oom-test --format='{{.State.OOMKilled}}')

echo ""
echo "Container Exit Code: $EXIT_CODE"
echo "OOMKilled: $OOM_KILLED"

if [ "$EXIT_CODE" -eq 137 ] || [ "$OOM_KILLED" = "true" ]; then
    echo "✓ OOM successfully triggered!"
else
    echo "⚠ Container did not OOMKill (may need to retry)"
fi

echo ""
echo "[4/5] Triggering agent remediation..."

# Get container ID
CONTAINER_ID=$(docker ps -aq -f name=nginx-oom-test)

# Construct alert JSON
ALERT_JSON=$(cat <<EOF
{
  "description": "Docker container crashed with OOMKilled",
  "container_id": "nginx-oom-test",
  "status": "OOMKilled"
}
EOF
)

echo "Alert being sent to agent:"
echo "$ALERT_JSON" | jq . 2>/dev/null || echo "$ALERT_JSON"
echo ""

# Send to agent
echo "Calling agent..."
docker exec -e TEST_ALERT="$ALERT_JSON" remediation-agent python -c "
import os, json, sys
sys.path.insert(0, '/app')
from agent import handle_alert

alert = json.loads(os.environ['TEST_ALERT'])
print('[SCENARIO] Processing alert via agent...')
result = handle_alert(alert)
print('[SCENARIO] Agent finished processing')
" 2>&1 | tee /tmp/agent-output.log

echo ""
echo "[5/5] Verifying remediation..."
sleep 3

# Check if memory was increased
OLD_MEMORY="52428800"  # 50MB in bytes
NEW_MEMORY=$(docker inspect nginx-oom-test --format='{{.HostConfig.Memory}}')

echo "Memory limit check:"
echo "  Before: 50MB (52428800 bytes)"
echo "  After:  $(echo $NEW_MEMORY | awk '{printf "%.0fMB", $1/1048576}') ($NEW_MEMORY bytes)"
echo ""

if [ "$NEW_MEMORY" -gt "$OLD_MEMORY" ]; then
    echo "✓ SUCCESS: Memory limit was increased by agent!"
    echo "  Agent successfully remediated the OOM issue"
else
    echo "⚠ Memory limit unchanged"
    echo "  Check agent logs for decision reasoning"
fi

echo ""
echo "=========================================="
echo "Scenario Complete!"
echo "=========================================="
echo ""

echo "Container status:"
docker ps -a -f name=nginx-oom-test

echo ""
echo "Audit logs (agent decisions):"
ls -lht monitoring/audit-logs/ 2>/dev/null | head -3 || echo "  (Check: docker exec remediation-agent ls -l /var/log/agent/audit/)"

echo ""
echo "View agent decision:"
echo "  docker logs remediation-agent | grep -A 20 'ALERT RECEIVED'"

echo ""
echo "Cleanup:"
echo "  docker stop nginx-oom-test && docker rm nginx-oom-test"
echo ""