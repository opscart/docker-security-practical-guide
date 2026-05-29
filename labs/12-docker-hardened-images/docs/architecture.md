# Trust Control Plane — Architecture

## Overview

The trust control plane is a three-layer pattern joined by a feedback loop. The layers are **roles**, not products. Any signer, any admission controller, and any drift auditor that fill the roles satisfies the pattern.

```
┌─────────────────────────────────────────────┐
│           SUPPLY CHAIN LAYER                │
│  Build → Sign → SBOM → Attest → Push        │
└───────────────────┬─────────────────────────┘
                    │ signed image + attestations
┌───────────────────▼─────────────────────────┐
│              TRUST LAYER                    │
│  Admission controller verifies at deploy    │
│  (Kyverno verifyImages + SBOM policy)       │
└───────────────────┬─────────────────────────┘
                    │ admitted workload
┌───────────────────▼─────────────────────────┐
│           ENFORCEMENT LAYER                 │
│  Continuous drift audit + vuln inventory    │
│  (analyze-drift.py + audit-fleet.sh)        │
└───────────────────┬─────────────────────────┘
                    │ findings
                    └──────────────► feedback into Supply Chain
```

## Layer Responsibilities

### Supply Chain Layer
Produces verifiable evidence about what was built and by whom.

- **Sign** every image with cosign keyless (Fulcio + Rekor)
- **Generate** a CycloneDX SBOM and attach as an in-toto attestation
- **Attest** vulnerability scan results (grype)
- **Optionally** produce a SLSA provenance attestation (SLSA Level 3)

Output: an image whose origin, contents, and build environment are independently verifiable by anyone with access to the public key infrastructure.

### Trust Layer
Admits only workloads whose evidence satisfies policy.

- **`require-signature`** — rejects pods whose images lack a valid cosign signature from an approved identity
- **`require-sbom-attestation`** — rejects pods whose images lack an attached SBOM attestation
- **`require-trusted-registry`** — constrains the registries from which images may be pulled
- **`break-glass-exception`** — time-bounded policy exception for emergency deployments (see [runbook.md](runbook.md))

The identity matcher (`subject` + `issuer`) is the unit of governance. Swapping vendors means updating the matcher, not the policy structure.

### Enforcement Layer
Answers what continues to be true after admission.

- **`analyze-drift.py`** — compares running pod digests against last-known-good signed manifests; flags drift, unsigned workloads, and SBOM-absent images
- **`audit-fleet.sh`** — scanner-driven vulnerability inventory by cohort; surfaces the CVE differential between signing states as a continuous signal

Both run on a schedule (CronJob manifests in `fleet/`). Findings emit as Kubernetes events.

### Feedback Loop
Findings have owners and remediation paths:

| Finding type | Owner | Remediation |
|---|---|---|
| Drift detected | Team owning workload | Redeploy from signed digest |
| Unsigned workload | Team owning pipeline | Wire pipeline into supply chain layer |
| SBOM absent | Team owning build | Add syft + cosign attest step |
| CVE in running image | Team + platform | Rebuild base, push new signed digest |

Without the loop, the enforcement layer becomes an alerting backwater. The loop is what makes the pattern operational rather than decorative.

## Design Decisions

**Kyverno over OPA/Gatekeeper.** Kyverno's `verifyImages` is a first-class primitive for signature verification. Gatekeeper requires external attestation providers (e.g., Ratify) for the same capability. The architectural pattern is identical; the integration cost differs.

**Keyless signing over long-lived keys.** Sigstore's keyless model ties the signing identity to the CI/CD pipeline's OIDC token. No key storage, no rotation risk, no secret management overhead. The tradeoff: requires a Fulcio-compatible OIDC issuer (GitHub Actions, Azure workload identity, etc.).

**CycloneDX over SPDX.** Both are valid. CycloneDX has better tooling in the grype/syft ecosystem at the time of writing. The policy layer is format-agnostic.

## Further Reading

- [thesis.md](thesis.md) — what the lab claims and what it doesn't
- [dhi-substitution-test.md](dhi-substitution-test.md) — walkthrough of the substitution test across three configurations
- [compliance-mapping.md](compliance/compliance-mapping.md) — how each layer maps to HIPAA, PCI DSS, SOC 2, FDA 21 CFR Part 11