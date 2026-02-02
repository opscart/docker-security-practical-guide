#!/bin/bash

# /proc and /sys Mount Audit Script
# Scans running containers for kernel interface mounts

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

# Check prerequisites
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running or not accessible${NC}"
    exit 1
fi

print_header "/proc and /sys Mount Audit"
echo "Scanning Docker host: $(hostname)"
echo "Timestamp: $(date)"
echo

TOTAL=0
PROC_FULL=0
SYS_FULL=0
PROC_SUBPATH=0

echo "Scanning all running containers..."
echo

while read container_id; do
    [ -z "$container_id" ] && continue
    TOTAL=$((TOTAL + 1))

    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container_id" 2>/dev/null | sed 's|/||')
    CONTAINER_IMAGE=$(docker inspect --format='{{.Config.Image}}' "$container_id" 2>/dev/null)
    MOUNTS_JSON=$(docker inspect --format='{{json .Mounts}}' "$container_id" 2>/dev/null)

    # Check for /proc mounts
    PROC_SOURCE=$(echo "$MOUNTS_JSON" | python3 -c "
import json, sys
try:
    mounts = json.load(sys.stdin)
    for m in mounts:
        src = m.get('Source', '')
        if src == '/proc':
            print('FULL')
        elif src.startswith('/proc/'):
            print(f'SUBPATH:{src}')
except:
    pass
" 2>/dev/null)

    # Check for /sys mounts
    SYS_SOURCE=$(echo "$MOUNTS_JSON" | python3 -c "
import json, sys
try:
    mounts = json.load(sys.stdin)
    for m in mounts:
        src = m.get('Source', '')
        if src == '/sys' or src.startswith('/sys/'):
            print(src)
except:
    pass
" 2>/dev/null)

    if [ "$PROC_SOURCE" = "FULL" ]; then
        print_found "$CONTAINER_NAME — Full /proc mount"
        echo "  Image: $CONTAINER_IMAGE"
        echo "  Risk: HIGH — Full process enumeration and system reconnaissance"
        echo "  Recommendation: Mount only specific files (e.g., /proc/meminfo)"
        echo
        PROC_FULL=$((PROC_FULL + 1))
    elif echo "$PROC_SOURCE" | grep -q "SUBPATH:"; then
        SUBPATH=$(echo "$PROC_SOURCE" | sed 's/SUBPATH://')
        # Check if it's a safe subpath
        case "$SUBPATH" in
            /proc/meminfo|/proc/cpuinfo|/proc/loadavg|/proc/stat|/proc/diskstats)
                echo -e "${GREEN}✅ $CONTAINER_NAME — Safe /proc subpath: $SUBPATH${NC}"
                ;;
            /proc/net/*|/proc/[0-9]*)
                print_found "$CONTAINER_NAME — Sensitive /proc subpath: $SUBPATH"
                echo "  Image: $CONTAINER_IMAGE"
                echo "  Risk: MEDIUM — Network or process reconnaissance possible"
                echo
                ;;
            *)
                print_warning "$CONTAINER_NAME — /proc subpath: $SUBPATH (review needed)"
                echo "  Image: $CONTAINER_IMAGE"
                ;;
        esac
        PROC_SUBPATH=$((PROC_SUBPATH + 1))
    fi

    if [ -n "$SYS_SOURCE" ]; then
        if [ "$SYS_SOURCE" = "/sys" ]; then
            print_found "$CONTAINER_NAME — Full /sys mount"
            echo "  Image: $CONTAINER_IMAGE"
            echo "  Risk: MEDIUM — Hardware enumeration and kernel interface access"
            echo
            SYS_FULL=$((SYS_FULL + 1))
        else
            print_warning "$CONTAINER_NAME — /sys subpath: $SYS_SOURCE"
            echo "  Image: $CONTAINER_IMAGE"
        fi
    fi
done < <(docker ps -q)

# Summary
echo
print_header "Audit Summary"
echo
echo "Total containers scanned:     $TOTAL"
echo "Full /proc mounts:            $PROC_FULL"
echo "/proc subpath mounts:         $PROC_SUBPATH"
echo "Full /sys mounts:             $SYS_FULL"
echo

if [ "$PROC_FULL" -eq 0 ] && [ "$SYS_FULL" -eq 0 ]; then
    print_ok "No full /proc or /sys mounts found"
else
    TOTAL_RISK=$((PROC_FULL + SYS_FULL))
    print_warning "Found $TOTAL_RISK container(s) with full kernel interface mounts"
    echo
    echo "Recommended Actions:"
    echo
    echo "  1. Replace full /proc mounts with specific subpath mounts:"
    echo "     docker run -v /proc/meminfo:/host-proc/meminfo:ro myapp"
    echo
    echo "  2. Block /proc and /sys hostPath volumes via admission policy:"
    echo "     See artifacts/kyverno-block-proc-sys.yaml"
    echo
    echo "  3. Deploy Falco rules for runtime monitoring:"
    echo "     See artifacts/falco-proc-sys-rules.yaml"
fi
