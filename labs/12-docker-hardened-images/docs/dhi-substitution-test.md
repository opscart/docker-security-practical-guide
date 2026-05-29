# DHI Substitution Test

## Purpose

The substitution test is the core methodological claim of this lab: the same Kyverno policies, the same drift audit, and the same SBOM verification operate identically regardless of which hardened-image vendor supplies the base image.

Swap the vendor. Only the identity matcher changes. Everything else — policy structure, enforcement layer, audit tooling — is invariant.

This distinguishes **having the pattern** from **having a product dependency**.

---

## The Three Configurations

### Configuration A — Docker Hardened Images (DHI)

| Element | Value |
|---|---|
| Base image | `dhi.io/python:3.13` |
| Signing identity | Docker's signing pipeline |
| OIDC issuer | Docker / Fulcio |
| Registry | `dhi.io` |
| Kyverno matcher | Docker's `subject` + `issuer` |

DHI ships the supply chain layer pre-populated: cosign signature, CycloneDX SBOM, SLSA L3 provenance, and OpenVEX attestation are all attached by Docker's own pipeline. Your only job is to verify them.

**Operational note:** DHI signatures resolve via Docker Scout's registry infrastructure (`registry.scout.docker.com`) rather than at the image's own registry path. Kyverno handles this via the `repository` field in `verifyImages`. Custom tooling needs to account for this explicitly.

---

### Configuration B — Chainguard Images

| Element | Value |
|---|---|
| Base image | e.g. `cgr.dev/chainguard/python:latest` |
| Signing identity | Chainguard's signing pipeline |
| OIDC issuer | Chainguard / Fulcio |
| Registry | `cgr.dev` |
| Kyverno matcher | Chainguard's `subject` + `issuer` |

Like DHI, Chainguard ships a pre-populated supply chain layer. The Kyverno policy shape is identical to Configuration A. The only edits are the `subject`, `issuer`, and `imageReferences` fields.

---

### Configuration C — Self-Built on DHI Base

| Element | Value |
|---|---|
| Base image | `dhi.io/python:3.13` (DHI base, application layer added) |
| Signing identity | Project's GitHub Actions OIDC identity |
| OIDC issuer | `https://token.actions.githubusercontent.com` |
| Registry | GHCR or ACR (project-owned) |
| Kyverno matcher | Project's GitHub org + workflow path |

The supply chain layer is project-owned. The GitHub Actions workflow (`supply-chain-gate.yml`) signs the built image, generates the SBOM, attests the vulnerability scan, and verifies all three before pushing.

**Key distinction from A and B:** the trust root shifts from a vendor's signing identity to a project-owned identity. The verification mechanism (cosign keyless against Fulcio) is identical. What changes is *who* is trusted to issue images that pass admission.

This is what the substitution test actually demonstrates: **trust-root invariance**, not base-image-vendor neutrality. The pattern works across all three configurations because the mechanism is the same. The authority differs.

---

## Running the Test

### Prerequisites

```bash
# Cluster with Kyverno installed
kubectl get pods -n kyverno

# Lab policies applied
kubectl apply -k policies/

# Verify all three policies are in Enforce mode
kubectl get clusterpolicy -o custom-columns='NAME:.metadata.name,ACTION:.spec.validationFailureAction'
```

### Step 1 — Verify a DHI image signature (Configuration A)

```bash
# Verify DHI signature via Docker Scout registry path
cosign verify \
  --certificate-identity-regexp '^https://github\.com/docker/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --repository registry.scout.docker.com/docker/dhi-python \
  dhi.io/python:3.13
```

Expected: verification passes, subject shows Docker's signing identity.

### Step 2 — Verify a self-built image signature (Configuration C)

```bash
# Verify project-signed image from supply-chain-gate.yml
cosign verify \
  --certificate-identity-regexp '^https://github\.com/opscart/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  <your-image-ref>
```

Expected: verification passes, subject shows the GitHub Actions workflow identity (`supply-chain-gate.yml@refs/heads/master`).

### Step 3 — Confirm admission policy is enforcer-mode

```bash
# Attempt to deploy an unsigned image — should be rejected
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: unsigned-test
  namespace: default
spec:
  containers:
    - name: unsigned
      image: nginx:latest
EOF
```

Expected: admission webhook rejects the pod, naming `require-signature` and the specific identity mismatch.

### Step 4 — Deploy a signed workload — should be admitted

```bash
# Deploy using a DHI-based or project-signed image
# (substitute a real signed image reference from your registry)
kubectl apply -f experiments/E3-admission-enforcement/
```

Expected: pod starts successfully, no policy violation.

### Step 5 — Run the drift audit across the fleet

```bash
python3 experiments/E1-drift-observation/analyze-drift.py \
  --cluster $(kubectl config current-context) \
  --output table
```

Expected: signed-verified workloads show `OK`; any unsigned or drifted workloads are flagged regardless of which vendor's base image they use.

---

## What the Test Proves and What It Doesn't

| Claim | Verdict |
|---|---|
| Same Kyverno policies work across DHI, Chainguard, self-built | ✓ Demonstrated |
| Same drift audit works across all three | ✓ Demonstrated |
| Vendor swap requires only identity-matcher edits | ✓ Demonstrated |
| Base image minimality is equivalent across vendors | ✗ Not claimed — DHI and Chainguard differ in package counts and SLA commitments |
| Pattern eliminates runtime exploits | ✗ Not claimed — see [thesis.md](thesis.md) for scope limits |

---

## Further Reading

- [architecture.md](architecture.md) — the three-layer model the substitution test validates
- [thesis.md](thesis.md) — what the lab claims and what it doesn't
- [compliance-mapping.md](compliance/compliance-mapping.md) — how vendor-neutrality supports audit portability