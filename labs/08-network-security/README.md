# Lab 08: Docker Network Security

## What You'll Learn

Master Docker network security by understanding isolation, segmentation, and encryption. This lab demonstrates practical network security patterns for production container deployments, from basic isolation to advanced TLS encryption.

**Key Outcomes:**
- Create and manage custom Docker networks for isolation
- Implement multi-tier network segmentation (web/app/database)
- Configure internal networks for database security
- Set up TLS encryption between containers
- Identify and avoid common network misconfigurations

## Prerequisites

- Docker Engine 20.10+
- macOS, Linux, or Windows with WSL2
- 20-30 minutes
- Basic understanding of Docker networking concepts
- Completed Lab 02 (Secure Configs) - recommended

## Quick Start

```bash
# Clone the repository (if not already done)
git clone https://github.com/opscart/docker-security-practical-guide.git
cd docker-security-practical-guide/labs/08-network-security

# Run all scenarios (interactive mode)
./run-all-demos.sh

# Or run individual scenarios
./demo-isolation.sh              # Scenario 1
./demo-segmentation.sh           # Scenario 2
./demo-internal-network.sh       # Scenario 3
./demo-tls-encryption.sh         # Scenario 4
./demo-misconfigurations.sh      # Scenario 5

# Clean up all resources
./cleanup.sh
```

## Understanding the Problem

### Why Network Security Matters

**Real-World Incidents:**

**Docker API Exposure (2019)**
- Thousands of Docker daemons exposed to internet
- Attackers deployed cryptocurrency miners
- Root cause: Containers on host network without firewall
- Impact: Complete host compromise

**MongoDB Ransomware (2017)**
- 27,000+ MongoDB databases held for ransom
- Many running in containers without network isolation
- Attackers accessed databases directly from internet
- Cost: Millions in ransom payments and data loss

**Container Escape via Network (2020)**
- Misconfigured container networks allowed lateral movement
- Attacker compromised one container, reached entire cluster
- Root cause: All containers on single flat network
- Impact: Full infrastructure compromise

### The Challenge

**Without Network Security:**
```
All containers on default bridge → No isolation →
One compromised container = entire system at risk →
Attackers can reach databases, internal APIs, secrets
```

**With Network Security:**
```
Segmented networks → Isolated tiers →
Compromised web container cannot reach database →
Reduced blast radius and lateral movement prevention
```

### Docker Network Drivers

| Driver | Use Case | Security Level | When to Use |
|--------|----------|----------------|-------------|
| **bridge** | Single-host container networking | Medium | Default for custom networks |
| **host** | Container shares host network | Low (dangerous) | Only for trusted containers needing host access |
| **none** | No networking | High | Batch jobs, completely isolated workloads |
| **overlay** | Multi-host networking | Medium-High | Swarm/Kubernetes clusters |

### Security Principles

1. **Network Isolation**: Containers on different networks cannot communicate by default
2. **Least Privilege**: Only connect containers that truly need to communicate
3. **Defense in Depth**: Combine network isolation with other security controls
4. **Segmentation**: Separate tiers (web/app/database) into distinct networks
5. **Encryption**: Use TLS for inter-service communication when crossing network boundaries

## Lab Scenarios

### Overview

This lab consists of 5 hands-on scenarios that progressively build your network security knowledge:

| Scenario | Topic | Time | Difficulty |
|----------|-------|------|------------|
| 1 | Network Isolation Basics | 3 min | Easy |
| 2 | Multi-Tier Segmentation | 4 min | Easy |
| 3 | Internal Networks | 3 min | Medium |
| 4 | TLS Encryption | 4 min | Medium |
| 5 | Common Misconfigurations | 3 min | Easy |

**Total Time:** 15-20 minutes

---

## Scenario 1: Network Isolation Basics

### What You'll Learn

- Create custom Docker networks
- Verify network isolation between containers
- Understand DNS-based service discovery
- Connect containers to multiple networks
- Apply principle of least privilege

### Security Concept

**Network isolation is the foundation of container security.** By default, containers on different networks cannot communicate, providing natural segmentation and reducing your attack surface. This prevents lateral movement if one container is compromised.

### Architecture

```
frontend-net                    backend-net
┌─────────────────┐            ┌─────────────────┐
│  web-frontend   │            │  web-backend    │
│  api-frontend   │            │                 │
│                 │            │                 │
│  api-backend ───┼────────────┼─→ (gateway)     │
└─────────────────┘            └─────────────────┘
     ↑                              ↑
     │                              │
   Isolated                      Isolated
```

### Running the Scenario

```bash
# Run the automated demo
./demo-isolation.sh

# The script will:
# 1. Create two isolated networks (frontend-net, backend-net)
# 2. Launch containers on separate networks
# 3. Demonstrate isolation (ping fails across networks)
# 4. Show DNS resolution within same network
# 5. Create a gateway container with access to both networks
```

### Step-by-Step Explanation

#### Step 1: Create Isolated Networks

```bash
# Create frontend network for web tier
docker network create frontend-net

# Create backend network for application tier
docker network create backend-net
```

**Why custom networks?**
- Automatic DNS resolution between containers
- Better isolation than default bridge
- Can specify custom IP ranges and subnets
- Support for network drivers and plugins

#### Step 2: Launch Containers on Separate Networks

```bash
# Web container on frontend network
docker run -d --name web-frontend \
    --network frontend-net \
    nginx:alpine

# Backend container on different network
docker run -d --name web-backend \
    --network backend-net \
    nginx:alpine
```

**Key Point:** These containers are now isolated from each other. They cannot communicate, even though they're on the same Docker host.

#### Step 3: Verify Network Isolation

```bash
# Try to ping across networks (will fail)
docker exec web-frontend ping -c 2 web-backend

# Expected output:
# ping: bad address 'web-backend'
```

**Why it fails:**
- DNS resolution only works within same network
- No network route exists between frontend-net and backend-net
- This is intentional isolation, not a problem

#### Step 4: Test DNS Within Same Network

```bash
# Launch another container on frontend-net
docker run -d --name api-frontend \
    --network frontend-net \
    nginx:alpine

# Now ping should work (same network)
docker exec web-frontend ping -c 2 api-frontend

# Expected output:
# 2 packets transmitted, 2 packets received
```

**Automatic DNS:**
- Docker provides built-in DNS server for custom networks
- Containers can find each other by name (no IP addresses needed)
- Automatic load balancing if you scale services

#### Step 5: Multi-Network Access (When Needed)

```bash
# Create API gateway that needs access to both networks
docker run -d --name api-backend \
    --network frontend-net \
    nginx:alpine

# Connect to backend network as well
docker network connect backend-net api-backend

# Verify it can reach both networks
docker exec api-backend ping -c 2 web-frontend  # Works
docker exec api-backend ping -c 2 web-backend   # Works
```

**When to use this:**
- API gateways that route between tiers
- Monitoring containers that need visibility across networks
- Service meshes that handle inter-service communication

**Security consideration:** Minimize containers with multi-network access. Each one is a potential bridge for attackers.

### Verification

Check your network configuration:

```bash
# List networks
docker network ls

# Inspect network details
docker network inspect frontend-net
docker network inspect backend-net

# Check which networks a container is connected to
docker inspect web-frontend --format '{{range $net, $config := .NetworkSettings.Networks}}{{$net}}: {{$config.IPAddress}}{{"\n"}}{{end}}'
```

### Security Best Practices

1. **Create Separate Networks Per Tier**
   ```bash
   docker network create web-tier
   docker network create app-tier
   docker network create data-tier
   ```

2. **Use DNS Names, Not IP Addresses**
   ```bash
   # Good
   DATABASE_URL=postgresql://db:5432/mydb
   
   # Bad
   DATABASE_URL=postgresql://172.18.0.2:5432/mydb
   ```

3. **Minimize Multi-Network Containers**
   ```bash
   # Only gateways should span networks
   # Everything else stays in its tier
   ```

4. **Never Use Default Bridge**
   ```bash
   # Bad - no DNS, less isolation
   docker run nginx
   
   # Good - custom network with DNS
   docker run --network app-net nginx
   ```

### Common Pitfalls

**Pitfall 1: Using --network host**
```bash
# DANGEROUS - Bypasses all isolation
docker run --network host nginx

# Container now has full access to host network
# No firewall, no isolation
# If compromised, attacker has host access
```

**Pitfall 2: Connecting Everything to Every Network**
```bash
# WRONG - Defeats purpose of isolation
docker network connect backend-net web-frontend
docker network connect frontend-net web-backend

# Now isolation is gone
# Better: Only API gateway spans networks
```

**Pitfall 3: Exposing Internal Services**
```bash
# WRONG - Database accessible from internet
docker run -p 5432:5432 postgres

# RIGHT - Database only on internal network
docker run --network data-tier postgres
```

### Troubleshooting

**Problem:** Container can't resolve DNS names
```bash
# Check which network it's on
docker inspect <container> | grep NetworkMode

# Verify DNS is working
docker exec <container> nslookup <target>

# Solution: Ensure on custom network (not default bridge)
```

**Problem:** Containers can't communicate on same network
```bash
# Check if both are on same network
docker network inspect <network-name>

# Verify no firewall rules blocking
docker exec <container1> nc -zv <container2> <port>
```

**Problem:** Multi-network container not working
```bash
# Check all network connections
docker inspect <container> --format '{{json .NetworkSettings.Networks}}'

# Verify routing
docker exec <container> ip route
```

### Key Takeaways

✓ **Default isolation** protects containers from each other  
✓ **Custom networks** provide DNS-based service discovery  
✓ **Network segmentation** limits blast radius of compromises  
✓ **Least privilege** means minimal multi-network connections  
✓ **Never use host networking** unless absolutely required  

---

## Scenario 2: Multi-Tier Network Segmentation

[Coming in Phase 2]

**What you'll learn:**
- Create production 3-tier architecture
- Segment web, application, and database tiers
- Implement firewall-like rules with network isolation
- Design secure inter-tier communication patterns

---

## Scenario 3: Internal Networks

[Coming in Phase 2]

**What you'll learn:**
- Create internal networks (no external gateway)
- Completely isolate databases from internet
- Allow application access while blocking external connections
- Understand when to use internal vs regular networks

---

## Scenario 4: TLS Encryption Between Containers

[Coming in Phase 3]

**What you'll learn:**
- Generate self-signed certificates
- Configure nginx with TLS
- Set up encrypted container-to-container communication
- Verify certificate validation

---

## Scenario 5: Common Misconfigurations

[Coming in Phase 4]

**What you'll learn:**
- Identify insecure network patterns
- Understand security impact of misconfigurations
- See real examples of what NOT to do
- Fix vulnerable network setups

---

## Docker Compose Integration

[Coming in Phase 5]

Example secure multi-tier architecture:

```yaml
version: '3.8'

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge  
  database:
    driver: bridge
    internal: true  # No external access

services:
  web:
    image: nginx
    networks:
      - frontend
    ports:
      - "80:80"

  app:
    build: ./app
    networks:
      - frontend
      - backend
    environment:
      - DATABASE_URL=postgresql://db:5432/mydb

  db:
    image: postgres
    networks:
      - database  # Internal only
```

---

## Production Best Practices

### Network Design Principles

1. **Segment by Function**
   - Separate networks for web, application, and data tiers
   - Each tier has different security requirements
   - Limit communication paths between tiers

2. **Use Internal Networks for Databases**
   - Database network has no external gateway
   - Applications access via internal network only
   - Impossible to reach from internet

3. **Minimize Network Surface Area**
   - Only expose necessary ports to host
   - Use internal communication when possible
   - Gateway containers are single point of control

4. **Implement Defense in Depth**
   - Network isolation + seccomp profiles
   - Network isolation + image signing
   - Network isolation + runtime monitoring
   - Multiple layers of security

### Fortune 500 Patterns

**Pattern 1: DMZ Architecture**
```
Internet → DMZ Network (web) → Internal Network (app) → Secure Network (db)
```

**Pattern 2: Service Mesh**
```
All services on mesh network with mutual TLS
Sidecar proxies handle encryption and routing
Central policy enforcement
```

**Pattern 3: Zero Trust**
```
No implicit trust between containers
Every connection authenticated and encrypted
Network policies enforce access control
```

---

## Troubleshooting Guide

### Network Not Found

**Error:** `Error response from daemon: network <name> not found`

**Solution:**
```bash
# Create the network
docker network create <name>

# Verify creation
docker network ls
```

### DNS Resolution Fails

**Error:** `ping: bad address '<hostname>'`

**Causes:**
1. Container on default bridge (no DNS)
2. Containers on different networks
3. DNS name doesn't match container name

**Solution:**
```bash
# Use custom network
docker network create mynet
docker run --network mynet --name app1 nginx
docker run --network mynet --name app2 nginx

# Test DNS
docker exec app1 ping app2  # Should work
```

### Connection Refused

**Error:** `Connection refused` when containers try to communicate

**Causes:**
1. Service not listening on correct port
2. Network isolation blocking connection
3. Firewall rules on host

**Solution:**
```bash
# Check if service is listening
docker exec <container> netstat -tlnp

# Verify network connectivity
docker exec <container1> nc -zv <container2> <port>

# Check network membership
docker network inspect <network>
```

---

## Resources

### Official Documentation
- [Docker Networking Overview](https://docs.docker.com/network/)
- [Use bridge networks](https://docs.docker.com/network/bridge/)
- [Use overlay networks](https://docs.docker.com/network/overlay/)

### Security Guidelines
- [CIS Docker Benchmark - Network Configuration](https://www.cisecurity.org/benchmark/docker)
- [NIST Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)

### Related Labs
- **Lab 02**: Secure Configs (container hardening basics)
- **Lab 05**: Seccomp Profiles (syscall filtering complements network isolation)
- **Lab 09**: Secrets Management (securing credentials in networked containers)

---

## Summary

You've learned:
- ✓ Create and manage custom Docker networks
- ✓ Implement network isolation for security
- ✓ Use DNS-based service discovery
- ✓ Apply principle of least privilege to networking
- ✓ Avoid common network security pitfalls

**Key Takeaways:**
1. Network isolation is fundamental to container security
2. Custom networks provide both DNS and isolation
3. Segment networks by tier (web/app/database)
4. Minimize containers with multi-network access
5. Never use host networking for untrusted containers

---

## Next Steps

1. **Run all scenarios**: `./run-all-demos.sh`
2. **Apply to your stack**: Segment your existing deployments
3. **Add encryption**: Implement TLS between services
4. **Test isolation**: Verify compromised containers can't reach databases
5. **Move to Lab 09**: Learn secrets management for secure credential distribution

---

**Found this lab helpful? Star the repository!**

**Found an issue? [Open an issue on GitHub](https://github.com/opscart/docker-security-practical-guide/issues)**

**Questions? [Start a discussion](https://github.com/opscart/docker-security-practical-guide/discussions)**