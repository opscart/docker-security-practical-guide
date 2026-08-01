# Publications and Research

This page connects the research, reproducible experiments, open-source implementations, and practitioner publications associated with this repository and the wider OpsCart ecosystem.

The repository remains focused on Docker and container security. Kubernetes research is included where it directly informs container operations, runtime behavior, evidence preservation, or AI-assisted remediation.

## Research Publications

### Operational Memory Architecture for Kubernetes: Evidence Horizon Taxonomy and Extended Causal Pattern Preservation

- **Author:** Shamsher Khan
- **Category:** Distributed, Parallel, and Cluster Computing (`cs.DC`)
- **arXiv:** [2607.02528](https://arxiv.org/abs/2607.02528)
- **DOI:** [10.48550/arXiv.2607.02528](https://doi.org/10.48550/arXiv.2607.02528)
- **Submitted:** May 22, 2026

This extended Operational Memory Architecture paper formalizes five evidence horizons in Kubernetes and adds causal patterns for scheduler evidence, ephemeral debugging, and short-lived workloads that polling-based observability can miss.

**Related implementation and evidence**

- [k8s-causal-memory](https://github.com/opscart/k8s-causal-memory)
- Kubernetes event and watch-based evidence collection
- Scheduler-event and ephemeral-container evidence preservation
- Experiments on Minikube and AKS

**Related publications**

- [What `kubectl debug` Doesn't Tell You: The Silent Evidence Gap](https://www.cncf.io/blog/2026/05/18/what-kubectl-debug-doesnt-tell-you-the-silent-evidence-gap/)
- [The Pod Prometheus Never Saw: Kubernetes' Sampling Blind Spot](https://dzone.com/articles/the-pod-prometheus-never-saw)
- [When Kubernetes Says "All Green" But Your System Is Already Failing](https://dzone.com/articles/when-kubernetes-says-all-green)
- [When Kubernetes Forgets: The 90-Second Evidence Gap](https://dzone.com/articles/when-kubernetes-forgets)

### Operational Memory Architecture for Kubernetes: Preserving Causal Context Across the Evidence Horizon

- **Author:** Shamsher Khan
- **Category:** Distributed, Parallel, and Cluster Computing (`cs.DC`)
- **arXiv:** [2605.18755](https://arxiv.org/abs/2605.18755)
- **DOI:** [10.48550/arXiv.2605.18755](https://doi.org/10.48550/arXiv.2605.18755)
- **Submitted:** March 6, 2026

This paper introduces the evidence horizon and the Operational Memory Architecture for preserving Kubernetes failure evidence before native status fields and events are overwritten or rotated.

**Core implementation**

- Go-based Kubernetes watcher
- SQLite operational memory store
- Causal patterns for OOM kills and ConfigMap-related failures
- Latency and stress experiments on Minikube and AKS

### Decomposing Docker Container Startup Performance: A Three-Tier Measurement Study on Heterogeneous Infrastructure

- **Author:** Shamsher Khan
- **Category:** Performance (`cs.PF`)
- **arXiv:** [2602.15214](https://arxiv.org/abs/2602.15214)
- **DOI:** [10.48550/arXiv.2602.15214](https://doi.org/10.48550/arXiv.2602.15214)
- **Submitted:** February 16, 2026

This measurement study decomposes Docker startup latency across Azure Premium SSD, Azure Standard HDD, and macOS Docker Desktop. It evaluates image size, storage tier, virtualization overhead, namespace creation, CPU throttling, and OverlayFS behavior using reproducible benchmarks.

### Docker Security Research Preprint

- **Platform:** TechRxiv
- **DOI:** [10.36227/techrxiv.176591893.32096869/v1](https://doi.org/10.36227/techrxiv.176591893.32096869/v1)
- **Full record:** [TechRxiv version 1](https://www.techrxiv.org/doi/full/10.36227/techrxiv.176591893.32096869/v1)

This preprint is part of the Docker security research stream supporting the practical labs, security controls, and reproducible implementation artifacts in this repository.

> The TechRxiv title should be added here exactly as shown on the official record when the record is next reviewed. The DOI and official record link are preserved now.

## Research Artifacts and Archived Records

- [Zenodo record 19798927](https://zenodo.org/records/19798927)
- [Zenodo record 19685352](https://zenodo.org/records/19685352)

Zenodo records are used for durable research artifacts, experiment packages, datasets, or preserved versions associated with the broader OpsCart research program.

## CNCF Publications

### When Kubernetes Restarts Your Pod — And When It Doesn't

- **Publisher:** Cloud Native Computing Foundation
- **Published:** March 17, 2026
- **Article:** [Read on CNCF](https://www.cncf.io/blog/2026/03/17/when-kubernetes-restarts-your-pod-and-when-it-doesnt/)
- **Companion repository:** [k8s-pod-restart-mechanics](https://github.com/opscart/k8s-pod-restart-mechanics)

The article distinguishes container restarts, pod recreation, in-place resize, configuration propagation, and control-plane updates using Kubernetes 1.35 behavior and reproducible examples.

### What `kubectl debug` Doesn't Tell You: The Silent Evidence Gap

- **Publisher:** Cloud Native Computing Foundation
- **Published:** May 18, 2026
- **Article:** [Read on CNCF](https://www.cncf.io/blog/2026/05/18/what-kubectl-debug-doesnt-tell-you-the-silent-evidence-gap/)

The article explains why ephemeral debugging can begin after critical evidence has already disappeared and connects operational debugging to evidence-horizon preservation.

## Practitioner Publications

### DZone

Author profile: [Shamsher Khan on DZone](https://dzone.com/authors/shamsherkhan-1)

Selected Docker, container-security, Kubernetes, and AI operations articles:

- **Building Production-Safe Agentic Remediation With Docker MCP Gateway: Lessons From 43% to 100% Accuracy**
  - Related implementation: [Lab 11 — Docker MCP Gateway](../labs/11-docker-mcp-gateway/)
- **Your AI Coding Agent Can't Steal What It Never Had: The Docker Sandbox Isolation Story**
  - Related implementation: [Lab 13 — AI Context Poisoning](../labs/13-ai-context-poisoning/)
- **Docker Hardened Images Are Free Now — Here's What You Still Need to Build**
  - Related implementation: [Lab 12 — Docker Hardened Images](../labs/12-docker-hardened-images/)
- **Docker Secrets Management: From Development to Production**
  - Related implementation: [Lab 10 — Secrets Management](../labs/10-secrets-management/)
- **Docker Runtime Escape: Why Mounting `docker.sock` Is Worse Than Running Privileged Containers**
  - Related implementation: [Lab 09 — Runtime Escape](../labs/09-runtime-escape/)
- **Advanced Docker Security: From Supply Chain Transparency to Network Defense**
  - Related implementations: [Lab 07 — SBOM](../labs/07-supply-chain-sbom/) and [Lab 08 — Network Security](../labs/08-network-security/)
- **Docker Security: 6 Practical Labs From Audit to AI Protection**
  - Earlier article associated with the initial six-lab version of this repository

Selected Kubernetes and operations articles:

- **From Bash Script to Operational Triage: What Eight Months of Kubernetes Debugging Taught Me**
- **The Pod Prometheus Never Saw: Kubernetes' Sampling Blind Spot**
- **When Kubernetes Says "All Green" But Your System Is Already Failing**
- **When Kubernetes Forgets: The 90-Second Evidence Gap**
- **How I Cut Kubernetes Debugging Time by 80% With One Bash Script**
- **AI-Assisted Kubernetes Diagnostics: A Practical Implementation**

Current article titles, publication dates, and engagement metrics should be treated as profile-managed information and not duplicated as fixed repository statistics.

### dev.to

Author profile: [Shamsher Khan on dev.to](https://dev.to/shamsher_khan)

Selected related articles:

- **Production AI Agents in Kubernetes: A 7-Control Checklist for Platform Teams**
- **You Blocked `docker.sock`. Your Containers Are Still Not Safe**
- **My Bash Script Found the Problems. Engineers Still Didn't Know Where to Start**
- **What a 60-Second War-Room Scan Reveals**

### Medium

Author profile: [Shamsher Khan on Medium](https://medium.com/@shams.khan22)

Selected related articles:

- **The Docker Security Guide Fortune 500 Teams Wish Existed**
- **Beyond Docker: containerd and the Modern Container Runtime Landscape**
- **Ultimate `kubectl` Guide for DevOps and Platform Engineers**
- **The Kubernetes Pod Lifecycle: From Creation to Termination**
- **Kubernetes Services Demystified: When to Use Which Type and Why It Matters**

### OpsCart

- [Docker Security Guide](https://opscart.com/guides-tutorials/docker-security-guide/)
- [Container articles](https://opscart.com/category/containers/)
- [OpsCart](https://opscart.com/)

OpsCart is the central navigation layer connecting labs, implementation repositories, research, and practitioner articles.

## Research-to-Implementation Traceability

### Docker Runtime and Container Security

```text
Container-security research
        ↓
Labs 01–10
        ↓
Runtime escape, secrets, SBOM, signing, seccomp, and network experiments
        ↓
DZone, dev.to, Medium, and OpsCart articles
```

### Docker MCP Gateway

```text
Lab 11 implementation
        ↓
Initial 43% scenario accuracy
        ↓
Security and decision-control improvements
        ↓
100% result across the documented scenario suite
        ↓
Production-safe remediation article
```

The reported percentages apply to the documented Lab 11 scenario evaluation. They are not a general benchmark for all agentic remediation systems.

### Docker Hardened Images and Trust Governance

```text
Lab 12 architecture
        ↓
Fleet drift, provenance, admission, CI/CD, and runtime experiments
        ↓
Migration, runbook, compliance, and troubleshooting documentation
        ↓
Practitioner publication
```

### AI Context Poisoning and Sandbox Isolation

```text
Context-poisoning threat model
        ↓
Claude Code and Gemini CLI experiments
        ↓
Deterministic zero-width character detection
        ↓
Docker Sandbox filesystem-isolation test
        ↓
Lab 13 evidence and practitioner publication
```

### Kubernetes Evidence Horizon

```text
Operational incident observation
        ↓
Evidence-horizon hypothesis
        ↓
OMA research and reproducible implementation
        ↓
CNCF and DZone publications
        ↓
Operational-memory and incident-history designs
```

## Citation and Reuse

When citing research, prefer the DOI or official arXiv record. When reproducing an experiment, cite both the research record and the relevant implementation repository or lab.

For questions, corrections, or replication results, open an issue in the repository associated with the implementation.
