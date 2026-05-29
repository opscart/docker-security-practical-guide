# Runbook

Operational procedures for engineers running the trust control plane in production. Covers the failure modes most likely to page you.

---

## 1. Admission Webhook Failure

**Symptom:** All pod deployments failing with `connection refused` or `context deadline exceeded` from the admission webhook.

**Cause:** Kyverno admission controller pods are down or unreachable. This is the highest-severity operational failure — it blocks all workload changes cluster-wide.

**Immediate check:**
```bash
kubectl get pods -n kyverno
kubectl describe pod -n kyverno -l app.kubernetes.io/component=admission-controller
```

**If Kyverno pods are crashing:**
```bash
# Check logs for the root cause
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller --tail=50

# If webhook is blocking cluster recovery, temporarily patch to Ignore failurePolicy
# WARNING: this disables enforcement — use only during confirmed Kyverno outage
kubectl patch webhookconfiguration kyverno-resource-validating-webhook-cfg \
  --type='json' \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
```

**Recovery:** Restore Kyverno pods, then immediately revert `failurePolicy` back to `Fail`. Log the incident and duration in the audit trail — this window is a compliance event.

```bash
# Revert after Kyverno recovers
kubectl patch webhookconfiguration kyverno-resource-validating-webhook-cfg \
  --type='json' \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Fail"}]'
```

---

## 2. Legitimate Deployment Blocked by Policy

**Symptom:** A valid workload is rejected at admission. Engineer reports `Error from server: admission webhook denied the request`.

**Diagnose:**
```bash
# See exactly which policy rule fired and why
kubectl get events --field-selector reason=PolicyViolation -n <namespace>

# Check the specific image reference and signing state
cosign verify \
  --certificate-identity-regexp '^https://github\.com/opscart/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  <image-ref>
```

**Common causes and fixes:**

| Cause | Fix |
|---|---|
| Image not signed | Trigger the signing pipeline (`supply-chain-gate.yml`) and redeploy |
| Wrong signing identity | Check `subject` in cosign verify output against policy matcher |
| SBOM attestation missing | Re-run `cosign attest` step in the pipeline |
| Image pulled from unapproved registry | Mirror image into approved registry first |
| DHI signature path mismatch | Add `repository: registry.scout.docker.com/docker/dhi-*` to policy |

---

## 3. Debugging a Distroless Container (No Shell)

**Symptom:** Pod is running but you need to inspect the filesystem, check network, or trace a process. `kubectl exec -it <pod> -- /bin/sh` fails because the container has no shell.

**Solution:** Attach an ephemeral debug container to the running pod.

```bash
# Attach a busybox debug container sharing the target container's process namespace
kubectl debug -it <pod-name> \
  --image=busybox:1.37 \
  --target=<container-name> \
  --share-processes \
  -n <namespace>
```

Inside the debug container you can:
```bash
# Inspect the target process
ps aux

# Check open files
ls /proc/<pid>/fd

# Network connectivity
wget -qO- http://localhost:8080/health

# Read target container filesystem via /proc
cat /proc/<pid>/root/app/config.yaml
```

**Requirements:**
- Kubernetes 1.25+ with `EphemeralContainers` feature gate enabled (on by default from 1.25)
- Your RBAC must include `pods/ephemeralcontainers` verb. Check:
```bash
kubectl auth can-i create pods/ephemeralcontainers -n <namespace>
```

**If RBAC is missing:**
```bash
# Add ephemeral container permission to your on-call role
kubectl patch clusterrole <oncall-role> --type='json' \
  -p='[{"op":"add","path":"/rules/-","value":{"apiGroups":[""],"resources":["pods/ephemeralcontainers"],"verbs":["create","update"]}}]'
```

**Practice this before you need it.** The `kubectl debug` syntax is not intuitive under pressure. Run it against a non-critical pod in a staging namespace as part of on-call onboarding.

---

## 4. Break-Glass Deployment

**When to use:** A critical fix must deploy immediately and the image cannot be signed in time (e.g., signing pipeline is down, key rotation is mid-flight).

**The break-glass policy** (`policies/break-glass-exception.yaml`) allows a time-bounded exception for images labeled with a break-glass annotation and deployed by an approved identity.

**Procedure:**

```bash
# Step 1 — Apply the break-glass exception (requires cluster-admin)
kubectl apply -f policies/break-glass-exception.yaml

# Step 2 — Add the break-glass annotation to your deployment
kubectl annotate pod <pod-name> \
  security.opscart.io/break-glass="true" \
  security.opscart.io/break-glass-reason="signing-pipeline-outage-$(date +%Y%m%d-%H%M)" \
  security.opscart.io/break-glass-approver="<your-name>"

# Step 3 — Deploy the unsigned image
kubectl apply -f <manifest>

# Step 4 — IMMEDIATELY open a remediation ticket
# Every break-glass event is a compliance event. Document:
# - Time of activation
# - Reason
# - Who approved
# - Image deployed
# - Time of resolution (when signing pipeline recovered and image was re-deployed signed)

# Step 5 — Remove the exception as soon as the signed image is ready
kubectl delete -f policies/break-glass-exception.yaml
kubectl rollout restart deployment/<name> -n <namespace>
```

**Audit note:** Break-glass activations appear in Kyverno event logs automatically. The annotation trail above adds the human context the log alone cannot provide. Both are required for compliance evidence.

---

## 5. Drift Alert — Workload Digest Has Changed

**Symptom:** `analyze-drift.py` reports `DRIFTED` for a workload that was previously clean.

**Diagnose:**
```bash
# See current running digest
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].imageID}'

# Compare against last-known-good signed digest in the fleet manifest
cat fleet/inventory.json | jq '.services[] | select(.name=="<service-name>") | .signed_digest'
```

**Common causes:**

| Cause | Fix |
|---|---|
| In-place image update by a controller | Identify the controller, add `imagePullPolicy: Never` or pin by digest |
| Mutating webhook changed the image reference | Audit mutating webhooks: `kubectl get mutatingwebhookconfigurations` |
| Manual `kubectl set image` | Re-deploy from the signed manifest; add RBAC restriction to prevent direct image changes |
| Legitimate new release not yet in manifest | Update `fleet/inventory.json` with the new signed digest after verifying |

**Remediation for any cause:**
```bash
# Re-deploy from the signed manifest (not the current running state)
kubectl rollout restart deployment/<name> -n <namespace>

# Confirm drift clears
python3 experiments/E1-drift-observation/analyze-drift.py \
  --cluster $(kubectl config current-context) \
  --output table
```

---

## 6. Signing Key / OIDC Identity Change

**When this happens:** Team renames the signing workflow, changes the GitHub org, or rotates to a new OIDC provider.

**Impact:** Existing policy matchers will reject images signed under the new identity. New images will be blocked at admission.

**Procedure:**

```bash
# Step 1 — Verify new identity is working
cosign verify \
  --certificate-identity-regexp '^https://github\.com/<new-org>/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  <newly-signed-image-ref>

# Step 2 — Update the policy identity matcher
# Edit policies/require-signature.yaml:
# subject: "https://github.com/<new-org>/*"
# issuer:  "https://token.actions.githubusercontent.com"

# Step 3 — Apply updated policy
kubectl apply -f policies/require-signature.yaml

# Step 4 — Verify policy updated
kubectl get clusterpolicy require-signature -o jsonpath='{.spec.rules[0].verifyImages[0].attestors}'

# Step 5 — Run drift audit to confirm no workloads are now flagged
python3 experiments/E1-drift-observation/analyze-drift.py \
  --cluster $(kubectl config current-context) \
  --output table
```

**Do not delete the old policy before the new one is applied and verified.** There is no safe window between them.

---

## Quick Reference

| Situation | First command |
|---|---|
| Deployment blocked | `kubectl get events --field-selector reason=PolicyViolation -n <ns>` |
| Need shell in distroless pod | `kubectl debug -it <pod> --image=busybox:1.37 --target=<container> --share-processes` |
| Check drift state | `python3 experiments/E1-drift-observation/analyze-drift.py --output table` |
| Verify image signature | `cosign verify --certificate-identity-regexp ... <image-ref>` |
| Kyverno pods down | `kubectl get pods -n kyverno` |
| Break-glass needed | `kubectl apply -f policies/break-glass-exception.yaml` (then immediately open ticket) |

---

## Further Reading

- [architecture.md](architecture.md) — how the layers producing these alerts are structured
- [compliance-mapping.md](compliance/compliance-mapping.md) — audit implications of break-glass and drift events
- [troubleshooting.md](troubleshooting.md) — deeper diagnostic patterns beyond on-call scope