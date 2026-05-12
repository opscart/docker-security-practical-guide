# E5 — Runtime Failure Modes

> "Distroless images are great until 2 AM when production breaks and there's
> no shell to debug it. Then teams pull DHI out and the whole trust chain
> collapses."
>
> — every senior platform engineer, on hearing the DHI thesis

This experiment answers that objection.

---

## Hypothesis

Distroless container runtime opacity creates an operational SLA risk. The
risk is *manageable* with three specific patterns that preserve the trust
contract while restoring debuggability. Without those patterns, teams
revert to non-hardened images under operational pressure — and the entire
trust control plane collapses at the first incident.

## Experiment

Three patterns, each independently demonstrable:

1. **Ephemeral debug containers** (`kubectl debug --image`) — attach a
   debug toolset *alongside* a running distroless pod, sharing PID and
   network namespace. The DHI container itself never gains tools.

2. **Dev-variant pattern** — `dhi.io/<image>:<tag>-dev` exists in the DHI
   catalog with shell + debug tools included. Use it in development and
   staging; the admission policy *allows* it in dev namespaces and
   *rejects* it in prod. Same enforcement primitive (image origin
   policy), different allow-list per environment.

3. **Pre-built debug sidecar pattern** — platform teams maintain a curated
   "debug pod" image with `curl`, `dig`, `nc`, `strace`, `tcpdump`, ready
   to drop next to any pod via the ephemeral-container API. No
   build-time changes to applications.

Each pattern is exercised against three realistic 2 AM scenarios catalogued
in `failure-modes/`:
- "service is unreachable from this pod"
- "container exits immediately on start"
- "container is being OOM-killed"

## Observation

For each pattern × scenario combination: the actual command sequence a
responder runs, the diagnostic output it produces, the time to diagnose,
and what the trust contract looks like before and after the debug session.

The headline finding: **at no point is the DHI image itself modified,
re-tagged, or pulled outside its signed identity.** The application
container remains cryptographically attested throughout the incident.
Only the debug tooling — explicitly separate, explicitly ephemeral —
gains the visibility a responder needs.

## Conclusion

Distroless is operationally viable. The three patterns above are how
mature platform teams run it. The image is hardened; debugging is solved
separately, with admission-controlled tooling, not by weakening the
image.

The "no shell at 2 AM" objection turns out to be a *false trade-off*:
hardened runtime AND operational debuggability are simultaneously
achievable. The lab's enforcement layer (E3) is what makes this work —
without it, teams would pull a debug image into prod and the trust chain
would silently rot.

---

## How to use this experiment

Start with the failure modes catalog:
- [failure-modes/README.md](failure-modes/README.md)

Then walk through the three patterns:
- [Pattern 1: Ephemeral debug containers](#pattern-1-ephemeral-debug-containers) (below)
- [Pattern 2: Dev-variant pattern](dev-variant-pattern/README.md)
- [Pattern 3: Pre-built debug sidecar](#pattern-3-pre-built-debug-sidecar) (below)

## Pattern 1: Ephemeral debug containers

`kubectl debug` (GA since K8s 1.25) attaches a *new* container into a
running pod's namespaces. The original pod's containers are unchanged.

```bash
# Start with a running DHI-based pod (your application)
kubectl run dhi-app \
  --image=dhi.io/python:3.13 \
  --image-pull-policy=Never \
  --command -- python -c "import time; time.sleep(3600)"

# At 2 AM: something is wrong with the network. Attach a debug shell.
# The --image-pull-policy=Never is critical for our local lab, since
# we pre-load images. In a real cluster the debug image would be
# pulled from a trusted internal registry.
kubectl debug -it dhi-app \
  --image=busybox:1.37 \
  --target=dhi-app \
  -- sh

# Inside the debug container:
#   - You can see the application's processes (shared PID namespace)
#   - You can see the application's network (shared network namespace)
#   - You CANNOT modify the application container's filesystem
#   - The debug container is gone the moment you exit
```

What this preserves:
- The `dhi-app` pod's image identity stays `dhi.io/python:3.13`
- No new container is added to the deployed manifest
- The application container's filesystem is unmodified
- Audit log shows: who ran `kubectl debug`, when, with what image

What this costs:
- The debug image (`busybox:1.37`) must itself be from a trusted
  registry — see `dev-variant-pattern/allow-debug-images.yaml`
- The K8s feature `EphemeralContainers` must be enabled (GA since 1.25)
- RBAC must permit `pods/ephemeralcontainers` create — typically only
  granted to SREs, not application developers

See `debug-distroless.sh` for an automated wrapper.

## Pattern 3: Pre-built debug sidecar

For incidents that need consistent, repeatable tooling (network probes,
strace, tcpdump, log tailing), maintain a single internal "debug pod"
image with the tools your team actually uses.

The image is built once, scanned, signed, and stored in your trusted
registry — same supply chain pipeline as application images. It's
*pulled* into incident investigations via `kubectl debug --image=...`,
never *baked into* the application image.

A typical debug image manifest:

```dockerfile
# debug-toolkit/Dockerfile — example, not shipped in this lab
FROM nicolaka/netshoot:v0.13   # or your team's curated base

# Add tools your team actually uses. Resist the urge to add everything.
# Every tool is an attack surface in a debug container.
RUN apk add --no-cache \
    bind-tools \
    curl \
    netcat-openbsd \
    strace \
    tcpdump
```

This image:
- Lives in your internal registry (e.g., `internal-registry.corp/debug-toolkit:v3`)
- Is signed and SBOM-attested by the same CI/CD pipeline as production images
- Has its own admission policy — only RBAC-restricted SRE roles can pull it
  via `kubectl debug`
- Is *never* used as a `FROM` line in an application Dockerfile

Run it like Pattern 1:

```bash
kubectl debug -it dhi-app \
  --image=internal-registry.corp/debug-toolkit:v3 \
  --target=dhi-app \
  -- /bin/sh
```

## What this experiment does NOT solve

- **Crashed pods with no running containers.** `kubectl debug` requires
  a running pod. For crashloop scenarios, use `kubectl debug --copy-to`
  (Pattern 2 with the dev-variant) or examine pod events + container
  logs first.
- **Image-baked secrets exfiltration.** None of these patterns help if a
  developer accidentally `COPY`s a `.env` file into the application
  image. That's an E4-layer problem (build-time scanning).
- **Application-level bugs.** Distroless or not, business logic bugs
  need application-level observability (logs, metrics, traces). These
  patterns are for *operational* debugging (network, kernel, process),
  not application debugging.

## File layout

```
E5-runtime-failure-modes/
├── README.md                              ← this file
├── debug-distroless.sh                    ← Pattern 1 orchestrator
├── ephemeral-debug-container.yaml         ← Pattern 1 declarative form
├── dev-variant-pattern/
│   ├── README.md                          ← Pattern 2 narrative
│   ├── allow-dev-variants-in-dev.yaml     ← Kyverno policy refinement
│   └── deploy-dev-variant.yaml            ← Example pod using -dev image
└── failure-modes/
    ├── README.md                          ← Scenario index
    ├── scenario-cant-reach-service.md
    ├── scenario-pod-crashloop.md
    └── scenario-memory-leak.md
```