# Scenario: "Service X is unreachable from this pod"

**Symptom**: An application running on a DHI-based image reports
connection timeouts to another service in the cluster. The other service
is healthy and reachable from elsewhere. The application has no shell
to run `curl`, `nslookup`, or `nc` from inside the container.

**Pattern**: Ephemeral debug container (Pattern 1).

## Diagnostic walkthrough

### Step 1: rule out the obvious from outside the pod

```bash
# Confirm the target service has endpoints
kubectl -n <target-ns> get endpoints <target-service>
# Look for a non-empty ENDPOINTS column

# Confirm the source pod's DNS config is sane
kubectl -n <source-ns> get pod <source-pod> \
  -o jsonpath='{.spec.dnsPolicy}'
# Expect: ClusterFirst (or similar)

# Confirm there's no NetworkPolicy blocking egress
kubectl -n <source-ns> get networkpolicy
# If results, inspect them: kubectl describe networkpolicy <name>
```

If any of these reveals the problem, you're done. Most "unreachable
service" issues are NetworkPolicy or missing-endpoints issues.

### Step 2: attach an ephemeral debug container

If outside-the-pod diagnostics turned up nothing, get inside the pod's
network namespace:

```bash
./debug-distroless.sh <source-pod> -n <source-ns>
# Or directly:
kubectl -n <source-ns> debug -it <source-pod> \
  --image=nicolaka/netshoot:v0.13 \
  --target=<source-pod> \
  --image-pull-policy=Never \
  -- sh
```

### Step 3: diagnose from inside the network namespace

The debug container now shares the source pod's network namespace. DNS
resolution, routes, iptables — everything looks like what the
application sees.

```bash
# Inside the debug container:

# 1. Does DNS resolve the target?
nslookup <target-service>.<target-ns>.svc.cluster.local
# Expect: a 10.x or 172.x ClusterIP, not NXDOMAIN

# 2. Is the IP reachable?
nc -v -w 2 <resolved-ip> <port>
# Expect: "open" or connection succeeded

# 3. If TCP succeeded, does the HTTP layer work?
curl -v --connect-timeout 5 http://<target-service>.<target-ns>.svc.cluster.local:<port>/healthz
# Look at: status code, response time, TLS errors

# 4. If everything from the debug container works, the issue may be the
#    application's HTTP client config (timeouts, TLS settings, headers).
#    That's an application-layer issue, not infrastructure.
```

### Step 4: exit cleanly

```bash
# Inside the debug container:
exit

# Back at your terminal — the application pod is untouched:
kubectl -n <source-ns> get pod <source-pod>
# Same image, same digest, no new persistent containers.
```

## What the trust contract looks like after this incident

| Property | Before incident | After incident |
|----------|----------------|----------------|
| Application image | `dhi.io/python:3.13` | `dhi.io/python:3.13` |
| Image digest | sha256:abc... | sha256:abc... (unchanged) |
| Signed by | GitHub OIDC workflow | GitHub OIDC workflow |
| SBOM attestation | present | present |
| Audit trail | n/a | "ephemeral container `debug-shell` attached at T+0, exited at T+5min, by user@example.com" |

The debug session is in the audit log. The image is untouched. The
trust attestations remain valid for the application container.

## Common variations

- **TLS handshake fails** — the application image may have an outdated
  CA bundle (rare with DHI, but possible if the destination uses a
  custom internal CA). Check `/etc/ssl/certs/` if you have file access
  via Pattern 2 (dev-variant).

- **mTLS / service mesh issues** — Linkerd or Istio sidecars add their
  own network namespace shenanigans. The debug container joins the
  *application* container's namespace; if the mesh proxy is a different
  container in the same pod, target it instead:
  `--target=istio-proxy` etc.

- **DNS works for some names, not others** — check `/etc/resolv.conf`
  inside the debug container. CoreDNS misconfigurations show up here.