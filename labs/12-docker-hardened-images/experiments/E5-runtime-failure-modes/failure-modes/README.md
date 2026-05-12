# Failure Modes Catalog

Three realistic 2 AM scenarios, each diagnosed using the patterns from
this experiment's parent README. Use these as runbook templates for your
own incident response procedures.

## Scenarios

| File | Failure | Diagnostic pattern |
|------|---------|--------------------|
| [scenario-cant-reach-service.md](scenario-cant-reach-service.md) | "Service X is unreachable from this pod" | Pattern 1 — ephemeral debug with network tools |
| [scenario-pod-crashloop.md](scenario-pod-crashloop.md) | "Container exits immediately on start" | Pattern 2 — dev-variant for filesystem inspection |
| [scenario-memory-leak.md](scenario-memory-leak.md) | "Container is being OOM-killed periodically" | Pattern 3 — debug sidecar with strace/process tools |

## Common to all scenarios

The fastest-to-information first move is **always**:

```bash
# What does Kubernetes know about the pod's state?
kubectl describe pod <pod>          # events, container state, restart counts
kubectl logs <pod> --previous       # last-crashed container's stdout/stderr
kubectl get events --sort-by='.lastTimestamp' \
  --field-selector involvedObject.name=<pod>
```

Two of three scenarios in this catalog are solved by these three
commands alone, *before* attaching a debug container. The patterns
above are for the remaining one-third where the answer isn't in
Kubernetes' view.

## What's not in this catalog

Application-level debugging — slow database queries, business logic
errors, race conditions in async code. Those need application-level
observability (logs, traces, profilers) that's the responsibility of
the application, not the platform.

This catalog is strictly *infrastructure-layer* failure modes: network,
kernel, container runtime, resource limits. The boundary is whether
the diagnostic needs to see the host's view of the pod, or the
application's internal state.