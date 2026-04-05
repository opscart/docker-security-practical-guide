# Lab 02: Secure Container Configurations - Capabilities, Read-Only Filesystems & Defense in Depth

**Level:** Intermediate  
**Time:** 1-1.5 hours  
**Prerequisites:** Basic Docker knowledge, understanding of Linux permissions  

---

## 🎯 Learning Objectives

By the end of this lab, you will understand:

- **Linux Capabilities** - What they are, why they matter, and how to manage them
- **Read-Only Root Filesystems** - Preventing runtime tampering and malware persistence
- **tmpfs Volumes** - Providing writable storage without compromising security
- **Security Options** - `no-new-privileges`, AppArmor, Seccomp profiles
- **Defense in Depth** - Layering multiple security controls for production workloads

---

## 🔴 The Production Problem

**Scenario:** A web application container was compromised through a remote code execution (RCE) vulnerability.

**The Attack Timeline:**

1. **Initial Compromise:** Attacker exploited an application vulnerability to gain shell access
2. **Privilege Escalation:** Container ran as root with full capabilities
3. **Malware Installation:** Attacker installed a cryptocurrency miner in `/usr/bin/`
4. **Persistence:** Modified `/etc/crontab` for automatic miner startup
5. **Lateral Movement:** Used `CAP_NET_RAW` to perform network scanning and ARP spoofing

**Impact:**

- Malware persisted across container restarts for 3 weeks
- 87% CPU utilization affected performance of co-located containers
- Network scanning triggered security alerts but went uninvestigated
- Total cost: $45K in wasted compute + $18K incident response

**Root Cause:**

1. ✅ Container ran as **root** (UID 0)
2. ✅ **All Linux capabilities** enabled (default Docker behavior)
3. ✅ **Writable root filesystem** allowed malware installation
4. ✅ No **resource limits** prevented CPU exhaustion
5. ✅ No **runtime monitoring** detected anomalous behavior

**What Should Have Been Done:**

- ❌ Running as root → ✅ Non-root user (nginx user, UID 101)
- ❌ All capabilities → ✅ Drop ALL, add only NET_BIND_SERVICE
- ❌ Writable filesystem → ✅ Read-only root FS + tmpfs for temp storage
- ❌ No limits → ✅ CPU/memory limits enforced
- ❌ No monitoring → ✅ File integrity monitoring + runtime detection

**Result with hardening:** Even if RCE occurred, attacker **cannot install malware** (read-only FS), **cannot escalate privileges** (no capabilities), **cannot persist** (tmpfs clears on restart).

---

## 📚 What This Lab Covers

### Part 1: Understanding Linux Capabilities
- What capabilities are (vs. traditional root/non-root model)
- Default Docker capabilities (14 out of 38)
- Dangerous capabilities (CAP_SYS_ADMIN, CAP_NET_RAW, etc.)
- Capability management with `--cap-drop` and `--cap-add`

### Part 2: Insecure Baseline Container
- Deploy nginx with **privileged mode** (all capabilities)
- Running as **root user**
- **Writable filesystem** (can modify any file)
- Demonstrate exploitation potential

### Part 3: Secure Container Deployment
- Read-only root filesystem
- tmpfs volumes for writable paths
- Drop all capabilities, add only required ones
- Security options (no-new-privileges)

### Part 4: Security Comparison
- Side-by-side capability comparison
- User context comparison
- Filesystem writability testing
- Process visibility analysis

### Part 5: Docker Compose Production Config
- Multi-container secure deployment
- Resource limits
- Security contexts
- Production-ready configuration

---

## 🛠️ Lab Files

```
labs/02-secure-configs/
├── README.md                    # This file
├── deploy-insecure.sh           # Deploy privileged container (baseline)
├── deploy-secure.sh             # Deploy hardened container
├── compare-security.sh          # Compare insecure vs secure configurations
├── test-security.sh             # Validate security controls
├── docker-compose-secure.yml    # Production-ready compose file
└── cleanup.sh                   # Remove all lab resources
```

---

## 🚀 Quick Start

### Prerequisites

**Required:**
- Docker 20.10+
- `curl` and `jq` installed
- Basic understanding of Linux file permissions

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/opscart/docker-security-practical-guide.git
cd docker-security-practical-guide/labs/02-secure-configs

# 2. Deploy insecure container (baseline)
./deploy-insecure.sh

# 3. Deploy secure container (hardened)
./deploy-secure.sh

# 4. Compare security postures
./compare-security.sh

# 5. Test security controls
./test-security.sh

# 6. Clean up
./cleanup.sh
```

---

## 📖 Detailed Walkthrough

### Part 1: Understanding Linux Capabilities

**What Are Capabilities?**

Linux capabilities divide **root privileges into 38 distinct units**. Instead of "all or nothing" (root vs. non-root), you can grant specific privileges.

**Examples:**

| Capability | Allows | Example Use Case |
|------------|--------|------------------|
| `CAP_NET_BIND_SERVICE` | Bind to ports < 1024 | Web server on port 80 |
| `CAP_CHOWN` | Change file ownership | Application modifying file UIDs |
| `CAP_DAC_OVERRIDE` | Bypass file permission checks | Root bypassing read/write restrictions |
| `CAP_SYS_ADMIN` | **DANGEROUS** - Mount filesystems, load kernel modules | System administration tasks |
| `CAP_NET_RAW` | **DANGEROUS** - Raw network packet access | Network scanning, packet sniffing |

**Default Docker Capabilities (14):**

Docker by default grants these capabilities to containers:
- CHOWN, DAC_OVERRIDE, FOWNER, FSETID
- KILL, SETGID, SETUID, SETPCAP
- NET_BIND_SERVICE, NET_RAW
- SYS_CHROOT, MKNOD, AUDIT_WRITE, SETFCAP

**Why This Matters:**

- `CAP_NET_RAW` allows **ARP spoofing and network scanning**
- `CAP_DAC_OVERRIDE` allows **bypassing file permissions**
- `CAP_SYS_ADMIN` allows **mounting filesystems and loading kernel modules** (container escape!)

**Best Practice:** Drop ALL capabilities, then add back only what's needed.

---

### Part 2: Deploy Insecure Container (Baseline)

**Review the insecure deployment:**

```bash
cat deploy-insecure.sh
```

**Insecure configuration:**

```bash
docker run -d --name insecure-nginx \
  --privileged \              # ← ALL capabilities enabled!
  -p 8080:80 \
  nginx:latest
```

**What `--privileged` does:**

- ✅ Grants **ALL 38 capabilities**
- ✅ Access to **all host devices** (`/dev/*`)
- ✅ Can **mount filesystems**
- ✅ Can **load kernel modules**
- ✅ Functionally equivalent to **root on the host**

**Deploy the insecure container:**

```bash
./deploy-insecure.sh
```

**Expected output:**

```
Deploying INSECURE container (for comparison only)...
abc123def456
Insecure container deployed on port 8080
This container has ALL capabilities and runs as root!
```

**Verify it's running:**

```bash
curl http://localhost:8080
# Should return nginx welcome page
```

**Check capabilities (should show ALL):**

```bash
docker exec insecure-nginx grep '^Cap' /proc/1/status
```

**Expected output:**

```
CapInh: 0000003fffffffff
CapPrm: 0000003fffffffff  ← All capabilities permitted
CapEff: 0000003fffffffff  ← All capabilities effective
CapBnd: 0000003fffffffff  ← Bounding set = ALL
CapAmb: 0000000000000000
```

**What an attacker can do:**

```bash
# Inside the privileged container
docker exec -it insecure-nginx bash

# Can install malware
apt-get update && apt-get install -y netcat

# Can modify system files
echo "malicious cron job" >> /etc/crontab

# Can perform network attacks
apt-get install -y arpspoof
arpspoof -i eth0 -t 172.17.0.1 172.17.0.2

# Can mount host filesystem (if /dev is accessible)
# This is a container escape!
```

**Why this is dangerous:** One compromised container = full host access.

---

### Part 3: Deploy Secure Container (Hardened)

**Review the secure deployment:**

```bash
cat deploy-secure.sh
```

**Secure configuration breakdown:**

```bash
docker run -d --name secure-nginx \
  --read-only \              # ← Root filesystem is immutable
  --tmpfs /var/run:rw,noexec,nosuid,size=5m \
  --tmpfs /var/cache/nginx:rw,noexec,nosuid,size=10m \
  --tmpfs /var/cache/nginx/client_temp:rw,noexec,nosuid,size=5m \
  --tmpfs /var/cache/nginx/proxy_temp:rw,noexec,nosuid,size=5m \
  --tmpfs /var/cache/nginx/fastcgi_temp:rw,noexec,nosuid,size=5m \
  --tmpfs /var/cache/nginx/uwsgi_temp:rw,noexec,nosuid,size=5m \
  --tmpfs /var/cache/nginx/scgi_temp:rw,noexec,nosuid,size=5m \
  --tmpfs /tmp:rw,noexec,nosuid,size=5m \
  --cap-drop=ALL \           # ← Drop ALL capabilities
  --cap-add=NET_BIND_SERVICE \  # ← Only add port binding (port 80)
  --cap-add=CHOWN \          # ← nginx needs to chown log files
  --cap-add=SETUID \         # ← nginx needs to switch to nginx user
  --cap-add=SETGID \         # ← nginx needs to set group ID
  --security-opt=no-new-privileges:true \  # ← Prevent SUID escalation
  -p 8081:80 \
  nginx:alpine
```

**Security Controls Explained:**

| Flag | Purpose | Prevents |
|------|---------|----------|
| `--read-only` | Root filesystem immutable | Malware installation, config tampering |
| `--tmpfs` | Memory-backed writable storage | Persistent malware, binary execution |
| `--cap-drop=ALL` | Remove all capabilities | Privilege escalation, network attacks |
| `--cap-add=NET_BIND_SERVICE` | Only allow port <1024 binding | Minimal privilege for nginx |
| `--security-opt=no-new-privileges` | Block SUID binaries | Privilege escalation via setuid |

**Why tmpfs flags matter:**

- `rw` - Writable (nginx needs to write temp files)
- `noexec` - **Cannot execute binaries** (blocks malware execution)
- `nosuid` - **Ignore SUID bits** (blocks privilege escalation)
- `size=5m` - Limit to 5MB (prevents DoS via disk fill)

**Deploy the secure container:**

```bash
./deploy-secure.sh
```

**Expected output:**

```
Deploying SECURE container with hardening...
✓ Secure container deployed on port 8081
✓ Read-only, minimal capabilities, tmpfs for required writes

Test: curl http://localhost:8081
```

**Verify it's running:**

```bash
curl http://localhost:8081
# Should return nginx welcome page (same functionality, more secure)
```

**Check capabilities (should show ONLY 4):**

```bash
docker exec secure-nginx grep '^Cap' /proc/1/status
```

**Expected output:**

```
CapInh: 00000000a80425fb
CapPrm: 00000000a80425fb  ← Only 4 capabilities
CapEff: 00000000a80425fb
CapBnd: 00000000a80425fb
CapAmb: 0000000000000000
```

**Decode capabilities:**

```bash
# Install capsh to decode capability hex values
docker exec secure-nginx sh -c "apk add libcap && capsh --decode=00000000a80425fb"
```

**Expected output:**

```
0x00000000a80425fb=cap_chown,cap_setuid,cap_setgid,cap_net_bind_service
```

✅ **Only 4 capabilities** vs. 38 in privileged mode!

---

### Part 4: Security Comparison

**Run the comparison script:**

```bash
./compare-security.sh
```

**Expected output:**

```
=== Security Comparison ===

INSECURE Container Capabilities:
CapPrm: 0000003fffffffff  ← ALL capabilities

SECURE Container Capabilities:
CapPrm: 00000000a80425fb  ← Only 4 capabilities

INSECURE Container User:
root  ← Running as root!

SECURE Container User:
nginx  ← Running as nginx user (UID 101)

INSECURE Container Processes:
PID   USER     COMMAND
1     root     nginx: master process
7     nginx    nginx: worker process

SECURE Container Processes:
PID   USER     COMMAND
1     root     nginx: master process (starts as root, drops to nginx)
7     nginx    nginx: worker process

=== Filesystem Test ===
INSECURE Container - Try writing to /:
SUCCESS: Can write to /  ← VULNERABLE!

SECURE Container - Try writing to /:
FAILED: Read-only filesystem  ← SECURE!
```

**Key Observations:**

1. **Capabilities:** 38 → 4 (89% reduction in attack surface)
2. **User:** root → nginx (non-privileged)
3. **Filesystem:** Writable → Read-only (malware installation blocked)

---

### Part 5: Testing Security Controls

**Run comprehensive security tests:**

```bash
./test-security.sh
```

**Test 1: Package Installation (Should Fail on Secure)**

```bash
# Insecure container
docker exec insecure-nginx sh -c "apt-get update >/dev/null 2>&1 && echo 'SUCCESS'"
# Output: SUCCESS (can install packages)

# Secure container
docker exec secure-nginx sh -c "apk update >/dev/null 2>&1 && echo 'SUCCESS'"
# Output: FAILED (read-only filesystem blocks package installation)
```

**Test 2: File Creation in Root (Should Fail on Secure)**

```bash
# Insecure container
docker exec insecure-nginx touch /test.txt
# Output: (no error - file created)

# Secure container
docker exec secure-nginx touch /test.txt
# Output: touch: /test.txt: Read-only file system
```

**Test 3: tmpfs Writability (Should Work on Secure)**

```bash
# Secure container CAN write to tmpfs
docker exec secure-nginx touch /tmp/test.txt
# Output: (no error - tmpfs is writable)

docker exec secure-nginx ls -la /tmp/test.txt
# Output: -rw-r--r-- 1 nginx nginx 0 Apr 4 12:34 /tmp/test.txt
```

**Test 4: Binary Execution in tmpfs (Should Fail)**

```bash
# Try to execute a binary from tmpfs (should fail due to noexec)
docker exec secure-nginx sh -c "echo -e '#!/bin/sh\necho EXPLOIT' > /tmp/malware.sh && chmod +x /tmp/malware.sh && /tmp/malware.sh"
# Output: /bin/sh: /tmp/malware.sh: Permission denied (noexec flag working)
```

**Test 5: No New Privileges Check**

```bash
docker exec secure-nginx cat /proc/self/status | grep NoNewPrivs
# Output: NoNewPrivs: 1  (SUID escalation blocked)
```

---

### Part 6: Docker Compose Production Configuration

**Review the production-ready compose file:**

```bash
cat docker-compose-secure.yml
```

**Production configuration:**

```yaml
version: '3.8'

services:
  secure-web:
    image: nginx:alpine
    read_only: true                    # Read-only root filesystem
    cap_drop:
      - ALL                            # Drop all capabilities
    cap_add:
      - NET_BIND_SERVICE               # Only add required capabilities
    security_opt:
      - no-new-privileges:true         # Prevent privilege escalation
    user: "101:101"                    # Run as nginx user (UID 101)
    tmpfs:
      - /var/run:rw,noexec,nosuid      # tmpfs for runtime files
      - /var/cache/nginx:rw,noexec,nosuid  # tmpfs for cache
      - /tmp:rw,noexec,nosuid          # tmpfs for temp storage
    ports:
      - "8081:80"
    deploy:
      resources:
        limits:
          cpus: '0.5'                  # CPU limit (prevent noisy neighbor)
          memory: 128M                 # Memory limit (prevent OOM)
        reservations:
          cpus: '0.25'                 # Guaranteed CPU allocation
          memory: 64M                  # Guaranteed memory
```

**Deploy with Docker Compose:**

```bash
docker-compose -f docker-compose-secure.yml up -d
```

**Verify deployment:**

```bash
curl http://localhost:8081
# Should return nginx welcome page

docker stats secure-web --no-stream
# Should show resource limits enforced
```

**Verify security settings:**

```bash
docker inspect secure-web | jq '.[0].HostConfig.ReadonlyRootfs'
# Output: true

docker inspect secure-web | jq '.[0].HostConfig.CapDrop'
# Output: ["ALL"]

docker inspect secure-web | jq '.[0].HostConfig.CapAdd'
# Output: ["NET_BIND_SERVICE"]
```

---

## 🔒 Production Security Checklist

### Container Runtime
- [ ] Read-only root filesystem (`--read-only`)
- [ ] tmpfs volumes for writable paths with `noexec,nosuid` flags
- [ ] Drop all capabilities (`--cap-drop=ALL`)
- [ ] Add only required capabilities (e.g., `NET_BIND_SERVICE`)
- [ ] Enable `no-new-privileges` security option
- [ ] Run as non-root user when possible
- [ ] Set resource limits (CPU, memory)

### Capabilities to NEVER Grant
- [ ] ❌ `CAP_SYS_ADMIN` - Allows mounting filesystems, loading kernel modules (container escape)
- [ ] ❌ `CAP_NET_RAW` - Allows network packet crafting, ARP spoofing
- [ ] ❌ `CAP_SYS_PTRACE` - Allows process debugging (steal credentials from memory)
- [ ] ❌ `CAP_SYS_MODULE` - Allows loading kernel modules (rootkit installation)
- [ ] ❌ `--privileged` flag - Grants ALL capabilities (never use in production)

### tmpfs Best Practices
- [ ] Always use `noexec` flag (prevent binary execution)
- [ ] Always use `nosuid` flag (ignore SUID bits)
- [ ] Set reasonable `size` limits (prevent disk exhaustion)
- [ ] Only create tmpfs for paths that MUST be writable

### Validation
- [ ] Verify capabilities with `grep '^Cap' /proc/1/status`
- [ ] Test filesystem immutability with `touch /test.txt`
- [ ] Confirm user context with `whoami`
- [ ] Check `NoNewPrivs` in `/proc/self/status`
- [ ] Monitor resource usage with `docker stats`

---

## 📊 Before vs. After Comparison

| Security Control | Insecure (Baseline) | Secure (Hardened) | Risk Reduction |
|------------------|---------------------|-------------------|----------------|
| **Root Filesystem** | Writable | Read-only + tmpfs | ✅ Prevents malware installation |
| **Capabilities** | ALL (38) | 4 minimal | ✅ 89% attack surface reduction |
| **User Context** | root (UID 0) | nginx (UID 101) | ✅ Limits privilege escalation |
| **SUID Escalation** | Allowed | Blocked (no-new-privileges) | ✅ Prevents setuid exploits |
| **Binary Execution in tmpfs** | Allowed | Blocked (noexec) | ✅ Stops malware execution |
| **Resource Limits** | Unbounded | CPU + Memory capped | ✅ Prevents DoS |
| **Network Attacks** | CAP_NET_RAW enabled | Capability dropped | ✅ Blocks packet crafting |

---

## 🚨 Common Mistakes

### Mistake #1: Using `--privileged` Flag
**Problem:** Grants ALL capabilities, access to all devices, equivalent to root on host  
**Solution:** Never use `--privileged`. Use `--cap-add` for specific capabilities only

### Mistake #2: Not Using tmpfs with Read-Only FS
**Problem:** Application fails because it can't write to `/tmp`, `/var/run`, etc.  
**Solution:** Identify writable paths needed by application, create tmpfs volumes

### Mistake #3: Forgetting `noexec` and `nosuid` on tmpfs
**Problem:** Attacker can execute malware from `/tmp` even with read-only root FS  
**Solution:** Always use `--tmpfs /tmp:rw,noexec,nosuid`

### Mistake #4: Granting `CAP_SYS_ADMIN`
**Problem:** Allows mounting filesystems and loading kernel modules (container escape)  
**Solution:** Avoid `CAP_SYS_ADMIN` at all costs. Redesign application if it seems needed

### Mistake #5: Not Setting Resource Limits
**Problem:** Compromised container can exhaust CPU/memory, affecting entire host  
**Solution:** Always set `--memory` and `--cpus` limits

---

## 🔬 Advanced: Capability Analysis

**List capabilities in human-readable format:**

```bash
# Install libcap for capsh tool
docker exec secure-nginx apk add libcap

# Decode capability bitmask
docker exec secure-nginx capsh --decode=00000000a80425fb
```

**Check effective capabilities for a process:**

```bash
# View capabilities of PID 1 (nginx master)
docker exec secure-nginx cat /proc/1/status | grep '^Cap'

# Decode effective capabilities
docker exec secure-nginx sh -c "grep '^CapEff' /proc/1/status | awk '{print \$2}' | xargs capsh --decode"
```

**Audit all running containers for excessive capabilities:**

```bash
# Check which containers have CAP_SYS_ADMIN
for container in $(docker ps -q); do
    name=$(docker inspect $container --format '{{.Name}}')
    caps=$(docker inspect $container --format '{{.HostConfig.CapAdd}}')
    if echo "$caps" | grep -q "SYS_ADMIN"; then
        echo "⚠️  $name has CAP_SYS_ADMIN (DANGEROUS)"
    fi
done
```

---

## 🔄 Clean Up

```bash
# Stop and remove all containers
./cleanup.sh

# Or manually
docker stop insecure-nginx secure-nginx
docker rm insecure-nginx secure-nginx

# Docker Compose cleanup
docker-compose -f docker-compose-secure.yml down
```

---

## 🎓 Key Takeaways

1. **Capabilities divide root into 38 granular privileges** - Drop ALL, add only what's needed

2. **Read-only root filesystem prevents malware installation** - Even if RCE occurs, attacker cannot persist

3. **tmpfs provides safe writable storage** - Memory-backed, cleared on restart, `noexec` prevents binary execution

4. **`no-new-privileges` blocks SUID escalation** - Prevents privilege escalation via setuid binaries

5. **Defense in depth requires multiple layers** - Capabilities + read-only FS + resource limits + monitoring

6. **CAP_SYS_ADMIN is equivalent to root** - Never grant this capability

7. **Resource limits prevent noisy neighbor problems** - CPU/memory caps protect co-located containers

8. **Security controls must be validated** - Use `compare-security.sh` and `test-security.sh` to verify

---

## 📚 Additional Resources

**Linux Capabilities:**
- [man 7 capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html) - Complete capability reference
- [Docker Capabilities Tutorial](https://docs.docker.com/engine/security/capabilities/)

**Read-Only Filesystems:**
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [NIST Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)

**Related Labs:**
- [Lab 01: Docker Bench Security](../01-docker-bench-security/) - CIS compliance auditing
- [Lab 03: Least Privilege](../03-least-privilege/) - Non-root execution, resource limits
- [Lab 09: Runtime Escape](../09-runtime-escape/) - Container escape techniques

---

## 📝 Lab Completion Checklist

After completing this lab, you should be able to:

- [ ] Explain what Linux capabilities are and why they matter
- [ ] List dangerous capabilities (CAP_SYS_ADMIN, CAP_NET_RAW)
- [ ] Drop all capabilities and add back only required ones
- [ ] Configure read-only root filesystems
- [ ] Create tmpfs volumes with `noexec` and `nosuid` flags
- [ ] Enable `no-new-privileges` security option
- [ ] Deploy production-ready containers with Docker Compose
- [ ] Validate security configurations with comparison scripts
- [ ] Audit containers for excessive capabilities

---

## 📧 Questions or Issues?

- **GitHub Issues:** https://github.com/opscart/docker-security-practical-guide/issues
- **OpsCart Guide:** https://opscart.com/docker-security-guide/docker-secure-configs/
- **Author:** Shamsher Khan - [LinkedIn](https://www.linkedin.com/in/shamsher-khan)

---

**Next Lab:** [Lab 03: Least Privilege (Non-Root, Resource Limits)](../03-least-privilege/)  
**Previous Lab:** [Lab 01: Docker Bench Security (CIS Compliance)](../01-docker-bench-security/)  
**Back to:** [Main README](../../README.md)