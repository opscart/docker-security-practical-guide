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

### What You'll Learn

- Design a production 3-tier network architecture
- Segment web, application, and database tiers into separate networks
- Control inter-tier communication with network isolation
- Apply principle of least privilege at the network level
- Understand why flat networks are dangerous

### Security Concept

**Network segmentation limits blast radius.** If an attacker compromises the web tier, they cannot directly reach the database tier. This forces them through application controls and logging, providing multiple opportunities to detect and stop the attack.

> **Real-World Incident:** In 2020, a Fortune 500 company suffered a breach where attackers compromised a web server. Because all containers were on one flat network, they pivoted directly to the database and exfiltrated customer data. Proper segmentation would have stopped this lateral movement.

### Architecture

```
Without Segmentation (Dangerous):
┌─────────────────────────────────────────────┐
│         All containers on one network        │
│  [Web] ←→ [App] ←→ [DB]                     │
│  Problem: Web can directly access DB         │
└─────────────────────────────────────────────┘

With Segmentation (Secure):
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  public-net  │     │   app-net    │     │ database-net │
│              │     │              │     │              │
│    [web]     │←───→│    [app]     │←───→│    [db]      │
│              │     │              │     │              │
│ Port 8080    │     │ Internal     │     │ Internal     │
│ exposed      │     │ only         │     │ only         │
└──────────────┘     └──────────────┘     └──────────────┘

Key: Only [app] spans two networks — it is the only gateway to the database.
```

### Running the Scenario

```bash
./demo-segmentation.sh

# The script will:
# 1. Create three isolated networks (public-net, app-net, database-net)
# 2. Deploy database on database-net only (no exposed ports)
# 3. Deploy application tier as the gateway between app and database networks
# 4. Deploy web tier on public-net, connected to app-net for backend access
# 5. Verify web → db is blocked, app → db succeeds
# 6. Simulate an attacker trying to reach the database from the web tier
```

### Step-by-Step Explanation

#### Step 1: Create the Three Networks

```bash
docker network create public-net
docker network create app-net
docker network create database-net
```

**Why three networks?** Each tier has its own isolation boundary. A container can only communicate with containers on a shared network. Adding more networks does not add meaningful overhead.

#### Step 2: Deploy the Database (Most Secure Tier)

```bash
docker run -d --name db \
    --network database-net \
    -e POSTGRES_PASSWORD=secret \
    -e POSTGRES_DB=appdb \
    postgres:15-alpine
```

No `-p` flag. The database has no exposed ports and is only reachable from containers on `database-net`.

#### Step 3: Deploy the Application Tier (The Gateway)

```bash
docker run -d --name app \
    --network app-net \
    -e DB_HOST=db \
    lab08-api:latest

# Connect app to database-net so it can reach the db
docker network connect database-net app
```

`app` spans two networks intentionally — it is the **only** container allowed to bridge the app and database tiers.

#### Step 4: Deploy the Web Tier (Public-Facing)

```bash
docker run -d --name web \
    --network public-net \
    -p 8080:80 \
    nginx:alpine

# Connect web to app-net so it can reach the app tier
docker network connect app-net web
```

`web` spans `public-net` and `app-net` but has **no connection to `database-net`**.

#### Step 5: Verify Segmentation

```bash
# Web → App: should succeed
docker exec web nc -zv app 5000

# Web → DB: should be blocked
docker exec web nc -zv db 5432

# App → DB: should succeed
docker exec app nc -zv db 5432
```

Expected output:
```
Web → App:  open          ✓ (correct — web talks to app)
Web → DB:   bad address   ✓ (correct — web cannot reach db)
App → DB:   open          ✓ (correct — app is the only gateway)
```

#### Step 6: Attack Scenario

```bash
# Attacker has compromised the web container and tries to reach the database
docker exec web nc -zv db 5432
# Output: bad address 'db'
# Web has no route to database-net — attack stopped at the network level
```

### Verification

```bash
# Confirm which networks each container belongs to
docker inspect web --format '{{range $net, $cfg := .NetworkSettings.Networks}}{{$net}}: {{$cfg.IPAddress}}{{"\n"}}{{end}}'
docker inspect app --format '{{range $net, $cfg := .NetworkSettings.Networks}}{{$net}}: {{$cfg.IPAddress}}{{"\n"}}{{end}}'
docker inspect db  --format '{{range $net, $cfg := .NetworkSettings.Networks}}{{$net}}: {{$cfg.IPAddress}}{{"\n"}}{{end}}'

# Expected:
# web: public-net + app-net        (2 networks)
# app: app-net + database-net      (2 networks — the gateway)
# db:  database-net only           (1 network — most secure)
```

### Security Best Practices

1. **Databases get exactly one network — their own**
   ```bash
   # No -p flag, no other network connections
   docker run --network database-net postgres
   ```

2. **Only gateway containers span networks**
   ```bash
   # app bridges app-net and database-net — controlled access point
   # web bridges public-net and app-net — routes to app, not db
   ```

3. **Never expose database ports to the host**
   ```bash
   # Bad
   docker run -p 5432:5432 postgres

   # Good
   docker run --network database-net postgres
   ```

4. **Audit network connections regularly**
   ```bash
   docker network inspect database-net
   docker inspect <container> | grep -A 10 Networks
   ```

### Common Pitfalls

**Pitfall 1: Connecting web directly to database-net**
```bash
# WRONG — destroys the purpose of segmentation
docker network connect database-net web
# Now the web tier can reach the database directly
```

**Pitfall 2: Exposing the database port**
```bash
# WRONG — database reachable from host and potentially internet
docker run -p 5432:5432 --network database-net postgres
```

**Pitfall 3: One flat network for everything**
```bash
# WRONG — all containers can see each other
docker network create app-network
docker run --network app-network web
docker run --network app-network app
docker run --network app-network db
```

### Key Takeaways

✓ **Segmentation stops lateral movement** — web compromise does not equal database access
✓ **Only gateways span networks** — minimise containers that bridge tiers
✓ **No exposed ports for internal tiers** — databases and app services need no `-p` flag
✓ **Network layout is auditable** — `docker network inspect` shows exactly what can reach what

---

## Scenario 3: Internal Networks

### What You'll Learn

- Create Docker internal networks with no external gateway
- Completely isolate databases from the internet
- Verify a compromised container cannot reach outside
- Allow app tier access while blocking all external routes
- Understand when to use `--internal` vs a regular network

### Security Concept

**Network segmentation (Scenario 2) stops lateral movement between tiers. Internal networks go further** — they remove the external gateway entirely. Even if a database container is compromised, the attacker cannot download malware, reach a C2 server, or exfiltrate data over the internet. They are trapped inside the network.

| Network type | Containers reach each other | Containers reach the internet |
|---|---|---|
| Regular | ✓ | ✓ |
| `--internal` | ✓ | ✗ |

### Architecture

```
app-net (regular):
┌─────────────────────────────────┐
│  app   172.19.0.2               │  ← has internet + reaches db
│  web-test 172.19.0.3            │  ← has internet, cannot reach db
└─────────────────────────────────┘

database-net (--internal):
┌─────────────────────────────────┐
│  db    172.25.0.2  Gateway: -   │  ← no default route, no internet
│  app   172.25.0.3               │  ← gateway into this network
└─────────────────────────────────┘

Connectivity matrix:
  app  → db        ✓  (app bridges both networks)
  app  → internet  ✓  (app is on regular app-net)
  db   → internet  ✗  (--internal: no default route)
  web  → db        ✗  (web is not connected to database-net)
```

### Running the Scenario

```bash
./demo-internal-network.sh

# The script will:
# 1. Create app-net (regular) and database-net (--internal)
# 2. Deploy postgres on database-net — show gateway field is empty
# 3. Prove the database cannot ping 8.8.8.8 (no default route)
# 4. Deploy app on app-net — prove it CAN reach the internet
# 5. Connect app to database-net as the gateway
# 6. Verify the full connectivity matrix (3 tests)
# 7. Walk through the attack scenario showing why --internal matters
```

### Step-by-Step Explanation

#### Step 1: Create the Networks

```bash
# Regular network — containers get a default gateway
docker network create app-net

# Internal network — no default gateway, no internet route
docker network create --internal database-net
```

Verify the flag is set:
```bash
docker network inspect database-net --format 'Internal: {{.Internal}}'
# Internal: true

docker network inspect app-net --format 'Internal: {{.Internal}}'
# Internal: false
```

#### Step 2: Deploy the Database on the Internal Network

```bash
docker run -d --name db \
    --network database-net \
    -e POSTGRES_PASSWORD=secret \
    postgres:15-alpine
```

Check the gateway field — it will be empty:
```bash
docker inspect db --format '{{range .NetworkSettings.Networks}}Gateway: {{.Gateway}}{{end}}'
# Gateway:    ← empty, no default route
```

#### Step 3: Prove the Database Cannot Reach the Internet

```bash
docker exec db ping -c 2 -W 2 8.8.8.8
# ping: connect: Network unreachable

docker exec db ip route
# 172.25.0.0/16 dev eth0 scope link src 172.25.0.2
# ← No 0.0.0.0/0 default route
```

#### Step 4: Deploy the App as the Gateway

```bash
# App starts on regular network (has internet)
docker run -d --name app --network app-net alpine:latest sleep 3600

# Connect app to internal network — it becomes the only gateway to db
docker network connect database-net app
```

#### Step 5: Verify the Connectivity Matrix

```bash
# App → DB: should succeed
docker exec app nc -zw2 db 5432
# open ✓

# DB → Internet: should be blocked
docker exec db ping -c 1 -W 2 8.8.8.8
# Network unreachable ✓

# Container on app-net only → DB: should be blocked
docker run --rm --network app-net alpine nc -zw2 db 5432
# bad address 'db' ✓  (db is not on app-net)
```

### Verification

```bash
# Confirm database-net has no gateway
docker network inspect database-net | grep -A 5 '"Gateway"'

# Confirm db has no default route
docker exec db ip route

# Confirm app spans both networks
docker inspect app --format '{{range $net, $cfg := .NetworkSettings.Networks}}{{$net}}: {{$cfg.IPAddress}}{{"\n"}}{{end}}'
# app-net: 172.19.0.2
# database-net: 172.25.0.3
```

### When to Use `--internal`

**Use it for:**
- Databases (PostgreSQL, MySQL, MongoDB, Redis)
- Internal message queues (RabbitMQ, Kafka)
- Secret stores that should never call out
- Any service with no legitimate reason to reach the internet

**Do not use it for:**
- Services that pull updates or licences from the internet
- Containers that push metrics to external monitoring
- Services using OAuth/OIDC (need to reach the identity provider)

### Common Pitfalls

**Pitfall 1: Forgetting the app needs internet access too**
```bash
# If you put app on --internal as well, it loses internet access
# Only the database tier should be --internal
docker network create --internal database-net   # correct
docker network create app-net                   # regular — app needs internet
```

**Pitfall 2: Exposing a port on an internal-network container**
```bash
# -p still works on --internal containers but exposes to the host
# Avoid -p on database containers entirely
docker run --network database-net postgres        # correct — no -p
docker run -p 5432:5432 --network database-net postgres  # wrong
```

### Key Takeaways

✓ **`--internal` removes the default route** — no internet access for that container
✓ **Compromise is contained** — attacker cannot download tools or exfiltrate data
✓ **Complements Scenario 2** — segmentation stops lateral movement, `--internal` stops egress
✓ **The gateway pattern holds** — only the app container bridges regular and internal networks

---

## Scenario 4: TLS Encryption Between Containers

### What You'll Learn

- Generate self-signed TLS certificates with a local CA
- Configure nginx with TLS encryption
- Test and verify encrypted container-to-container communication
- Understand the difference between skipping and verifying certificates
- Know when TLS between containers is necessary vs overkill

### Security Concept

**Network isolation prevents unauthorised access, but traffic between containers on the same network is unencrypted by default.** If an attacker gains access to the Docker host or network layer, they can read all inter-container traffic in plain text. TLS encrypts data in transit regardless of where the attacker is positioned.

| Threat | Network Isolation | TLS Encryption |
|--------|:-----------------:|:--------------:|
| External access | ✓ Blocked | — |
| Network sniffing | ✗ Plain text | ✓ Encrypted |
| Man-in-the-middle | ✗ Vulnerable | ✓ Protected |
| Multi-tenant traffic | ✗ Shared | ✓ Crypto boundary |
| Container compromise | ✗ No protection | ✓ Data encrypted |

**Best security: Network Isolation + TLS together** — isolation prevents access, TLS protects data if isolation is ever breached.

### When to Use TLS Between Containers

**Use it when:**
- Handling sensitive data (passwords, PII, financial records)
- Operating in multi-tenant environments
- Compliance requirements apply (HIPAA, PCI DSS, SOC 2)
- Implementing a zero-trust architecture

**May be overkill when:**
- Single-tenant, fully trusted internal network
- Network is already encrypted at the VPN or overlay layer
- Performance is critical and encryption overhead is measurable

### Architecture

```
Host
├── secure-net (bridge)
│   ├── nginx-basic   (port 8080 → HTTP,  unencrypted baseline)
│   ├── nginx-tls     (port 8443 → HTTPS, TLS enabled)
│   └── client        (curl test container with CA cert mounted)
│
certs/
├── ca.pem            (Certificate Authority — used to verify the server cert)
├── server-cert.pem   (Server public certificate)
└── server-key.pem    (Server private key — never leave the host)
```

### Running the Scenario

```bash
./demo-tls-encryption.sh

# The script will:
# 1. Generate self-signed certificates (skips if already present)
# 2. Create secure-net bridge network
# 3. Start nginx without TLS on port 8080 (baseline)
# 4. Start nginx with TLS on port 8443 (certs mounted as read-only volume)
# 5. Test HTTPS with -k (skips verification) — shows it works but is insecure
# 6. Test HTTPS with --cacert (proper verification) — the correct approach
# 7. Inspect live certificate details with openssl
# 8. Test container-to-container TLS from a client container on the same network
# 9. Compare HTTP vs HTTPS latency
```

### Step-by-Step Explanation

#### Step 1: Generate Certificates

```bash
cd certs && ./generate-certs.sh && cd ..
```

This creates three files:
- `ca.pem` — the Certificate Authority that signed the server cert
- `server-cert.pem` — the server's public certificate presented to clients
- `server-key.pem` — the server's private key (stays on the server, never shared)

#### Step 2: Create the Network

```bash
docker network create secure-net
```

A standard bridge network. TLS provides the encryption layer on top — no special network driver required.

#### Step 3: Start the Unencrypted Baseline

```bash
docker run -d --name nginx-basic \
    --network secure-net \
    -p 8080:80 \
    nginx:alpine

curl -s http://localhost:8080/health
# {"status": "healthy"}  ← works, but traffic is plain text
```

#### Step 4: Start nginx with TLS

Certificates are mounted as a read-only volume — they never get baked into the image:

```bash
docker run -d --name nginx-tls \
    --network secure-net \
    -v "$(pwd)/configs/nginx-tls.conf:/etc/nginx/nginx.conf:ro" \
    -v "$(pwd)/certs:/etc/nginx/certs:ro" \
    -p 8443:443 \
    nginx:alpine
```

#### Step 5: Test Without Certificate Verification (Insecure)

```bash
curl -k https://localhost:8443/health
# {"status": "healthy"}  ← works, but -k skips verification
```

The `-k` flag tells curl to accept any certificate, including forged ones. **Never use `-k` in production** — it defeats the purpose of TLS by leaving you open to man-in-the-middle attacks.

#### Step 6: Test With Certificate Verification (Correct)

```bash
curl --cacert certs/ca.pem https://localhost:8443/health
# {"status": "healthy"}  ← certificate verified against our CA
```

This is the secure approach — curl verifies the server's certificate was signed by our trusted CA before sending any data.

#### Step 7: Inspect the Live Certificate

```bash
openssl s_client -connect localhost:8443 -showcerts < /dev/null 2>/dev/null \
    | openssl x509 -text -noout \
    | grep -A5 "Subject:"
```

Shows the certificate's subject, issuer, validity period, and SANs (Subject Alternative Names).

#### Step 8: Container-to-Container TLS

```bash
# Start a client container on the same network, with the CA cert mounted
docker run -d --name client \
    --network secure-net \
    -v "$(pwd)/certs:/certs:ro" \
    alpine:latest sleep 3600

docker exec client apk add --no-cache curl

# From inside the network, use the container name as the hostname
docker exec client curl -k https://nginx-tls/health
# ✓ Container-to-container TLS working

# With certificate verification
docker exec client curl --cacert /certs/ca.pem https://nginx-tls/health
```

#### Step 9: Performance Comparison

```bash
time curl -s http://localhost:8080/health  > /dev/null   # HTTP baseline
time curl -k -s https://localhost:8443/health > /dev/null # HTTPS overhead
```

TLS adds roughly 1–5ms per request for the handshake. For most services this is negligible. For very high-throughput, latency-sensitive paths, consider terminating TLS at a load balancer rather than per-service.

### Verification

```bash
# Confirm TLS container is running and listening on 443
docker ps --filter name=nginx-tls

# Check the certificate expiry
openssl s_client -connect localhost:8443 < /dev/null 2>/dev/null \
    | openssl x509 -noout -dates

# Confirm the private key stays on the host — not inside the container
docker exec nginx-tls ls /etc/nginx/certs/
# server-cert.pem  server-key.pem  ca.pem  ← mounted read-only from host
```

### Production Best Practices

**Certificate management:**
- Use CA-signed certificates for public services (Let's Encrypt is free)
- Use an internal CA for private inter-service communication
- Store certificates in a secrets manager (Vault, AWS Secrets Manager) — not in the image
- Alert 30 days before expiry; automate renewal

**TLS configuration:**
- Enforce TLS 1.2+ minimum — disable TLS 1.0 and 1.1
- Use forward secrecy cipher suites (ECDHE)
- Enable HSTS to prevent downgrade attacks
- For service-to-service: implement mTLS (mutual TLS) so both sides verify identity

**In Docker Compose:**
```yaml
services:
  nginx:
    image: nginx:alpine
    volumes:
      - ./certs:/etc/nginx/certs:ro   # read-only — key never in image
      - ./configs/nginx-tls.conf:/etc/nginx/nginx.conf:ro
    ports:
      - "443:443"
```

### Key Takeaways

✓ **Isolation ≠ encryption** — containers on the same network can read each other's plain-text traffic
✓ **Never use `-k` in production** — it silently disables the security TLS provides
✓ **Mount certificates as read-only volumes** — never bake private keys into images
✓ **TLS overhead is small** — ~1–5ms per request, worth it for sensitive data
✓ **Combine with isolation** — Scenario 3 (`--internal`) stops egress, TLS encrypts what stays inside

---

## Scenario 5: Common Misconfigurations

### What You'll Learn

- Identify 8 common Docker network and runtime security mistakes
- Understand the security impact of each misconfiguration
- See working before/after comparisons
- Apply a production security checklist

### Security Concept

**Most breaches happen not from sophisticated zero-days, but from simple misconfigurations.** Each mistake below has been exploited in real production environments. Knowing what not to do is as important as knowing the right patterns.

### Running the Scenario

```bash
./demo-misconfigurations.sh

# The script walks through 8 misconfigurations:
# 1. Default bridge network (no DNS)
# 2. --network host (no isolation)
# 3. Exposing unnecessary ports
# 4. No resource limits
# 5. Running as root
# 6. Privileged mode
# 7. Flat network architecture
# 8. No health checks
```

### Step-by-Step Explanation

#### Mistake 1: Using the Default Bridge Network

```bash
# Bad — containers cannot find each other by name
docker run -d --name web nginx:alpine
docker run -d --name db  postgres:15-alpine -e POSTGRES_PASSWORD=secret

docker exec web ping -c 1 db
# Output: ping: bad address 'db'
# You'd need to hardcode the IP, which changes on every restart
```

```bash
# Good — custom network with automatic DNS
docker network create app-net
docker run -d --name web --network app-net nginx:alpine
docker run -d --name db  --network app-net postgres:15-alpine -e POSTGRES_PASSWORD=secret

docker exec web ping -c 1 db
# Output: 1 packets received — DNS works
```

**Why it matters:** No DNS forces teams to use hardcoded IPs. Hardcoded IPs change on restart, leading to broken services and pressure to put everything on one network.

---

#### Mistake 2: Using `--network host`

```bash
# Bad — container shares the host's entire network namespace
docker run -d --name web --network host nginx:alpine

docker exec web ip addr show
# Shows ALL host network interfaces — eth0, lo, VPN tunnels
```

```bash
# Good — isolated bridge with explicit port mapping
docker run -d --name web -p 80:80 nginx:alpine
```

**Why it matters:** A compromised container on host networking has direct access to every interface, service, and internal route on the host. Port conflicts also make deployments unpredictable.

---

#### Mistake 3: Exposing Unnecessary Ports

```bash
# Bad — database directly reachable from the host (and potentially the internet)
docker run -p 5432:5432 postgres

# Good — database reachable only by containers on the same network
docker run --network app-net postgres
```

| Tier | Ports to expose | Reason |
|------|----------------|--------|
| Web | 80, 443 | Needs internet access |
| App | none | Reached via internal DNS only |
| Database | none | Internal only, never public |

---

#### Mistake 4: No Resource Limits

```bash
# Bad — container can consume all host CPU and memory
docker run -d --name web nginx:alpine

docker inspect web | grep -A 5 Memory
# "Memory": 0   ← unlimited
```

```bash
# Good — bounded resources prevent DoS and runaway processes
docker run -d --name web \
    --memory="256m" \
    --memory-swap="256m" \
    --cpus="1.0" \
    nginx:alpine

docker stats --no-stream web
```

**Why it matters:** A single container with a memory leak or under attack can trigger the OOM killer on the host, taking down unrelated services.

---

#### Mistake 5: Running as Root

```bash
# Bad — container process runs as uid=0
docker run --rm alpine:latest id
# uid=0(root) gid=0(root)

# Good — run as unprivileged user
docker run --rm --user 1000:1000 alpine:latest id
# uid=1000 gid=1000
```

**Why it matters:** If an attacker exploits a vulnerability in the application, they land as root inside the container. Combined with other misconfigurations (missing read-only FS, mounted socket), this often leads directly to host compromise.

---

#### Mistake 6: Privileged Mode

```bash
# Bad — ALL security features disabled
docker run --privileged nginx:alpine
# Full access to host devices, kernel modules, and namespaces
# Root inside the container = root on the host

# Good — grant only what the container actually needs
docker run --device=/dev/video0 my-camera-app        # specific device
docker run --cap-add NET_BIND_SERVICE nginx:alpine   # specific capability
```

**Why it matters:** `--privileged` is the most common path to container escape. It appears in Docker-in-Docker setups, CI runners, and monitoring agents — often without the team realising it disables all container isolation. Lab 09 demonstrates a full host escape from a privileged container.

---

#### Mistake 7: Flat Network Architecture

```bash
# Bad — all tiers on one network, web can reach the database directly
docker network create app-network
docker run --network app-network web
docker run --network app-network app
docker run --network app-network db
```

```
# Good — tiered networks (covered in Scenario 2)
public-net:   web only
app-net:      web + app
database-net: app + db
```

**Why it matters:** A flat network means any compromised container can reach any other container, including databases and internal APIs. Segmentation forces attackers through controlled chokepoints.

---

#### Mistake 8: No Health Checks

```bash
# Bad — Docker reports "Up" even when the application has crashed internally
docker run -d --name web nginx:alpine
docker ps --format "table {{.Names}}\t{{.Status}}"
# web   Up 10 seconds   ← Docker has no idea if nginx is actually serving
```

```bash
# Good — Docker actively verifies the application is responding
docker run -d --name web \
    --health-cmd="wget --quiet --tries=1 --spider http://localhost/ || exit 1" \
    --health-interval=10s \
    --health-timeout=3s \
    --health-retries=3 \
    nginx:alpine

docker ps --format "table {{.Names}}\t{{.Status}}"
# web   Up 12 seconds (healthy)
```

**Why it matters:** Without health checks, load balancers route traffic to dead containers and orchestrators cannot restart failed ones. Health checks also catch tampering — an attacker who replaces your binary will likely break the health endpoint.

---

### Production Security Checklist

Run through this before deploying any container to production:

```
□ Using a custom network (not the default bridge)
□ Not using --network host
□ Only web/API tier ports exposed (-p), nothing else
□ Memory and CPU limits set on all containers
□ Running as non-root user (USER in Dockerfile or --user flag)
□ No --privileged flag
□ Networks properly segmented by tier
□ Health checks defined for all services
□ Databases on internal networks with no exposed ports
□ TLS in place for any sensitive inter-service communication
```

### Key Takeaways

✓ **Default bridge has no DNS** — always use custom networks
✓ **Host networking removes all isolation** — never use it in production
✓ **Databases need no exposed ports** — internal DNS is enough
✓ **Resource limits are a security control**, not just an ops concern
✓ **`--privileged` disables all container security** — use specific capabilities instead
✓ **Health checks detect both failures and tampering**

---

## Docker Compose Integration

This lab includes two compose files that put all five scenarios into a single deployable stack — one showing every anti-pattern, one showing the secure equivalent.

| File | Purpose |
|------|---------|
| `docker-compose.insecure.yml` | 10 deliberate anti-patterns — for comparison only |
| `docker-compose.yml` | Production-ready secure 3-tier architecture |

### Running the Secure Stack

```bash
# Start the secure stack
docker compose up -d

# Verify all containers are healthy
docker compose ps

# Confirm web cannot reach the database directly
docker exec web nc -zv db 5432    # Should fail — no route

# Confirm app can reach the database
docker exec app nc -zv db 5432    # Should succeed — authorized gateway

# Tear down
docker compose down -v
```

### Side-by-Side Comparison

**`docker-compose.insecure.yml` — what NOT to do:**

```yaml
services:
  database:
    image: postgres:15-alpine
    ports:
      - "5432:5432"          # ❌ Database exposed to internet
    environment:
      - POSTGRES_PASSWORD=password123   # ❌ Weak password in plain text

  web:
    image: nginx:alpine
    network_mode: "host"     # ❌ Bypasses all Docker networking

  admin:
    image: alpine:latest
    privileged: true         # ❌ Disables all container security
    volumes:
      - /:/host              # ❌ Full host filesystem mounted
      - /var/run/docker.sock:/var/run/docker.sock  # ❌ Docker socket

  api:
    image: node:18-alpine
    environment:
      - API_KEY=super-secret-key-123   # ❌ Secret in environment variable
    # ❌ No resource limits, no health check, runs as root
```

**`docker-compose.yml` — the secure equivalent:**

```yaml
networks:
  frontend:
    driver: bridge          # Web tier — exposed to internet
  backend:
    driver: bridge          # App tier — internal only
  database:
    driver: bridge
    internal: true          # ✅ No external gateway (Scenario 3)

services:
  web:
    image: nginx:alpine
    networks:
      - frontend
      - backend             # ✅ Reaches app tier only, not database
    ports:
      - "8080:80"           # ✅ Only web tier is exposed
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s

  app:
    build: ./app
    networks:
      - backend
      - database            # ✅ Only gateway to the database tier
    user: "1000:1000"       # ✅ Non-root user
    read_only: true         # ✅ Read-only root filesystem
    tmpfs:
      - /tmp
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5000/health"]
      interval: 30s

  db:
    image: postgres:15-alpine
    networks:
      - database            # ✅ Internal network only — no internet access
    user: "postgres"        # ✅ Non-root user
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M      # ✅ Resource limits prevent DoS
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
```

### Security Controls at a Glance

| Control | Insecure | Secure |
|---------|----------|--------|
| Network segmentation | ✗ Flat / host | ✅ 3-tier |
| Database internet access | ✗ Exposed | ✅ `internal: true` |
| Database port | ✗ `5432:5432` | ✅ Not exposed |
| Privileged mode | ✗ Enabled | ✅ Not used |
| User | ✗ root | ✅ Non-root |
| Resource limits | ✗ None | ✅ CPU + memory |
| Health checks | ✗ None | ✅ All services |
| Secrets | ✗ Plain text env vars | ✅ No secrets in compose |

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