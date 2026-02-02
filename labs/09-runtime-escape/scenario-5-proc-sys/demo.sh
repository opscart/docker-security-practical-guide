#!/bin/bash

# Lab 09 - Scenario 5: /proc and /sys Exposure Demo
# Demonstrates how mounting /proc exposes host system information
# for reconnaissance and attack planning

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_analysis() {
    echo -e "${CYAN}[ANALYSIS]${NC} $1"
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
║      Lab 09 - Scenario 5: /proc and /sys Exposure             ║
║                                                               ║
║  This demo shows how mounting /proc from the host             ║
║  exposes system information for reconnaissance.               ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF

print_warning "⚠️  WARNING: This demonstration shows container reconnaissance techniques!"
print_warning "   Only run this in a safe, isolated test environment."
echo
print_info "📝 ENVIRONMENT NOTE:"
print_info "   On macOS with Docker Desktop, /proc reflects the Linux VM,"
print_info "   not the macOS host. The data shown is real but belongs to the"
print_info "   VM that Docker runs inside. On a Linux host, /proc exposes"
print_info "   actual host process and system data."
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

# Detect environment
DETECTED_ENV="unknown"
if [[ "$(uname -s)" == "Darwin" ]]; then
    DETECTED_ENV="macOS (Docker Desktop)"
elif [[ "$(uname -s)" == "Linux" ]]; then
    if grep -q "microsoft" /proc/version 2>/dev/null; then
        DETECTED_ENV="WSL (Windows Subsystem for Linux)"
    else
        DETECTED_ENV="Linux (native Docker)"
    fi
fi
print_info "Detected environment: $DETECTED_ENV"

###############################################
# Demo 1: /proc Mount — System Reconnaissance
###############################################
print_header "Demo 1: /proc Mount — What an Attacker Can Read"

print_step "Starting container with /proc mounted read-only..."
echo "  Command: docker run -v /proc:/host-proc:ro alpine"
echo
docker run -dit --name proc-recon -v /proc:/host-proc:ro alpine sleep 120 &>/dev/null

echo
print_step "1. Kernel Version (target identification)"
echo "  Command: docker exec proc-recon cat /host-proc/version"
echo
KERNEL_VERSION=$(docker exec proc-recon cat /host-proc/version 2>/dev/null)
echo "  Output: $KERNEL_VERSION"
echo

print_analysis "An attacker uses the kernel version string to:"
print_analysis "  • Look up known CVEs for this kernel build"
print_analysis "  • Identify the distribution and release date"
print_analysis "  • Determine if known local privilege escalation exploits apply"
echo

print_step "2. Network Configuration (lateral movement planning)"
echo "  Command: docker exec proc-recon cat /host-proc/net/route"
echo
echo "  Network routing table:"
docker exec proc-recon cat /host-proc/net/route 2>/dev/null | head -10
echo
echo "  Active TCP connections:"
docker exec proc-recon cat /host-proc/net/tcp 2>/dev/null | head -8
echo

print_analysis "An attacker uses network data to:"
print_analysis "  • Map internal subnets and routing (route table)"
print_analysis "  • Identify other services listening on the host (tcp/tcp6)"
print_analysis "  • Plan lateral movement to adjacent systems"
echo

print_step "3. Process List (operational intelligence)"
echo "  Command: docker exec proc-recon ls /host-proc/ | grep -E '^[0-9]+$'"
echo
echo "  Running process IDs (first 15):"
docker exec proc-recon sh -c 'ls /host-proc/ | grep -E "^[0-9]+$" | sort -n | head -15'
echo

print_step "  Reading process command lines..."
docker exec proc-recon sh -c '
for pid in $(ls /host-proc/ | grep -E "^[0-9]+$" | sort -n | head -10); do
    cmdline=$(cat /host-proc/$pid/cmdline 2>/dev/null | tr "\0" " " || true)
    if [ -n "$cmdline" ]; then
        echo "  PID $pid: $cmdline"
    fi
done
'
echo

print_analysis "An attacker uses the process list to:"
print_analysis "  • Identify running services (databases, web servers, apps)"
print_analysis "  • Find processes running as root that might be exploitable"
print_analysis "  • Locate credential files referenced in process arguments"
echo

print_step "4. Memory and CPU Information"
echo "  Memory:"
docker exec proc-recon sh -c 'head -5 /host-proc/meminfo' 2>/dev/null
echo
echo "  CPU:"
docker exec proc-recon sh -c 'head -3 /host-proc/cpuinfo' 2>/dev/null
echo

print_analysis "Hardware profiling helps an attacker:"
print_analysis "  • Estimate whether brute-force attacks are feasible"
print_analysis "  • Identify cloud provider and instance type"
print_analysis "  • Plan resource-intensive exploitation attempts"

print_warning "Cleaning up demo container..."
docker rm -f proc-recon &>/dev/null

wait_for_enter

###############################################
# Demo 2: /sys Mount — Hardware and Kernel Interface Exposure
###############################################
print_header "Demo 2: /sys Mount — Kernel Interface Reconnaissance"

print_step "Starting container with /sys mounted read-only..."
echo "  Command: docker run -v /sys:/host-sys:ro alpine"
echo
docker run -dit --name sys-recon -v /sys:/host-sys:ro alpine sleep 120 &>/dev/null

echo
print_step "1. Block Device Information"
echo "  Block devices visible via /sys:"
docker exec sys-recon sh -c 'ls /host-sys/block/ 2>/dev/null' || echo "  (not available in this environment)"
echo

print_step "2. Network Device Information"
echo "  Network interfaces:"
docker exec sys-recon sh -c 'ls /host-sys/class/net/ 2>/dev/null' || echo "  (not available in this environment)"
echo
echo "  Interface details:"
docker exec sys-recon sh -c '
for iface in $(ls /host-sys/class/net/ 2>/dev/null); do
    echo "  $iface:"
    echo "    type:    $(cat /host-sys/class/net/$iface/type 2>/dev/null || echo unknown)"
    echo "    operstate: $(cat /host-sys/class/net/$iface/operstate 2>/dev/null || echo unknown)"
    echo "    address: $(cat /host-sys/class/net/$iface/address 2>/dev/null || echo unknown)"
done
' 2>/dev/null
echo

print_step "3. Hardware Model (cloud instance identification)"
docker exec sys-recon sh -c '
echo "  Vendor:  $(cat /host-sys/devices/system/cpu/modalias 2>/dev/null || echo unknown)"
echo "  DMI:     $(ls /host-sys/class/dmi/id/ 2>/dev/null | head -5 || echo "not available")"
' 2>/dev/null
echo

print_analysis "Hardware enumeration via /sys helps an attacker:"
print_analysis "  • Confirm the cloud provider (AWS, Azure, GCP) from DMI data"
print_analysis "  • Map disk topology for targeted data exfiltration"
print_analysis "  • Identify network topology for VLAN/segment mapping"

print_warning "Cleaning up demo container..."
docker rm -f sys-recon &>/dev/null

wait_for_enter

###############################################
# Demo 3: Comparison — Normal vs Mounted /proc
###############################################
print_header "Demo 3: Normal Container vs /proc-Mounted Container"

print_step "Normal container — what /proc looks like by default..."
echo
docker run --rm alpine sh -c '
echo "  /proc contents (normal container):"
ls /proc/ | tr "\n" "  "
echo
echo
echo "  Kernel version:"
cat /proc/version
echo
echo "  Process list (container-only):"
ls /proc/ | grep -E "^[0-9]+$"
'
echo

print_step "Container with host /proc mounted — what changes..."
echo
docker run --rm -v /proc:/host-proc:ro alpine sh -c '
echo "  /host-proc contents (host /proc):"
ls /host-proc/ | head -30 | tr "\n" "  "
echo
echo
echo "  Kernel version (host):"
cat /host-proc/version
echo
echo "  Process count (host):"
echo "    $(ls /host-proc/ | grep -E "^[0-9]+$" | wc -l) processes visible"
echo
echo "  Normal container /proc (self only):"
echo "    $(ls /proc/ | grep -E "^[0-9]+$" | wc -l) process(es) visible"
'
echo

print_info "The difference is clear: a normal container sees only its own processes."
print_info "A mounted /proc exposes every process on the host (or VM on Docker Desktop)."

wait_for_enter

###############################################
# Demo 4: Detection — Auditing /proc and /sys Mounts
###############################################
print_header "Demo 4: Detection — Finding /proc and /sys Mounts"

print_step "Creating test containers for audit demonstration..."
docker run -dit --name audit-proc -v /proc:/host-proc:ro alpine sleep 60 &>/dev/null
docker run -dit --name audit-sys -v /sys:/host-sys:ro alpine sleep 60 &>/dev/null
docker run -dit --name audit-clean alpine sleep 60 &>/dev/null

echo
print_step "Scanning containers for /proc and /sys mounts..."
echo

docker ps -q | while read container_id; do
    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container_id" 2>/dev/null | sed 's|/||')
    MOUNTS=$(docker inspect --format='{{json .Mounts}}' "$container_id" 2>/dev/null)

    PROC_MOUNT=$(echo "$MOUNTS" | grep -o '"Source":"/proc"' || true)
    SYS_MOUNT=$(echo "$MOUNTS" | grep -o '"Source":"/sys"' || true)

    if [ -n "$PROC_MOUNT" ] || [ -n "$SYS_MOUNT" ]; then
        echo -e "${RED}🚨 $CONTAINER_NAME — Kernel interface mount detected:${NC}"
        [ -n "$PROC_MOUNT" ] && echo "    /proc mounted (process and system reconnaissance)"
        [ -n "$SYS_MOUNT" ] && echo "    /sys mounted (hardware and kernel interface access)"
        echo
    else
        echo -e "${GREEN}✅ $CONTAINER_NAME — No /proc or /sys mounts${NC}"
    fi
done

print_warning "Cleaning up audit containers..."
docker rm -f audit-proc audit-sys audit-clean &>/dev/null

wait_for_enter

###############################################
# Summary
###############################################
print_header "Demo Complete - Summary"

echo -e "${GREEN}What we demonstrated:${NC}

1. ${YELLOW}/proc Mount — System Reconnaissance${NC}
   - Kernel version → CVE identification and exploit targeting
   - Network routing → Internal subnet mapping and lateral movement planning
   - Process list  → Service discovery and credential file location
   - Memory/CPU    → Hardware profiling and attack feasibility assessment

2. ${YELLOW}/sys Mount — Hardware Reconnaissance${NC}
   - Block devices  → Disk topology for data exfiltration planning
   - Network devices → Network segment and interface mapping
   - Hardware model → Cloud provider and instance type identification

3. ${YELLOW}Normal vs Mounted — The Visibility Gap${NC}
   - Normal container: sees only its own 1-2 processes
   - Mounted /proc: sees every process on the host (or VM)
   - The mount flag is the only difference

4. ${YELLOW}Detection${NC}
   - docker inspect shows all mounts including /proc and /sys
   - Automated scanning catches these mounts reliably

${RED}Key Takeaways:${NC}

• /proc and /sys mounts are reconnaissance tools, not direct exploits
• The data they expose enables targeted attacks against specific vulnerabilities
• Read-only mounts (:ro) prevent writes but not reconnaissance
• Docker Desktop shows VM data, not host data — but Linux hosts expose everything
• This is the \"default nobody audits\" blind spot from the article

${GREEN}Defense Strategies:${NC}

1. Never mount /proc or /sys from the host
2. Use specific subpath mounts if individual files are needed
3. Audit all containers for /proc and /sys mounts
4. Monitor with Falco for /proc access patterns inside containers
5. Apply Pod Security Standards restricted profile

${BLUE}Next Steps:${NC}

1. Run ./defense.sh to implement protections
2. Run ./validate.sh to confirm defenses work

${BLUE}Documentation:${NC}
Full details in README.md

${BLUE}Cleanup:${NC}
Run ./cleanup.sh to remove all demo containers"