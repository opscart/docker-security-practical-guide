#!/bin/bash

# Scenario 3: CAP_SYS_ADMIN Defense Implementation (Docker-Focused)
# This script implements Docker-native defenses against CAP_SYS_ADMIN container escapes

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
    if ! docker ps &>/dev/null; then
        print_error "Docker is not running or not accessible"
        return 1
    fi
    return 0
}

# Defense 1: Docker Daemon Configuration
configure_docker_daemon() {
    print_header "Defense 1: Docker Daemon Security Configuration"
    
    print_step "Recommended Docker daemon settings for production:"
    echo
    
    cat <<'EOF'
Add to /etc/docker/daemon.json:

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

What these do:
• no-new-privileges: Prevents privilege escalation
• userns-remap: Isolates container user namespaces
• selinux-enabled: Enables SELinux (if available)
• live-restore: Keeps containers running during daemon restart
• userland-proxy: Reduces attack surface

After changes: sudo systemctl restart docker
EOF
    
    echo
    print_warning "Note: These are system-level changes requiring root access"
    echo
}

# Defense 2: Docker Compose Security
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
      # Note: SYS_ADMIN is NOT included!
    
    # Security options
    security_opt:
      - no-new-privileges:true
      - apparmor:docker-default
      # - seccomp:./seccomp-profile.json  # Uncomment to use custom profile
    
    # Run as non-root user
    user: "1000:1000"
    
    # Read-only root filesystem
    read_only: true
    
    # Temporary writable directories
    tmpfs:
      - /tmp:noexec,nosuid,size=64m
      - /var/tmp:noexec,nosuid,size=64m
    
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
    
    # Environment variables (never hardcode secrets!)
    environment:
      - APP_ENV=production
    
    # Logging
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Example: Application requiring specific capabilities
  network-app:
    image: mynetworkapp:latest
    
    cap_drop:
      - ALL
    cap_add:
      - NET_ADMIN      # For network operations
      - NET_RAW        # For raw sockets
      # Still NO SYS_ADMIN!
    
    security_opt:
      - no-new-privileges:true
    
    user: "1000:1000"
    read_only: true
    
    tmpfs:
      - /tmp:noexec,nosuid,size=64m
EOF
    
    print_step "Created: $ARTIFACTS_DIR/docker-compose-secure.yml"
    echo
    
    print_step "To use this secure configuration:"
    echo "  docker-compose -f $ARTIFACTS_DIR/docker-compose-secure.yml up -d"
    echo
    
    print_step "Key security features:"
    echo "  • All capabilities dropped by default"
    echo "  • Only safe capabilities added explicitly"
    echo "  • No new privileges allowed"
    echo "  • Non-root user"
    echo "  • Read-only root filesystem"
    echo "  • Resource limits enforced"
    echo
}

# Defense 3: Seccomp Profile
create_seccomp_profile() {
    print_header "Defense 3: Seccomp Profile to Block Dangerous Syscalls"
    
    print_step "Creating seccomp profile to block mount/umount syscalls..."
    
    cat > "$ARTIFACTS_DIR/seccomp-no-sys-admin.json" <<'EOF'
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
      "comment": "Block syscalls commonly used with CAP_SYS_ADMIN for escapes"
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
      "comment": "Block other syscalls requiring CAP_SYS_ADMIN"
    }
  ]
}
EOF
    
    print_step "Created: $ARTIFACTS_DIR/seccomp-no-sys-admin.json"
    echo
    
    print_step "To use this seccomp profile:"
    echo "  docker run --security-opt seccomp=$ARTIFACTS_DIR/seccomp-no-sys-admin.json myapp"
    echo
    
    print_step "Or in docker-compose.yml:"
    cat <<'EOF'
  services:
    app:
      security_opt:
        - seccomp:./artifacts/seccomp-no-sys-admin.json
EOF
    echo
}

# Defense 4: AppArmor Profile
create_apparmor_profile() {
    print_header "Defense 4: AppArmor Profile (Linux Only)"
    
    print_step "Creating AppArmor profile to restrict container operations..."
    
    cat > "$ARTIFACTS_DIR/docker-no-sys-admin-apparmor" <<'EOF'
#include <tunables/global>

profile docker-no-sys-admin flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>
  
  # Deny mounting filesystems
  deny mount,
  deny umount,
  deny pivot_root,
  
  # Deny namespace manipulation
  deny /proc/sys/kernel/** w,
  deny /sys/kernel/** w,
  
  # Deny cgroup manipulation
  deny /sys/fs/cgroup/** w,
  
  # Deny access to kernel modules
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
}
EOF
    
    print_step "Created: $ARTIFACTS_DIR/docker-no-sys-admin-apparmor"
    echo
    
    print_step "To install this AppArmor profile (requires root):"
    cat <<'EOF'
  sudo cp artifacts/docker-no-sys-admin-apparmor /etc/apparmor.d/
  sudo apparmor_parser -r /etc/apparmor.d/docker-no-sys-admin-apparmor
EOF
    echo
    
    print_step "To use with Docker:"
    echo "  docker run --security-opt apparmor=docker-no-sys-admin myapp"
    echo
}

# Defense 5: Container Auditing
audit_docker_containers() {
    print_header "Defense 5: Audit Running Docker Containers"
    
    if ! check_docker; then
        print_warning "Docker not available, skipping audit"
        return
    fi
    
    print_step "Scanning running containers for CAP_SYS_ADMIN..."
    echo
    
    FOUND=0
    
    while read container_id; do
        CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container_id" 2>/dev/null | sed 's|/||')
        CAPS=$(docker inspect --format='{{.HostConfig.CapAdd}}' "$container_id" 2>/dev/null)
        PRIVILEGED=$(docker inspect --format='{{.HostConfig.Privileged}}' "$container_id" 2>/dev/null)
        
        if [ "$PRIVILEGED" = "true" ]; then
            print_error "Container: $CONTAINER_NAME (ID: ${container_id:0:12}) - PRIVILEGED MODE"
            FOUND=$((FOUND + 1))
        elif echo "$CAPS" | grep -qi "SYS_ADMIN"; then
            print_error "Container: $CONTAINER_NAME (ID: ${container_id:0:12}) - Has CAP_SYS_ADMIN"
            echo "  Capabilities: $CAPS"
            FOUND=$((FOUND + 1))
        fi
    done < <(docker ps -q)
    
    echo
    if [ $FOUND -eq 0 ]; then
        print_step "No containers with CAP_SYS_ADMIN or privileged mode found"
    else
        print_warning "Found $FOUND container(s) with dangerous capabilities"
        echo
        echo "Recommended actions:"
        echo "  1. Review if CAP_SYS_ADMIN is truly necessary"
        echo "  2. Replace with safer alternatives (specific capabilities)"
        echo "  3. Recreate containers with secure configuration"
    fi
    echo
}

# Defense 6: Docker Image Scanning
scan_docker_image() {
    print_header "Defense 6: Docker Image Analysis"
    
    print_step "Example: Scanning an image for security issues"
    echo
    
    cat <<'EOF'
You can use Docker Scout or other tools to scan images:

# Docker Scout (built-in)
docker scout cves myimage:latest

# Trivy (install separately)
trivy image myimage:latest

# Grype (install separately)
grype myimage:latest

These tools will detect:
• Known vulnerabilities (CVEs)
• Exposed secrets
• Unsafe Dockerfile practices
• Running as root
• Missing security updates
EOF
    echo
}

# Show alternative solutions
show_alternatives() {
    print_header "Alternative Solutions (Instead of CAP_SYS_ADMIN)"
    
    cat <<EOF
${GREEN}1. For FUSE Filesystems${NC}

   Instead of: docker run --cap-add=SYS_ADMIN s3fs-container
   
   Use: Host-mounted volumes with proper permissions
   
   Example:
     # Mount on host
     s3fs mybucket /mnt/s3 -o allow_other
     
     # Use in container
     docker run -v /mnt/s3:/data:ro myapp

${GREEN}2. For VPN Containers${NC}

   Instead of: docker run --cap-add=SYS_ADMIN vpn-container
   
   Use: Only NET_ADMIN capability
   
   Example:
     docker run --cap-drop=ALL --cap-add=NET_ADMIN \
       --device=/dev/net/tun vpn-container

${GREEN}3. For Container Builds${NC}

   Instead of: docker run --cap-add=SYS_ADMIN docker:dind
   
   Use: Rootless builders
   
   Examples:
     • Kaniko (no daemon, no privileges)
     • Buildah (rootless capable)
     • Docker buildx with containerd

${GREEN}4. For System Monitoring${NC}

   Instead of: docker run --cap-add=SYS_ADMIN monitoring-agent
   
   Use: Host-mounted /proc and specific capabilities
   
   Example:
     docker run --cap-drop=ALL --cap-add=DAC_READ_SEARCH \
       -v /proc:/host/proc:ro monitoring-agent

EOF
}

# Summary and checklist
show_summary() {
    print_header "Defense Implementation Summary"
    
    cat <<EOF
${GREEN}Docker Security Defenses Against CAP_SYS_ADMIN:${NC}

${BLUE}1. Docker Daemon Configuration${NC}
   └─ Harden daemon.json with no-new-privileges, userns-remap
   └─ File: See output above for recommended settings

${BLUE}2. Docker Compose Security${NC}
   └─ Drop ALL capabilities, add only specific ones
   └─ File: $ARTIFACTS_DIR/docker-compose-secure.yml

${BLUE}3. Seccomp Profiles${NC}
   └─ Block mount/umount syscalls at kernel level
   └─ File: $ARTIFACTS_DIR/seccomp-no-sys-admin.json

${BLUE}4. AppArmor Profiles (Linux)${NC}
   └─ Restrict container operations via LSM
   └─ File: $ARTIFACTS_DIR/docker-no-sys-admin-apparmor

${BLUE}5. Container Auditing${NC}
   └─ Scan running containers for dangerous capabilities
   └─ Use Docker inspect API

${BLUE}6. Image Scanning${NC}
   └─ Scan images before deployment
   └─ Tools: Docker Scout, Trivy, Grype

${YELLOW}Docker Security Checklist:${NC}

[ ] Configure Docker daemon with security settings
[ ] Use secure Docker Compose templates
[ ] Apply seccomp profiles to containers
[ ] Use AppArmor/SELinux where available
[ ] Audit running containers regularly
[ ] Scan images before deployment
[ ] Drop ALL capabilities by default
[ ] Add only necessary capabilities
[ ] Run containers as non-root user
[ ] Use read-only root filesystems
[ ] Enable no-new-privileges
[ ] Document exceptions for SYS_ADMIN usage

${GREEN}Testing Your Defenses:${NC}

# Test 1: Try to run container with SYS_ADMIN
docker run --cap-add=SYS_ADMIN alpine mount
# With seccomp: Should fail with "Operation not permitted"

# Test 2: Run with secure configuration
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE \\
  --security-opt no-new-privileges \\
  --read-only --user 1000:1000 myapp
# Should work fine

# Test 3: Audit running containers
docker ps -q | xargs -I {} docker inspect --format='{{.Name}}: {{.HostConfig.CapAdd}}' {}

${BLUE}Additional Resources:${NC}

• Docker Security Best Practices:
  https://docs.docker.com/engine/security/

• CIS Docker Benchmark:
  https://www.cisecurity.org/benchmark/docker

• Docker Seccomp Documentation:
  https://docs.docker.com/engine/security/seccomp/

• AppArmor Documentation:
  https://docs.docker.com/engine/security/apparmor/

${GREEN}Your Docker containers are now hardened against CAP_SYS_ADMIN escapes!${NC}

EOF
}

# Main execution
main() {
    clear
    
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    Lab 09 - Scenario 3: Docker Security Defense Setup        ║
║                                                               ║
║  Docker-native defenses against CAP_SYS_ADMIN escapes         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF

    echo
    echo "Select defense implementation:"
    echo
    echo "  1) Deploy all defenses (recommended)"
    echo "  2) Show Docker daemon configuration"
    echo "  3) Create secure Docker Compose template"
    echo "  4) Create Seccomp profile"
    echo "  5) Create AppArmor profile"
    echo "  6) Audit running containers"
    echo "  7) Show image scanning guide"
    echo "  8) Show alternative solutions"
    echo "  9) Show summary and checklist"
    echo "  10) Create Falco detection rules"
    echo "  0) Exit"
    echo
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

# Defense 6: Create Falco Rules
create_falco_rules() {
    print_header "Defense 6: Falco Runtime Detection Rules"
    
    print_step "Creating Falco rules for CAP_SYS_ADMIN detection..."
    
    cat > "$ARTIFACTS_DIR/falco-docker-sys-admin-rules.yaml" <<'EOF'
# Falco Rules for CAP_SYS_ADMIN Container Escape Detection (Docker)
#
# Installation (Linux only):
#   1. Install Falco: curl -s https://falco.org/script/install | sudo bash
#   2. Copy rules: sudo cp falco-docker-sys-admin-rules.yaml /etc/falco/rules.d/
#   3. Restart: sudo systemctl restart falco
#
# Test: docker run --cap-add=SYS_ADMIN alpine mount

- rule: Container Mount Operation Detected
  desc: Detect filesystem mount operations in non-privileged Docker containers
  condition: >
    spawned_process and
    container and
    container.privileged = false and
    proc.name = mount and
    not proc.pname in (dockerd, containerd, containerd-shim, runc)
  output: >
    Mount operation detected in non-privileged container - possible CAP_SYS_ADMIN abuse
    (user=%user.name container_id=%container.id container_name=%container.name
    image=%container.image.repository command=%proc.cmdline parent=%proc.pname)
  priority: WARNING
  tags: [container, filesystem, sys_admin, docker, T1611]
  source: syscall

- rule: Container Namespace Manipulation
  desc: Detect nsenter or unshare usage in Docker containers
  condition: >
    spawned_process and
    container and
    proc.name in (nsenter, unshare) and
    not container.privileged = true
  output: >
    Namespace manipulation tool detected in Docker container
    (user=%user.name container_id=%container.id container_name=%container.name
    image=%container.image.repository command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, namespace, escape, sys_admin, docker, T1611]
  source: syscall

- rule: Cgroup Release Agent Modification
  desc: Detect modification of cgroup release_agent (Felix Wilhelm escape)
  condition: >
    open_write and
    container and
    fd.name contains "release_agent" and
    fd.name startswith /sys/fs/cgroup
  output: >
    Cgroup release_agent modification detected - classic container escape attempt
    (user=%user.name container_id=%container.id container_name=%container.name
    file=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, cgroup, escape, sys_admin, docker, T1611]
  source: syscall

- rule: Container Accessing Host Block Devices
  desc: Detect when Docker container accesses host block devices
  condition: >
    open and
    container and
    fd.name startswith /dev/ and
    fd.name pmatch (/dev/sd*, /dev/vd*, /dev/nvme*, /dev/xvd*, /dev/hd*)
  output: >
    Docker container accessing host block device - possible mount escape attempt
    (user=%user.name container_id=%container.id container_name=%container.name
    device=%fd.name command=%proc.cmdline)
  priority: WARNING
  tags: [container, device, sys_admin, docker, T1611]
  source: syscall

- rule: Container Cgroup Mount Operation
  desc: Detect cgroup mounting inside Docker container
  condition: >
    spawned_process and
    container and
    proc.name = mount and
    proc.cmdline contains "cgroup"
  output: >
    Cgroup mount detected in Docker container - possible escape preparation
    (user=%user.name container_id=%container.id container_name=%container.name
    command=%proc.cmdline)
  priority: WARNING
  tags: [container, cgroup, mount, sys_admin, docker, T1611]
  source: syscall

- rule: Sensitive File Access from Container
  desc: Detect Docker container accessing sensitive host files
  condition: >
    open_read and
    container and
    (fd.name in (/etc/shadow, /etc/sudoers, /root/.ssh/id_rsa, /root/.ssh/id_ed25519) or
     fd.name startswith /etc/docker/)
  output: >
    Docker container accessing sensitive host file - possible post-escape activity
    (user=%user.name container_id=%container.id container_name=%container.name
    file=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, sensitive_files, post_escape, docker, T1552]
  source: syscall

- rule: Container Modifying Host Filesystem
  desc: Detect Docker container writing to critical host paths
  condition: >
    open_write and
    container and
    (fd.name startswith /etc/ or
     fd.name startswith /root/ or
     fd.name startswith /usr/bin/ or
     fd.name startswith /usr/sbin/)
  output: >
    Docker container modifying critical host path - possible backdoor installation
    (user=%user.name container_id=%container.id container_name=%container.name
    file=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, host_modification, backdoor, docker, T1546]
  source: syscall
EOF

    print_step "Created: $ARTIFACTS_DIR/falco-docker-sys-admin-rules.yaml"
    echo
    
    # Platform-aware usage instructions
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_warning "Falco requires Linux kernel - cannot run on macOS"
        echo "  Rules file is created for deployment on Linux production servers"
        echo
        echo "  On your Linux server:"
        echo "    1. curl -s https://falco.org/script/install | sudo bash"
        echo "    2. sudo cp $ARTIFACTS_DIR/falco-docker-sys-admin-rules.yaml /etc/falco/rules.d/"
        echo "    3. sudo systemctl restart falco"
    else
        print_step "To deploy Falco on this Linux system:"
        echo "    1. curl -s https://falco.org/script/install | sudo bash"
        echo "    2. sudo cp $ARTIFACTS_DIR/falco-docker-sys-admin-rules.yaml /etc/falco/rules.d/"
        echo "    3. sudo systemctl restart falco"
        echo "    4. Test: docker run --cap-add=SYS_ADMIN alpine mount"
        echo "    5. sudo journalctl -u falco -f"
    fi
    echo
}

# Show Falco info (platform-aware)
show_falco_info() {
    print_header "Runtime Monitoring with Falco"
    
    # Detect platform
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_warning "Falco is not supported on macOS (requires Linux kernel)"
        echo
        echo "Falco provides real-time detection of container escapes but requires"
        echo "a Linux kernel to monitor syscalls."
        echo
        echo "For Mac users:"
        echo "  • Falco rules file is included for reference"
        echo "  • Deploy Falco on Linux production servers"
        echo "  • Use Docker Desktop's built-in security features"
        echo
        echo "For Linux deployment:"
        echo "  1. Install Falco:"
        echo "     curl -s https://falco.org/script/install | sudo bash"
        echo
        echo "  2. Copy rules:"
        echo "     sudo cp artifacts/falco-docker-sys-admin-rules.yaml /etc/falco/rules.d/"
        echo
        echo "  3. Restart Falco:"
        echo "     sudo systemctl restart falco"
        echo
        echo "  4. Test detection:"
        echo "     docker run --cap-add=SYS_ADMIN alpine mount"
        echo
        echo "  5. View alerts:"
        echo "     sudo journalctl -u falco -f"
        echo
    else
        # Linux system
        print_step "Falco can be installed on this Linux system"
        echo
        
        cat <<'EOF'
Install Falco for real-time container escape detection:

1. Install Falco:
   curl -s https://falco.org/script/install | sudo bash

2. Copy rules:
   sudo cp artifacts/falco-docker-sys-admin-rules.yaml /etc/falco/rules.d/

3. Restart Falco:
   sudo systemctl restart falco

4. Test detection:
   docker run --cap-add=SYS_ADMIN alpine mount

5. View alerts:
   sudo journalctl -u falco -f

Falco will detect:
• Mount operations in containers
• Namespace manipulation (nsenter, unshare)
• Cgroup release_agent modifications
• Host block device access
• Sensitive file access
• Host filesystem modifications
EOF
    fi
    echo
}

main "$@"