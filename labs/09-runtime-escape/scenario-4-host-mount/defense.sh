#!/bin/bash

# Lab 09 - Scenario 4: Host Path Mount Defense Script
# Implements protections against dangerous bind mounts

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

print_header "Scenario 4: Host Path Mount — Defense Implementation"

###############################################
# Defense 1: Docker Daemon Configuration
###############################################
print_header "Defense 1: Docker Daemon Configuration"

DAEMON_CONFIG="/etc/docker/daemon.json"

print_step "Checking current daemon configuration..."
if [ -f "$DAEMON_CONFIG" ]; then
    echo "  Current config:"
    cat "$DAEMON_CONFIG" | sed 's/^/    /'
else
    print_info "No daemon.json found — creating recommended configuration"
fi

echo
print_step "Recommended daemon.json additions:"
cat << 'EOF'
{
  "no-new-privileges": true,
  "userns-remap": "default",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

echo
print_info "Apply with: sudo cp daemon.json /etc/docker/daemon.json && sudo systemctl restart docker"
echo
print_info "Note: userns-remap maps container root to an unprivileged host UID."
print_info "      Even if a bind mount exposes /etc, writes run as a non-root user."

###############################################
# Defense 2: Falco Runtime Rules
###############################################
print_header "Defense 2: Falco Runtime Detection Rules"

FALCO_RULES="artifacts/falco-host-mount-rules.yaml"
mkdir -p artifacts

print_step "Writing Falco rules to $FALCO_RULES..."
cat > "$FALCO_RULES" << 'FALCO_EOF'
# Falco rules for detecting dangerous bind mounts
# Deploy: kubectl create cm falco-rules-host-mount --from-file=rules.yaml=$FALCO_RULES -n falco

# Rule 1: Detect access to sensitive host paths via bind mount
- rule: Container Accessing Sensitive Host Path
  desc: >
    A container accessed a file in a sensitive host path mounted via bind mount.
    This may indicate credential theft or configuration tampering.
  condition: >
    container and
    (open or openat) and
    not container.privileged and
    fd.name startswith /host-etc or
    fd.name startswith /host-root or
    fd.name startswith /host-home
  output: >
    Sensitive host path accessed in container
    (user=%user.name container_id=%container.id container_name=%container.name
    file=%fd.name command=%proc.cmdline)
  priority: HIGH
  tags: [container, bind-mount, credential-access]

# Rule 2: Detect docker.sock access from containers
- rule: Container Docker Socket Access
  desc: >
    A container accessed the Docker socket. This enables the container
    to create or modify other containers on the host.
  condition: >
    container and
    (open or openat) and
    fd.name = /var/run/docker.sock
  output: >
    Docker socket accessed from container
    (user=%user.name container_id=%container.id container_name=%container.name
    command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, docker-sock, escalation]

# Rule 3: Detect new container creation via socket (escalation chain)
- rule: Container Creating New Containers
  desc: >
    A container executed the docker CLI, likely using a mounted socket
    to create new containers. This is the escalation chain pattern.
  condition: >
    spawned_process and
    container and
    proc.name = docker and
    proc.args contains "run"
  output: >
    Container executing docker run — possible escalation chain
    (user=%user.name container_id=%container.id container_name=%container.name
    command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, docker-sock, escalation, bind-mount]

# Rule 4: Detect reading of /etc/shadow via any path
- rule: Container Shadow File Read
  desc: >
    A container read /etc/shadow or a bind-mounted copy of it.
    This indicates credential theft.
  condition: >
    container and
    open and
    (fd.name = /etc/shadow or
     fd.name endswith /shadow) and
    not proc.name in (pam_authenticate, getent, passwd)
  output: >
    Shadow file read in container — credential theft attempt
    (user=%user.name container_id=%container.id container_name=%container.name
    file=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, credential, shadow, bind-mount]
FALCO_EOF

print_step "Falco rules written to $FALCO_RULES"
echo
echo "  Deploy with:"
echo "    kubectl create cm falco-rules-host-mount \\"
echo "      --from-file=rules.yaml=$FALCO_RULES -n falco"
echo "    kubectl rollout restart daemonset/falco -n falco"

###############################################
# Defense 3: Audit Script
###############################################
print_header "Defense 3: Bind Mount Audit Script"

AUDIT_SCRIPT="artifacts/audit-host-mounts.sh"

print_step "Writing audit script to $AUDIT_SCRIPT..."
cat > "$AUDIT_SCRIPT" << 'AUDIT_EOF'
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
AUDIT_EOF

chmod +x "$AUDIT_SCRIPT"
print_step "Audit script written and made executable: $AUDIT_SCRIPT"

###############################################
# Defense 4: Kubernetes Admission Policy
###############################################
print_header "Defense 4: Kubernetes Admission Policy"

KYVERNO_POLICY="artifacts/kyverno-block-host-mounts.yaml"

print_step "Writing Kyverno policy to $KYVERNO_POLICY..."
cat > "$KYVERNO_POLICY" << 'KYVERNO_EOF'
# Kyverno policy to block dangerous host path mounts
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-host-path-mounts
  annotations:
    policies.kyverno.io/title: Restrict Host Path Mounts
    policies.kyverno.io/category: Security
    policies.kyverno.io/severity: critical
    policies.kyverno.io/description: >-
      Blocks pods from mounting sensitive host paths via hostPath volumes.
      Host path mounts expose the underlying node filesystem and can be
      used for credential theft or privilege escalation.

spec:
  validationFailureAction: enforce
  background: true

  rules:
  - name: check-host-path-mounts
    match:
      any:
      - resources:
          kinds:
          - Pod

    validate:
      message: >-
        Mounting sensitive host paths is not allowed.
        Use ConfigMap, Secret, or emptyDir volumes instead.
        Blocked paths: /etc, /root, /home, /var/run/docker.sock, /proc, /sys, /
      pattern:
        spec:
          volumes:
          - X-(hostPath):
              path: "?(/allowed-path/*)"
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

1. ${YELLOW}Docker Daemon Config${NC}
   - no-new-privileges: true
   - userns-remap: default
   - Apply to /etc/docker/daemon.json

2. ${YELLOW}Falco Runtime Rules${NC}
   - Detect sensitive host path access
   - Detect docker.sock access from containers
   - Detect container escalation chains
   - Detect shadow file reads
   - File: $FALCO_RULES

3. ${YELLOW}Audit Script${NC}
   - Scans all containers for bind mounts
   - Classifies risk by source path
   - Flags docker.sock mounts as CRITICAL
   - File: $AUDIT_SCRIPT

4. ${YELLOW}Kubernetes Admission Policy${NC}
   - Blocks hostPath volumes for sensitive paths
   - Enforced at admission time
   - File: $KYVERNO_POLICY

${BLUE}Next Steps:${NC}
  Run ./validate.sh to test defenses
  Run ./cleanup.sh to remove demo artifacts"