# Scenario: "Container is being OOM-killed periodically"

**Symptom**: A pod runs fine for some time, then is terminated by the
kernel OOM killer. The pod restarts (via Kubernetes), runs for a while,
then is OOM-killed again. Memory limits aren't obviously misconfigured.

**Pattern**: Pre-built debug sidecar (Pattern 3). You need persistent
observability over time, not a one-shot inspection — a debug image with
process and syscall tracing tools is the right fit.

## Diagnostic walkthrough

### Step 1: confirm OOM is actually the cause

Don't assume; verify.

```bash
# Look for OOMKilled in container status
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
# Expect: OOMKilled (vs. Error, Completed, ContainerStatusUnknown)

# Look at kernel OOM events on the node
kubectl get events --sort-by='.lastTimestamp' \
  --field-selector reason=OOMKilling

# Check the memory limits set on the container
kubectl get pod <pod> -o jsonpath='{.spec.containers[0].resources}'
```

If `reason=OOMKilled`, you have your direction. If the limit is suspiciously
low for the workload (e.g., 128Mi for a Python ML service), that's likely
the issue — increase the limit and observe.

If memory limit is reasonable and OOM still happens, you have a leak.
Continue.

### Step 2: attach a debug sidecar with process-watch tools

```bash
# Choose your debug image. A team-maintained debug-toolkit is ideal:
DEBUG_IMAGE="internal-registry.corp/debug-toolkit:v3"
# For the lab, use a public toolset:
DEBUG_IMAGE="nicolaka/netshoot:v0.13"

# Attach to the running pod (catch it while it's not yet OOM-killed)
kubectl debug -it <pod> \
  --image=$DEBUG_IMAGE \
  --target=<pod> \
  --image-pull-policy=Never \
  -- sh
```

### Step 3: observe memory growth in real time

```bash
# Inside the debug container, watching from the shared PID namespace:

# 1. Identify the application's main process
ps aux
# Note the PID of your application process

# 2. Watch its RSS grow
while true; do
  ps -p <pid> -o pid,vsz,rss,cmd
  date
  sleep 10
done

# 3. If RSS grows monotonically, that's a leak. Capture a heap profile
#    if the application supports it (Go: pprof, Python: tracemalloc).
#    For native code: gcore <pid>

# 4. For more detail on what allocations are happening:
strace -p <pid> -e trace=memory -c
# Run for ~60 seconds, Ctrl+C, look at the syscall counts.
# Lots of brk/mmap with steady RSS climb = leak in user code.
```

### Step 4: correlate with application behavior

A memory leak often correlates with a specific request pattern. If you
have logs accessible:

```bash
# In one shell, watch memory growth
watch -n 5 'ps -p <pid> -o pid,rss,vsz'

# In another shell, watch application requests
kubectl logs <pod> -f --tail=100 | grep -E "POST|PUT"

# Correlate: does RSS jump after specific request types?
```

### Step 5: clean up

```bash
# Inside the debug container:
exit

# Application pod and its image are unchanged.
kubectl get pod <pod>
```

## What the trust contract looks like after this incident

The debug toolkit image (`internal-registry.corp/debug-toolkit:v3` in
the example above) is itself a hardened, signed, attested image —
maintained by your platform team via the same supply-chain pipeline as
production application images. The trust contract isn't weakened by
attaching it; it's *extended* to include the debugging surface.

Worth noting in your team's playbook: the debug toolkit's signature and
SBOM are themselves verifiable. Anyone reviewing the audit trail can
confirm that the debug session used an approved tool image, not an
arbitrary one pulled by the responder.

```bash
# After the incident, an audit might look like:
cosign verify \
  --certificate-identity-regexp "^https://github\\.com/<your-org>/debug-toolkit/.*$" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  internal-registry.corp/debug-toolkit:v3
```

## When this pattern isn't enough

Long-form memory leak investigation often requires *application-level*
heap profiling — pprof for Go, tracemalloc for Python, jcmd for Java.
These usually require running the profiler inside the application's own
process space, which a sidecar container can't do.

For that, the right pattern is: build a separate `:profiling` image
variant (`dhi.io/python:3.13-dev` plus your profiling tooling) and run
periodic profiling jobs in a dev or staging environment. Production
incidents then provide *symptoms*, and the profiling environment
provides *diagnosis*.

This separation — symptom in prod, diagnosis in dev — is the same
pattern as the dev-variant approach in scenario-pod-crashloop.md. The
trust contract stays intact in prod; the diagnostic capability lives
elsewhere.