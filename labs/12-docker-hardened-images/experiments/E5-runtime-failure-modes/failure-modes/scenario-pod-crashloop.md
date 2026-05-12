# Scenario: "Container exits immediately on start (CrashLoopBackOff)"

**Symptom**: A pod's container crashes on startup, restart counter
climbing every minute or two. Kubernetes shows `CrashLoopBackOff`. Logs
are short or empty — the container exits before producing useful output.

**Pattern**: Dev-variant pattern (Pattern 2). `kubectl debug` requires a
*running* container; for crashloops you need a different approach.

## Diagnostic walkthrough

### Step 1: read what Kubernetes already knows

```bash
# Pod state and recent events
kubectl describe pod <pod>

# Last container's stdout/stderr (the --previous flag is critical here)
kubectl logs <pod> --previous

# Container exit code (in case of OOMKill, signal kills, etc.)
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
```

Common findings here that solve the issue without further debugging:
- Exit code 1 + stack trace → application-level bug
- Exit code 137 → OOMKilled (see scenario-memory-leak.md)
- Exit code 139 → segfault, likely binary incompatibility
- "Error: ImagePullBackOff" → registry auth or missing image
- "Insufficient memory" in events → resource limits too low

### Step 2: if logs don't tell the story, deploy the dev-variant

When the application exits without producing useful logs, you need to
see what its environment actually looks like. The dev-variant has bash,
file inspection tools, and the same runtime libraries as the production
image.

```bash
# Apply the policy refinement if not already done
kubectl apply -f labs/12-docker-hardened-images/experiments/E5-runtime-failure-modes/dev-variant-pattern/allow-dev-variants-in-dev.yaml

# Label the troubleshooting namespace
kubectl create namespace incident-NNNN 2>/dev/null || true
kubectl label namespace incident-NNNN environment=dev --overwrite

# Use `kubectl debug --copy-to` to clone the crashed pod with a
# substituted image, leaving the original alone. Note the dev-variant image.
kubectl debug <crashed-pod> \
  -n <ns-with-crash> \
  --copy-to=<crashed-pod>-debug \
  --image=dhi.io/python:3.13-dev \
  --share-processes \
  -- bash

# Now you have an interactive shell in a near-identical pod with the
# same volumes, env vars, and command... but it landed in a bash shell
# instead of executing the original command.
```

### Step 3: reproduce the failure manually

Inside the bash shell, run the original entrypoint command yourself and
watch what happens:

```bash
# Inside the debug pod's bash shell:

# Confirm Python and required packages are present
python --version
pip list

# Confirm env vars are what you expect (config errors are common crashloop causes)
env | grep -i app   # or whatever prefix your config uses

# Confirm mounted files are present and readable
ls -la /app/        # or your application's working dir
cat /etc/myapp/config.yaml 2>/dev/null || echo "config file missing"

# Run the actual entrypoint command with verbose output
python -u app.py 2>&1 | tee /tmp/crash.log
# When it crashes, you have the full output captured.
```

### Step 4: clean up

```bash
# Delete the debug copy
kubectl -n <ns> delete pod <crashed-pod>-debug

# The original crashed pod is still there, still crashlooping —
# you didn't touch it. Now you know what to fix.
```

## What the trust contract looks like after this incident

| Property | Before incident | After incident |
|----------|----------------|----------------|
| Production application image | `dhi.io/python:3.13` | `dhi.io/python:3.13` (unchanged) |
| Debug copy image | n/a | `dhi.io/python:3.13-dev` (different signature, same DHI chain, in a dev-labelled namespace) |
| Production namespace policy | strict | strict (unchanged) |
| Debug namespace policy | strict | strict + `restrict-dev-variants` allowing -dev in `environment=dev` |

The production image is untouched. The debug pod was created in a
namespace explicitly labelled for it, with an image still signed and
attested through DHI's normal supply chain.

## Common crashloop causes and what to look for

| Pattern | Likely cause | Where to look in the dev-variant shell |
|---------|--------------|----------------------------------------|
| Empty logs + exit code 0 | Process forked and parent exited | `ps aux` after starting the entrypoint |
| Exit code 1 + brief error | Config / env var missing | `env`, mounted ConfigMaps, Secrets |
| Exit code 137 / 143 | OOM kill or signal kill | `dmesg`, container resource limits |
| Exit code 126 | Permissions issue on entrypoint | `ls -la /app/<entrypoint>`, file ownership |
| Exit code 127 | Binary not found | `which python`, $PATH inspection |

## Why NOT to use the dev variant directly in production

You might be tempted to just deploy `dhi.io/python:3.13-dev` to
production "temporarily" while debugging. Don't:

1. The `-dev` variant has a larger attack surface (shell, package
   manager, debug tools). Running it in prod weakens the trust contract.
2. The `restrict-dev-variants` policy will reject the apply, which is
   the point of the policy.
3. "Temporary" changes to production rarely stay temporary. The next
   incident finds the dev image still running.

If you genuinely need a debuggable image in production for an extended
window, that's a *change request* through your normal change management
process, with a planned rollback. The lab's break-glass exception
pattern (in E3) is built for exactly this.