# Lab 12 — Docker Hardened Images as a Container Trust Control Plane

> **Thesis**: Container security failures in Kubernetes are not caused by
> insecure images. They are caused by the absence of *enforceable
> fleet-wide trust governance*. DHI is a container trust control plane,
> instantiated as one implementation example — the architecture works
> identically with Chainguard, self-built distroless + cosign, or any
> other signing primitive.

This lab demonstrates a complete trust control plane built on Docker
Hardened Images, with empirical evidence that the *governance pattern*
matters more than the *image choice*.

---

## What this lab is

Five hypothesis-driven experiments demonstrating the three-layer model:

```
                              The Control Loop
              ┌──────────────────────────────────────────────┐
              ▼                                              │
    ┌─────────────────┐    ┌─────────────────┐    ┌──────────┴────────┐
    │   Supply Chain  │───▶│      Trust      │───▶│    Enforcement    │
    │      Layer      │    │      Layer      │    │       Layer       │
    │                 │    │                 │    │                   │
    │  Build, sign,   │    │  Cryptographic  │    │  Admission        │
    │  attest at CI   │    │  verification   │    │  control policies │
    │  pipeline time  │    │  of artifacts   │    │  reject untrusted │
    │     (E4)        │    │     (E2)        │    │      (E3)         │
    └─────────────────┘    └─────────────────┘    └─────────┬─────────┘
              ▲                                              │
              │       Operations: drift observation,         │
              └───────  runtime failure modes  ──────────────┘
                                (E1, E5)
```

| Experiment | Hypothesis | Layer demonstrated |
|------------|-----------|---------------------|
| [E1](experiments/E1-drift-observation/README.md) | Image-level controls collapse without fleet-wide enforcement | Observability foundation |
| [E2](experiments/E2-trust-provenance/README.md) | Image trust requires four signals, not one | Trust layer primitive |
| [E3](experiments/E3-admission-enforcement/README.md) | Build-time security collapses if runtime admission lacks teeth | Enforcement layer |
| [E4](experiments/E4-supply-chain-gates/README.md) | Without build-time gates, runtime enforcement absorbs failures | Supply chain layer |
| [E5](experiments/E5-runtime-failure-modes/README.md) | Distroless is operationally viable with three specific patterns | Operations |

Each experiment carries a **Hypothesis / Experiment / Observation /
Conclusion** structure (H/E/O/C) — this is a research artifact, not a
tutorial. The conclusions are empirically supported by data and working
code in the experiments themselves.

## What this lab is NOT

- **Not a DHI marketing piece**. The `docs/dhi-substitution-test.md`
  document explicitly demonstrates that Chainguard, self-built
  distroless + cosign, or any equivalent could be substituted into this
  architecture without changing any policy, script, or workflow.

- **Not a tutorial**. Each experiment poses a hypothesis and validates
  it with measurable observations. Readers seeking "do step 1, then
  step 2" content will be more comfortable with the linked DZone
  practitioner walkthrough.

- **Not theoretical**. Every claim in the experiments is backed by
  executable code that produces verifiable results. The Kyverno
  rejection messages, cosign verification outputs, and CycloneDX SBOM
  deltas are all reproducible on any machine with Docker.

---

## The trust contract this lab enforces

Any pod admitted to the cluster must satisfy four conditions:

1. **Origin**: image must come from an allow-listed registry (default: `dhi.io/*`)
2. **Signature**: image must be cryptographically signed (cosign keyless or key-based)
3. **Provenance**: image must have a verifiable CycloneDX SBOM attestation
4. **Vulnerability scan**: image must have a signed vulnerability scan attestation

These are enforced as **vendor-neutral Kyverno primitives** — the
policies don't say "DHI", they say "trusted registry" and "valid
signature for our key." See [`policies/`](policies/) for the
canonical implementations.

Break-glass: a documented PolicyException pattern (see
`policies/break-glass-exception.yaml`) provides time-bound audited
overrides for incident response — strict-by-default with explicit
escape valve, not "disable enforcement at 2 AM."

---

## Quick start (15 minutes, requires Docker Desktop)

```bash
# 1. Install platform prerequisites
brew install kind kubectl helm jq cosign syft

# 2. Authenticate to dhi.io (free tier suffices for this lab)
docker login dhi.io

# 3. Bring up the platform: kind cluster + Kyverno + DHI auth
./platform/bootstrap.sh

# 4. Apply the trust policies
kubectl apply -k policies/

# 5. Run the rejection test (the headline E3 demo)
kubectl run rejected-test --image=nginx:latest --restart=Never
# Expected: rejected by require-trusted-registry policy
```

If step 5 produces a denial message naming the policy, you have a
working trust control plane. Tear down with `./platform/teardown.sh`.

## Reproducing the experiments

Each experiment has its own README with detailed run instructions.
Start with E2 (verifies real DHI signatures, ~5 minutes), then E3
(admission control demo, ~10 minutes), then E1, E4, E5.

```
labs/12-docker-hardened-images/
├── README.md                         ← you are here
├── docs/
│   ├── thesis.md                     ← the full architectural argument
│   ├── architecture.md               ← three-layer model in depth
│   ├── dhi-substitution-test.md      ← why this isn't a DHI advocacy piece
│   ├── migration-playbook.md         ← phased rollout for production teams
│   ├── runbook.md                    ← operational procedures
│   ├── compliance/
│   │   └── compliance-mapping.md     ← PCI-DSS 4.0 §6.3, 21 CFR Part 11
│   ├── implementation-variants/
│   │   └── aks/                      ← Azure-specific implementation notes
│   └── troubleshooting.md            ← real issues encountered building this
├── experiments/                      ← E1 through E5
├── platform/                         ← bootstrap + teardown for kind cluster
├── policies/                         ← the four core Kyverno policies
├── fleet/                            ← 12-service synthetic fleet (E1 data)
└── tools/                            ← verify-image.sh, audit-fleet.sh, etc.
```

---

## Why this lab exists

Docker Hardened Images were announced as a security product. Most
analyses treat them as "better Docker images." The framing this lab
proposes is different: **DHI is a building block for a control plane,
and the control plane is what delivers security outcomes — not the
image alone.**

A team that buys DHI but doesn't deploy admission control, supply chain
verification, and observable governance will get marginal security
benefits. A team that builds the control plane with *any* hardened
image foundation (DHI, Chainguard, self-built) will get
order-of-magnitude better outcomes — because the failure modes that
actually cause incidents in regulated environments are *governance*
failures, not *image* failures.

This lab provides both: a working control plane *and* the evidence
that the control plane is what matters.

---

## Engineering context

This lab was built incrementally over several focused sessions on
real hardware (Apple Silicon MacBook Pro, Docker Desktop 4.x, kind
0.31.0, Kyverno 3.3.4). The build encountered enough real issues that
[`docs/troubleshooting.md`](docs/troubleshooting.md) is itself a
substantial artifact — capturing the actual friction points teams will
hit, with diagnoses and resolutions.

Some of those issues:
- containerd 2.x removed the legacy `[mirrors]` registry block
- `registry:2` pull-through cache doesn't honor containerd's `?ns=` parameter
- DHI images have no `/bin/sh` (use exec-form `RUN`)
- DHI images run as `nonroot` (uid 65532), so `pip install --user`
  installs to `/home/nonroot/.local`, not `/root/.local`
- Kyverno's `webhookTimeoutSeconds` is capped at 30
- Kyverno's `rekor`/`ctlog` blocks must be *inside* `keys`, not siblings
- `mutateDigest: true` is incompatible with `validationFailureAction: Audit`
- PolicyException feature must be explicitly enabled via Helm value or
  controller arg

These are the kinds of details that separate a lab artifact from a
sales demo. If you're building production trust governance, you'll
hit these issues. Save yourself the hours by starting with this lab.

---

## Related publications

- (planned) "Docker Hardened Images as a Container Trust Control Plane:
  A Migration Field Guide for Regulated Environments" — InfoQ
- (planned) Implementation deep-dive — DZone
- (planned) Canonical archive + extended troubleshooting — opscart.com
- DHI substitution analysis — see [`docs/dhi-substitution-test.md`](docs/dhi-substitution-test.md)

## Author

**Shamsher Khan** — Senior DevOps Engineer at GlobalLogic. IEEE Senior
Member, DZone Core Member, CNCF blog contributor. Author of
[OpsCart](https://opscart.com).

## License

Lab content under the repository's root LICENSE. DHI images themselves
are subject to Docker Hardened Images terms of service.