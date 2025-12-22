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
- Generate forensic evidence for runtime detection

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

This lab contains multiple runtime escape scenarios, each demonstrating a different attack vector. 

**Important:** Each scenario is designed to be:
- ✅ Fully standalone
- ✅ Independently reproducible  
- ✅ Mapped to a specific real-world misconfiguration

⚠️ **You do NOT need to run all scenarios.**  
Each article or learning session focuses on a **single scenario**. The multiple scenarios exist to show the breadth of container escape techniques, but you can master them one at a time.

### Available Scenarios

This lab includes scenarios covering different escape techniques. **Start with Scenario 1** (Docker Socket Escape) - it's the most common and impactful attack in production environments.

Additional scenarios are available for advanced learning and will be covered in future articles.

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

All tools will be installed inside containers during exercises:
- Docker CLI (inside containers)
- curl, wget
- Basic Linux utilities (mount, nsenter, etc.)

## 📁 Lab Structure

```
labs/09-runtime-escape/
├── README.md                          # This file
├── setup.sh                           # Initial setup
├── cleanup.sh                         # Remove all traces
│
├── scenario-1-docker-socket/
│   ├── README.md                      # Detailed walkthrough
│   ├── docker-compose.yml             # Vulnerable setup
│   ├── exploit.sh                     # Automated exploit
│   └── manual-steps.md                # Step-by-step guide
│
├── scenario-2-privileged/
│   ├── README.md
│   ├── docker-compose.yml
│   ├── exploit.sh
│   └── manual-steps.md
│
├── scenario-3-sys-admin/
│   ├── README.md
│   ├── docker-compose.yml
│   ├── exploit.sh
│   └── manual-steps.md
│
├── scenario-4-host-mount/
│   ├── README.md
│   ├── docker-compose.yml
│   ├── exploit.sh
│   └── manual-steps.md
│
├── scenario-5-proc-sys/
│   ├── README.md
│   ├── docker-compose.yml
│   ├── exploit.sh
│   └── manual-steps.md
│
└── artifacts/
    ├── collect-all-iocs.sh            # Gather all forensic data
    ├── generate-timeline.sh           # Create attack timeline
    └── README.md                      # Artifact documentation
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

### 3. Choose Your Path

**Option A: Automated Exploits (Quick)**
```bash
cd scenario-1-docker-socket
./exploit.sh
```

**Option B: Manual Step-by-Step (Learning)**
```bash
cd scenario-1-docker-socket
cat manual-steps.md
# Follow instructions
```

### 4. Clean Up After Each Scenario

```bash
cd scenario-1-docker-socket
docker-compose down -v
```

### 5. Full Cleanup at End

```bash
cd ../..
./cleanup.sh
```

## 📚 Scenario Overview

### Scenario 1: Docker Socket Escape (THE BIG ONE)

**The Attack:**
```
Container with docker.sock → Install docker CLI → Create privileged container → Mount host / → chroot → Host root access
```

**Why It Works:**
- Docker socket = API to Docker daemon
- Docker daemon runs as root
- Any container can create containers if it has socket access
- New container can mount host filesystem

**Real-World Examples:**
- Jenkins CI/CD with docker.sock for builds
- Portainer (container management UI)
- Docker-in-Docker (DinD) patterns
- Watchtower (automatic container updates)

**Preview:**
```bash
# Start vulnerable container
docker run -d --name victim \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ubuntu:22.04 sleep infinity

# Execute escape
docker exec victim sh -c "
  apt-get update && apt-get install -y docker.io
  docker run -it --rm --privileged --pid=host --net=host \
    -v /:/host ubuntu:22.04 chroot /host bash
"
# You are now root on the host machine
```

---

### Scenario 2: Privileged Container Escape

**The Attack:**
```
--privileged container → nsenter to host namespaces → Host access
```

**Why It Works:**
- `--privileged` removes ALL security restrictions
- Full access to /dev devices
- Can manipulate namespaces
- All capabilities enabled

**Real-World Examples:**
- Legacy applications requiring hardware access
- Docker-in-Docker implementations
- System monitoring tools
- Network packet capture tools

---

### Scenario 3: CAP_SYS_ADMIN Abuse

**The Attack:**
```
CAP_SYS_ADMIN capability → Mount host disk → Access host filesystem
```

**Why It Works:**
- SYS_ADMIN allows mount operations
- Can create device nodes
- Can mount any filesystem

---

### Scenario 4: Host Path Mount Abuse

**The Attack:**
```
Mounted /etc or /root → Modify host files → Add backdoor user
```

**Why It Works:**
- Direct write access to host filesystem
- Can modify critical system files
- Can install persistence mechanisms

---

### Scenario 5: /proc and /sys Manipulation

**The Attack:**
```
Mounted /proc → Read host secrets → Modify kernel parameters
```

**Why It Works:**
- /proc exposes running processes
- Process memory and environment visible
- Can modify kernel settings

## 🎓 Learning Path

### Recommended Order

1. **Start with Scenario 1 (Docker Socket)**
   - Most common in real world
   - Most dangerous
   - Easiest to understand

2. **Then Scenario 2 (Privileged)**
   - Shows why --privileged is dangerous
   - Introduces namespace concepts

3. **Then Scenarios 3-5**
   - Build on previous knowledge
   - Show additional attack vectors

### For Different Learners

**If you're a Developer:**
- Focus on understanding WHY these are dangerous
- Learn what NOT to do in production
- Understand CI/CD security implications

**If you're a Security Engineer:**
- Document all IOCs (Indicators of Compromise)
- Practice detection signatures
- Build runtime detection rules

**If you're a DevOps Engineer:**
- Understand operational security risks
- Learn container hardening techniques
- Audit existing infrastructure

## 📊 Expected Outcomes

### Artifacts You'll Generate

After completing all scenarios, you'll have:

**Forensic Evidence:**
- Attack logs from each scenario
- System call traces
- File modification logs
- Network connection logs
- Process execution logs

**Detection Signatures:**
- Falco rules for runtime detection
- Sysdig filters
- Audit log patterns
- IOC lists

**Hardening Guides:**
- Configuration checklists
- Policy recommendations
- Remediation steps and best practices

### Skills You'll Gain

✅ Offensive security mindset  
✅ Container security internals  
✅ Linux namespace understanding  
✅ Capability system knowledge  
✅ Forensic analysis basics  
✅ Attack detection patterns  

## 🔍 Key Concepts Explained

### Why Docker Socket is Dangerous

The Docker socket (`/var/run/docker.sock`) is a Unix socket that provides an API to the Docker daemon. When you mount this socket into a container:

```
Container → Docker Socket → Docker Daemon (root) → Create Privileged Container → Host Access
```

**Chain of trust broken:** Container shouldn't be able to create other containers.

### Why --privileged is Dangerous

Normal container:
```
Namespaces: ✓ Isolated
Cgroups: ✓ Limited
Capabilities: ✓ Restricted (14/38)
Devices: ✓ Limited access
Seccomp: ✓ Syscall filtering
```

Privileged container:
```
Namespaces: ✗ Can break out
Cgroups: ✗ No limits
Capabilities: ✗ All 38 enabled
Devices: ✗ Full /dev access
Seccomp: ✗ No filtering
```

### Capability Breakdown

Linux has 38 capabilities. Here's what matters for escapes:

| Capability | Allows | Escape Risk |
|------------|--------|-------------|
| CAP_SYS_ADMIN | Mount, namespace manipulation | CRITICAL |
| CAP_SYS_PTRACE | Process tracing, memory access | HIGH |
| CAP_SYS_MODULE | Load kernel modules | CRITICAL |
| CAP_DAC_OVERRIDE | Bypass file permissions | MEDIUM |
| CAP_NET_ADMIN | Network configuration | MEDIUM |

## 🛡️ Prevention Overview

**Quick Reference** (Detailed hardening in future articles):

| Attack Vector | Prevention |
|---------------|------------|
| Docker Socket | Never mount socket; use alternatives |
| Privileged Mode | Never use; break down requirements |
| CAP_SYS_ADMIN | Drop all caps; add only needed ones |
| Host Mounts | Use volumes; avoid sensitive paths |
| /proc Access | Read-only; limit exposure |

## 🔗 Integration with Other Labs

### Uses Knowledge From:
- Capabilities and read-only filesystems
- Non-root users and privilege escalation
- Network isolation concepts

### Prepares You For:
- Runtime detection of container attacks
- Using escape techniques to understand secret theft
- Hardening containers against these attacks

### Generates Data For:
- IOCs, detection rules, and security patterns
- Access patterns and secret locations
- Vulnerability assessments and hardening checklists

## 📖 Additional Resources

### Official Documentation
- [Docker Security](https://docs.docker.com/engine/security/)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Namespaces](https://man7.org/linux/man-pages/man7/namespaces.7.html)

### Research Papers & Talks
- [Understanding Docker Container Escapes](https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/)
- [Felix Wilhelm's cgroup Escape](https://blog.dragonsector.pl/2019/02/cve-2019-5736-escape-from-docker-and.html)
- [Abusing Privileged and Unprivileged Linux Containers](https://www.nccgroup.com/us/research-blog/abusing-privileged-and-unprivileged-linux-containers/)

### Tools & Projects
- [CDK (Container Penetration Toolkit)](https://github.com/cdk-team/CDK)
- [deepce (Docker Enumeration)](https://github.com/stealthcopter/deepce)
- [BOtB (Break Out The Box)](https://github.com/brompwnie/botb)

## 🤝 Contributing

Found an issue? Have a new escape technique?

1. Test it in isolation
2. Document the technique
3. Create detection signatures
4. Submit a PR with all artifacts

## 📝 Notes

### Compatibility

✅ **Works on:**
- Docker Desktop (Mac/Windows)
- Linux with Docker Engine
- WSL2 with Docker

⚠️ **Platform differences:**
- Some escapes work differently on Mac (VM-based)
- Windows containers have different architecture
- All examples tested on Linux containers

### Troubleshooting

**Issue: Cannot install docker inside container**
```bash
# Some base images don't have package managers
# Use ubuntu:22.04 or debian:bullseye
```

**Issue: Permission denied**
```bash
# Ensure you have sudo/admin rights on host
# Docker daemon must be running
```

**Issue: Port conflicts**
```bash
# Stop all containers first
docker stop $(docker ps -aq)
```

## ⏱️ Time Management

**Recommended schedule:**

**Session 1 (60 min):**
- Setup: 10 min
- Scenario 1: 25 min
- Scenario 2: 15 min
- Break: 10 min

**Session 2 (60 min):**
- Scenario 3: 20 min
- Scenario 4: 15 min
- Scenario 5: 15 min
- Break: 10 min

**Session 3 (30 min):**
- Artifact collection: 15 min
- Analysis: 10 min
- Cleanup: 5 min

## ✅ Completion Checklist

- [ ] Completed Scenario 1: Docker Socket Escape
- [ ] Completed Scenario 2: Privileged Container Escape
- [ ] Completed Scenario 3: CAP_SYS_ADMIN Abuse
- [ ] Completed Scenario 4: Host Path Mount Abuse
- [ ] Completed Scenario 5: /proc Manipulation
- [ ] Collected all forensic artifacts
- [ ] Generated IOC lists
- [ ] Documented attack patterns
- [ ] Cleaned up all containers and resources
- [ ] Ready to build detection rules

## 🎯 What's Next?

After completing this lab:

1. Learn to detect these attacks in real-time using Falco and runtime security tools
2. Understand how these escape techniques enable secret theft
3. Implement hardening configurations to prevent these attacks

---

**🔒 Remember: With great power comes great responsibility. Use this knowledge ethically.**

**🔒 Security is not about if you'll be attacked, but when. Understand the attack to defend against it.**

**📚 Complete all scenarios, document everything, prepare for detection engineering!**