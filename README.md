![License](https://img.shields.io/github/license/opscart/docker-security-practical-guide)
![Stars](https://img.shields.io/github/stars/opscart/docker-security-practical-guide?style=social)
![Last commit](https://img.shields.io/github/last-commit/opscart/docker-security-practical-guide)
![GitHub Actions](https://img.shields.io/github/actions/workflow/status/opscart/docker-security-practical-guide/main.yml)

# Docker Security: A Practical Guide

A comprehensive, hands-on guide to Docker security best practices with real-world examples and lab exercises.

## 🎯 What You'll Learn

This guide takes you from basic Docker security concepts to advanced hardening techniques through practical, reproducible lab exercises. Each lab builds on previous knowledge while remaining self-contained.

### Core Topics Covered

- **Security Auditing**: Using Docker Bench Security for CIS compliance
- **Secure Images**: Building hardened, minimal container images
- **Least Privilege**: Implementing proper access controls
- **Image Signing**: Verifying container authenticity
- **Network Security**: Isolating and securing container communications
- **AI/ML Security**: Protecting machine learning workloads
- **Supply Chain Security**: SBOM generation and vulnerability scanning
- **Network Architecture**: Multi-tier segmentation and encryption

## 🌐 OpsCart Labs Platform

This Docker Security guide is part of the **OpsCart Labs** collection — production-grade hands-on labs built from real Fortune 500 retail & pharmaceutical cluster experience.

**Visit [OpsCart Labs](https://opscart.com/labs/)** for:
- **70+ Total Labs** across 2 lab series
- **~60 Hours** of hands-on content
- **GitHub-Backed** — All labs available as open source
- **Automated Validation** — Exam tips, real scenarios, war-room notes

### Available Lab Series

**🔐 Docker Security: Practical Guide** (This Repository)
- Runtime escape, secrets management, image hardening, and secret management
- 12 labs covering CIS benchmarks to production security patterns
- **Status:** Active development

**☸️ Certified Kubernetes Administrator Exam Prep** ([production-cka](https://github.com/opscart/production-cka))
- 70 hands-on labs covering every CKA exam domain
- Automated validation scripts, real exam tips, Fortune 500 cluster notes
- Cluster Arch 25% • Networking 20% • Workloads 15% • Storage 10% • Troubleshooting 30%
- **Status:** 5/70 labs complete

**🎯 Kubernetes Practical Exercises** (Coming Soon)
- Focused exercises covering core Kubernetes concepts
- Ideal for engineers who want to sharpen specific skills without full exam prep
- Pods & Workloads • Networking • Storage • Debugging

### Why OpsCart Labs?

**Production-Grade** — Built from managing 8+ production AKS clusters  
**Real Scenarios** — Fortune 500 pharmaceutical & retail experience  
**GitHub-First** — All content open source and version controlled  
**Practitioner Authority** — IEEE Senior Member, DZone Core Member, CNCF contributor  

**Explore all labs:** [opscart.com/labs](https://opscart.com/labs/)

---

## 📚 Lab Structure

### Level 1: Fundamentals (Labs 01-06)

Foundation labs covering essential Docker security concepts.

---

### [Lab 01: Security Auditing with Docker Bench](./labs/01-docker-bench-security/)

**What You'll Learn:**
- Run comprehensive security audits using Docker Bench Security
- Understand CIS Docker Benchmark compliance checks
- Identify common security misconfigurations
- Fix vulnerable container configurations

**Key Concepts:**
- Privileged container detection
- Network namespace isolation
- Capability management
- Security profile enforcement

**Time:** 30-45 minutes

---

### [Lab 02: Secure Container Configurations](./labs/02-secure-configs/)

**What You'll Learn:**
- Compare insecure vs secure container configurations
- Understand and apply Linux capabilities
- Implement read-only filesystems
- Use tmpfs for required write operations
- Apply security options like no-new-privileges

**Key Concepts:**
- Linux capability system
- Read-only root filesystems
- Capability dropping (drop all, add specific)
- tmpfs mounts with noexec and nosuid
- Container hardening without breaking functionality

**Time:** 45-60 minutes

---

### [Lab 03: Least Privilege Containers](./labs/03-vulnerability-scanning/)

**What You'll Learn:**
- Run containers as non-root users
- Drop unnecessary Linux capabilities
- Implement read-only filesystems
- Configure security contexts

**Key Concepts:**
- User namespace remapping
- Capability dropping
- Resource constraints
- Security policies

**Time:** 30-45 minutes

---

### [Lab 04: Image Signing and Verification](./labs/04-image-signing/)

**What You'll Learn:**
- Sign container images with Cosign
- Verify image signatures before deployment
- Implement Docker Content Trust
- Enforce signing policies
- Manage signing keys securely

**Key Concepts:**
- Digital signatures and cryptographic verification
- Cosign and Sigstore project
- Docker Content Trust (DCT)
- Keyless signing with OIDC
- Supply chain attack prevention
- Policy enforcement for signed images

**Time:** 45-60 minutes

---

### [Lab 05: Network Security Basics](./labs/05-network-security/)

**What You'll Learn:**
- Configure secure Docker networks
- Implement network policies
- Use service mesh patterns
- Secure inter-container communication

**Key Concepts:**
- Custom bridge networks
- Network segmentation
- Encrypted communication
- Traffic control

**Time:** 30-45 minutes

---

### [Lab 06: AI Model Security](./labs/06-ai-model-security/)

**What You'll Learn:**
- Secure containerized machine learning workloads
- Set appropriate resource limits for ML containers
- Implement input validation and rate limiting
- Protect model intellectual property
- Monitor ML container behavior
- Deploy ML models securely in production

**Key Concepts:**
- Resource management for ML workloads
- Model extraction and adversarial attacks
- API authentication and authorization
- Input validation for ML endpoints
- Model encryption and access control
- Monitoring and anomaly detection for ML services

**Time:** 60-90 minutes

---

### Level 2: Advanced Security (Labs 07-08)

Advanced labs covering supply chain security and comprehensive network security.

---

### [Lab 07: Supply Chain Security with SBOM](./labs/07-supply-chain-sbom/)

**What You'll Learn:**
- Generate Software Bill of Materials (SBOM) using Syft
- Scan SBOMs for vulnerabilities with Grype
- Compare SBOM versions to track changes
- Integrate SBOM generation into CI/CD pipelines
- Meet compliance requirements (Executive Order 14028)

**Key Concepts:**
- SBOM formats (SPDX, CycloneDX, Syft JSON)
- Supply chain transparency
- Vulnerability management
- Dependency tracking
- CVE detection and remediation
- CI/CD security automation

**Key Tools:**
- **Syft**: SBOM generation
- **Grype**: Vulnerability scanning
- **Azure DevOps** and **GitHub Actions**: CI/CD integration

**Time:** 45-60 minutes

**Why This Matters:**
- Required for US federal software (EO 14028)
- Enables rapid response to vulnerabilities (e.g., Log4Shell)
- Provides complete software inventory
- Supports compliance audits (PCI DSS, SOC 2)

---

### [Lab 08: Docker Network Security (5 Scenarios)](./labs/08-network-security/)

**What You'll Learn:**
- Implement network isolation between containers
- Design multi-tier segmented architectures
- Use internal networks for complete database isolation
- Configure TLS encryption for container-to-container communication
- Identify and fix 8 common network misconfigurations

**5 Interactive Scenarios:**

**Scenario 1: Network Isolation** (3-4 minutes)
- Create isolated networks with DNS resolution
- Implement gateway containers spanning multiple networks
- Understand network boundaries

**Scenario 2: Multi-Tier Segmentation** (4-5 minutes)
- Design 3-tier architecture (web/app/database)
- Force traffic through monitored gateways
- Prevent direct web-to-database access

**Scenario 3: Internal Networks** (3-4 minutes)
- Use internal networks with no external gateway
- Achieve complete database isolation
- Meet PCI DSS and HIPAA requirements

**Scenario 4: TLS Encryption** (4-5 minutes)
- Generate self-signed certificates
- Configure nginx with TLS
- Implement encrypted container communication
- Understand TLS performance implications

**Scenario 5: Common Misconfigurations** (3-4 minutes)
- Learn 8 common network security mistakes:
  1. Using default bridge network (no DNS)
  2. Using `--network host` (bypasses security)
  3. Exposing unnecessary ports (databases)
  4. No resource limits (DoS risk)
  5. Running as root
  6. Using `--privileged` mode
  7. Flat network architecture
  8. No health checks

**Key Concepts:**
- Defense in depth
- Network segmentation
- Zero-trust architecture
- TLS/mTLS implementation
- Resource management
- Security misconfiguration prevention

**Time:** 18-22 minutes (all scenarios) or 3-5 minutes each

**Why This Matters:**
- Prevents lateral movement during breaches
- Meets compliance requirements
- Protects sensitive data in transit
- Enables zero-trust architectures
- Real-world production patterns

---

### Level 3: Red Team / Offensive Security (Lab 09)

Hands-on container escape scenarios — understanding how attackers break out of containers.

---

### [Lab 09: Docker Runtime Escape (5 Scenarios)](./labs/09-runtime-escape/)

**What You'll Learn:**
- Execute 5 real container escape techniques in a controlled environment
- Understand why blocking docker.sock alone is not sufficient
- Implement runtime detection with Falco and admission control with Kyverno
- Audit containers for dangerous configurations that standard scans miss

**5 Escape Scenarios:**

**Scenario 1: Docker Socket Escape** (25 min)
- Mount docker.sock → install Docker CLI → create privileged container → mount host / → chroot to host root
- The most common escape in production (Jenkins, Portainer, DinD, Watchtower)

**Scenario 2: Privileged Container Escape** (15 min)
- 5 demonstrations: capability comparison, host filesystem via block device, network namespace escape, cgroup release_agent (Felix Wilhelm technique), detection
- `--privileged` disables every security boundary simultaneously

**Scenario 3: CAP_SYS_ADMIN Abuse** (20 min)
- Single capability that enables 30+ system operations including mount and namespace manipulation
- Passes standard security audits (`Privileged: false`) while providing near-privileged access

**Scenario 4: Host Path Mount Abuse** (15 min)
- `/etc` bind mount reads credentials directly; docker.sock escalation chain (two containers cooperating)
- Risk-classified audit: CRITICAL (docker.sock), HIGH (/etc), MEDIUM (system paths)

**Scenario 5: /proc and /sys Exposure** (15 min)
- Reconnaissance: kernel version → CVE targeting, network data → lateral movement, process list → service discovery
- Read-only mounts prevent writes but not information disclosure

**Key Concepts:**
- Container isolation boundaries and how each is broken
- The audit gap: what scanners check vs what attackers exploit
- Defense-in-depth: Falco rules, Kyverno admission policies, audit scripts
- Docker Desktop vs Linux host behavioral differences

**Defense Artifacts Generated:**
- Falco runtime detection rules (Scenarios 3, 4, 5)
- Kyverno admission policies (Scenarios 4, 5)
- Audit scripts with risk classification (Scenarios 2, 3, 4, 5)

**Time:** 2-2.5 hours (all scenarios) or 15-25 minutes each

**Why This Matters:**
- Blocking docker.sock and --privileged is necessary but not sufficient
- CAP_SYS_ADMIN, host mounts, and /proc are the blind spots attackers use next
- Runtime detection rules generated here are production-ready

---

### Level 4: Production Security (Lab 10-11)

Advanced production security patterns for secret management.

---

### [Lab 10: Docker Secrets Management (5 Scenarios)](./labs/10-secrets-management/)

**What You'll Learn:**
- Identify 5 common secret leakage patterns in Docker environments
- Implement Docker Swarm native secrets with encrypted storage
- Integrate HashiCorp Vault for centralized secret management
- Use BuildKit secret mounts for build-time credentials
- Scan repositories for leaked secrets with automated tools
- Prevent secret commits using pre-commit hooks and CI/CD integration

**Key Concepts:**
- Anti-patterns: hardcoded secrets, ENV vars, build args, git history leaks
- Docker Swarm secrets: encrypted at rest, in-memory tmpfs mounts
- External secret management: Vault dev mode and production patterns
- BuildKit secret mounts: build-time secrets that never persist
- Secret scanning: GitLeaks, pre-commit hooks, CI/CD integration

**5 Interactive Scenarios:**

**Scenario 1: Anti-Patterns** (15 min)
- Demonstrate 5 ways secrets leak in Docker containers
- Hardcoded secrets visible in `docker history`
- Environment variables exposed in `docker inspect`
- Build arguments persisting in image layers
- Mounted files with wrong permissions (world-readable)
- Git history leaks (permanent even after deletion)

**Scenario 2: Docker Swarm Secrets** (20 min)
- Create and manage secrets via Swarm CLI
- Deploy services with secret mounts at `/run/secrets/`
- Verify secrets NOT visible in `docker inspect` (metadata only)
- Understand encrypted storage and tmpfs security properties
- Compare with anti-patterns (ENV vars vs Swarm secrets)

**Scenario 3: HashiCorp Vault Integration** (25 min)
- Run Vault in dev mode (containerized, macOS compatible)
- Store and retrieve secrets via CLI and HTTP API
- Integrate applications with Vault at runtime
- Understand centralized secret management
- Compare Vault vs Swarm secrets (environment flexibility)

**Scenario 4: BuildKit Secret Mounts** (15 min)
- Pass secrets to builds without ARG leakage
- Access private npm/pip registries during build
- Use SSH keys for private git repos during build
- Implement multi-stage builds with secret isolation
- Verify secrets don't persist in final image or history

**Scenario 5: Secret Scanning** (15 min)
- Scan repositories for leaked secrets with GitLeaks
- Detect secrets in git history (even after deletion)
- Set up pre-commit hooks to prevent secret commits
- Integrate secret scanning in CI/CD pipelines (GitHub Actions, Azure DevOps)
- Create custom detection rules for company-specific secrets

**Time:** 90 minutes (all scenarios) or 15-25 minutes each

**Why This Matters:**
- Secrets in git are permanent (even after deletion)
- Environment variables leak through docker inspect and logs
- BuildKit secrets enable secure builds without image pollution
- Automated scanning prevents accidental commits
- Multi-layered approach (Swarm + Vault + scanning) for production

### [Lab 11: Docker MCP Gateway for AI-Powered Container Remediation](./labs/11-docker-mcp-gateway/)

**What You'll Learn:**
- Build an AI-powered Docker container management system using Model Context Protocol (MCP)
- Integrate AutoGen multi-agent framework with GPT-4 for decision-making
- Implement automated container failure detection and remediation
- Create production-grade security pipelines (HMAC auth, rate limiting, audit logging)
- Design intelligent escalation policies (auto-fix vs human intervention)

**Key Concepts:**
- Model Context Protocol (MCP) - standardized tool interface for AI agents
- AutoGen framework - multi-agent conversation and tool execution
- Docker API integration - logs, restart, resource updates
- AI decision-making - context-aware remediation vs escalation
- Security pipeline - authentication, rate limiting, input validation, audit trail
- Production patterns - read-only filesystems, non-root users, health checks

**4 Interactive Scenarios:**

**Scenario 1: OOMKilled Auto-Remediation** (5 min)
- Container killed due to out-of-memory
- Agent detects OOMKilled (exit code 137)
- Agent increases memory limit by 50-100%
- Validates: Smart resource scaling based on failure analysis

**Scenario 2: CrashLoopBackOff Escalation** (5 min)
- Container crashes immediately on startup (config/code bug)
- Agent recognizes: Restart won't fix it
- Agent escalates to human with log details
- Validates: Conservative decision-making for complex issues

**Scenario 3: Exit Code Analysis** (5 min)
- Container exits with error (database connection failed)
- Agent attempts restart (reasonable for network errors)
- Container still exits → Agent escalates
- Validates: Smart retry logic with escalation fallback

**Scenario 4: Health Check Failure** (5 min)
- Container running but failing health checks (app deadlock)
- Agent restarts unhealthy container
- Validates: Auto-recovery for stuck/deadlocked applications

**Architecture:**
```
Docker Failure → AutoGen Agent (GPT-4) → MCP Server (Security Pipeline) → Docker API
                                              ↓
                                     HMAC Auth → Rate Limit → Validate → Audit
```

**Technologies:**
- **AutoGen** (pyautogen 0.1.14) - Multi-agent framework
- **OpenAI GPT-4** - Decision-making and reasoning
- **Model Context Protocol (MCP)** - Standardized tool interface
- **Docker API** - Container management (logs, restart, update)
- **Redis** - Rate limiting (100 req/hour per agent)
- **Flask** - MCP server implementation

**Security Features:**
- HMAC signature authentication
- Redis-backed rate limiting
- Input validation (injection protection)
- Complete audit trail (JSON logging)
- Multi-stage Docker builds
- Non-root execution (UID 1000)
- Read-only filesystems with tmpfs
- Capability dropping
- Resource limits

**Time:** 60-90 minutes (setup + 4 scenarios)

**Why This Matters:**
- Reduces on-call burden by automating common container failures
- Demonstrates AI-powered infrastructure automation
- Implements production-grade security patterns
- Shows when to auto-remediate vs escalate to humans
- First Docker MCP Gateway implementation in open source

**Prerequisites:**
- Docker Desktop or Docker Engine
- OpenAI API key (GPT-4 access)
- 8GB RAM minimum
- Understanding of Docker API basics

**What You'll Build:**
- MCP server with 3 Docker tools (logs, restart, resource update)
- AutoGen AI agent with context-aware decision-making
- Security pipeline with authentication and rate limiting
- Complete audit trail system
- 4 production-ready test scenarios

---

### Level 5: Trust Governance (Lab 12)

### [Lab 12: Docker Hardened Images as a Container Trust Control Plane](./labs/12-docker-hardened-images/)

**What You'll Learn:**
- Build a complete container trust control plane on top of Docker Hardened Images
- Enforce vendor-neutral admission policies with Kyverno (registry, signature, SBOM)
- Implement keyless cosign signing in GitHub Actions with verifiable supply chain attestations
- Operate distroless containers in production with three documented debug patterns
- Run a 12-service synthetic fleet audit demonstrating drift observation at scale
- Apply the substitution test: prove the architecture works with Chainguard, self-built distroless, or any signing primitive

**Key Concepts:**
- Three-layer model: Supply Chain → Trust → Enforcement, joined by an observable control loop
- Vendor-neutral policy primitives — policies enforce "trusted registry," not "DHI specifically"
- Phased rollout: Enforce mode for registry origin, Audit mode for signature/SBOM during migration
- Break-glass exception pattern via Kyverno PolicyException with namespace-label gates
- Keyless cosign signing using GitHub OIDC (no private keys to manage, rotate, or leak)
- DHI substitution test: same architecture works with any hardened image foundation

**5 Hypothesis-Driven Experiments (H/E/O/C format):**

**E1: Drift Observation** (15 min)
- 12-service synthetic fleet with explicit variation matrix (origin × signing × patch age)
- `audit-fleet.sh` produces risk-graded inventory (CRITICAL/HIGH/MEDIUM/LOW/OK)
- `analyze-drift.py` 7-section deep analysis report
- Headline finding: unsigned services average 130× more critical CVEs than signed_verified
- Validates: Image-level controls collapse without fleet-wide enforcement

**E2: Trust Provenance Verification** (10 min)
- `verify-image.sh` validates four trust signals on real DHI images
- Attestation discovery → CycloneDX SBOM → SLSA provenance v0.2 → OpenVEX
- Uses `docker scout attest get --verify --skip-tlog` with cosign-equivalent verification
- Demonstrates: DHI signatures live at `registry.scout.docker.com/docker/dhi-*`, not conventional location
- Validates: Image trust requires four signals, not one

**E3: Admission Enforcement** (15 min)
- Vendor-neutral Kyverno policies: trusted-registry (Enforce), signature (Audit), SBOM (Audit)
- Break-glass exception via PolicyException with `trust.governance.io/break-glass-approved` label
- Three demonstrated patterns: strict enforcement, phased Audit rollout, audited bypass
- Empirical result: Kubernetes admission webhook rejects nginx, admits dhi.io/python, allows break-glass
- Validates: Build-time security collapses if runtime admission lacks teeth

**E4: Supply Chain Gates** (workflow runs ~5 min on push)
- GitHub Actions workflow with keyless cosign signing via GitHub OIDC
- 18-step pipeline: build → push → sign → SBOM attest → vuln scan attest → verify
- Image pushed to ghcr.io with three cryptographic attestations, verifiable by anyone
- Companion: `generate-sbom-delta.sh` computes package delta vs DHI base
- Validates: Without build-time gates, runtime enforcement absorbs failures

**E5: Runtime Failure Modes** (documentation + walkthroughs)
- Answers the "no shell at 2 AM" operational objection to distroless
- Three patterns: ephemeral debug containers, dev-variant pattern, debug sidecar
- Three runbook scenarios: unreachable service, crashloop, OOM kill
- `restrict-dev-variants` policy: `-dev` variants admitted only in `environment=dev` namespaces
- Validates: Distroless is operationally viable with patterns that preserve the trust contract

**Architecture:**
```
                              The Control Loop
              ┌──────────────────────────────────────────────┐
              ▼                                              │
    ┌─────────────────┐    ┌─────────────────┐    ┌──────────┴────────┐
    │   Supply Chain  │───▶│      Trust      │───▶│    Enforcement    │
    │      Layer      │    │      Layer      │    │       Layer       │
    │     (E4)        │    │     (E2)        │    │       (E3)        │
    └─────────────────┘    └─────────────────┘    └─────────┬─────────┘
              ▲                                              │
              │       Operations: drift (E1), failure modes (E5)
              └──────────────────────────────────────────────┘
```

**Technologies:**
- **Docker Hardened Images (DHI)** — hardened base images with signed SBOM + SLSA + VEX attestations
- **Kyverno 3.3.4** — Kubernetes-native policy engine for admission control
- **Cosign 2.4.1** — signature and attestation tooling (keyless via Sigstore)
- **Syft + Grype** — CycloneDX SBOM generation and vulnerability scanning
- **kind 0.31.0** — local Kubernetes for the lab environment
- **GitHub Actions** — CI/CD with keyless OIDC signing

**Trust Contract Enforced:**
Any pod admitted to the cluster must satisfy four conditions:
1. **Origin** — image from allow-listed registry
2. **Signature** — image has valid cosign signature
3. **Provenance** — image has verifiable CycloneDX SBOM attestation
4. **Vulnerability scan** — image has signed vulnerability scan attestation

**Time:** 90–120 minutes (setup + 5 experiments)

**Why This Matters:**
- Container security failures in regulated environments are governance failures, not image failures
- Demonstrates the architectural pattern that turns hardened images into security outcomes
- Vendor-neutral framing: the same patterns work with Chainguard, self-built distroless, or other primitives
- Includes a substantive [troubleshooting log](./labs/12-docker-hardened-images/docs/troubleshooting.md) documenting real friction points encountered during the build
- Production-grade: includes phased migration playbook, compliance mapping (PCI-DSS 4.0 §6.3, 21 CFR Part 11), and break-glass patterns

**Prerequisites:**
- Docker Desktop with at least 4 CPU / 6 GB RAM
- `docker login dhi.io` (free tier suffices)
- Tools: `kind`, `kubectl`, `helm`, `jq`, `cosign`, `syft` (install via `brew install`)
- GitHub repository for E4 (or skip E4's pipeline run; the YAML is the artifact)

---


## 🚀 Getting Started

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Linux, macOS, or Windows with WSL2
- Basic Docker knowledge
- Terminal/command line familiarity

### Quick Start

1. **Clone the repository:**
```bash
git clone https://github.com/opscart/docker-security-practical-guide.git
cd docker-security-practical-guide
```

2. **Start with Lab 01:**
```bash
cd labs/01-docker-bench-security
./run-audit.sh
```

3. **Follow along with the README in each lab directory**

## 📖 How to Use This Guide

### For Beginners

1. Start with Lab 01 to understand security auditing
2. Progress sequentially through Level 1 (Labs 01-06)
3. Complete all exercises before moving forward
4. Review the "Common Issues" sections
5. Move to Level 2 (Labs 07-08) for advanced topics

### For Experienced Users

1. Jump to specific labs based on your needs
2. Use as a reference for security patterns
3. Adapt examples to your use cases
4. Focus on Level 2 labs for advanced techniques
5. Contribute improvements via pull requests

### For Security Auditors

1. Use Lab 01 for baseline security assessments
2. Reference CIS Benchmark mappings
3. Lab 07 for supply chain compliance
4. Lab 08 for network architecture reviews
5. Adapt checklists for your compliance needs
6. Document findings using provided templates

### For DevOps/Platform Engineers

1. Lab 07 for CI/CD security integration
2. Lab 08 for production network architecture
3. Use automation scripts in your pipelines
4. Implement security best practices from all labs

## 🔧 Lab Setup

Each lab is self-contained and includes:

- `README.md`: Comprehensive guide with theory and practice
- `docker-compose.yml`: Ready-to-run configurations
- Scripts: Automation for common tasks
- Examples: Both vulnerable and secure configurations
- CI/CD configs: Azure DevOps and GitHub Actions (Labs 07-08)

### Running a Lab

```bash
# Navigate to lab directory
cd labs/XX-lab-name

# Review the README
cat README.md

# Run the lab exercise
./run-demo.sh  # or specific lab script

# Clean up
./cleanup.sh
```

## 🎓 Learning Path

### Level 1: Fundamentals
```
Lab 01: Security Auditing (CIS Benchmark)
    ↓
Lab 02: Secure Configurations (Capabilities, Read-only FS)
    ↓
Lab 03: Least Privilege (Non-root, Resource Limits)
    ↓
Lab 04: Image Signing (Cosign, Content Trust)
    ↓
Lab 05: Network Security Basics (Custom Networks)
    ↓
Lab 06: AI/ML Security (Model Protection)
```

### Level 2: Advanced
```
Lab 07: Supply Chain Security
         (SBOM, Vulnerability Scanning)
    ↓
Lab 08: Network Security
         (5 Scenarios: Isolation to Encryption)
```

### Level 3: Red Team
```
Lab 09: Runtime Escape
         (5 Scenarios: Socket to /proc)
```

### Level 4: Production Security
```
Lab 10: Secret Managment
Lab 11: Docker MCP Gateway for AI-Powered Container Remediation
```

### Level 5: Trust Governance (Lab 12)
```
Lab 12: Docker Hardened Images as a Container Trust Control Plane
    **5 Hypothesis-Driven Experiments (H/E/O/C format):**
        **E1: Drift Observation** 
        *E2: Trust Provenance Verification**
        *E3: Admission Enforcement**
        **E4: Supply Chain Gates**
        **E5: Runtime Failure Modes**
```

**Estimated Time:** 
- Level 1 (Labs 01-06): 4-6 hours
- Level 2 (Labs 07-08): 2-3 hours
- Level 3 (Lab 09): 2-2.5 hours
- Level 4 (Lab 10-11): 2-2.5 hours
- Level 5 (Lab 12):1.5-2 hours
- Complete guide: 11.5-13 hours
- With practice exercises: 15-19 hours


## 🛠️ Tools & Technologies

### Security Tools Used

**Level 1:**
- **Docker Bench Security**: CIS compliance auditing
- **Trivy**: Vulnerability scanning
- **Cosign**: Container signing
- **Anchore**: Image analysis
- **Notary**: Content trust

**Level 2:**
- **Syft**: SBOM generation (Lab 07)
- **Grype**: Vulnerability scanning (Lab 07)
- **OpenSSL**: Certificate generation (Lab 08)
- **nginx**: TLS configuration (Lab 08)

### Technologies Covered

- Docker Engine & Docker Compose
- Linux Security Modules (AppArmor, SELinux)
- Seccomp profiles
- User namespaces
- Capability systems
- Docker networking (bridge, internal, overlay)
- TLS/mTLS encryption
- CI/CD integration (Azure DevOps, GitHub Actions)

## 📝 Best Practices Summary

### Image Security
- Use minimal base images (alpine, distroless)
- Scan for vulnerabilities regularly
- Generate and maintain SBOMs (Lab 07)
- Sign and verify images (Lab 04)
- Use specific tags, never `latest`
- Implement multi-stage builds

### Runtime Security
- Run as non-root user (Lab 03)
- Drop unnecessary capabilities (Lab 02)
- Use read-only filesystems (Lab 02)
- Enable security profiles
- Set resource limits (Lab 08)
- Implement health checks (Lab 08)

### Network Security
- Use custom bridge networks (Lab 08)
- Implement multi-tier segmentation (Lab 08)
- Use internal networks for databases (Lab 08)
- Avoid host network mode (Lab 08)
- Encrypt traffic with TLS (Lab 08)
- Control ingress/egress

### Supply Chain Security (Lab 07)
- Generate SBOMs for all images
- Scan regularly for vulnerabilities
- Track dependency changes
- Automate in CI/CD pipelines
- Meet compliance requirements
- Respond quickly to CVEs

### Secrets Management
- Never hardcode credentials
- Use Docker secrets or external vaults
- Rotate secrets regularly
- Limit secret access scope
- Audit secret usage

### Operational Security
- Regular security audits (Lab 01)
- Keep Docker updated
- Monitor container behavior
- Log security events
- Incident response plan
- Track SBOM and vulnerability changes (Lab 07)

## 🏗️ Architecture Patterns

### Multi-Tier Segmentation (Lab 08)
```
┌──────────────┐       ┌──────────────┐       ┌─────────────────┐
│  Public Net  │       │   App Net    │       │  Database Net   │
│              │       │              │       │   (INTERNAL)    │
│    [Web]     │◄─────►│    [App]     │◄─────►│      [DB]       │
│   :8443      │  TLS  │              │       │   No Gateway    │
└──────────────┘       └──────────────┘       └─────────────────┘
     ▲
     │
  Internet
```

### Supply Chain Security (Lab 07)
```
[Container] → [Syft] → [SBOM] → [Grype] → [Security Report]
                ↓
        [SPDX/CycloneDX/JSON]
                ↓
           [CVE Database]
                ↓
        [Critical/High/Medium/Low]
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add your improvements
4. Test thoroughly
5. Submit a pull request

### Contribution Ideas

- Additional lab exercises
- Security tool integrations
- Cloud platform examples (AWS, Azure, GCP)
- Kubernetes security labs
- Advanced threat scenarios
- Additional SBOM formats
- More network security patterns

## 📚 Additional Resources

### Official Documentation
- [Docker Security](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Docker Bench Security](https://github.com/docker/docker-bench-security)
- [Syft (SBOM Generation)](https://github.com/anchore/syft)
- [Grype (Vulnerability Scanning)](https://github.com/anchore/grype)

### Security Standards
- [NIST Container Security](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)
- [OWASP Docker Top 10](https://owasp.org/www-project-docker-top-10/)
- [CIS Controls](https://www.cisecurity.org/controls)
- [Executive Order 14028](https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/) - SBOM Requirements

### SBOM Resources (Lab 07)
- [SPDX Specification](https://spdx.dev/)
- [CycloneDX Standard](https://cyclonedx.org/)
- [CISA SBOM Resources](https://www.cisa.gov/sbom)
- [NTIA SBOM Minimum Elements](https://www.ntia.gov/report/2021/minimum-elements-software-bill-materials-sbom)

### Network Security Resources (Lab 08)
- [Docker Network Documentation](https://docs.docker.com/network/)
- [Container Network Security](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [TLS Best Practices](https://wiki.mozilla.org/Security/Server_Side_TLS)

### Community Resources
- [Docker Security Subreddit](https://reddit.com/r/docker)
- [Docker Community Slack](https://dockercommunity.slack.com)
- [Stack Overflow Docker Tag](https://stackoverflow.com/questions/tagged/docker)
- [CNCF Slack](https://slack.cncf.io/)

## 🐛 Troubleshooting

### Common Issues

**Issue: Permission denied running scripts**
```bash
chmod +x script-name.sh
```

**Issue: Docker daemon not running**
```bash
sudo systemctl start docker
```

**Issue: Port already in use**
```bash
docker ps  # Check running containers
docker-compose down  # Stop services
lsof -i :PORT  # Find process using port
```

**Issue: Image pull failures**
```bash
docker login  # Authenticate if needed
docker pull image-name  # Manual pull to test
```

**Issue: Syft/Grype not found (Lab 07)**
```bash
# Install Syft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Install Grype
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
```

**Issue: Certificate generation fails (Lab 08)**
```bash
# Ensure OpenSSL is installed
openssl version

# Check certificate generation script
cd labs/08-network-security/certs
chmod +x generate-certs.sh
./generate-certs.sh
```

**Issue: Network already exists (Lab 08)**
```bash
# Clean up all networks
cd labs/08-network-security
./cleanup.sh
```

## 📊 Lab Completion Status

Track your progress:

- [ ] Lab 01: Security Auditing ⏱️ 30-45 min
- [ ] Lab 02: Secure Configurations ⏱️ 45-60 min
- [ ] Lab 03: Least Privilege ⏱️ 30-45 min
- [ ] Lab 04: Image Signing ⏱️ 45-60 min
- [ ] Lab 05: Network Security Basics ⏱️ 30-45 min
- [ ] Lab 06: AI/ML Security ⏱️ 60-90 min
- [ ] Lab 07: Supply Chain Security (SBOM) ⏱️ 45-60 min
- [ ] Lab 08: Network Security (5 Scenarios) ⏱️ 18-22 min
- [ ] Lab 09: Runtime Escape (5 Scenarios) ⏱️ 2-2.5 hrs
- [ ] Lab 10: Secrets Management (5 Scenarios) ⏱️ 90 min
- [ ] Lab 11: Docker MCP Gateway (AI-Powered Remediation) ⏱️ 60-90 min

**Total Time:** 11.5-14 hours

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details

## ✨ Acknowledgments

- Docker team for security tools and documentation
- CIS for the Docker Benchmark
- OWASP for security guidelines
- Anchore team for Syft and Grype (Lab 07)
- Sigstore project for Cosign (Lab 04)
- Open source security community
- CNCF for cloud native security standards

## 📧 Contact & Support

- **Author**: Shamsher Khan
- **GitHub**: [@opscart](https://github.com/opscart)
- **Blog**: [@OpsCart](https://opscart.com)
- **Issues**: [Report issues](https://github.com/opscart/docker-security-practical-guide/issues)
- **Discussions**: [GitHub Discussions](https://github.com/opscart/docker-security-practical-guide/discussions)

### Professional Background
- Senior DevOps Engineer
- IEEE Senior Member
- 15+ years IT experience
- 10+ years Cloud & DevOps specialization
- Published author on DZone and technical publications

## 🌟 Star This Repository!

If you find this guide helpful:
1. ⭐ Star the repository
2. 🔀 Fork for your own learning
3. 📢 Share with your team
4. 💬 Provide feedback
5. 🤝 Contribute improvements


### Stay Updated

- Watch this repository for updates
- Follow [@opscart](https://github.com/opscart) on GitHub
- Join discussions in the Issues tab

---

**🎯 From fundamentals to advanced patterns, this guide has everything you need to secure your Docker deployments in production.**

---

**⭐ If you find this guide helpful, please star the repository!**

**🔒 Remember: Security is a journey, not a destination. Keep learning, keep improving!**
