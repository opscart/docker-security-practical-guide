# Lab 09: Docker Runtime Escape — Container to Host Root

**Level:** Advanced (Red Team)  
**Time:** 2-2.5 hours  
**Prerequisites:** Basic Docker knowledge

⚠️ **Note:** This is internal lab documentation. When referencing this content externally (articles, presentations), refer to it as "Docker Runtime Escape" or "Container Breakout Lab" without numbering.

## 🎯 Learning Objectives

By the end of this lab, you will:

- Understand 5 real container escape techniques used by attackers
- Execute controlled escapes in a safe environment
- Recognize attack indicators and system artifacts
- Understand why certain Docker configurations are dangerous
- Implement detection and defense for each attack vector

## ⚠️ CRITICAL SAFETY WARNING

**This lab demonstrates real attack techniques. Use ONLY in isolated test environments.**

- ✅ Run on local Docker Desktop
- ✅ Use dedicated test VM
- ✅ Ensure no production data accessible
- ❌ NEVER run on production systems
- ❌ NEVER run on shared infrastructure
- ❌ NEVER run on corporate networks without approval

**Legal Notice:** These techniques are for educational purposes only. Unauthorized use against systems you don't own is illegal.

## 📋 Scope of This Lab

This lab contains 5 runtime escape scenarios, each demonstrating a different attack vector. Each scenario is designed to be fully standalone and independently reproducible, mapped to a specific real-world misconfiguration.

⚠️ **You do NOT need to run all scenarios.**  
Each article or learning session focuses on a **single scenario**. The multiple scenarios exist to show the breadth of container escape techniques, but you can master them one at a time.

## 🛠️ Prerequisites

### System Requirements

- Docker Engine 20.10+ or Docker Desktop
- Linux, macOS, or Windows with WSL2
- At least 4GB free RAM
- 10GB free disk space

### Knowledge Requirements

- Basic Docker commands (docker run, exec, ps)
- Linux command line familiarity
- Understanding of Labs 01-08 concepts
- Basic networking knowledge

### Tools Required

All tools are installed inside containers during exercises:
- Docker CLI (inside containers)
- curl, wget
- Basic Linux utilities (mount, nsenter, etc.)

## 📁 Lab Structure

```
labs/09-runtime-escape/
├── README.md                              # This file
├── setup.sh                               # Initial setup (pulls images)
├── cleanup.sh                             # Remove all traces
│
├── scenario-1-docker-socket/              # Scenario 1: Socket escape
│   ├── README.md
│   ├── docker-compose.yml                 # Vulnerable setup
│   ├── exploit.sh                         # Automated exploit
│   ├── cleanup.sh
│   └── manual-steps.md                    # Step-by-step walkthrough
│
├── scenario-2-privileged/                 # Scenario 2: --privileged escape
│   ├── README.md
│   ├── demo.sh                            # Attack demonstrations (5 demos)
│   ├── defense.sh                         # Generates defenses + artifacts
│   ├── cleanup.sh                         # Removes demo containers
│   ├── validate.sh                        # Verifies defenses in place
│   └── artifacts/
│       └── audit-privileged.sh            # Scans for privileged containers
│
├── scenario-3-sys-admin/                  # Scenario 3: CAP_SYS_ADMIN abuse
│   ├── README.md
│   ├── demo.sh                            # Attack demonstrations
│   ├── defense.sh                         # Generates defenses + artifacts
│   ├── cleanup.sh
│   ├── validate.sh
│   └── artifacts/
│       ├── audit-sys-admin.sh             # Scans for SYS_ADMIN containers
│       └── falco-docker-sys-admin-rules.yaml
│
├── scenario-4-host-mount/                 # Scenario 4: Host path mounts
│   ├── README.md
│   ├── demo.sh                            # Attack demonstrations (3 demos)
│   ├── defense.sh                         # Generates defenses + artifacts
│   ├── cleanup.sh
│   ├── validate.sh
│   └── artifacts/
│       ├── audit-host-mounts.sh           # Risk-classifies bind mounts
│       ├── falco-host-mount-rules.yaml    # 4 Falco detection rules
│       └── kyverno-block-host-mounts.yaml # Admission policy
│
├── scenario-5-proc-sys/                   # Scenario 5: /proc and /sys exposure
│   ├── README.md
│   ├── demo.sh                            # Attack demonstrations (4 demos)
│   ├── defense.sh                         # Generates defenses + artifacts
│   ├── cleanup.sh
│   ├── validate.sh
│   └── artifacts/
│       ├── audit-proc-sys-mounts.sh       # Classifies /proc /sys mounts
│       ├── falco-proc-sys-rules.yaml      # 4 Falco detection rules
│       └── kyverno-block-proc-sys.yaml    # Admission policy
│
└── artifacts/
    └── README.md                          # Artifact documentation
```

## 🚀 Quick Start

### 1. Clone and Navigate

```bash
cd docker-security-practical-guide/labs/09-runtime-escape
```

### 2. Run Setup

```bash
chmod +x setup.sh
./setup.sh
```

This pulls the required base images (ubuntu:22.04, alpine) and sets script permissions across all scenarios.

### 3. Run a Scenario

**Scenario 1 (Socket Escape) — automated exploit:**
```bash
cd scenario-1-docker-socket
./exploit.sh
```

**Scenarios 2–5 — standard flow for each:**
```bash
cd scenario-N-name
./demo.sh        # Watch the attack
./defense.sh     # Generate detections and policies
./validate.sh    # Confirm defenses work
./cleanup.sh     # Remove everything
```

### 4. Full Cleanup

```bash
cd ../..
./cleanup.sh
```

## 📚 Scenario Overview

### Scenario 1: Docker Socket Escape

**Attack complexity:** Medium  
**Detection difficulty:** Medium  
**Impact:** Critical — full host root access

**The Attack:**
```
Container with docker.sock mounted
  → Install docker CLI inside container
  → Use socket to create new privileged container
  → Mount host / into new container
  → chroot into host filesystem
  → Root on the host
```

**Why It Works:** The Docker socket is the API to the daemon. The daemon runs as root. Any container with socket access can create containers — including ones that mount the entire host filesystem.

**Real-World Prevalence:** Jenkins CI/CD pipelines, Portainer, Docker-in-Docker (DinD), Watchtower — all commonly mount docker.sock.

**Files:** `exploit.sh` (automated), `manual-steps.md` (step-by-step walkthrough)

---

### Scenario 2: Privileged Container Escape

**Attack complexity:** Low  
**Detection difficulty:** Low  
**Impact:** Critical — full host access, all capabilities enabled

**The Attack (5 demonstrations):**
1. Capability comparison — privileged vs normal container shows all 41 caps enabled
2. Host filesystem access — mount host block device directly inside container
3. Network namespace escape — `nsenter` into host network namespace
4. Cgroup release_agent — Felix Wilhelm technique: write a cgroup release_agent that executes on the host when the cgroup empties
5. Detection — audit scan identifies privileged containers

**Why It Works:** `--privileged` disables every security boundary: namespaces, seccomp, capability restrictions, device access. It is the nuclear option.

**Real-World Prevalence:** Legacy apps needing hardware access, DinD implementations, network packet capture tools.

**Files:** `demo.sh` → `defense.sh` → `validate.sh` → `cleanup.sh`

---

### Scenario 3: CAP_SYS_ADMIN Abuse

**Attack complexity:** Medium  
**Detection difficulty:** Medium-High  
**Impact:** Critical — nearly identical to privileged

**The Attack:**
```
Container with --cap-add=SYS_ADMIN
  → mount host block device (SYS_ADMIN allows mount syscall)
  → Access host filesystem via mounted device
  → Read /etc/shadow, SSH keys, any host file
```

**Why It Works:** CAP_SYS_ADMIN is a single capability that enables 30+ system operations including mount, namespace manipulation, and BPF. Security audits check `Privileged: true` but miss `CapAdd: [SYS_ADMIN]` — the container passes the audit while having nearly the same attack surface.

**Real-World Prevalence:** FUSE filesystem mounts (s3fs), VPN containers, monitoring agents — all commonly request SYS_ADMIN.

**Files:** `demo.sh` → `defense.sh` → `validate.sh` → `cleanup.sh`

---

### Scenario 4: Host Path Mount Abuse

**Attack complexity:** Low  
**Detection difficulty:** Medium  
**Impact:** High — credential theft, persistence, socket escalation chain

**The Attack (3 demonstrations):**
1. `/etc` bind mount — read `/etc/shadow`, `/etc/passwd`, SSH keys, SSL certificates directly
2. docker.sock escalation chain — Container A mounts the socket → installs Docker CLI → creates Container B with `/etc` mounted → reads shadow file. Two containers cooperating to escalate privileges.
3. Audit demonstration — automated scan classifies all bind mounts by risk level (CRITICAL for docker.sock, HIGH for /etc, MEDIUM for system paths)

**Why It Works:** Bind mounts give direct access to host paths with no isolation. `-v /etc:/host-etc` inside a container maps the live host `/etc` — reads see real credentials, writes modify the real filesystem.

**Real-World Prevalence:** Config file injection, log collection, persistent storage — developers routinely bind-mount paths without understanding which ones are dangerous.

**Files:** `demo.sh` → `defense.sh` → `validate.sh` → `cleanup.sh`

---

### Scenario 5: /proc and /sys Exposure

**Attack complexity:** Low  
**Detection difficulty:** Medium  
**Impact:** Medium — reconnaissance enables targeted follow-up attacks

**The Attack (4 demonstrations):**
1. `/proc` mount reconnaissance — kernel version (CVE targeting), network routing table (lateral movement planning), full process list (service discovery), memory/CPU profiling
2. `/sys` mount reconnaissance — block device topology, all network interfaces and MAC addresses, hardware/DMI data (cloud provider identification)
3. Normal vs mounted comparison — normal container sees 1–2 processes; mounted `/proc` exposes every process on the host (788 in test run)
4. Detection — automated scan identifies `/proc` and `/sys` mounts across all containers

**Why It Works:** `/proc` and `/sys` are read-only information sources, not direct exploits. The attack is reconnaissance: kernel version → look up CVEs, network data → plan lateral movement, process list → find exploitable services. `:ro` mounts prevent writes but do nothing to stop information disclosure.

**Docker Desktop note:** On macOS, `/proc` reflects the Linux VM that Docker Desktop runs, not the macOS host. The data is real but belongs to the VM. On Linux hosts, `/proc` exposes actual host data.

**Files:** `demo.sh` → `defense.sh` → `validate.sh` → `cleanup.sh`

## 🎓 Learning Path

### Recommended Order

1. **Scenario 1 (Docker Socket)** — Most common in production, clearest attack chain
2. **Scenario 2 (Privileged)** — Introduces namespace and capability concepts
3. **Scenario 3 (CAP_SYS_ADMIN)** — Shows why capability audits matter
4. **Scenario 4 (Host Mounts)** — Covers the escalation chain pattern
5. **Scenario 5 (/proc and /sys)** — Reconnaissance and information disclosure

### For Different Learners

**Developer:** Focus on understanding WHY these are dangerous and what NOT to do in production. Pay attention to the CI/CD implications in Scenarios 1 and 2.

**Security Engineer:** Run `defense.sh` in each scenario — it generates Falco rules, Kyverno admission policies, and audit scripts. These are production-ready detection artifacts.

**DevOps Engineer:** Run `validate.sh` after each `defense.sh`. The validation checks confirm that defenses actually work, which is the same verification pattern you'd use in a hardening audit.

## 🔍 Key Concepts

### Why Docker Socket is Dangerous

```
Container → Docker Socket → Docker Daemon (root) → Create Privileged Container → Host Access
```

The socket is the API to the daemon. The daemon runs as root. Socket access = ability to create any container, including ones that mount the host filesystem.

### Why --privileged is Dangerous

| Boundary | Normal Container | Privileged Container |
|----------|-----------------|---------------------|
| Namespaces | Isolated | Can break out |
| Cgroups | Limited | No limits |
| Capabilities | 14 of 38 | All 38 |
| Devices | Limited | Full /dev access |
| Seccomp | Syscall filtering | No filtering |

### Capability Breakdown

| Capability | Allows | Escape Risk |
|------------|--------|-------------|
| CAP_SYS_ADMIN | Mount, namespace manipulation | CRITICAL |
| CAP_SYS_PTRACE | Process tracing, memory access | HIGH |
| CAP_SYS_MODULE | Load kernel modules | CRITICAL |
| CAP_DAC_OVERRIDE | Bypass file permissions | MEDIUM |
| CAP_NET_ADMIN | Network configuration | MEDIUM |

### The Audit Gap

Most security scanners check:
```bash
docker inspect container | jq '.HostConfig.Privileged'   # true/false
```

They miss:
```bash
docker inspect container | jq '.HostConfig.CapAdd'       # ["SYS_ADMIN"]
docker inspect container | jq '.Mounts[] | select(.Source=="/etc")'
docker inspect container | jq '.Mounts[] | select(.Source=="/proc")'
```

This is the core thesis of the lab: blocking `--privileged` and `docker.sock` is necessary but not sufficient. The four blind spots (privileged bypass via capabilities, host mounts, socket-based escalation chains, and /proc reconnaissance) are what attackers use after the obvious vectors are locked down.

## 🛡️ Defense Artifacts

Each scenario (2–5) generates a consistent defense set when you run `defense.sh`:

| Artifact | Purpose | Scenarios |
|----------|---------|-----------|
| `audit-*.sh` | Scans running containers, classifies risk | 2, 3, 4, 5 |
| `falco-*-rules.yaml` | Runtime detection rules for Falco | 3, 4, 5 |
| `kyverno-block-*.yaml` | Kubernetes admission policy | 4, 5 |

### Deploying Falco Rules

```bash
kubectl create cm falco-rules-SCENARIO \
  --from-file=rules.yaml=artifacts/falco-SCENARIO-rules.yaml -n falco
kubectl rollout restart daemonset/falco -n falco
```

### Deploying Kyverno Policies

```bash
kubectl apply -f artifacts/kyverno-block-SCENARIO.yaml
```

## 🔗 Integration with Other Labs

**Uses knowledge from:** Labs 01–03 (capabilities, read-only filesystems, least privilege), Lab 05 (network isolation)

**Prepares you for:** Runtime detection engineering, secret theft analysis, container hardening policy

## 📖 Additional Resources

- [Docker Security Documentation](https://docs.docker.com/engine/security/)
- [Linux Capabilities Man Page](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Trail of Bits — Understanding Docker Container Escapes](https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/)
- [Felix Wilhelm's cgroup Escape](https://blog.dragonsector.pl/2019/02/cve-2019-5736-escape-from-docker-and.html)
- [NCC Group — Abusing Privileged and Unprivileged Linux Containers](https://www.nccgroup.com/us/research-blog/abusing-privileged-and-unprivileged-linux-containers/)
- [CDK — Container Penetration Toolkit](https://github.com/cdk-team/CDK)
- [deepce — Docker Enumeration](https://github.com/stealthcopter/deepce)

## 📝 Platform Notes

✅ **Works on:** Docker Desktop (Mac/Windows), Linux with Docker Engine, WSL2

⚠️ **Docker Desktop differences:**
- Block devices (`/dev/sd*`, `/dev/vd*`) are not exposed — Scenarios 2 and 3 block device demos show this transparently
- `nsenter` to host namespaces is blocked — demos detect this and fall back gracefully
- `/proc` reflects the Linux VM, not the macOS host — Scenario 5 documents this explicitly
- cgroup v2 (default on modern systems) restricts the release_agent technique — Scenario 2 handles both v1 and v2

## ✅ Completion Checklist

- [ ] Scenario 1: Docker Socket Escape — `exploit.sh` completed
- [ ] Scenario 2: Privileged — `demo.sh` → `defense.sh` → `validate.sh` (6/6 passed)
- [ ] Scenario 3: CAP_SYS_ADMIN — `demo.sh` → `defense.sh` → `validate.sh` (all passed)
- [ ] Scenario 4: Host Mounts — `demo.sh` → `defense.sh` → `validate.sh` (6/6 passed)
- [ ] Scenario 5: /proc and /sys — `demo.sh` → `defense.sh` → `validate.sh` (6/6 passed)
- [ ] Cleanup: `./cleanup.sh` from lab root

## 🎯 What's Next?

After completing this lab:

1. Learn to detect these attacks in real-time using Falco and runtime security tools
2. Understand how these escape techniques enable secret theft
3. Implement hardening configurations to prevent these attacks

---

**🔒 Remember: With great power comes great responsibility. Use this knowledge ethically.**

**🔒 Security is not about if you'll be attacked, but when. Understand the attack to defend against it.**