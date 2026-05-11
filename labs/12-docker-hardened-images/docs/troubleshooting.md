# Troubleshooting & Challenges

Real issues encountered while building this lab, with diagnoses and resolutions.
Each entry is something you'll likely hit too — capturing them here so you don't
have to re-derive the fixes.

---

## Trust Verification (E2 / verify-image.sh)

### Issue: `cosign verify dhi.io/python:3.13` returns "no signatures found"

**Symptom**:
```
cosign verify dhi.io/python:3.13 --key <DHI public key> --insecure-ignore-tlog=true
Error: no matching signatures
```

**Cause**: DHI signatures and attestations are not stored at the conventional
`<image>.sig` location next to the image. They live in a separate registry:
`registry.scout.docker.com/docker/dhi-<image>@sha256:<digest>`.

**Resolution**: Use `docker scout attest get --verify --skip-tlog` which performs
the two-step discover-then-verify flow. The underlying cryptographic primitive
is still cosign + DHI's published public key; Scout handles attestation
discovery. With `VERBOSE=1`, `verify-image.sh` prints the cosign-equivalent
command Scout ran internally.

**Reference**: Implemented in `tools/verify-image.sh`.

---

### Issue: `docker scout` reports "Log in with your Docker ID"

**Symptom**: Even after `docker login dhi.io` succeeds, `docker scout` commands
fail claiming you're not authenticated.

**Cause**: Docker Scout authenticates against Docker Hub (`index.docker.io`)
directly. `docker login dhi.io` only stores credentials for the `dhi.io`
registry endpoint, not for Docker Hub. They're separate auth contexts in
`~/.docker/config.json` even when using the same Docker Hub credentials
underneath.

**Resolution**:
```bash
docker login         # for Docker Scout (Docker Hub auth)
docker login dhi.io  # for pulling DHI images
```

Both required. Same credentials, two contexts.

---

## Fleet Audit (E1 / audit-fleet.sh)

### Issue: PyYAML installation fails on macOS Homebrew Python 3.14

**Symptom**:
```
ImportError: dlopen(.../pyexpat.cpython-314-darwin.so):
  Symbol not found: _XML_SetAllocTrackerActivationThreshold
```

**Cause**: Homebrew Python 3.14 was compiled against a newer libexpat than
the system version on macOS. Pip imports xmlrpc → xml.parsers → pyexpat,
which can't load. Affects any pip operation, not just PyYAML.

**Resolution chosen**: Eliminated PyYAML dependency entirely. The lab's
inventory file is JSON instead of YAML, parsed via Python's stdlib `json`
module. No external Python packages required.

**Alternative resolutions** if you need PyYAML for other reasons:
- `brew reinstall python@3.14` (often picks up newer libexpat)
- `brew install python@3.13` and switch to 3.13
- Manual pip bootstrap: `curl https://bootstrap.pypa.io/get-pip.py | python3 - --user`

---

### Issue: Python venv corrupted after recreating inside active venv

**Symptom**:
```
python3 -m venv .venv
Error: Command '...ensurepip --upgrade --default-pip' returned non-zero exit status 1
# ...then pip command not found inside the "active" venv
```

**Cause**: Running `python3 -m venv .venv` while *inside* a venv tries to
overwrite the active venv. If `ensurepip` fails mid-way (common with bleeding-
edge Python versions), you're left with a venv that has the activate script
but no pip.

**Resolution**:
```bash
deactivate
rm -rf .venv
# For our lab, venv isn't needed — pure stdlib works
```

**Lesson**: For single-script dependencies, prefer `pip install --user` over
venv. Less ceremony, less to break.

---

## Platform Bootstrap

### Issue: Port conflict on local registry

**Symptom**:
```
docker: Error response from daemon: failed to set up container networking:
Bind for 0.0.0.0:5001 failed: port is already allocated
```

**Cause**: Another container (often a forgotten registry from an earlier
project, like a previous minikube setup) is using the port.

**Resolution**: Check with `docker ps` and either stop the conflicting
container, or override the registry port:
```bash
REG_PORT=5002 ./bootstrap.sh
```

`bootstrap.sh` supports the `REG_PORT` environment variable since v2.

---

### Issue: kind cluster creation hangs at "Starting control-plane"

**Symptom**: Cluster creation spins on the control-plane init step for 4+
minutes, then fails with `kubelet is not healthy`.

**Cause**: Multiple possible causes — narrowed via diagnostic:
```bash
kind create cluster --name probe   # minimal cluster, no custom config
```
- If `probe` succeeds: the custom kind-config.yaml is the problem
- If `probe` also fails: environmental (Docker Desktop resources)

In our case, the custom `kind-config.yaml` used the deprecated `[mirrors]`
block which containerd 2.x (shipped with K8s 1.31+) removed.

**Resolution**: Use modern `config_path` approach in kind-config.yaml:
```yaml
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
```

Then write per-host `hosts.toml` files into that directory after cluster
creation.

---

### Issue: Local registry pull-through cache returns 404 for `?ns=` requests

**Symptom**: `crictl pull dhi.io/python:3.13` fails. Registry logs show:
```
"HEAD /python/manifests/3.13?ns=dhi.io HTTP/1.1" 404 19
```

**Cause**: Docker `registry:2`'s pull-through cache mode doesn't honor the
OCI Distribution `ns` query parameter that modern containerd sends when
talking to mirrors. The registry returns 404 immediately without attempting
to proxy upstream.

**Resolution chosen**: Removed the local pull-through cache entirely. The
mirror was a "production realism" decoration but not load-bearing for the
lab's thesis (admission control). Pre-loading images into the kind node
via `docker save | ctr import` is the standard kind pattern for private
registries.

**Alternative**: Use `zot` or distribution-registry v3 instead of `registry:2` —
both handle the `ns` parameter correctly. Trade: another tool to install.

---

### Issue: Containerd `hosts.toml` auth header doesn't work for token-auth registries

**Symptom**: With `[host.X.header] authorization = "Basic <creds>"` in
hosts.toml, containerd still gets 401:
```
failed to fetch anonymous token: ... 401 Unauthorized
```

**Cause**: The word "anonymous" is the giveaway. Containerd's per-host
`header` directive only applies to direct registry requests. For OAuth
token-exchange (which happens at a different endpoint — `dhi.io/token`),
containerd uses its credential resolver, not the per-host headers. So the
Basic auth header is never sent to the token endpoint, and containerd
performs an unauthenticated token fetch → 401.

**Resolution chosen**: Pre-load images into the kind node from the host
instead of trying to authenticate containerd directly. The host's `docker
pull` works because Docker's CLI auth is mature; containerd's in-cluster
auth for token-based registries is more complex.

```bash
docker pull dhi.io/python:3.13
docker save dhi.io/python:3.13 | \
  docker exec -i dhi-trust-control-plane-control-plane \
    ctr --namespace=k8s.io images import -
```

**Alternative**: Inject auth into containerd's main `config.toml` via
`containerdConfigPatches.registry.configs.<host>.auth` — this still works
in containerd 2.x but ties credentials to cluster lifetime and requires
recreating the cluster when credentials rotate.

---

### Issue: `kind load docker-image` fails with "content digest not found" on Apple Silicon

**Symptom**:
```
kind load docker-image dhi.io/python:3.13 --name dhi-trust-control-plane
ERROR: failed to load image: ...
ctr: content digest sha256:<X>: not found
```

**Cause**: `kind load docker-image` internally calls
`ctr import --all-platforms`. But `docker pull` on Apple Silicon only fetches
the single platform you need (arm64) — not all platforms. When `ctr` looks
for the other-platform manifests, they don't exist locally → "content digest
not found."

**Resolution**: Bypass `kind load` and pipe `docker save` directly to
`ctr import` without `--all-platforms`:

```bash
docker save dhi.io/python:3.13 | \
  docker exec -i dhi-trust-control-plane-control-plane \
    ctr --namespace=k8s.io images import -
```

Then verify with `--image-pull-policy=Never` to confirm pods can use the
pre-loaded image without attempting a fresh pull.

---

## How to add new entries

When you hit a new issue while extending this lab, add an entry with:
1. **Symptom** — verbatim error output (helps future readers grep)
2. **Cause** — the underlying mechanism, not just "X was broken"
3. **Resolution** — what actually fixed it, including any tradeoffs
4. (optional) **Alternative** — paths considered but not taken, with reasons

The goal is that someone reading this file 6 months from now can fix the same
issue in 5 minutes instead of 5 hours.