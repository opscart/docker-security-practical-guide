# Scenario 5: /proc and /sys Exposure — The Reconnaissance Blind Spot

## Overview

This scenario demonstrates how mounting `/proc` or `/sys` from the host turns a container into a reconnaissance platform. Unlike the previous scenarios, this is not a direct credential theft or code execution attack. It is an **information disclosure** scenario — the container reads system data that enables an attacker to plan and execute targeted attacks against specific vulnerabilities, network segments, and services.

This is the blind spot the article describes as "the default nobody audits." Most security teams check for `--privileged` and `docker.sock`. Almost none check whether containers can enumerate host processes, read network routing tables, or identify kernel versions for CVE lookup.

**Attack Complexity:** Low  
**Detection Difficulty:** High (mounts look identical to legitimate monitoring)  
**Prevalence:** Common (monitoring agents, debugging containers, CI environments)  
**Impact:** Medium-High (enables targeted exploitation of other vulnerabilities)

## Table of Contents

1. [Understanding /proc and /sys](#understanding-proc-and-sys)
2. [Why Teams Mount These Paths](#why-teams-mount-these-paths)
3. [Attack Demonstrations](#attack-demonstrations)
4. [What Attackers Do With This Data](#what-attackers-do-with-this-data)
5. [Defense Strategies](#defense-strategies)
6. [Hands-On Lab](#hands-on-lab)
7. [Detection and Monitoring](#detection-and-monitoring)

---

## Understanding /proc and /sys

### What Is /proc?

`/proc` is a virtual filesystem that exposes kernel and process data as readable files. It does not exist on disk — the kernel generates its contents on demand. Every running process has a directory under `/proc/[pid]/` containing its command line, environment, memory maps, open file descriptors, and more.

When a container mounts the host's `/proc`, it gains read access to all of this data for every process running on the host.

### What Is /sys?

`/sys` (sysfs) is another virtual filesystem that exposes hardware and kernel interface information. It contains data about block devices, network interfaces, CPU topology, memory controllers, and other hardware.

### What a Normal Container Sees

By default, every container has its **own** `/proc` — containing only the processes running inside that container (typically 1-3 PIDs). It has no access to the host's `/proc` or `/sys`.

```bash
# Normal container — sees only its own processes
docker run --rm alpine sh -c 'ls /proc/ | grep -E "^[0-9]+$"'
# Output: 1  (just the container's init process)

# There is no /sys in a standard container
docker run --rm alpine ls /sys/
# Output: (empty or minimal — no host hardware data)
```

### What Changes With a Mount

```bash
# Mount host /proc into the container
docker run --rm -v /proc:/host-proc:ro alpine sh -c 'ls /host-proc/ | grep -E "^[0-9]+$" | wc -l'
# Output: 247  (every process on the host)
```

The `:ro` flag makes it read-only — the container cannot modify kernel state through `/proc`. But read access alone is sufficient for reconnaissance.

### Docker Desktop Transparency Note

On macOS and Windows, Docker Desktop runs containers inside a Linux VM. When you mount `/proc` on Docker Desktop, you are mounting the **VM's** `/proc`, not your macOS or Windows host's `/proc`. The data is real but belongs to the VM.

On a **native Linux host**, mounting `/proc` exposes the actual host's process list, network configuration, and kernel data. The attack demonstrations in this scenario show what that looks like — the same commands work on both environments, but on Linux they expose production-relevant data.

This distinction matters for threat modeling: a container on a Linux production server can enumerate every service running on that server. A container on Docker Desktop cannot do the same to the developer's macOS.

---

## Why Teams Mount These Paths

### Common Justifications

#### 1. Monitoring Agents
```bash
# Prometheus node exporter needs system metrics
docker run -v /proc:/host-proc:ro -v /sys:/host-sys:ro node-exporter:latest
```
**Developer reasoning:** "The monitoring agent needs to read system metrics."  
**Reality:** Node exporters only need specific files (`/proc/meminfo`, `/proc/stat`, `/proc/diskstats`). Mounting all of `/proc` gives them — and any attacker who compromises the agent — far more access than metrics collection requires.

#### 2. Debugging Containers
```bash
# Quick debugging session — "let me just see what's running"
docker run -v /proc:/host-proc:ro alpine sh
```
**Developer reasoning:** "I need to see what's happening on the host from inside a container."  
**Reality:** This is the most casual and least audited use case. Debug containers are often left running.

#### 3. Security Scanning Tools
```bash
# Some vulnerability scanners mount /proc to enumerate running software
docker run -v /proc:/host-proc:ro -v /sys:/host-sys:ro scanner:latest
```
**Developer reasoning:** "The scanner needs deep system visibility."  
**Reality:** If the scanner itself is compromised, it has the exact reconnaissance capability an attacker needs.

### The Problem

Mounting `/proc` for monitoring is so routine that it rarely triggers security review. A Prometheus exporter with `-v /proc:/host-proc:ro` looks like standard infrastructure. Nobody questions it. But the same mount that lets the exporter read `/proc/meminfo` also lets it — or anything that compromises it — read every process's command line, environment variables, and open files.

---

## Attack Demonstrations

### Prerequisites

```bash
# Ensure you're in the scenario directory
cd labs/09-runtime-escape/scenario-5-proc-sys

# Make scripts executable
chmod +x *.sh
```

### Attack 1: /proc Mount — System Reconnaissance

**Scenario:** A container mounts the host's `/proc` read-only. An attacker inside the container extracts kernel version, network configuration, and the full process list.

**Setup:**
```bash
docker run -dit --name proc-recon -v /proc:/host-proc:ro alpine sleep 120
```

**Attack:**
```bash
# Step 1: Read kernel version — target identification
docker exec proc-recon cat /host-proc/version
# Output: Linux version 5.15.0-76-generic (buildd@lcy02-amd64-041) ...
# This tells the attacker: Ubuntu 22.04, kernel 5.15.0-76, build date

# Step 2: Read network routing table — internal network mapping
docker exec proc-recon cat /host-proc/net/route
# Output: Iface   Destination     Gateway     Flags   ...
#         eth0    00000000        0100A8C0    0003    ...  (192.168.1.0 gateway)
#         eth0    0000A8C0        00000000    0001    ...  (192.168.0.0 local)

# Step 3: Read active TCP connections
docker exec proc-recon cat /host-proc/net/tcp
# Output: Hex-encoded source/dest IP and port pairs
# Decoded: shows which services are listening and which connections are active

# Step 4: Enumerate running processes
docker exec proc-recon sh -c '
for pid in $(ls /host-proc/ | grep -E "^[0-9]+$" | sort -n | head -20); do
    cmdline=$(cat /host-proc/$pid/cmdline 2>/dev/null | tr "\0" " " || true)
    [ -n "$cmdline" ] && echo "PID $pid: $cmdline"
done
'
# Output: Shows every running process — databases, web servers, apps, cron jobs

# Step 5: Read memory and CPU information
docker exec proc-recon head -5 /host-proc/meminfo
docker exec proc-recon head -3 /host-proc/cpuinfo
```

**Cleanup:**
```bash
docker rm -f proc-recon
```

---

### Attack 2: /sys Mount — Hardware Reconnaissance

**Scenario:** A container mounts `/sys` read-only and enumerates hardware topology — block devices, network interfaces, and hardware model information.

**Setup:**
```bash
docker run -dit --name sys-recon -v /sys:/host-sys:ro alpine sleep 120
```

**Attack:**
```bash
# Step 1: Enumerate block devices
docker exec sys-recon ls /host-sys/block/
# Output: loop0  loop1  sda  (host disk devices)

# Step 2: Enumerate network interfaces
docker exec sys-recon sh -c '
for iface in $(ls /host-sys/class/net/); do
    echo "$iface: $(cat /host-sys/class/net/$iface/address 2>/dev/null)"
done
'
# Output: eth0: aa:bb:cc:dd:ee:ff
#         lo: 00:00:00:00:00:00
#         docker0: 02:42:ac:11:00:01

# Step 3: Read hardware model (cloud provider identification)
docker exec sys-recon sh -c 'ls /host-sys/class/dmi/id/ 2>/dev/null'
# Output: product_name  sys_vendor  ...
# product_name contains: "Standard PC" (QEMU), "Xen" (AWS), etc.
```

**Cleanup:**
```bash
docker rm -f sys-recon
```

---

## What Attackers Do With This Data

This section documents the attack planning that `/proc` and `/sys` reconnaissance enables. These are not live exploits — they are the next steps an attacker takes after gathering the data shown above.

### Kernel Version → CVE Lookup

The kernel version string from `/proc/version` is the single most valuable piece of data a `/proc` mount exposes. With it, an attacker can:

1. Search public CVE databases for known vulnerabilities in that exact kernel build
2. Identify whether local privilege escalation exploits exist (e.g., DirtyPipe for kernels before 5.16.42)
3. Determine the distribution and release date to narrow the attack surface

```
Example: "Linux version 5.15.0-76-generic" → search for CVEs affecting 5.15.0-76
If the host hasn't patched a known LPE, the attacker has a path to root on the host.
```

### Network Data → Lateral Movement Planning

The routing table and TCP connection data from `/proc/net/` tell an attacker:

1. What internal subnets the host is connected to
2. Which other hosts are reachable without crossing a firewall
3. What services are listening on the host (ports and states)
4. Which external connections are active (potential exfiltration targets)

```
Example: Route table shows 10.0.0.0/16 local subnet
→ Attacker scans for databases, credential stores, or other containers in that range
```

### Process List → Service Discovery

The process list from `/proc/[pid]/cmdline` reveals:

1. Every application running on the host — databases, web servers, message queues
2. Command-line arguments, which often include connection strings, API keys, or paths to credential files
3. Which processes run as root (potential privilege escalation targets)
4. Container orchestration details (kubelet, containerd, dockerd)

```
Example: PID 1234: /usr/bin/mysql --password=s3cr3t --datadir=/var/lib/mysql
→ Attacker now knows the MySQL password and data directory
```

### Hardware Data → Cloud Provider Identification

The DMI data in `/sys/class/dmi/id/` identifies the cloud provider and instance type:

1. AWS instances show "Xen" or specific EC2 instance metadata
2. Azure shows "Standard_D*" or similar
3. GCP shows "Google" in vendor fields

Knowing the provider enables targeting provider-specific attack surfaces — metadata service endpoints, instance-level IAM roles, and provider-specific escape techniques.

---

## Defense Strategies

### Defense 1: Mount Only What You Need

This is the single most effective defense. Replace full `/proc` mounts with specific file mounts.

#### Safe Subpaths for Monitoring

| File | Contains | Risk |
|---|---|---|
| `/proc/meminfo` | Memory usage statistics | None |
| `/proc/cpuinfo` | CPU model and speed | None |
| `/proc/loadavg` | System load average | None |
| `/proc/stat` | CPU time statistics | None |
| `/proc/diskstats` | Disk I/O statistics | None |

#### Dangerous Paths (Never Mount)

| Path | Contains | Risk |
|---|---|---|
| `/proc` (full) | Everything below | Process enumeration, credential exposure |
| `/proc/net/*` | Network topology | Lateral movement planning |
| `/proc/[pid]/*` | Per-process details | Credential and argument exposure |
| `/sys` (full) | All hardware data | Cloud provider identification |

#### Docker Example
```bash
# Instead of:
docker run -v /proc:/host-proc:ro node-exporter

# Mount only what the exporter needs:
docker run \
  -v /proc/meminfo:/host-proc/meminfo:ro \
  -v /proc/stat:/host-proc/stat:ro \
  -v /proc/diskstats:/host-proc/diskstats:ro \
  node-exporter
```

#### Kubernetes Example
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-exporter
spec:
  containers:
  - name: exporter
    image: node-exporter:latest
    volumeMounts:
    - name: proc-meminfo
      mountPath: /host-proc/meminfo
      readOnly: true
    - name: proc-stat
      mountPath: /host-proc/stat
      readOnly: true
  volumes:
  - name: proc-meminfo
    hostPath:
      path: /proc/meminfo
      type: File
  - name: proc-stat
    hostPath:
      path: /proc/stat
      type: File
```

---

### Defense 2: Block at Admission Time

```yaml
# File: artifacts/kyverno-block-proc-sys.yaml
# See defense.sh for the full policy

# Blocks:
#   hostPath.path: /proc
#   hostPath.path: /sys
#   hostPath.path: /proc/net

# Allows:
#   hostPath.path: /proc/meminfo  (specific file mounts)
#   hostPath.path: /proc/stat     (specific file mounts)
```

---

### Defense 3: Runtime Monitoring

The Falco rules in `artifacts/falco-proc-sys-rules.yaml` detect four patterns:

1. **Process cmdline reads** — a container reading `/proc/[pid]/cmdline` for multiple PIDs
2. **Network reconnaissance** — reads of `/proc/net/route`, `/proc/net/tcp`
3. **Hardware enumeration** — reads of `/sys/class/` or `/sys/devices/`
4. **Bulk scanning** — rapid sequential reads of many `/proc/[pid]/` directories

These rules distinguish between a monitoring agent reading `/proc/meminfo` once (normal) and a process iterating through dozens of PIDs (reconnaissance).

---

## Hands-On Lab

### Quick Start

Run the automated demonstration:
```bash
./demo.sh
```

This will:
1. Mount `/proc` and extract kernel version, network config, and process list
2. Mount `/sys` and enumerate hardware and network interfaces
3. Compare a normal container's `/proc` (1 process) vs a mounted `/proc` (all host processes)
4. Show the audit script detecting `/proc` and `/sys` mounts

### Manual Step-by-Step

#### Step 1: Compare Normal vs Mounted /proc

```bash
echo "=== Normal container ==="
docker run --rm alpine sh -c 'echo "Processes:"; ls /proc/ | grep -cE "^[0-9]+$"'

echo -e "\n=== Mounted /proc ==="
docker run --rm -v /proc:/host-proc:ro alpine sh -c 'echo "Processes:"; ls /host-proc/ | grep -cE "^[0-9]+$"'
```

#### Step 2: Extract Reconnaissance Data

```bash
# Kernel version
docker run --rm -v /proc:/host-proc:ro alpine cat /host-proc/version

# Process list (first 10)
docker run --rm -v /proc:/host-proc:ro alpine sh -c '
for pid in $(ls /host-proc/ | grep -E "^[0-9]+$" | sort -n | head -10); do
    cmdline=$(cat /host-proc/$pid/cmdline 2>/dev/null | tr "\0" " ")
    [ -n "$cmdline" ] && echo "PID $pid: $cmdline"
done
'
```

#### Step 3: Test Subpath Isolation

```bash
# Only meminfo is accessible — not the full /proc
docker run --rm \
  -v /proc/meminfo:/host-proc/meminfo:ro \
  alpine sh -c '
echo "=== meminfo (should work) ==="
head -3 /host-proc/meminfo

echo -e "\n=== version (should fail) ==="
cat /host-proc/version 2>&1 || echo "Blocked — subpath isolation works"
'
```

#### Step 4: Run the Audit

```bash
./defense.sh
./artifacts/audit-proc-sys-mounts.sh
```

#### Step 5: Validate Defenses

```bash
./validate.sh
```

#### Step 6: Cleanup

```bash
./cleanup.sh
```

---

## Detection and Monitoring

### Audit Script: Scan for /proc and /sys Mounts

The audit script (`artifacts/audit-proc-sys-mounts.sh`) classifies mounts into three categories:

**Full /proc mount** — HIGH risk. The container can enumerate all host processes, read command lines (which often contain credentials), and map the network.

**Sensitive subpath** — MEDIUM risk. Mounts like `/proc/net/*` or `/proc/[pid]/*` expose specific reconnaissance data without full process enumeration.

**Safe subpath** — LOW risk. Mounts like `/proc/meminfo` or `/proc/stat` expose only aggregate metrics with no reconnaissance value.

```bash
chmod +x artifacts/audit-proc-sys-mounts.sh
./artifacts/audit-proc-sys-mounts.sh

# Example output:
# 🚨 FOUND: monitoring-agent — Full /proc mount
#   Image: prometheus/node_exporter:latest
#   Risk: HIGH — Full process enumeration and system reconnaissance
#   Recommendation: Mount only specific files (e.g., /proc/meminfo)
#
# ✅ metrics-collector — Safe /proc subpath: /proc/meminfo
```

### Falco Rules

Deploy the rules from `artifacts/falco-proc-sys-rules.yaml`:

```bash
kubectl create cm falco-rules-proc-sys \
  --from-file=rules.yaml=artifacts/falco-proc-sys-rules.yaml -n falco
kubectl rollout restart daemonset/falco -n falco
```

The rules fire on:
- Any container reading another process's `cmdline` via `/proc/[pid]/cmdline`
- Any container reading network data from `/proc/net/`
- Any container accessing hardware data from `/sys/class/` or `/sys/devices/`
- Rapid sequential reads across multiple `/proc/[pid]/` directories

### Continuous Monitoring

- Alert on any new container with a full `/proc` or `/sys` mount
- Alert on bulk `/proc` scanning (more than 10 PID reads in a short window)
- Weekly audit via `audit-proc-sys-mounts.sh`
- Review all monitoring agent configurations quarterly — ensure they mount specific files, not full `/proc`

---

## Summary

### Key Takeaways

1. **This is reconnaissance, not a direct exploit**
   - `/proc` and `/sys` mounts don't steal credentials directly
   - They give an attacker the information needed to find and exploit other vulnerabilities
   - Kernel version → CVE targeting. Process list → credential discovery. Network data → lateral movement.

2. **Read-only does not mean safe**
   - `:ro` prevents writes to kernel state
   - It does not prevent reading process command lines, network topology, or hardware details
   - Reconnaissance is a read-only operation by nature

3. **This is the blind spot nobody audits**
   - `--privileged` gets flagged. `docker.sock` gets flagged.
   - A Prometheus exporter with `-v /proc:/host-proc:ro` passes every security review
   - The fix is trivial (mount specific files) but requires awareness of the risk

4. **Docker Desktop masks the severity on macOS**
   - On macOS, you see VM data — real but not your actual host
   - On Linux production servers, this exposes everything
   - Test locally, but threat-model for the production environment

### Production Checklist

- [ ] Audit all containers for `/proc` and `/sys` mounts (run `audit-proc-sys-mounts.sh`)
- [ ] Replace full `/proc` mounts with specific file mounts (`/proc/meminfo`, `/proc/stat`)
- [ ] Block full `/proc` and `/sys` hostPath volumes via admission policy
- [ ] Deploy Falco rules for `/proc` reconnaissance detection
- [ ] Review monitoring agent configurations — ensure minimal mount scope
- [ ] Apply Pod Security Standards restricted profile to production namespaces
- [ ] Re-audit quarterly

---

## References

- [Linux /proc Filesystem Documentation](https://www.kernel.org/doc/Documentation/filesystems/proc.txt)
- [Linux /sys (sysfs) Documentation](https://www.kernel.org/doc/Documentation/filesystems/sysfs.txt)
- [Kubernetes Pod Security Standards — Restricted Profile](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [CIS Docker Benchmark — Section 5.2](https://www.cisecurity.org/benchmarks/docker)
- [OWASP Container Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

---

## Lab Files

- `demo.sh` — Automated reconnaissance demonstrations (4 demos)
- `defense.sh` — Defense implementation (Falco rules, audit script, admission policy)
- `cleanup.sh` — Remove all lab artifacts
- `validate.sh` — Verify defenses are active
- `artifacts/audit-proc-sys-mounts.sh` — Production mount audit script
- `artifacts/falco-proc-sys-rules.yaml` — Runtime detection rules
- `artifacts/kyverno-block-proc-sys.yaml` — Admission policy

---

**Previous Scenario:** [Scenario 4: Host Path Mounts](../scenario-4-host-mount/)  
**Main Lab:** [Lab 09: Runtime Escape](../)  
**Repository:** [docker-security-practical-guide](https://github.com/opscart/docker-security-practical-guide)