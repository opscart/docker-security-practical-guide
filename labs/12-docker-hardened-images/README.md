# Lab 12: Docker Hardened Images as a Container Trust Control Plane

> **Thesis (TODO — replace with locked sentence):** Container security failures in Kubernetes are not caused by insecure images, but by the absence of enforceable fleet-wide trust governance. This lab demonstrates how policy, provenance, and CI/CD enforcement interact as a single control plane — instantiated using Docker Hardened Images (DHI), but generalizable to any trust-layer choice.

## The Control Loop

_See [docs/control-loop.svg](docs/control-loop.svg). To be embedded here once produced._

## Three-Layer Model

1. **Supply Chain Layer** — CI/CD, SBOM, signing
2. **Trust Layer** — registry, attestation, provenance (DHI lives here)
3. **Enforcement Layer** — admission control, runtime policy, break-glass

## Experiments

| #  | Name                  | Layer         | Role       |
|----|-----------------------|---------------|------------|
| E1 | Drift observation     | Observability | Supporting |
| E2 | Trust provenance      | Trust         | **Core**   |
| E3 | Admission enforcement | Enforcement   | **Core**   |
| E4 | Supply chain gates    | Supply chain  | **Core**   |
| E5 | Runtime failure modes | Operations    | Supporting |

## DHI Substitution Test

Replace DHI with Chainguard, or with self-built distroless + internal cosign — the architecture is unchanged. The contribution is the control loop, not the trust-layer vendor. See [docs/dhi-substitution-test.md](docs/dhi-substitution-test.md).

## Prerequisites

- Docker 24+
- kind (Kubernetes 1.28+)
- kubectl, cosign, syft, grype
- Docker Hub account + Personal Access Token (DHI registry requires `docker login dhi.io`)

## Quick Start

```bash
make up        # Bootstrap kind + local registry + Kyverno
make verify    # Verify platform health
make down      # Tear down
```

## Cross-References

- **Lab 04** (Image Signing) — Cosign tooling reused in E2
- **Lab 07** (Supply Chain SBOM) — SBOM tooling reused in E4
- **Lab 09** (Runtime Escape) — Kyverno admission patterns extended in E3
