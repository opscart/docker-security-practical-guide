# Manual Concepts Guide - Rootless Docker Test

This guide helps you understand rootless Docker concepts through **hands-on demonstrations** without requiring a full rootless Docker installation.

---

## 🎯 Purpose

The automated test (`./run-test.sh`) shows **conceptual comparisons**. This manual guide lets you:
1. Simulate rootless behavior with non-root containers
2. Compare root vs non-root access patterns
3. Understand the impact differences
4. See actual permission denials

**Time:** 15-20 minutes

---

## 🚀 Prerequisites

- Docker installed (standard root Docker)
- Terminal access
- Basic Linux knowledge

---

## 🔬 Manual Demonstration

### Part 1: Understanding the Current Setup (Root Docker)

**Step 1: Verify Docker runs as root**

```bash
# Check Docker daemon user
ps aux | grep dockerd

# On most systems, you'll see:
# root      <pid>  ... /usr/bin/dockerd
```

**Step 2: Start a normal container as root**

```bash
docker run -it --rm ubuntu:22.04 bash
```

**Step 3: Inside the container, check privileges**

```bash
# Check user
whoami
# Output: root

# Try privileged operations
cat /etc/shadow
# Output: Shows password hashes ✓

apt-get update
# Output: Works ✓

useradd testuser
# Output: User created ✓

# Exit
exit
```

**What this proves:** In standard Docker, containers run as root by default and can do privileged operations inside the container.

---

### Part 2: Simulating Non-Root User (Rootless Concept)

**Step 1: Start a container as non-root user**

```bash
# Run as user ID 1000 (typical non-root user)
docker run -it --rm \
  --user 1000:1000 \
  ubuntu:22.04 bash
```

**Step 2: Inside the container, check limited privileges**

```bash
# Check user
whoami
# Output: I have no name! (or: 1000)

# Try privileged operations
cat /etc/shadow
# Output: Permission denied ✗

apt-get update
# Output: Permission denied (can't write to lists) ✗

useradd testuser
# Output: Permission denied ✗

# But you can do user-level operations
cd ~
touch myfile.txt
echo "test" > myfile.txt
cat myfile.txt
# Output: Works ✓

# Exit
exit
```

**What this proves:** Non-root users have very limited permissions, even inside containers.

---

### Part 3: Simulating the Escape (Root vs Non-Root)

**Scenario A: Escape with Root Docker**

```bash
# Start container with socket (dangerous)
docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ubuntu:22.04 bash
```

Inside container:
```bash
# Install docker
apt-get update && apt-get install -y docker.io

# Create escape container
docker run -it --rm \
  --privileged \
  --pid=host \
  -v /:/host \
  ubuntu:22.04 \
  chroot /host bash

# Now in "escaped" state, check who you are:
whoami
# Output: root ✗ FULL SYSTEM ACCESS

# Can you read shadow file?
cat /etc/shadow
# Output: YES ✗ COMPROMISED

# Can you create users?
useradd attacker
# Output: YES ✗ BACKDOOR INSTALLED

# Exit
exit
exit
```

**Result:** Complete system compromise.

---

**Scenario B: Simulating Escape with Rootless Concept**

We'll simulate this by using a non-root user:

```bash
# Start container as non-root with socket
docker run -it --rm \
  --user 1000:1000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ubuntu:22.04 bash
```

Inside container:
```bash
# Try to install docker
apt-get update && apt-get install -y docker.io
# Output: Permission denied ✗

# Can't even install tools without root!

# But let's assume attacker somehow got docker CLI...
# Try to create escape container
docker run --privileged ubuntu
# Output: Permission denied (can't access socket) ✗

# Exit
exit
```

**Even if they escape somehow, simulate landing as non-root:**

```bash
# Simulate "escaped" non-root user
docker run -it --rm \
  --user 1000:1000 \
  --pid=host \
  ubuntu:22.04 bash
```

Inside "escaped" container:
```bash
whoami
# Output: I have no name! (non-root) ✓ Limited damage

# Try to read shadow
cat /etc/shadow
# Output: Permission denied ✓ Protected

# Try to create user
useradd attacker
# Output: Permission denied ✓ Cannot create backdoor

# What CAN you access?
ls /home
# Output: Can see home directories ⚠️

# Can you read user files?
cat /home/username/.bash_history
# Output: Depends on permissions, might work ⚠️

# Exit
exit
```

**Result:** Escape happened, but damage is LIMITED to non-root user scope.

---

### Part 4: Side-by-Side Comparison

**Create two terminals and compare:**

**Terminal 1 (Root Container):**
```bash
docker run -it --rm ubuntu:22.04 bash

# Inside:
whoami                    # root
cat /etc/shadow          # WORKS ✗
apt-get update           # WORKS ✗
useradd test             # WORKS ✗
```

**Terminal 2 (Non-Root Container):**
```bash
docker run -it --rm --user 1000:1000 ubuntu:22.04 bash

# Inside:
whoami                    # 1000 or "I have no name!"
cat /etc/shadow          # Permission denied ✓
apt-get update           # Permission denied ✓
useradd test             # Permission denied ✓
```

**This demonstrates the core concept:** What user the Docker daemon runs as determines what the "escaped" attacker can do.

---

## 📊 Understanding the Impact

### Root Docker (Current Setup)

When escape succeeds:
```
Attacker → Escape → Lands as root → Full system access
```

**What attacker can do:**
- ✗ Read /etc/shadow
- ✗ Modify /etc/passwd
- ✗ Install system packages
- ✗ Create new users
- ✗ Install persistent backdoors
- ✗ Access ALL files
- ✗ Compromise entire system

---

### Rootless Docker (If Installed)

When escape succeeds:
```
Attacker → Escape → Lands as regular user → Limited access
```

**What attacker CANNOT do:**
- ✓ Cannot read /etc/shadow (permission denied)
- ✓ Cannot modify /etc/passwd (permission denied)
- ✓ Cannot install system packages (permission denied)
- ✓ Cannot create new users (permission denied)
- ✓ Cannot install system-wide backdoors (permission denied)
- ✓ Cannot access other users' files (permission denied)

**What attacker CAN still do:**
- ⚠️ Read user's own files (~/.ssh/, ~/.bash_history)
- ⚠️ Access user's containers
- ⚠️ Read environment variables of user's processes
- ⚠️ Modify files in user's home directory

---

## 🎓 Key Insights

### 1. Escape Still Happens
Rootless Docker does NOT prevent the container escape. The breakout still succeeds.

### 2. Damage Is Contained
The attacker lands as a regular user, not root. This drastically limits what they can do.

### 3. Defense in Depth
This is a "limit the blast radius" approach:
- Primary defense: Don't mount docker.sock
- Secondary defense (if socket is mounted): Limit damage with rootless

### 4. Real-World Analogy
- **Root Docker:** Breaking into a building and landing in the security control room
- **Rootless Docker:** Breaking into a building and landing in a janitor's closet

Both are breaches, but the impact is vastly different.

---

## 🔍 Testing Yourself

**Try these exercises:**

### Exercise 1: File Access Test
```bash
# As root container
docker run -it --rm ubuntu:22.04 bash
cat /etc/shadow  # Works

# As non-root container  
docker run -it --rm --user 1000:1000 ubuntu:22.04 bash
cat /etc/shadow  # Permission denied
```

### Exercise 2: Package Installation Test
```bash
# As root
docker run -it --rm ubuntu:22.04 bash
apt-get update && apt-get install -y curl  # Works

# As non-root
docker run -it --rm --user 1000:1000 ubuntu:22.04 bash
apt-get update  # Fails - can't write to /var/lib/apt
```

### Exercise 3: User Creation Test
```bash
# As root
docker run -it --rm ubuntu:22.04 bash
useradd testuser  # Works

# As non-root
docker run -it --rm --user 1000:1000 ubuntu:22.04 bash
useradd testuser  # Permission denied
```

---

## 💡 Real Rootless Docker Installation (Optional)

If you want to actually install rootless Docker:

**Requirements:**
- Separate VM or test system (don't do on production)
- Linux system (not macOS Docker Desktop)
- Root access for initial setup

**Installation:**
```bash
# Install rootless Docker
curl -fsSL https://get.docker.com/rootless | sh

# Configure environment
export PATH=/home/username/bin:$PATH
export DOCKER_HOST=unix:///run/user/1000/docker.sock

# Verify
docker run hello-world
systemctl --user status docker
```

**Then run the actual escape attack and observe:**
- Container escapes successfully
- But lands as non-root user
- Cannot access /etc/shadow
- Cannot install system packages
- Damage is limited

---

## 📋 Summary

### What You Learned

1. **Docker daemon user matters** - Root daemon = root escape
2. **Non-root limits damage** - Even after escape, limited access
3. **Rootless ≠ Prevention** - Attack still succeeds, just less damage
4. **Defense in depth works** - Layers of security are better than one

### When to Use Rootless

✓ **Use for:**
- Development environments
- Build servers
- CI/CD runners
- Untrusted workloads

✗ **Avoid for:**
- Production needing privileged containers
- Systems requiring full Docker compatibility
- Environments with cgroups v1 requirement

---

## 🔗 Related Documentation

- Automated test results: `artifacts/summary.txt`
- Official rootless docs: https://docs.docker.com/engine/security/rootless/
- Rootless limitations: https://docs.docker.com/engine/security/rootless/#known-limitations

---

**Manual concepts demonstration complete!** You now understand how rootless Docker limits the impact of container escapes even when they succeed.