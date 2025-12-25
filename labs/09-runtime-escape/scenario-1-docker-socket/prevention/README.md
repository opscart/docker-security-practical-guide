# Scenario 1: Prevention Methods Testing

**Purpose:** Test and validate three different approaches to prevent docker socket escape attacks

**Time:** 30-45 minutes for all tests

**Prerequisites:** Completed Scenario 1 (Docker Socket Escape)

---

## Overview

After demonstrating the socket escape attack in Scenario 1, this scenario tests **actual prevention methods** with real configurations and measurements.

We test three approaches:

1. **Socket Proxy** - Restrict Docker API access
2. **Kaniko** - Build images without Docker daemon  
3. **Rootless Docker** - Limit blast radius

Each test includes:
- ✅ Working configuration
- ✅ Attack attempt to verify prevention
- ✅ Performance/compatibility comparison
- ✅ Real-world use case recommendations

---

## Quick Start

```bash
# Make scripts executable
chmod +x run-prevention-tests.sh
chmod +x test-*/run-test.sh

# Run individual test
cd test-1-socket-proxy
./run-test.sh

# Or run all tests
./run-prevention-tests.sh
```

---

## Test 1: Socket Proxy

**Question:** Can we allow Docker access for monitoring/builds while blocking attacks?

**Approach:** Use `tecnativa/docker-socket-proxy` to filter Docker API calls

**Setup:**
```bash
cd test-1-socket-proxy
./run-test.sh
```

**What it tests:**
- ✅ Can containers still use `docker ps` and `docker info`?
- ✅ Does the proxy block `docker run --privileged`?
- ✅ Does the proxy block `docker exec`?
- ✅ Can monitoring tools still work?

**Expected Result:** Read operations work, write operations blocked

**Use Cases:**
- Monitoring tools (Prometheus exporters)
- Container management UIs (non-admin mode)
- CI/CD status dashboards

---

## Test 2: Kaniko

**Question:** Can we build images without giving socket access?

**Approach:** Use Kaniko to build images without Docker daemon

**Setup:**
```bash
cd test-2-kaniko
./run-test.sh
```

**What it tests:**
- ✅ Can we build a realistic Dockerfile?
- ✅ Is the built image functionally identical?
- ✅ Does it work without socket mount?
- ✅ How does build time compare?

**Expected Result:** Successful build, no socket needed, images work identically

**Use Cases:**
- Jenkins/GitLab CI builds
- Kubernetes-based builds
- GitHub Actions
- Any automated image building

---

## Test 3: Rootless Docker

**Question:** If escape succeeds, can we limit the damage?

**Approach:** Run Docker daemon as non-root user

**Setup:**
```bash
cd test-3-rootless
./run-test.sh
```

**What it tests:**
- ✅ Can attacker still read `/etc/shadow`? (should fail)
- ✅ Can attacker install system backdoors? (should fail)
- ✅ What can attacker still access?
- ✅ What are the trade-offs?

**Expected Result:** Escape succeeds, but impact limited to user scope

**Use Cases:**
- Development environments
- Build servers
- CI/CD runners
- Untrusted container workloads

---

## Results Summary

After running all tests, you'll have:

```
scenario-6-prevention/
├── test-1-socket-proxy/
│   └── artifacts/
│       ├── summary.txt           # Test results
│       ├── docker-ps-output.txt  # Allowed read operation
│       └── attack-attempt.txt    # Blocked write operation
│
├── test-2-kaniko/
│   └── artifacts/
│       ├── summary.txt               # Test results
│       ├── kaniko-build-output.txt   # Build logs
│       └── kaniko-test.tar           # Built image
│
└── test-3-rootless/
    └── artifacts/
        ├── summary.txt                 # Test results
        ├── comparison.txt              # Impact comparison
        └── root-capabilities.txt       # Permission analysis
```

---

## Comparison Matrix

| Method | Prevents Escape? | Use Case | Complexity | Trade-offs |
|--------|-----------------|----------|------------|------------|
| **Socket Proxy** | ✅ Yes | Monitoring, dashboards | Low | Must configure permissions correctly |
| **Kaniko** | ✅ Yes (N/A) | CI/CD builds | Low | Build-only, not runtime |
| **Rootless** | ❌ No (limits damage) | Dev, build servers | Medium | Some features unavailable |

**Key Insight:** No single solution fits all cases. Choose based on use case:
- Need monitoring? → Socket proxy
- Need builds? → Kaniko  
- Need defense in depth? → Rootless

---

## Integration with Scenario 1

This scenario builds on Scenario 1 by testing if these prevention methods actually work:

**Scenario 1:**
- Demonstrated the attack
- Generated IOCs and detection signatures
- Showed impact
- Tests prevention against the same attack
- Validates configurations work in practice
- Provides ready-to-use solutions

---

## Cleanup

```bash
# Clean up socket proxy test
cd test-1-socket-proxy
docker-compose down
rm -rf artifacts

# Clean up Kaniko test
cd test-2-kaniko
rm -f kaniko-test.tar Dockerfile
rm -rf artifacts

# Clean up rootless test  
cd test-3-rootless
rm -rf artifacts

# Or clean all at once
./cleanup.sh
```

---

## Next Steps

After completing these tests:

1. **For Production:** Implement socket proxy or Kaniko based on use case
2. **For Development:** Consider rootless Docker
3. **For Detection:** Use IOCs from Scenario 1 with Falco
4. **For Hardening:** Combine prevention + detection + monitoring

---

## Troubleshooting

**Socket proxy test fails:**
- Check if `tecnativa/docker-socket-proxy` image is accessible
- Verify Docker daemon is running
- Check network connectivity

**Kaniko build fails:**
- Ensure sufficient disk space
- Check internet connectivity (pulls base images)
- Verify Dockerfile syntax

**Permission errors:**
- Scripts need execute permission: `chmod +x *.sh`
- Tests need Docker access

---

## Learning Objectives

After completing this scenario, you will:

- ✅ Understand three practical prevention approaches
- ✅ Know when to use each approach
- ✅ Have working configurations ready to deploy
- ✅ Understand trade-offs of each method
- ✅ Be able to defend against socket escape attacks

---

**Remember:** Defense in depth is key. Combine prevention (this scenario) + detection (Scenario 1) + monitoring for best security posture.
