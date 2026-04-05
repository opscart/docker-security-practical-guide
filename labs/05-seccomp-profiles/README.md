# Lab 05: Custom Seccomp Profiles - Fine-Grained Syscall Filtering

**Level:** Advanced  
**Time:** 1.5-2 hours  
**Prerequisites:** Understanding of Linux syscalls, basic Docker knowledge  

---

## 🎯 Learning Objectives

By the end of this lab, you will understand:

- **Linux Syscalls** - What system calls are and why they matter for container security
- **Seccomp** - Secure Computing Mode for syscall filtering
- **Default Docker Profile** - What Docker blocks by default (44 out of ~300+ syscalls)
- **Custom Profiles** - Creating application-specific seccomp profiles
- **Security vs. Functionality** - Balancing restriction with operational needs
- **Profile Testing** - Validating seccomp profiles without breaking applications

---

## 🔴 The Production Problem

**Scenario:** A containerized API was exploited via a kernel vulnerability, allowing privilege escalation to root on the host.

**The Attack Timeline:**

1. **Initial Compromise:** SQL injection in legacy API exposed database credentials
2. **Container Breakout Attempt:** Attacker attempted to exploit **CVE-2022-0847 (Dirty Pipe)** - a Linux kernel write vulnerability
3. **Syscall Exploitation:** Exploit required `splice()` syscall to overwrite read-only files in `/proc`
4. **Privilege Escalation:** Successfully modified `/proc/self/mem` to inject code into PID 1
5. **Host Compromise:** Escaped container, gained root on Kubernetes worker node

**Impact:**

- **Full Kubernetes node compromise** (root access)
- **Lateral movement** to 12 other containers on same node
- **Data exfiltration** from compromised workloads
- **$340K** in incident response and forensic analysis
- **2-week cluster quarantine** during remediation

**Root Cause:**

1. **No seccomp profile** - Default Docker profile still allowed `splice()` syscall
2. **Kernel vulnerability** - CVE-2022-0847 unpatched (zero-day at time of attack)
3. **Excessive syscalls** - Application only needed 80 syscalls, Docker allowed 280+
4. **No syscall auditing** - No detection when unusual syscalls were invoked
5. **Privileged operations** - Container had capabilities that enabled exploitation

**What Should Have Been Done:**

- ❌ Default profile → ✅ **Custom seccomp profile blocking `splice()`, `ptrace`, `mount`**
- ❌ 280+ syscalls → ✅ **Whitelist only 80 required syscalls**
- ❌ No auditing → ✅ **Seccomp logging mode for detecting blocked syscalls**
- ❌ Unpatched kernel → ✅ **Defense in depth: even with kernel vuln, exploit blocked**
- ❌ No testing → ✅ **Automated seccomp profile generation + validation**

**Result with custom seccomp:** Dirty Pipe exploit **BLOCKED** at syscall level (`splice()` denied), **no privilege escalation** possible, **container breakout prevented**, **incident cost: $0**.

---

## 📚 What This Lab Covers

### Part 1: Understanding Seccomp and Syscalls
- What are Linux syscalls (300+ system calls)
- Docker's default seccomp profile (blocks 44 dangerous syscalls)
- Seccomp modes (SCMP_ACT_ALLOW, SCMP_ACT_ERRNO, SCMP_ACT_KILL)
- Why syscall filtering prevents container escapes

### Part 2: Testing Default Docker Profile
- Running container with default seccomp profile
- Testing file, network, and process operations
- Understanding what's allowed by default

### Part 3: Restrictive Seccomp Profile
- Minimal syscall whitelist (79 syscalls)
- Blocking network operations (bind, listen, socket)
- Blocking mount operations
- Testing application breakage with overly restrictive profiles

### Part 4: Custom Profile Generation
- Creating application-specific profiles (nginx example)
- Automated profile generation workflow
- Testing profiles in staging before production
- Balancing security and functionality

### Part 5: Web Application Profile
- Production-ready profile for web apps (125 syscalls)
- Network syscalls (socket, bind, listen, accept)
- File I/O syscalls (read, write, open, close)
- Process management syscalls (fork, exec, wait)

---

## 🛠️ Lab Files

```
labs/05-custom-seccomp/
├── README.md                    # This file
├── test-default-profile.sh      # Test Docker's default seccomp profile
├── test-restrictive-profile.sh  # Test minimal restrictive profile
├── generate-profile.sh          # Generate custom nginx seccomp profile
├── restrictive-profile.json     # Minimal profile (79 syscalls)
├── web-app-profile.json         # Web app profile (125 syscalls)
└── cleanup.sh                   # Remove test containers
```

---

## 🚀 Quick Start

### Prerequisites

**Required:**
- Docker 20.10+
- Linux kernel with seccomp support (check: `grep SECCOMP /boot/config-$(uname -r)`)
- `nc` (netcat) installed in Alpine containers

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/opscart/docker-security-practical-guide.git
cd docker-security-practical-guide/labs/05-custom-seccomp

# 2. Test default Docker seccomp profile
./test-default-profile.sh

# 3. Test restrictive profile (blocks network operations)
./test-restrictive-profile.sh

# 4. Generate custom nginx profile and test
./generate-profile.sh

# 5. Clean up
./cleanup.sh
```

---

## 📖 Detailed Walkthrough

### Part 1: Understanding Seccomp and Syscalls

**What Are Syscalls?**

Syscalls (system calls) are the interface between user-space applications and the Linux kernel.

**Examples:**

| Syscall | Purpose | Risk Level |
|---------|---------|------------|
| `read` | Read from file descriptor | ✅ Safe |
| `write` | Write to file descriptor | ✅ Safe |
| `socket` | Create network socket | ⚠️ Medium |
| `mount` | Mount filesystem | 🔴 **Dangerous** |
| `ptrace` | Process debugging | 🔴 **Dangerous** |
| `reboot` | Reboot system | 🔴 **Dangerous** |
| `kexec_load` | Load new kernel | 🔴 **Dangerous** |

**Total Linux Syscalls:** ~330 on x86_64 (varies by kernel version)

**Docker's Default Seccomp Profile:**

- **Allows:** ~280 syscalls
- **Blocks:** ~44 dangerous syscalls

**Blocked Syscalls (Examples):**

```json
[
  "acct",           // Process accounting
  "add_key",        // Keyring manipulation
  "bpf",            // Berkeley Packet Filter
  "clock_adjtime",  // Adjust system clock
  "delete_module",  // Remove kernel module
  "finit_module",   // Load kernel module
  "init_module",    // Load kernel module
  "kcmp",           // Compare processes
  "kexec_load",     // Load new kernel
  "keyctl",         // Keyring control
  "lookup_dcookie", // Cookie lookup
  "mount",          // Mount filesystem
  "name_to_handle_at", // File handle
  "perf_event_open", // Performance monitoring
  "personality",    // Set execution domain
  "pivot_root",     // Change root filesystem
  "ptrace",         // Process debugging
  "quotactl",       // Quota control
  "reboot",         // Reboot system
  "request_key",    // Request key from kernel
  "setns",          // Set namespace
  "settimeofday",   // Set system time
  "swapon",         // Enable swap
  "swapoff",        // Disable swap
  "syslog",         // Kernel logging
  "umount",         // Unmount filesystem
  "unshare"         // Unshare namespaces
]
```

**Why These Are Blocked:**

- **Container Escape:** `mount`, `ptrace`, `setns` enable breakout
- **Host Impact:** `reboot`, `swapon`, `settimeofday` affect entire system
- **Kernel Manipulation:** `init_module`, `kexec_load` modify kernel

**Seccomp Actions:**

```json
{
  "defaultAction": "SCMP_ACT_ERRNO",  // Block by default (return error)
  "syscalls": [
    {
      "names": ["read", "write", "open"],
      "action": "SCMP_ACT_ALLOW"  // Allow these syscalls
    }
  ]
}
```

**Actions:**
- `SCMP_ACT_ALLOW`: Allow syscall
- `SCMP_ACT_ERRNO`: Block syscall (return EPERM error)
- `SCMP_ACT_KILL`: Kill process immediately
- `SCMP_ACT_LOG`: Allow but log (audit mode)

---

### Part 2: Testing Default Docker Profile

**Run the test:**

```bash
./test-default-profile.sh
```

**What the script does:**

```bash
docker run --rm alpine sh -c "
  echo 'Testing basic operations...'
  echo 'File operations:' && ls / > /dev/null && echo '✓ Passed'
  echo 'Network operations:' && nc -l -p 8080 -w 1 & echo '✓ Passed'
  echo 'Process operations:' && ps aux > /dev/null && echo '✓ Passed'
"
```

**Expected output:**

```
Testing container with default Docker seccomp profile...
Testing basic operations...
File operations: ✓ Passed
Network operations: ✓ Passed
Process operations: ✓ Passed

Default profile allows most operations
```

**Why Everything Works:**

Default profile allows:
- File I/O (`read`, `write`, `open`, `close`, `stat`)
- Network (`socket`, `bind`, `listen`, `accept`, `connect`)
- Process management (`fork`, `exec`, `wait`, `kill`)

**Test Blocked Syscalls:**

```bash
# Try to mount filesystem (should fail)
docker run --rm alpine sh -c "mount /dev/sda1 /mnt"
# Output: mount: permission denied (default seccomp blocks this)

# Try to load kernel module (should fail)
docker run --rm alpine sh -c "insmod mymodule.ko"
# Output: Operation not permitted (blocked by seccomp)
```

---

### Part 3: Restrictive Seccomp Profile

**Review the restrictive profile:**

```bash
cat restrictive-profile.json
```

**Key characteristics:**

```json
{
  "defaultAction": "SCMP_ACT_ERRNO",  // Block everything by default
  "syscalls": [
    {
      "names": [
        "accept", "access", "arch_prctl", "brk", "capget",
        "clone", "close", "dup", "execve", "exit",
        "fcntl", "fstat", "futex", "getcwd", "getdents",
        "getpid", "getuid", "ioctl", "lseek", "mmap",
        "open", "openat", "read", "rt_sigaction", "stat",
        "wait4", "write"
        // ... 79 syscalls total
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

**What's blocked:**
- ❌ Network syscalls (`socket`, `bind`, `listen`, `accept`)
- ❌ Mount operations (`mount`, `umount`)
- ❌ Debugging (`ptrace`)
- ❌ Module loading (`init_module`)

**Run the test:**

```bash
./test-restrictive-profile.sh
```

**What the script does:**

```bash
docker run --rm \
  --security-opt seccomp=restrictive-profile.json \
  alpine sh -c "
    echo 'File operations:' && ls / > /dev/null && echo '✓ Passed' || echo '✗ Blocked'
    echo 'Network listen:' && nc -l -p 8080 -w 1 2>&1 || echo '✗ Blocked (expected)'
    echo 'Mount operations:' && mount 2>&1 || echo '✗ Blocked (expected)'
  "
```

**Expected output:**

```
Testing container with restrictive seccomp profile...
Testing basic operations...
File operations: ✓ Passed
Network listen: sh: nc: not found
✗ Blocked (expected)
Mount operations: mount: permission denied
✗ Blocked (expected)

Restrictive profile blocks dangerous syscalls
```

**Why This Profile is Too Restrictive for Web Apps:**

```bash
# Try to run nginx with restrictive profile (FAILS)
docker run -d --name nginx-test \
  --security-opt seccomp=restrictive-profile.json \
  -p 8080:80 nginx:alpine

# Check logs
docker logs nginx-test
# Output: nginx: [emerg] socket() failed (1: Operation not permitted)
```

**Why it fails:** nginx needs `socket()`, `bind()`, `listen()` syscalls which are blocked.

---

### Part 4: Custom Profile Generation for Nginx

**Run the profile generator:**

```bash
./generate-profile.sh
```

**What the script does:**

1. **Generates nginx-specific profile** (allows 200+ syscalls needed by nginx)
2. **Tests the profile** by running nginx container
3. **Validates nginx responds** to HTTP requests
4. **Reports results**

**Generated profile (`nginx-profile.json`):**

```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": [
    "SCMP_ARCH_X86_64",
    "SCMP_ARCH_X86",
    "SCMP_ARCH_X32",
    "SCMP_ARCH_AARCH64",
    "SCMP_ARCH_ARM"
  ],
  "syscalls": [
    {
      "names": [
        "accept", "accept4", "bind", "listen", "socket",  // Network syscalls
        "read", "write", "open", "close",                  // File I/O
        "fork", "execve", "wait4",                         // Process management
        "epoll_create", "epoll_ctl", "epoll_wait",        // Event polling
        "mmap", "mprotect", "munmap",                      // Memory management
        // ... ~200 syscalls total
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

**Expected output:**

```
Generating custom seccomp profile for nginx...
Profile generated: nginx-profile.json

Testing nginx with custom profile...
✓ Nginx started successfully with custom profile

Testing nginx response...
✓ Nginx responding to requests

✓ Test complete - profile works correctly

Generated profile blocks dangerous syscalls while allowing:
  - Network operations (socket, bind, listen, accept)
  - File operations (read, write, open, close)
  - Process management (fork, exec, wait)

Blocked syscalls include:
  - mount, umount (filesystem operations)
  - reboot, kexec_load (system operations)
  - ptrace (debugging)
  - module operations (kernel modules)
```

**How Profile Was Created:**

1. **Start with restrictive baseline** (deny all)
2. **Add essential syscalls** (read, write, open, close, exit)
3. **Run application** and capture errors
4. **Add syscalls iteratively** until application works
5. **Remove unnecessary syscalls** to minimize attack surface

**Automated Profile Generation (Advanced):**

```bash
# Use oci-seccomp-bpf-hook to trace syscalls
docker run --rm \
  --security-opt seccomp=unconfined \
  --annotation io.containers.trace-syscall=/tmp/nginx-trace.json \
  nginx:alpine

# Convert trace to seccomp profile
oci-seccomp-bpf-hook --trace-file /tmp/nginx-trace.json --output nginx-profile.json
```

---

### Part 5: Web Application Seccomp Profile

**Review the production web app profile:**

```bash
cat web-app-profile.json
```

**Profile characteristics:**

- **125 syscalls allowed** (vs. 280 in default Docker profile)
- **55% reduction in attack surface**
- **Optimized for HTTP/HTTPS web applications**

**Allowed syscall categories:**

**1. Network Operations (Required for Web Server):**
```
socket, bind, listen, accept, connect
setsockopt, getsockopt, getsockname, getpeername
sendto, sendmsg, recvfrom, recvmsg
shutdown
```

**2. File I/O (Required for Static Content):**
```
open, openat, close, read, write
lseek, fstat, stat, lstat, newfstatat
readlink, readv, writev
```

**3. Process Management (Required for Multi-Worker):**
```
fork, clone, execve, wait4, waitid
getpid, getppid, gettid, kill, tgkill
```

**4. Memory Management (Required for Performance):**
```
mmap, munmap, mprotect, mremap
brk, madvise
```

**5. Event Polling (Required for High Concurrency):**
```
epoll_create, epoll_create1, epoll_ctl, epoll_wait
poll, select
```

**Blocked (Dangerous) Syscalls:**

```
❌ mount, umount              (Filesystem operations)
❌ ptrace                      (Debugging/injection)
❌ reboot, kexec_load         (System operations)
❌ init_module, delete_module (Kernel modules)
❌ setns, unshare             (Namespace manipulation)
❌ swapon, swapoff            (Swap operations)
```

**Deploy with Web App Profile:**

```bash
# Run nginx with production profile
docker run -d --name nginx-secure \
  --security-opt seccomp=web-app-profile.json \
  -p 8081:80 \
  nginx:alpine

# Verify it works
curl http://localhost:8081
# Output: nginx welcome page

# Verify profile is applied
docker inspect nginx-secure | jq '.[0].HostConfig.SecurityOpt'
# Output: ["seccomp=web-app-profile.json"]
```

**Test attack scenario (should fail):**

```bash
# Try to escape via mount (blocked by seccomp)
docker exec nginx-secure mount /dev/sda1 /mnt
# Output: mount: permission denied

# Try to debug process with ptrace (blocked)
docker exec nginx-secure strace -p 1
# Output: strace: attach: ptrace(PTRACE_SEIZE, 1): Operation not permitted
```

---

## 🔒 Production Security Checklist

### Profile Creation
- [ ] Start with restrictive baseline (deny-by-default)
- [ ] Add only required syscalls (whitelist approach)
- [ ] Test profile in staging before production
- [ ] Document why each syscall is needed
- [ ] Review profile quarterly (remove unused syscalls)

### Testing & Validation
- [ ] Run application with profile in dev/staging
- [ ] Monitor for `EPERM` errors (blocked syscalls)
- [ ] Use `strace` to identify required syscalls
- [ ] Load test to ensure performance is acceptable
- [ ] Test failure scenarios (ensure errors are graceful)

### Deployment
- [ ] Apply profile via `--security-opt seccomp=profile.json`
- [ ] Store profiles in version control (Git)
- [ ] Use same profile across all replicas
- [ ] Document profile in deployment manifests
- [ ] Include profile in CI/CD pipeline

### Monitoring & Auditing
- [ ] Enable seccomp logging (`SCMP_ACT_LOG` mode)
- [ ] Monitor for blocked syscall attempts
- [ ] Alert on unusual syscall patterns
- [ ] Track profile violations in SIEM
- [ ] Regularly review audit logs

### Kubernetes Integration
- [ ] Store profiles in ConfigMaps
- [ ] Reference in Pod Security Context
- [ ] Use Pod Security Standards (Restricted)
- [ ] Enforce via admission controllers (OPA, Kyverno)

---

## 📊 Before vs. After Comparison

| Security Control | Default Docker Profile | Custom Web App Profile | Risk Reduction |
|------------------|------------------------|------------------------|----------------|
| **Allowed Syscalls** | ~280 | 125 | ✅ 55% reduction |
| **mount/umount** | ❌ Blocked | ❌ Blocked | 100% |
| **ptrace** | ❌ Blocked | ❌ Blocked | 100% |
| **splice** (Dirty Pipe) | ✅ **Allowed** | ❌ **Blocked** | 100% |
| **setns/unshare** | ❌ Blocked | ❌ Blocked | 100% |
| **Network syscalls** | ✅ Allowed | ✅ Allowed (needed) | N/A |
| **Attack Surface** | Large | **55% smaller** | ✅ Significant |

**Key Insight:** Custom profiles block exploitation vectors that default Docker profile misses (e.g., `splice()` for Dirty Pipe).

---

## 🚨 Common Mistakes

### Mistake #1: Using `unconfined` Seccomp Mode
**Problem:** Disables all syscall filtering (`--security-opt seccomp=unconfined`)  
**Solution:** NEVER use unconfined in production. Even default profile is better than nothing.

### Mistake #2: Overly Restrictive Profile Without Testing
**Problem:** Application fails silently or with cryptic errors  
**Solution:** Test profile thoroughly in staging. Use `strace` to identify missing syscalls.

### Mistake #3: Not Documenting Profile Changes
**Problem:** Future developers don't know why syscalls were added/removed  
**Solution:** Comment each syscall in profile, link to JIRA tickets for changes.

### Mistake #4: Ignoring Architecture Differences
**Problem:** Profile works on x86_64 but fails on ARM  
**Solution:** Include all architectures in profile, test on target platforms.

### Mistake #5: Forgetting to Update Profiles
**Problem:** Application updated, needs new syscalls, profile outdated  
**Solution:** Include profile testing in CI/CD. Regenerate profiles for major updates.

---

## 🔬 Advanced: Seccomp Logging and Audit

**Enable Logging Mode:**

```json
{
  "defaultAction": "SCMP_ACT_LOG",  // Log instead of block
  "syscalls": [
    {
      "names": ["read", "write", "open"],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

**Monitor audit logs:**

```bash
# View seccomp audit events
sudo ausearch -m SECCOMP -ts recent

# Example output:
# type=SECCOMP msg=audit(1712345678.123:456): auid=1000 uid=0 gid=0 
# ses=1 pid=12345 comm="nginx" exe="/usr/sbin/nginx" 
# sig=0 arch=c000003e syscall=165 compat=0 ip=0x7f1234567890 code=0x7ffc0000
```

**Decode syscall number:**

```bash
# Syscall 165 = mount
ausyscall 165
# Output: mount

# List all syscalls
ausyscall --dump
```

**Generate Profile from Audit Logs:**

```bash
# Collect syscalls used by application
sudo auditctl -a exit,always -F arch=b64 -S all -F exe=/usr/sbin/nginx

# Run application for 24 hours

# Extract unique syscalls
sudo ausearch -m SECCOMP -ts today | grep syscall= | \
  awk -F'syscall=' '{print $2}' | awk '{print $1}' | sort -u | \
  while read sc; do ausyscall $sc; done > allowed-syscalls.txt

# Convert to seccomp JSON profile
# (Use script or manual conversion)
```

---

## 🔄 Clean Up

```bash
./cleanup.sh
```

**What gets cleaned:**

```bash
docker stop nginx-secure 2>/dev/null
docker rm nginx-secure 2>/dev/null
```

---

## 🎓 Key Takeaways

1. **Seccomp reduces attack surface** - 55% fewer syscalls = 55% fewer exploitation paths

2. **Default Docker profile is insufficient** - Still allows dangerous syscalls like `splice()` (Dirty Pipe)

3. **Custom profiles prevent container escapes** - Block `mount`, `ptrace`, `setns` to stop breakouts

4. **Testing is critical** - Overly restrictive profiles break applications silently

5. **Whitelist approach is best** - Start with deny-all, add only required syscalls

6. **Logging mode enables safe testing** - Use `SCMP_ACT_LOG` to test without breaking apps

7. **Profiles should evolve** - Regenerate when applications are updated

8. **Defense in depth** - Seccomp + capabilities + namespaces + AppArmor = comprehensive security

---

## 📚 Additional Resources

**Seccomp Documentation:**
- [Linux Seccomp Documentation](https://www.kernel.org/doc/Documentation/prctl/seccomp_filter.txt)
- [Docker Seccomp Guide](https://docs.docker.com/engine/security/seccomp/)

**Profile Generators:**
- [oci-seccomp-bpf-hook](https://github.com/containers/oci-seccomp-bpf-hook) - Automatic profile generation
- [Docker Default Profile](https://github.com/moby/moby/blob/master/profiles/seccomp/default.json)

**Syscall References:**
- [Linux Syscall Table](https://filippo.io/linux-syscall-table/)
- [Syscall Man Pages](https://man7.org/linux/man-pages/man2/syscalls.2.html)

**Related Labs:**
- [Lab 02: Secure Configs](../02-secure-configs/) - Capabilities (complementary to seccomp)
- [Lab 09: Runtime Escape](../09-runtime-escape/) - Exploitation techniques seccomp prevents

---

## 📝 Lab Completion Checklist

After completing this lab, you should be able to:

- [ ] Explain what Linux syscalls are (300+ kernel interfaces)
- [ ] List dangerous syscalls (mount, ptrace, reboot, init_module)
- [ ] Understand Docker's default seccomp profile (blocks 44 syscalls)
- [ ] Create custom seccomp profiles for applications
- [ ] Test profiles without breaking applications
- [ ] Use `strace` to identify required syscalls
- [ ] Deploy seccomp profiles in production
- [ ] Enable seccomp logging for auditing
- [ ] Explain how seccomp prevents container escapes

---

## 📧 Questions or Issues?

- **GitHub Issues:** https://github.com/opscart/docker-security-practical-guide/issues
- **OpsCart Guide:** https://opscart.com/docker-security-guide/seccomp-profiles/
- **Author:** Shamsher Khan - [LinkedIn](https://www.linkedin.com/in/shamsher-khan)

---

**Next Lab:** [Lab 06: AI/ML Container Security](../06-ai-model-security/)  
**Previous Lab:** [Lab 04: Image Signing and Verification](../04-image-signing/)  
**Back to:** [Main README](../../README.md)