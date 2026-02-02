#!/bin/bash

# Lab 09 - Scenario 5: /proc and /sys Exposure Defense Script
# Implements protections against kernel interface reconnaissance

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

print_header "Scenario 5: /proc and /sys Exposure — Defense Implementation"

###############################################
# Defense 1: Subpath Mounting Guidance
###############################################
print_header "Defense 1: Subpath Mounting (When You Must Read /proc)"

print_info "Sometimes a container legitimately needs specific /proc data."
print_info "For example, a monitoring agent may need /proc/meminfo."
print_info "The safe approach: mount the specific file, not the entire /proc."
echo

print_step "BAD — mounts entire /proc (exposes everything):"
echo "  docker run -v /proc:/host-proc:ro myapp"
echo "  # Container can read /proc/[pid]/cmdline for ALL host processes"
echo
print_step "GOOD — mount only the specific file needed:"
echo "  docker run -v /proc/meminfo:/host-proc/meminfo:ro myapp"
echo "  # Container can only read meminfo — no process enumeration possible"
echo
echo "  Kubernetes equivalent:"
cat << 'EOF'
  volumes:
  - name: meminfo
    hostPath:
      path: /proc/meminfo
      type: File
  containers:
  - name: monitor
    volumeMounts:
    - name: meminfo
      mountPath: /host-proc/meminfo
      readOnly: true
EOF
echo
print_step "Safe subpaths for monitoring (read-only, single file):"
echo "  /proc/meminfo      — Memory usage statistics"
echo "  /proc/cpuinfo      — CPU model and speed"
echo "  /proc/loadavg      — System load average"
echo "  /proc/stat         — CPU time statistics"
echo "  /proc/diskstats    — Disk I/O statistics"
echo
print_warning "NEVER mount: /proc (full), /proc/[pid]/* (process details), /proc/net/* (network)"

###############################################
# Defense 2: Falco Runtime Rules
###############################################
print_header "Defense 2: Falco Runtime Detection Rules"

FALCO_RULES="artifacts/falco-proc-sys-rules.yaml"
mkdir -p artifacts

print_step "Writing Falco rules to $FALCO_RULES..."
cat > "$FALCO_RULES" << 'FALCO_EOF'
# Falco rules for detecting /proc and /sys reconnaissance
# Deploy: kubectl create cm falco-rules-proc-sys --from-file=rules.yaml=$FALCO_RULES -n falco

# Rule 1: Detect reading of other processes' command lines
- rule: Container Process Enumeration via /proc
  desc: >
    A container read another process's cmdline via /proc.
    This indicates reconnaissance — mapping running services on the host.
  condition: >
    container and
    open and
    fd.name pmatch (/proc/[0-9]*/cmdline, /host-proc/[0-9]*/cmdline) and
    not container.privileged
  output: >
    Process cmdline enumeration via /proc detected
    (user=%user.name container_id=%container.id container_name=%container.name
    file=%fd.name command=%proc.cmdline)
  priority: HIGH
  tags: [container, proc, reconnaissance]

# Rule 2: Detect reading of network configuration via /proc
- rule: Container Network Reconnaissance via /proc
  desc: >
    A container read network routing or connection data from /proc.
    This enables internal network mapping and lateral movement planning.
  condition: >
    container and
    open and
    (fd.name startswith /proc/net or
     fd.name startswith /host-proc/net or
     fd.name = /proc/net/route or
     fd.name = /host-proc/net/route or
     fd.name = /proc/net/tcp or
     fd.name = /host-proc/net/tcp)
  output: >
    Network reconnaissance via /proc detected
    (user=%user.name container_id=%container.id container_name=%container.name
    file=%fd.name command=%proc.cmdline)
  priority: MEDIUM
  tags: [container, proc, network, reconnaissance]

# Rule 3: Detect /sys access for hardware enumeration
- rule: Container Hardware Enumeration via /sys
  desc: >
    A container accessed hardware information through /sys.
    This enables cloud provider identification and hardware profiling.
  condition: >
    container and
    open and
    (fd.name startswith /sys/class or
     fd.name startswith /host-sys/class or
     fd.name startswith /sys/devices or
     fd.name startswith /host-sys/devices) and
    not container.privileged
  output: >
    Hardware enumeration via /sys detected
    (user=%user.name container_id=%container.id container_name=%container.name
    file=%fd.name command=%proc.cmdline)
  priority: LOW
  tags: [container, sys, hardware, reconnaissance]

# Rule 4: Detect bulk /proc scanning (reading many PIDs rapidly)
- rule: Container Bulk /proc Scanning
  desc: >
    A container is rapidly reading multiple /proc/[pid] entries.
    This pattern indicates automated process enumeration — a reconnaissance sweep.
  condition: >
    container and
    open and
    fd.name pmatch (/proc/[0-9]*/status, /host-proc/[0-9]*/status) and
    count(fd.name pmatch (/proc/[0-9]*/status, /host-proc/[0-9]*/status)) > 10
  output: >
    Bulk /proc scanning detected — automated reconnaissance
    (user=%user.name container_id=%container.id container_name=%container.name
    files_accessed=%evt.num command=%proc.cmdline)
  priority: HIGH
  tags: [container, proc, reconnaissance, scanning]
FALCO_EOF

print_step "Falco rules written to $FALCO_RULES"
echo
echo "  Deploy with:"
echo "    kubectl create cm falco-rules-proc-sys \\"
echo "      --from-file=rules.yaml=$FALCO_RULES -n falco"
echo "    kubectl rollout restart daemonset/falco -n falco"

###############################################
# Defense 3: Audit Script
###############################################
print_header "Defense 3: /proc and /sys Mount Audit Script"

AUDIT_SCRIPT="artifacts/audit-proc-sys-mounts.sh"

print_step "Writing audit script to $AUDIT_SCRIPT..."
cat > "$AUDIT_SCRIPT" << 'AUDIT_EOF'
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
AUDIT_EOF

chmod +x "$AUDIT_SCRIPT"
print_step "Audit script written and made executable: $AUDIT_SCRIPT"

###############################################
# Defense 4: Kubernetes Admission Policy
###############################################
print_header "Defense 4: Kubernetes Admission Policy"

KYVERNO_POLICY="artifacts/kyverno-block-proc-sys.yaml"

print_step "Writing Kyverno policy to $KYVERNO_POLICY..."
cat > "$KYVERNO_POLICY" << 'KYVERNO_EOF'
# Kyverno policy to block /proc and /sys hostPath mounts
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-proc-sys-mounts
  annotations:
    policies.kyverno.io/title: Restrict /proc and /sys Mounts
    policies.kyverno.io/category: Security
    policies.kyverno.io/severity: high
    policies.kyverno.io/description: >-
      Blocks pods from mounting /proc or /sys via hostPath volumes.
      These mounts expose kernel interfaces and enable system reconnaissance.
      If specific /proc data is needed (e.g., /proc/meminfo), mount only
      the individual file, not the entire directory.

spec:
  validationFailureAction: enforce
  background: true

  rules:
  - name: check-proc-mount
    match:
      any:
      - resources:
          kinds:
          - Pod

    validate:
      message: >-
        Mounting /proc or /sys via hostPath is not allowed.
        If you need specific data (e.g., /proc/meminfo), mount only
        that individual file: hostPath.path: /proc/meminfo
      deny:
        conditions:
          any:
          - key: "{{ request.object.spec.volumes[].hostPath.path }}"
            operator: Equals
            value: "/proc"
          - key: "{{ request.object.spec.volumes[].hostPath.path }}"
            operator: Equals
            value: "/sys"
          - key: "{{ request.object.spec.volumes[].hostPath.path }}"
            operator: Equals
            value: "/proc/net"
KYVERNO_EOF

print_step "Kyverno policy written to $KYVERNO_POLICY"
echo
echo "  Deploy with:"
echo "    kubectl apply -f $KYVERNO_POLICY"

###############################################
# Summary
###############################################
print_header "Defense Implementation Complete"

echo -e "${GREEN}Defenses configured:${NC}

1. ${YELLOW}Subpath Mounting Guidance${NC}
   - Safe alternatives for monitoring agents documented
   - Specific files (/proc/meminfo, /proc/cpuinfo) are acceptable
   - Full /proc or /proc/net mounts are blocked

2. ${YELLOW}Falco Runtime Rules${NC}
   - Detect process enumeration via /proc/[pid]/cmdline
   - Detect network reconnaissance via /proc/net/*
   - Detect hardware enumeration via /sys
   - Detect bulk /proc scanning patterns
   - File: $FALCO_RULES

3. ${YELLOW}Audit Script${NC}
   - Scans all containers for /proc and /sys mounts
   - Classifies subpath mounts as safe or sensitive
   - Reports full mounts as high-risk
   - File: $AUDIT_SCRIPT

4. ${YELLOW}Kubernetes Admission Policy${NC}
   - Blocks full /proc and /sys hostPath volumes
   - Allows specific safe subpaths
   - Enforced at admission time
   - File: $KYVERNO_POLICY

${BLUE}Next Steps:${NC}
  Run ./validate.sh to test defenses
  Run ./cleanup.sh to remove demo artifacts"