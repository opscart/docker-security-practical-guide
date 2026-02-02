#!/bin/bash

# Lab 09 - Scenario 2: Privileged Container Defense Setup
# Docker-native defenses against --privileged container escapes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ARTIFACTS_DIR="./artifacts"

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

check_docker() {
    docker ps &>/dev/null
}

# Ensure artifacts directory exists
mkdir -p "$ARTIFACTS_DIR"

###############################################
# Defense 1: Docker Daemon Configuration
###############################################
configure_docker_daemon() {
    print_header "Defense 1: Docker Daemon Security Configuration"

    print_step "Recommended Docker daemon settings for production:"
    echo
    echo "Add to /etc/docker/daemon.json:"
    echo
    cat << 'EOF'
{
  "no-new-privileges": true,
  "userns-remap": "default",
  "selinux-enabled": true,
  "live-restore": true,
  "userland-proxy": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    echo
    echo "What these do:"
    echo "• no-new-privileges: Prevents privilege escalation inside containers"
    echo "• userns-remap: Isolates container user namespaces from host"
    echo "• selinux-enabled: Enables SELinux enforcement (if available)"
    echo "• live-restore: Keeps containers running during daemon restart"
    echo "• userland-proxy: Reduces attack surface for networking"
    echo
    echo "After changes: sudo systemctl restart docker"
    echo
    print_warning "Note: These are system-level changes requiring root access"
    echo
}

###############################################
# Defense 2: Secure Docker Compose Template
###############################################
show_docker_compose_security() {
    print_header "Defense 2: Secure Docker Compose Configuration"

    print_step "Creating secure Docker Compose template..."

    cat > "$ARTIFACTS_DIR/docker-compose-secure.yml" <<'EOF'
version: '3.8'

services:
  secure-app:
    image: myapp:latest

    # Drop ALL capabilities by default
    cap_drop:
      - ALL

    # Add only specific safe capabilities
    cap_add:
      - NET_BIND_SERVICE
      # Note: --privileged is NEVER used here

    # Security options
    security_opt:
      - no-new-privileges:true
      - apparmor:docker-default
      # - seccomp:./artifacts/seccomp-no-privileged.json

    # Run as non-root user
    user: "1000:1000"

    # Read-only root filesystem
    read_only: true

    # Writable tmp
    tmpfs:
      - /tmp:noexec,nosuid,size=64m

    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 128M

    # Logging
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
EOF

    print_step "Created: $ARTIFACTS_DIR/docker-compose-secure.yml"
    echo
    print_step "To use this secure configuration:"
    echo "  docker-compose -f $ARTIFACTS_DIR/docker-compose-secure.yml up -d"
    echo
    print_step "Key security features:"
    echo "  • --privileged is never used"
    echo "  • All capabilities dropped by default"
    echo "  • Only safe capabilities added explicitly"
    echo "  • No new privileges allowed"
    echo "  • Non-root user"
    echo "  • Read-only root filesystem"
    echo "  • Resource limits enforced"
    echo
}

###############################################
# Defense 3: Seccomp Profile
###############################################
create_seccomp_profile() {
    print_header "Defense 3: Seccomp Profile to Block Dangerous Syscalls"

    print_step "Creating seccomp profile to block privileged syscalls..."

    cat > "$ARTIFACTS_DIR/seccomp-no-privileged.json" <<'EOF'
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "architectures": [
    "SCMP_ARCH_X86_64",
    "SCMP_ARCH_X86",
    "SCMP_ARCH_AARCH64",
    "SCMP_ARCH_ARM"
  ],
  "syscalls": [
    {
      "names": [
        "mount",
        "umount",
        "umount2",
        "pivot_root",
        "unshare",
        "clone",
        "setns"
      ],
      "action": "SCMP_ACT_ERRNO",
      "args": [],
      "comment": "Block syscalls used for filesystem and namespace escapes"
    },
    {
      "names": [
        "bpf",
        "fanotify_init",
        "lookup_dcookie",
        "perf_event_open",
        "quotactl",
        "swapon",
        "swapoff"
      ],
      "action": "SCMP_ACT_ERRNO",
      "args": [],
      "comment": "Block additional privileged syscalls"
    },
    {
      "names": [
        "add_key",
        "keyctl",
        "request_key"
      ],
      "action": "SCMP_ACT_ERRNO",
      "args": [],
      "comment": "Block kernel keyring access"
    },
    {
      "names": [
        "ptrace"
      ],
      "action": "SCMP_ACT_ERRNO",
      "args": [],
      "comment": "Block process tracing (prevents debugging into other containers/host)"
    },
    {
      "names": [
        "acct",
        "kexec",
        "reboot",
        "shutdown",
        "poweroff"
      ],
      "action": "SCMP_ACT_ERRNO",
      "args": [],
      "comment": "Block system-wide operations"
    }
  ]
}
EOF

    print_step "Created: $ARTIFACTS_DIR/seccomp-no-privileged.json"
    echo
    print_step "To use this seccomp profile:"
    echo "  docker run --security-opt seccomp=$ARTIFACTS_DIR/seccomp-no-privileged.json myapp"
    echo
    print_step "Or in docker-compose.yml:"
    cat <<'EOF'
  services:
    app:
      security_opt:
        - seccomp:./artifacts/seccomp-no-privileged.json
EOF
    echo
}

###############################################
# Defense 4: AppArmor Profile
###############################################
create_apparmor_profile() {
    print_header "Defense 4: AppArmor Profile (Linux Only)"

    print_step "Creating AppArmor profile to restrict privileged operations..."

    cat > "$ARTIFACTS_DIR/docker-no-privileged-apparmor" <<'EOF'
#include <tunables/global>

profile docker-no-privileged flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Deny all mount operations
  deny mount,
  deny umount,
  # Note: pivot_root is blocked via seccomp, not AppArmor

  # Deny namespace manipulation
  deny /proc/sys/kernel/** w,
  deny /sys/kernel/** w,

  # Deny cgroup manipulation
  deny /sys/fs/cgroup/** w,

  # Deny access to host block devices
  deny /dev/sd[a-z]* rw,
  deny /dev/vd[a-z]* rw,
  deny /dev/nvme[0-9]* rw,
  deny /dev/xvd[a-z]* rw,
  deny /dev/hd[a-z]* rw,

  # Deny ptrace (debugging other containers/host)
  deny ptrace peer=**,

  # Deny kernel module operations
  deny /proc/sys/kernel/modules_disabled w,

  # Allow normal container operations
  network inet tcp,
  network inet udp,
  capability setgid,
  capability setuid,
  capability net_bind_service,

  # Explicitly deny dangerous capabilities
  deny capability sys_admin,
  deny capability sys_module,
  deny capability sys_ptrace,
  deny capability net_admin,
  deny capability net_raw,
  deny capability audit_write,
}
EOF

    print_step "Created: $ARTIFACTS_DIR/docker-no-privileged-apparmor"
    echo
    print_step "To install this AppArmor profile (requires root):"
    cat <<'EOF'
  sudo cp artifacts/docker-no-privileged-apparmor /etc/apparmor.d/
  sudo apparmor_parser -r /etc/apparmor.d/docker-no-privileged-apparmor
EOF
    echo
    print_step "To use with Docker:"
    echo "  docker run --security-opt apparmor=docker-no-privileged myapp"
    echo
}

###############################################
# Defense 5: Audit Running Containers
###############################################
audit_docker_containers() {
    print_header "Defense 5: Audit Running Docker Containers"

    if ! check_docker; then
        print_warning "Docker not available, skipping audit"
        return
    fi

    print_step "Scanning running containers for --privileged mode..."
    echo

    FOUND=0

    while read container_id; do
        CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container_id" 2>/dev/null | sed 's|/||')
        PRIVILEGED=$(docker inspect --format='{{.HostConfig.Privileged}}' "$container_id" 2>/dev/null)
        CAPS=$(docker inspect --format='{{.HostConfig.CapAdd}}' "$container_id" 2>/dev/null)

        if [ "$PRIVILEGED" = "true" ]; then
            print_error "Container: $CONTAINER_NAME (ID: ${container_id:0:12}) - PRIVILEGED MODE"
            FOUND=$((FOUND + 1))
        elif echo "$CAPS" | grep -qi "SYS_ADMIN"; then
            print_error "Container: $CONTAINER_NAME (ID: ${container_id:0:12}) - Has CAP_SYS_ADMIN (near-privileged)"
            FOUND=$((FOUND + 1))
        fi
    done < <(docker ps -q)

    echo
    if [ $FOUND -eq 0 ]; then
        print_step "No privileged containers found"
    else
        print_warning "Found $FOUND container(s) with privileged or near-privileged access"
        echo
        echo "Recommended actions:"
        echo "  1. Review if --privileged is truly necessary"
        echo "  2. Replace with specific capabilities (e.g. --cap-add=NET_ADMIN)"
        echo "  3. Recreate containers with secure configuration"
        echo "  4. See artifacts/docker-compose-secure.yml for template"
    fi
    echo
}

###############################################
# Defense 6: Create Falco Rules
###############################################
create_falco_rules() {
    print_header "Defense 6: Falco Runtime Detection Rules"

    print_step "Creating Falco rules for privileged container detection..."

    cat > "$ARTIFACTS_DIR/falco-docker-privileged-rules.yaml" <<'EOF'
# Falco Rules for Privileged Container Escape Detection (Docker)
#
# Installation (Linux only):
#   1. Install Falco: curl -s https://falco.org/script/install | sudo bash
#   2. Copy rules: sudo cp falco-docker-privileged-rules.yaml /etc/falco/rules.d/
#   3. Restart: sudo systemctl restart falco
#
# Test: docker run --privileged alpine mount

- rule: Privileged Container Started
  desc: Detect when a privileged Docker container is started
  condition: >
    container_started and
    container.privileged = true
  output: >
    Privileged container started - HIGH RISK
    (user=%user.name container_id=%container.id container_name=%container.name
    image=%container.image.repository)
  priority: CRITICAL
  tags: [container, privileged, docker, T1611]
  source: syscall

- rule: Privileged Container Mount Operation
  desc: Detect filesystem mount in privileged container
  condition: >
    spawned_process and
    container and
    container.privileged = true and
    proc.name = mount
  output: >
    Mount operation in privileged container - possible host filesystem access
    (user=%user.name container_id=%container.id container_name=%container.name
    image=%container.image.repository command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, privileged, mount, docker, T1611]
  source: syscall

- rule: Privileged Container Namespace Manipulation
  desc: Detect nsenter or unshare in privileged container
  condition: >
    spawned_process and
    container and
    container.privileged = true and
    proc.name in (nsenter, unshare)
  output: >
    Namespace manipulation in privileged container - possible escape attempt
    (user=%user.name container_id=%container.id container_name=%container.name
    image=%container.image.repository command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, privileged, namespace, docker, T1611]
  source: syscall

- rule: Privileged Container Cgroup Modification
  desc: Detect cgroup release_agent modification in privileged container
  condition: >
    open_write and
    container and
    container.privileged = true and
    fd.name contains "release_agent"
  output: >
    Cgroup release_agent modified in privileged container - classic escape technique
    (user=%user.name container_id=%container.id container_name=%container.name
    file=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, privileged, cgroup, docker, T1611]
  source: syscall

- rule: Privileged Container Host Device Access
  desc: Detect privileged container accessing host block devices
  condition: >
    open and
    container and
    container.privileged = true and
    fd.name startswith /dev/ and
    fd.name pmatch (/dev/sd*, /dev/vd*, /dev/nvme*, /dev/xvd*, /dev/hd*)
  output: >
    Privileged container accessing host block device
    (user=%user.name container_id=%container.id container_name=%container.name
    device=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, privileged, device, docker, T1611]
  source: syscall

- rule: Privileged Container Sensitive File Access
  desc: Detect privileged container reading sensitive host files
  condition: >
    open_read and
    container and
    container.privileged = true and
    fd.name in (/etc/shadow, /etc/sudoers, /root/.ssh/id_rsa, /root/.ssh/id_ed25519)
  output: >
    Privileged container reading sensitive host file
    (user=%user.name container_id=%container.id container_name=%container.name
    file=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, privileged, sensitive_files, docker, T1552]
  source: syscall

- rule: Privileged Container Host Filesystem Write
  desc: Detect privileged container writing to host critical paths
  condition: >
    open_write and
    container and
    container.privileged = true and
    (fd.name startswith /etc/ or
     fd.name startswith /root/ or
     fd.name startswith /usr/bin/ or
     fd.name startswith /usr/sbin/)
  output: >
    Privileged container modifying critical host path - possible backdoor
    (user=%user.name container_id=%container.id container_name=%container.name
    file=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, privileged, host_modification, docker, T1546]
  source: syscall
EOF

    print_step "Created: $ARTIFACTS_DIR/falco-docker-privileged-rules.yaml"
    echo

    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_warning "Falco requires Linux kernel - cannot run on macOS"
        echo "  Rules file is created for deployment on Linux production servers"
        echo
        echo "  On your Linux server:"
        echo "    1. curl -s https://falco.org/script/install | sudo bash"
        echo "    2. sudo cp $ARTIFACTS_DIR/falco-docker-privileged-rules.yaml /etc/falco/rules.d/"
        echo "    3. sudo systemctl restart falco"
    else
        print_step "To deploy Falco on this Linux system:"
        echo "    1. curl -s https://falco.org/script/install | sudo bash"
        echo "    2. sudo cp $ARTIFACTS_DIR/falco-docker-privileged-rules.yaml /etc/falco/rules.d/"
        echo "    3. sudo systemctl restart falco"
        echo "    4. Test: docker run --privileged alpine mount"
        echo "    5. sudo journalctl -u falco -f"
    fi
    echo
}

###############################################
# Image Scanning Guide
###############################################
scan_docker_image() {
    print_header "Defense 7: Image Scanning Guide"

    echo "Scan container images before deployment to catch misconfigurations:"
    echo
    echo "1. Docker Scout (built-in):"
    echo "   docker scout quickview myapp:latest"
    echo
    echo "2. Trivy (open source):"
    echo "   trivy image myapp:latest"
    echo
    echo "3. Grype (open source):"
    echo "   grype myapp:latest"
    echo
    echo "What to look for:"
    echo "  • Dockerfile with --privileged in RUN steps"
    echo "  • Images tagged 'latest' (unpinned versions)"
    echo "  • Running as root user"
    echo "  • Missing seccomp/apparmor profiles"
    echo
}

###############################################
# Alternative Solutions
###############################################
show_alternatives() {
    print_header "Alternative Solutions (Instead of --privileged)"

    echo -e "${GREEN}1. For Network Operations${NC}"
    echo
    echo "   Instead of: docker run --privileged vpn-container"
    echo "   Use: Only NET_ADMIN capability"
    echo
    echo "   Example:"
    echo "     docker run --cap-drop=ALL --cap-add=NET_ADMIN \\"
    echo "       --device=/dev/net/tun vpn-container"
    echo

    echo -e "${GREEN}2. For Container Builds${NC}"
    echo
    echo "   Instead of: docker run --privileged docker:dind"
    echo "   Use: Rootless builders"
    echo
    echo "   Examples:"
    echo "     • Kaniko (no daemon, no privileges)"
    echo "     • Buildah (rootless capable)"
    echo "     • Docker buildx with containerd"
    echo

    echo -e "${GREEN}3. For System Monitoring${NC}"
    echo
    echo "   Instead of: docker run --privileged monitoring-agent"
    echo "   Use: Host-mounted /proc and specific capabilities"
    echo
    echo "   Example:"
    echo "     docker run --cap-drop=ALL --cap-add=DAC_READ_SEARCH \\"
    echo "       -v /proc:/host/proc:ro monitoring-agent"
    echo

    echo -e "${GREEN}4. For FUSE Filesystems${NC}"
    echo
    echo "   Instead of: docker run --privileged s3fs-container"
    echo "   Use: Mount on host, share as volume"
    echo
    echo "   Example:"
    echo "     # Mount on host first"
    echo "     s3fs mybucket /mnt/s3 -o allow_other"
    echo "     # Then share to container as read-only volume"
    echo "     docker run -v /mnt/s3:/data:ro myapp"
    echo

    echo -e "${GREEN}5. For Debugging (development only)${NC}"
    echo
    echo "   Instead of: docker run --privileged myapp"
    echo "   Use: Specific capabilities only"
    echo
    echo "   Example:"
    echo "     docker run --cap-drop=ALL \\"
    echo "       --cap-add=SYS_PTRACE \\"
    echo "       --cap-add=SYS_ADMIN \\"
    echo "       myapp"
    echo "     # Only add what you actually need, document why"
    echo
}

###############################################
# Summary
###############################################
show_summary() {
    print_header "Defense Implementation Summary"

    cat << EOF
${GREEN}Docker Security Defenses Against --privileged:${NC}

${BLUE}1. Docker Daemon Configuration${NC}
   └─ Harden daemon.json with no-new-privileges, userns-remap
   └─ System-level protection baseline

${BLUE}2. Docker Compose Security${NC}
   └─ Never use --privileged
   └─ Drop ALL capabilities, add only specific ones
   └─ File: $ARTIFACTS_DIR/docker-compose-secure.yml

${BLUE}3. Seccomp Profiles${NC}
   └─ Block mount/umount/ptrace syscalls at kernel level
   └─ File: $ARTIFACTS_DIR/seccomp-no-privileged.json

${BLUE}4. AppArmor Profiles (Linux)${NC}
   └─ Deny mount, device access, namespace manipulation
   └─ File: $ARTIFACTS_DIR/docker-no-privileged-apparmor

${BLUE}5. Container Auditing${NC}
   └─ Scan running containers for --privileged flag
   └─ File: $ARTIFACTS_DIR/audit-privileged.sh

${BLUE}6. Falco Runtime Detection${NC}
   └─ Real-time alerts when privileged containers act suspicious
   └─ File: $ARTIFACTS_DIR/falco-docker-privileged-rules.yaml

${YELLOW}Docker Security Checklist:${NC}

[ ] Never use --privileged in production
[ ] Configure Docker daemon with security settings
[ ] Use secure Docker Compose templates
[ ] Apply seccomp profiles to all containers
[ ] Use AppArmor/SELinux where available
[ ] Audit running containers regularly
[ ] Drop ALL capabilities by default
[ ] Add only necessary capabilities explicitly
[ ] Run containers as non-root user
[ ] Use read-only root filesystems
[ ] Enable no-new-privileges
[ ] Monitor with Falco for runtime detection
[ ] Scan images before deployment

${GREEN}Testing Your Defenses:${NC}

# Test 1: Verify privileged is blocked by seccomp
docker run --privileged \
  --security-opt seccomp=$ARTIFACTS_DIR/seccomp-no-privileged.json \
  alpine mount
# With seccomp on Linux: Should fail with "Operation not permitted"

# Test 2: Run with secure configuration
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE \\
  --security-opt no-new-privileges \\
  --read-only --user 1000:1000 alpine echo "secure"
# Should work fine

# Test 3: Audit running containers
./artifacts/audit-privileged.sh

${BLUE}Additional Resources:${NC}

• Docker Security Best Practices:
  https://docs.docker.com/engine/security/

• CIS Docker Benchmark:
  https://www.cisecurity.org/benchmark/docker

• Docker Seccomp Documentation:
  https://docs.docker.com/engine/security/seccomp/

• AppArmor Documentation:
  https://docs.docker.com/engine/security/apparmor/

${GREEN}Your Docker containers are now hardened against --privileged escapes!${NC}
EOF
    echo
}

###############################################
# Main Menu
###############################################
main() {
    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    Lab 09 - Scenario 2: Docker Security Defense Setup        ║
║                                                               ║
║  Docker-native defenses against --privileged escapes          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

Select defense implementation:

  1) Deploy all defenses (recommended)
  2) Show Docker daemon configuration
  3) Create secure Docker Compose template
  4) Create Seccomp profile
  5) Create AppArmor profile
  6) Audit running containers
  7) Show image scanning guide
  8) Show alternative solutions
  9) Show summary and checklist
  10) Create Falco detection rules
  0) Exit

EOF
    read -p "Enter choice [0-10]: " choice

    case $choice in
        1)
            configure_docker_daemon
            show_docker_compose_security
            create_seccomp_profile
            create_apparmor_profile
            create_falco_rules
            audit_docker_containers
            show_alternatives
            show_summary
            ;;
        2)
            configure_docker_daemon
            ;;
        3)
            show_docker_compose_security
            ;;
        4)
            create_seccomp_profile
            ;;
        5)
            create_apparmor_profile
            ;;
        6)
            audit_docker_containers
            ;;
        7)
            scan_docker_image
            ;;
        8)
            show_alternatives
            ;;
        9)
            show_summary
            ;;
        10)
            create_falco_rules
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    echo
    print_step "Defense setup complete!"
    echo
    echo "Run './defense.sh 9' to see the complete summary checklist"
}

main "$@"