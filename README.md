[![License](https://img.shields.io/github/license/opscart/docker-security-practical-guide)](./LICENSE)
[![Stars](https://img.shields.io/github/stars/opscart/docker-security-practical-guide?style=social)](https://github.com/opscart/docker-security-practical-guide/stargazers)
[![Last commit](https://img.shields.io/github/last-commit/opscart/docker-security-practical-guide)](https://github.com/opscart/docker-security-practical-guide/commits/master)
[![Supply Chain Gate](https://github.com/opscart/docker-security-practical-guide/actions/workflows/supply-chain-gate.yml/badge.svg?branch=master)](https://github.com/opscart/docker-security-practical-guide/actions/workflows/supply-chain-gate.yml)


# Docker Security: A Practical Guide

A hands-on Docker and container security guide built around reproducible labs, attack scenarios, defensive controls, and production-oriented validation.

<a id="what-youll-learn"></a>
## What You'll Learn

The repository progresses from foundational Docker hardening to runtime escape analysis, secrets management, software supply-chain trust, AI-assisted remediation, and AI context-poisoning defenses.

<a id="core-topics-covered"></a>
### Core Topics Covered

- **Security auditing:** Docker Bench Security and CIS-aligned checks
- **Container hardening:** least privilege, Linux capabilities, read-only filesystems, and resource controls
- **Vulnerability management:** Trivy, Syft, Grype, SBOMs, and policy enforcement
- **Image trust:** Cosign signing, provenance, attestations, and admission controls
- **Seccomp:** application-specific syscall filtering
- **Network security:** segmentation, internal networks, TLS, and misconfiguration testing
- **Runtime security:** Docker socket exposure, privileged containers, dangerous capabilities, host mounts, and `/proc` or `/sys` exposure
- **Secrets management:** Docker Swarm secrets, Vault, BuildKit secrets, secret scanning, and audit evidence
- **AI workload security:** ML container controls, secured MCP tool access, and AI context-poisoning defenses
- **Trust governance:** hardened images, Kyverno policies, signed attestations, and fleet drift analysis

<a id="opscart-labs-platform"></a>
## OpsCart Labs Platform

This guide is part of [OpsCart Labs](https://opscart.com/labs/), a collection of open-source, hands-on labs informed by production cloud and Kubernetes operations.

<a id="available-lab-series"></a>
### Available Lab Series

**Docker Security: A Practical Guide** — this repository

- 13 labs covering Docker security from auditing through AI context defense
- Reproducible scripts, configurations, policies, and captured experiment evidence
- Status: active development

**[Certified Kubernetes Administrator Exam Prep](https://github.com/opscart/production-cka)**

- Hands-on CKA preparation labs
- Automated validation and operational notes
- Status: active development

<a id="why-opscart-labs"></a>
### Why OpsCart Labs?

- Built from practical Docker, Kubernetes, cloud, and DevOps experience
- Designed around reproducible scenarios rather than theory alone
- Maintained in public Git repositories
- Intended for engineers, security practitioners, auditors, and platform teams

<a id="documentation-hub"></a>
## Documentation Hub

Use this section as the central entry point for the repository.

| Area | Purpose |
|---|---|
| [Lab Catalog](#lab-catalog) | Select a hands-on lab by security domain or learning level |
| [Publications and Research](./docs/publications-and-research.md) | Connect formal research, CNCF publications, practitioner articles, and implementation evidence |
| [Additional Resources](./docs/additional-resources.md) | Browse official documentation, standards, security tools, and primary research |
| [Setup Guide](./docs/setup-guide.md) | Prepare Docker, shared tooling, and the common lab environment |
| [Troubleshooting Guide](./docs/troubleshooting.md) | Diagnose shared Docker, Compose, networking, tooling, and Kubernetes problems |
| [Repository Issues](https://github.com/opscart/docker-security-practical-guide/issues) | Report broken links, reproducibility problems, or documentation corrections |

### Suggested Routes

- **New to the repository:** [Setup Guide](./docs/setup-guide.md) → [Lab Catalog](#lab-catalog) → Lab 01
- **Docker or container security practitioner:** [Lab Catalog](#lab-catalog) → Labs 02–10
- **Supply-chain or platform engineer:** Labs 03, 04, 07, 10, and 12
- **AI and agent-security reader:** Labs 06, 11, and 13
- **Research or publication reader:** [Publications and Research](./docs/publications-and-research.md)
- **Looking for authoritative references:** [Additional Resources](./docs/additional-resources.md)
- **A lab failed:** Lab README → [Troubleshooting Guide](./docs/troubleshooting.md) → repository issue

<a id="lab-structure"></a>
<a id="lab-catalog"></a>

## Companion Projects

Some topics evolve independently of this repository or require deeper experimentation than fits within the Docker Security Guide. These companion repositories provide verified implementations, extended experiments, and specialized documentation.

| Project | Description |
|----------|-------------|
| [Docker Sandbox DevOps](https://github.com/opscart/docker-sandbox-devops) | Dedicated companion repository for Docker Sandboxes, AI coding-agent isolation, Kubernetes debugging, and DevOps toolkit experiments. |

## Lab Catalog

Each lab has its own README with prerequisites, detailed steps, validation, expected results, and cleanup instructions. The root README intentionally provides a concise catalog so lab-specific documentation remains the source of truth.

<a id="level-1-fundamentals-labs-01-06"></a>
### Level 1: Foundations (Labs 01–06)

<a id="lab-01-security-auditing-with-docker-bench"></a>
#### [Lab 01: Security Auditing with Docker Bench](./labs/01-docker-bench-security/)

Run Docker Bench Security, interpret CIS-aligned findings, identify dangerous configurations, and review practical remediations.

**Estimated time:** 30–45 minutes

<a id="lab-02-secure-container-configurations"></a>
#### [Lab 02: Secure Container Configurations](./labs/02-secure-configs/)

Compare insecure and hardened configurations using capability controls, read-only filesystems, `tmpfs`, non-root execution, and `no-new-privileges`.

**Estimated time:** 45–60 minutes

<a id="lab-03-least-privilege-containers"></a>
<a id="lab-03-vulnerability-scanning-pipeline"></a>
#### [Lab 03: Vulnerability Scanning Pipeline](./labs/03-vulnerability-scanning/)

Scan images with Trivy, generate SBOMs with Syft, analyze them with Grype, and enforce vulnerability policy with OPA.

**Estimated time:** 60–90 minutes

<a id="lab-04-image-signing-and-verification"></a>
#### [Lab 04: Image Signing and Verification](./labs/04-image-signing/)

Sign and verify images with Cosign, examine content trust, manage signing keys, and enforce image-signing policy.

**Estimated time:** 45–60 minutes

<a id="lab-05-network-security-basics"></a>
<a id="lab-05-custom-seccomp-profiles"></a>
#### [Lab 05: Custom Seccomp Profiles](./labs/05-seccomp-profiles/)

Understand Linux syscalls, examine Docker's default seccomp behavior, generate restrictive profiles, and validate them without breaking workloads.

**Estimated time:** 90–120 minutes

<a id="lab-06-ai-model-security"></a>
#### [Lab 06: AI Model Security](./labs/06-ai-model-security/)

Harden containerized ML inference with resource controls, input validation, monitoring, and Kubernetes security settings.

**Estimated time:** 60–90 minutes

<a id="level-2-advanced-security-labs-07-08"></a>
### Level 2: Supply Chain and Network Security (Labs 07–08)

<a id="lab-07-supply-chain-security-with-sbom"></a>
#### [Lab 07: Supply Chain Security with SBOM](./labs/07-supply-chain-sbom/)

Generate and compare SBOMs, scan them for vulnerabilities, and integrate supply-chain checks into GitHub Actions and Azure Pipelines.

**Estimated time:** 45–60 minutes

<a id="lab-08-docker-network-security-5-scenarios"></a>
#### [Lab 08: Docker Network Security — 5 Scenarios](./labs/08-network-security/)

Practice network isolation, multi-tier segmentation, internal networks, TLS encryption, and common network-misconfiguration remediation.

**Estimated time:** 18–22 minutes

<a id="level-3-red-team--offensive-security-lab-09"></a>
### Level 3: Runtime Escape and Defense (Lab 09)

<a id="lab-09-docker-runtime-escape-5-scenarios"></a>
#### [Lab 09: Docker Runtime Escape — 5 Scenarios](./labs/09-runtime-escape/)

Explore Docker socket escape, privileged containers, `CAP_SYS_ADMIN`, host mounts, and `/proc` or `/sys` exposure, then apply Falco, Kyverno, and audit-script defenses.

> Run offensive scenarios only in an isolated disposable environment. Do not use a production host.

**Estimated time:** 2–2.5 hours

<a id="level-4-production-security-lab-10-11"></a>
### Level 4: Production Security and Controlled Remediation (Labs 10–11)

<a id="lab-10-docker-secrets-management-5-scenarios"></a>
<a id="lab-10-docker-secrets-management-6-scenarios"></a>
#### [Lab 10: Docker Secrets Management — 6 Scenarios](./labs/10-secrets-management/)

Study secret leakage anti-patterns, Docker Swarm secrets, Vault integration, BuildKit secret mounts, repository scanning, and audit/compliance evidence.

**Scenarios:**

1. Secret-management anti-patterns
2. Docker Swarm secrets
3. HashiCorp Vault integration
4. BuildKit secrets
5. Secret scanning
6. Audit and compliance

**Estimated time:** approximately 90 minutes

<a id="lab-11-docker-mcp-gateway-for-ai-powered-container-remediation"></a>
#### [Lab 11: Docker MCP Gateway for AI-Powered Container Remediation](./labs/11-docker-mcp-gateway/)

Build an AutoGen-based agent that uses GPT-3.5-turbo and a secured MCP server to inspect logs, restart containers, update resources, and escalate unsafe or uncertain remediation decisions.

The security pipeline includes HMAC authentication, Redis-backed rate limiting, input validation, audit logging, non-root execution, read-only filesystems, dropped capabilities, and resource limits.

**Scenarios:** OOM remediation, crash escalation, exit-code retry logic, and health-check recovery.

**Estimated time:** 60–90 minutes

<a id="level-5-trust-governance-lab-12"></a>
### Level 5: Container Trust Governance (Lab 12)

<a id="lab-12-docker-hardened-images-as-a-container-trust-control-plane"></a>
#### [Lab 12: Docker Hardened Images as a Container Trust Control Plane](./labs/12-docker-hardened-images/)

Build a vendor-neutral trust-control architecture using hardened images, Kyverno admission policies, Cosign, SBOM and provenance attestations, phased enforcement, break-glass controls, and fleet drift analysis.

**Experiments:**

1. Drift observation
2. Trust and provenance verification
3. Admission enforcement
4. Supply-chain gates
5. Runtime failure modes

**Estimated time:** 90–120 minutes

### Level 6: AI Context Security (Lab 13)

#### [Lab 13: AI Context Poisoning Detection and Defense](./labs/13-ai-context-poisoning/)

Test zero-width Unicode instruction injection and malicious agent hooks against controlled projects, compare Claude Code and Gemini CLI behavior, and validate Docker Sandboxes as an infrastructure-level defense.

The lab documents two independent defenses:

- Agent-layer detection and refusal
- Sandbox-level filesystem isolation

**Estimated time:** follow the lab README; execution time varies by agent and sandbox environment

<a id="getting-started"></a>
## Getting Started

<a id="prerequisites"></a>
### Prerequisites

Common requirements:

- Docker Engine or Docker Desktop
- Docker Compose v2
- Linux, macOS, or Windows with WSL2
- Basic Docker and command-line knowledge

Some advanced labs additionally require tools such as `kubectl`, `kind`, `helm`, `cosign`, `syft`, `grype`, `jq`, Python, an OpenAI API key, or Docker Sandboxes. Always check the selected lab's README before starting.

<a id="quick-start"></a>
### Quick Start

```bash
git clone https://github.com/opscart/docker-security-practical-guide.git
cd docker-security-practical-guide

cd labs/01-docker-bench-security
cat README.md
./run-audit.sh
```

<a id="how-to-use-this-guide"></a>
## How to Use This Guide

<a id="for-beginners"></a>
### For Beginners

Start with Labs 01–06, then continue according to your goals. Each lab remains self-contained, so you can pause or skip topics that are not relevant to your environment.

<a id="for-experienced-users"></a>
### For Experienced Users

Select labs by threat model:

- Labs 03, 04, 07, and 12 for vulnerability and supply-chain controls
- Labs 05, 08, and 09 for runtime and isolation controls
- Lab 10 for secrets management
- Labs 06, 11, and 13 for AI-related container security

<a id="for-security-auditors"></a>
### For Security Auditors

Use Lab 01 for baseline checks, Labs 03 and 07 for vulnerability and SBOM evidence, Lab 09 for runtime-risk review, Lab 10 for secrets evidence, and Lab 12 for admission and trust-governance controls.

<a id="for-devopsplatform-engineers"></a>
### For DevOps and Platform Engineers

Focus on reusable scripts, CI/CD examples, policies, runtime controls, and migration patterns. Adapt them to your platform only after reviewing each lab's assumptions and safety notes.

<a id="lab-setup"></a>
## Lab Setup

Each lab is self-contained and may include:

- A lab-specific `README.md`
- Setup, execution, validation, and cleanup scripts
- Dockerfiles or Docker Compose configurations
- Kubernetes manifests and policy definitions
- Vulnerable and hardened examples
- Captured experiment evidence
- CI/CD configurations where relevant

<a id="running-a-lab"></a>
### Running a Lab

```bash
cd labs/XX-lab-name
cat README.md

# Run only the commands documented by that lab.
# Cleanup commands also vary by lab.
```

<a id="learning-path"></a>
## Learning Path

```text
Foundations
Labs 01–06
    |
    +--> Supply chain and network security: Labs 07–08
    |
    +--> Runtime escape and defense: Lab 09
    |
    +--> Production security and remediation: Labs 10–11
    |
    +--> Container trust governance: Lab 12
    |
    +--> AI context security: Lab 13
```

**Estimated total:** approximately 14–17 hours, excluding optional extensions, environment setup, repeated experiments, and agent-dependent Lab 13 testing.

<a id="tools--technologies"></a>
## Tools and Technologies

<a id="security-tools-used"></a>
### Security Tools Used

Docker Bench Security, Trivy, Syft, Grype, Cosign, OPA, Kyverno, Falco, Vault, GitLeaks, OpenSSL, Docker Scout, kind, Kubernetes, Redis, Flask, AutoGen, Claude Code, Gemini CLI, and Docker Sandboxes.

<a id="technologies-covered"></a>
### Technologies Covered

Docker Engine, Docker Compose, Linux capabilities, seccomp, user namespaces, read-only filesystems, Docker networking, TLS, CI/CD security gates, SBOMs, provenance, admission control, secrets management, AI tool isolation, and context-poisoning defense.

<a id="best-practices-summary"></a>
## Best-Practices Summary

<a id="image-security"></a>
### Image and Supply-Chain Security

- Use minimal, maintained base images
- Pin versions or digests where reproducibility matters
- Scan images and generate SBOMs
- Sign and verify release images
- Enforce trusted origin, signature, provenance, and vulnerability policy
- Maintain break-glass procedures with auditability

<a id="runtime-security"></a>
### Runtime Security

- Run as a non-root user
- Drop unnecessary capabilities
- Use read-only filesystems and controlled writable mounts
- Apply seccomp and other supported Linux Security Modules
- Set CPU, memory, and PID limits
- Never expose the Docker socket to untrusted workloads

<a id="network-security"></a>
### Network Security

- Use dedicated networks instead of the default bridge
- Segment application tiers
- Restrict unnecessary ingress and egress
- Isolate sensitive services with internal networks
- Encrypt service traffic when required

<a id="supply-chain-security-lab-07"></a>
### Vulnerability and SBOM Management

- Generate SBOMs for release artifacts
- Scan continuously rather than only once
- Define severity and exception policy
- Preserve evidence for audits and incident response
- Track dependency and base-image changes

<a id="secrets-management"></a>
### Secrets Management

- Never commit production credentials
- Avoid hardcoded secrets and build arguments
- Prefer purpose-built secret stores or controlled secret mounts
- Rotate and scope credentials
- Scan repositories and audit access

<a id="operational-security"></a>
### Operational Security

- Monitor runtime behavior
- Record security-sensitive actions
- Maintain tested cleanup and incident-response procedures
- Separate automated remediation from high-risk actions
- Require human approval where confidence or blast radius is unacceptable

<a id="architecture-patterns"></a>
## Architecture References

<a id="multi-tier-segmentation-lab-08"></a>
### Network Segmentation

See [Lab 08 architecture diagrams](./labs/08-network-security/docs/ARCHITECTURE_DIAGRAMS.md) for multi-tier segmentation and encrypted communication patterns.

<a id="supply-chain-security-lab-07-1"></a>
### Supply-Chain Trust

See [Lab 12 architecture](./labs/12-docker-hardened-images/docs/architecture.md) for the Supply Chain → Trust → Enforcement control loop, and [Lab 07](./labs/07-supply-chain-sbom/) for SBOM workflows.

<a id="contributing"></a>
## Contributing

Contributions are welcome:

1. Fork the repository
2. Create a focused branch
3. Test the affected lab
4. Update its documentation
5. Submit a pull request

<a id="contribution-ideas"></a>
### Contribution Ideas

- Additional defensive scenarios
- Cloud-platform implementations
- CI/CD and policy integrations
- Compatibility testing on Linux, macOS, and Windows
- Corrections, reproducibility improvements, and clearer validation

<a id="additional-resources"></a>
## Additional Resources

Detailed external references are maintained in [docs/additional-resources.md](./docs/additional-resources.md).

<a id="official-documentation"></a>
<a id="security-standards"></a>
<a id="sbom-resources-lab-07"></a>
<a id="network-security-resources-lab-08"></a>
<a id="community-resources"></a>

<a id="troubleshooting"></a>
## Troubleshooting

Start with [docs/troubleshooting.md](./docs/troubleshooting.md), then use the selected lab's README or lab-local troubleshooting guide.

<a id="common-issues"></a>
### Common Checks

```bash
docker version
docker compose version
```

For script permission errors:

```bash
chmod +x script-name.sh
```

Do not use generic cleanup commands across all labs. Use the cleanup procedure documented by the selected lab.

<a id="lab-completion-status"></a>

## Lab Completion Checklist

- [ ] Lab 01: Security Auditing
- [ ] Lab 02: Secure Configurations
- [ ] Lab 03: Vulnerability Scanning Pipeline
- [ ] Lab 04: Image Signing and Verification
- [ ] Lab 05: Custom Seccomp Profiles
- [ ] Lab 06: AI Model Security
- [ ] Lab 07: Supply Chain Security with SBOM
- [ ] Lab 08: Docker Network Security
- [ ] Lab 09: Docker Runtime Escape
- [ ] Lab 10: Docker Secrets Management
- [ ] Lab 11: Docker MCP Gateway
- [ ] Lab 12: Container Trust Control Plane
- [ ] Lab 13: AI Context Poisoning Detection and Defense

<a id="license"></a>

## Related Repositories

### Docker Sandbox DevOps

Docker Sandboxes is evolving rapidly. To keep this repository focused on core Docker security while allowing rapid experimentation, advanced Docker Sandbox content is maintained in a dedicated companion repository.

Topics include:

- Docker Sandbox architecture
- microVM isolation
- AI coding agent security
- network policy experiments
- filesystem isolation
- credential isolation
- Kubernetes debugging inside Sandboxes
- custom DevOps toolkit
- verified engineering findings

Repository:

https://github.com/opscart/docker-sandbox-devops

## License

MIT License. See [LICENSE](./LICENSE).

<a id="acknowledgments"></a>
## Acknowledgments

Thanks to the Docker, CIS, OWASP, Anchore, Sigstore, CNCF, and broader open-source security communities whose tools, standards, and documentation support these labs.

<a id="contact--support"></a>

## Contact and Support

- **Author:** Shamsher Khan
- **GitHub:** [@opscart](https://github.com/opscart)
- **Website:** [OpsCart](https://opscart.com)
- **Issues:** [Report a problem or propose an improvement](https://github.com/opscart/docker-security-practical-guide/issues)
- **Discussions:** [GitHub Discussions](https://github.com/opscart/docker-security-practical-guide/discussions)

<a id="professional-background"></a>

### Professional Background

- Senior DevOps Engineer
- IEEE Senior Member
- 15+ years of IT experience
- 10+ years of cloud and DevOps specialization
- Published technical author and CNCF contributor

<a id="star-this-repository"></a>
## Support the Project

Star the repository, share a lab with your team, report reproducibility issues, or contribute a focused improvement.

<a id="stay-updated"></a>
### Stay Updated

Watch the repository and follow [@opscart](https://github.com/opscart) for updates.
