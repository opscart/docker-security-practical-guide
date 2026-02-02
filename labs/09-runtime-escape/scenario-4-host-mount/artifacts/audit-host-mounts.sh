#!/bin/bash

# Host Path Mount Audit Script
# Scans running containers for dangerous bind mounts

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_found() {
    echo -e "${RED}🚨 FOUND:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

print_ok() {
    echo -e "${GREEN}✅ OK:${NC} $1"
}

# High-risk host paths — mounting any of these is a red flag
HIGH_RISK_PATHS=(
    "/etc"
    "/root"
    "/home"
    "/var/run/docker.sock"
    "/var/run"
    "/proc"
    "/sys"
    "/usr"
    "/bin"
    "/sbin"
    "/lib"
    "/boot"
    "/dev"
    "/"
)

# Check prerequisites
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running or not accessible${NC}"
    exit 1
fi

print_header "Host Path Bind Mount Audit"
echo "Scanning Docker host: $(hostname)"
echo "Timestamp: $(date)"
echo

TOTAL=0
HIGH_RISK=0
MEDIUM_RISK=0
DOCKER_SOCK=0

echo "Scanning all running containers..."
echo

while read container_id; do
    [ -z "$container_id" ] && continue
    TOTAL=$((TOTAL + 1))

    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container_id" 2>/dev/null | sed 's|/||')
    CONTAINER_IMAGE=$(docker inspect --format='{{.Config.Image}}' "$container_id" 2>/dev/null)
    MOUNTS_JSON=$(docker inspect --format='{{json .Mounts}}' "$container_id" 2>/dev/null)

    # Extract bind mounts using python3 (handles JSON reliably)
    BIND_INFO=$(echo "$MOUNTS_JSON" | python3 -c "
import json, sys
try:
    mounts = json.load(sys.stdin)
    for m in mounts:
        if m.get('Type') == 'bind':
            print(f\"{m.get('Source', '')}|{m.get('Destination', '')}|{m.get('RW', True)}\")
except:
    pass
" 2>/dev/null)

    if [ -z "$BIND_INFO" ]; then
        continue
    fi

    # Evaluate each bind mount
    while IFS='|' read -r source dest rw; do
        [ -z "$source" ] && continue

        RISK_LEVEL="LOW"
        REASON=""

        # Check against high-risk paths
        for risk_path in "${HIGH_RISK_PATHS[@]}"; do
            if [ "$source" = "$risk_path" ] || [[ "$source" == ${risk_path}/* ]]; then
                if [ "$source" = "/var/run/docker.sock" ]; then
                    RISK_LEVEL="CRITICAL"
                    REASON="Docker socket — enables container creation/escalation"
                    DOCKER_SOCK=$((DOCKER_SOCK + 1))
                elif [ "$source" = "/etc" ] || [ "$source" = "/root" ] || [ "$source" = "/home" ]; then
                    RISK_LEVEL="HIGH"
                    REASON="Credential/config exposure ($source contains sensitive files)"
                    HIGH_RISK=$((HIGH_RISK + 1))
                elif [ "$source" = "/" ]; then
                    RISK_LEVEL="CRITICAL"
                    REASON="Full host filesystem mounted"
                    HIGH_RISK=$((HIGH_RISK + 1))
                else
                    RISK_LEVEL="MEDIUM"
                    REASON="System path ($source)"
                    MEDIUM_RISK=$((MEDIUM_RISK + 1))
                fi
                break
            fi
        done

        if [ "$RISK_LEVEL" = "CRITICAL" ] || [ "$RISK_LEVEL" = "HIGH" ]; then
            print_found "$CONTAINER_NAME [$RISK_LEVEL]"
            echo "  Image:       $CONTAINER_IMAGE"
            echo "  Mount:       $source → $dest"
            echo "  Read/Write:  $rw"
            echo "  Risk:        $REASON"
            echo
        elif [ "$RISK_LEVEL" = "MEDIUM" ]; then
            print_warning "$CONTAINER_NAME [MEDIUM]"
            echo "  Image:       $CONTAINER_IMAGE"
            echo "  Mount:       $source → $dest"
            echo "  Risk:        $REASON"
            echo
        fi
    done <<< "$BIND_INFO"
done < <(docker ps -q)

# Summary
echo
print_header "Audit Summary"
echo
echo "Total containers scanned:      $TOTAL"
echo "Docker socket mounts:          $DOCKER_SOCK"
echo "High-risk path mounts:         $HIGH_RISK"
echo "Medium-risk path mounts:       $MEDIUM_RISK"
echo

if [ "$DOCKER_SOCK" -eq 0 ] && [ "$HIGH_RISK" -eq 0 ] && [ "$MEDIUM_RISK" -eq 0 ]; then
    print_ok "No dangerous bind mounts found"
else
    TOTAL_RISK=$((DOCKER_SOCK + HIGH_RISK + MEDIUM_RISK))
    print_warning "Found $TOTAL_RISK dangerous bind mount(s)"
    echo
    echo "Recommended Actions:"
    echo
    echo "  1. Review each container — determine if the host mount is necessary"
    echo "     docker inspect <container-name> | jq '.Mounts'"
    echo
    echo "  2. Replace host mounts with Kubernetes-native volumes:"
    echo "     /etc config files → ConfigMap or Secret"
    echo "     Application data  → PersistentVolumeClaim"
    echo "     Temp storage      → emptyDir"
    echo
    echo "  3. Block docker.sock mounts via admission policy:"
    echo "     See artifacts/kyverno-block-docker-sock.yaml"
    echo
    echo "  4. Enable Falco runtime monitoring:"
    echo "     See artifacts/falco-host-mount-rules.yaml"
fi
