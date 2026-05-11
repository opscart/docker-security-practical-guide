#!/usr/bin/env bash
# bootstrap.sh — Bring up the trust-control-plane platform for Lab 12.
#
# Architecture: kind cluster + Kyverno, with containerd authenticated
# directly to dhi.io. No local registry — containerd pulls dhi.io images
# straight from upstream using credentials injected into hosts.toml.
#
# Orchestrates:
#   1. Prerequisite checks (docker, kind, kubectl, helm, jq, dhi.io auth)
#   2. kind Kubernetes cluster
#   3. dhi.io auth: write hosts.toml on kind node with Basic auth header
#      (containerd performs the Basic→Bearer token exchange with dhi.io
#      automatically — same flow `docker pull` does)
#   4. Kyverno admission controller installed via Helm
#   5. Health verification — confirm cluster can pull from dhi.io
#
# Idempotent: re-running is safe.
#
# Usage:
#   ./bootstrap.sh                # bring everything up
#   ./bootstrap.sh --skip-kyverno # cluster + auth only, no admission controller
#   ./bootstrap.sh --teardown     # invoke teardown.sh
#
# Environment overrides:
#   DHI_USER / DHI_PASS           # explicit credentials, bypasses extraction
#                                 # from ~/.docker/config.json (needed when
#                                 # docker uses macOS Keychain helper)
#
# Exit codes:
#   0  platform up and healthy
#   1  bring-up failed
#   2  prerequisite missing

set -euo pipefail

# ---------- configuration ----------

CLUSTER_NAME="dhi-trust-control-plane"
NODE_NAME="${CLUSTER_NAME}-control-plane"
KYVERNO_NAMESPACE="kyverno"
KYVERNO_VERSION="3.3.4"

SKIP_KYVERNO=0
TEARDOWN=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-kyverno) SKIP_KYVERNO=1; shift ;;
    --teardown)     TEARDOWN=1; shift ;;
    -h|--help)      sed -n '2,30p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *)              echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# ---------- color output ----------

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" ]] && [[ "$TERM" != "dumb" ]]; then
  GREEN="$(tput setaf 2 2>/dev/null || echo)"
  RED="$(tput setaf 1 2>/dev/null || echo)"
  YELLOW="$(tput setaf 3 2>/dev/null || echo)"
  BOLD="$(tput bold 2>/dev/null || echo)"
  DIM="$(tput dim 2>/dev/null || echo)"
  RESET="$(tput sgr0 2>/dev/null || echo)"
else
  GREEN=""; RED=""; YELLOW=""; BOLD=""; DIM=""; RESET=""
fi

step() { printf '\n%s==>%s %s%s%s\n' "$YELLOW" "$RESET" "$BOLD" "$1" "$RESET"; }
pass() { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
fail() { printf '  %s✗%s %s\n' "$RED"   "$RESET" "$1"; }
info() { printf '  %s·%s %s\n' "$YELLOW" "$RESET" "$1"; }
dim()  { printf '  %s%s%s\n'   "$DIM"   "$1" "$RESET"; }

# ---------- teardown shortcut ----------

if [[ "$TEARDOWN" == "1" ]]; then
  exec "$SCRIPT_DIR/teardown.sh"
fi

# ---------- prerequisite checks ----------

check_prereqs() {
  step "1. Prerequisite checks"
  local missing=()
  for cmd in docker kind kubectl helm jq; do
    if command -v "$cmd" >/dev/null 2>&1; then
      pass "$cmd: $(command -v "$cmd")"
    else
      missing+=("$cmd")
      fail "$cmd: not found"
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo ""
    fail "Missing prerequisite(s): ${missing[*]}"
    echo ""
    echo "  Install on macOS:"
    echo "    brew install kind kubectl helm jq"
    echo "  Docker Desktop must be running."
    exit 2
  fi

  if ! docker info >/dev/null 2>&1; then
    fail "Docker daemon not responding. Start Docker Desktop."
    exit 2
  fi
  pass "docker daemon: responsive"

  if ! docker_config_has_dhi_auth; then
    fail "Not authenticated to dhi.io"
    echo ""
    echo "  Containerd will be configured to pull dhi.io images using your"
    echo "  Docker Hub credentials. Run:"
    echo ""
    echo "      docker login dhi.io"
    echo ""
    echo "  Then re-run this script."
    exit 2
  fi
  pass "dhi.io auth: present in ~/.docker/config.json"
}

docker_config_has_dhi_auth() {
  local config="$HOME/.docker/config.json"
  [[ -f "$config" ]] || return 1
  jq -e '.auths["dhi.io"] // empty' "$config" >/dev/null 2>&1
}

# ---------- credential extraction ----------

extract_dhi_creds() {
  # If pre-set via environment, trust them.
  if [[ -n "${DHI_USER:-}" && -n "${DHI_PASS:-}" ]]; then
    return 0
  fi

  local config="$HOME/.docker/config.json"
  local auth_b64
  auth_b64=$(jq -r '.auths["dhi.io"].auth // empty' "$config" 2>/dev/null || true)

  if [[ -n "$auth_b64" ]]; then
    local decoded
    decoded=$(echo "$auth_b64" | base64 -d 2>/dev/null || echo "")
    DHI_USER="${decoded%%:*}"
    DHI_PASS="${decoded#*:}"
    if [[ -n "$DHI_USER" && -n "$DHI_PASS" && "$DHI_USER" != "$DHI_PASS" ]]; then
      return 0
    fi
  fi

  fail "Could not extract DHI credentials from ~/.docker/config.json"
  echo ""
  echo "  Your Docker config uses a credentials helper (likely macOS Keychain),"
  echo "  which stores credentials separately from config.json."
  echo ""
  echo "  Workaround: set DHI_USER and DHI_PASS environment variables and"
  echo "  re-run this script:"
  echo ""
  echo "      export DHI_USER='your-docker-hub-username'"
  echo "      export DHI_PASS='your-docker-hub-pat-or-password'"
  echo "      ./bootstrap.sh"
  return 1
}

# ---------- kind cluster ----------

start_cluster() {
  step "2. kind cluster"

  if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    pass "Cluster '${CLUSTER_NAME}' already exists"
  else
    info "Creating cluster (this takes ~30-90s)"
    kind create cluster \
        --name "$CLUSTER_NAME" \
        --config "$SCRIPT_DIR/kind-config.yaml"
    pass "Cluster '${CLUSTER_NAME}' created"
  fi

  kubectl --context "kind-${CLUSTER_NAME}" cluster-info >/dev/null
  pass "Cluster reachable"
}

# ---------- containerd dhi.io authentication ----------
#
# Modern containerd 2.x reads per-registry config from /etc/containerd/certs.d
# (the path is set by kind-config.yaml's config_path directive). We write a
# hosts.toml that:
#   - Tells containerd this is the dhi.io registry
#   - Provides Basic auth credentials in the request header
#
# When containerd sends a request to dhi.io with the Basic header, dhi.io
# responds with a 401 + WWW-Authenticate Bearer challenge. Containerd then
# exchanges Basic for Bearer at the dhi.io/token endpoint and retries with
# the bearer token — this is the same OAuth flow `docker pull` uses.

configure_dhi_auth() {
  step "3. Configure containerd dhi.io authentication"

  extract_dhi_creds || exit 2
  pass "DHI credentials resolved (user: $DHI_USER)"

  # Encode credentials as Basic auth.
  # Note: the value is Basic <base64("user:password")>
  local basic_auth
  basic_auth=$(printf '%s:%s' "$DHI_USER" "$DHI_PASS" | base64 | tr -d '\n')

  info "Writing /etc/containerd/certs.d/dhi.io/hosts.toml on kind node"
  docker exec "$NODE_NAME" mkdir -p /etc/containerd/certs.d/dhi.io

  # 600 perms — the file contains a credential and shouldn't be readable
  # by other processes on the node.
  docker exec -i "$NODE_NAME" sh -c \
      'cat > /etc/containerd/certs.d/dhi.io/hosts.toml && chmod 600 /etc/containerd/certs.d/dhi.io/hosts.toml' \
      <<EOF
server = "https://dhi.io"

[host."https://dhi.io"]
  capabilities = ["pull", "resolve"]

  [host."https://dhi.io".header]
    authorization = "Basic ${basic_auth}"
EOF

  pass "hosts.toml written (containerd will auth to dhi.io directly)"
  dim "(no containerd restart needed — certs.d is read on every pull)"
}

# ---------- Kyverno ----------

install_kyverno() {
  if [[ "$SKIP_KYVERNO" == "1" ]]; then
    step "4. Kyverno (skipped per --skip-kyverno)"
    return 0
  fi

  step "4. Kyverno admission controller"

  if helm --kube-context "kind-${CLUSTER_NAME}" list -n "$KYVERNO_NAMESPACE" 2>/dev/null \
       | grep -q "^kyverno"; then
    pass "Kyverno already installed in namespace '$KYVERNO_NAMESPACE'"
  else
    info "Adding Helm repo"
    helm --kube-context "kind-${CLUSTER_NAME}" repo add kyverno \
        https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
    helm --kube-context "kind-${CLUSTER_NAME}" repo update >/dev/null

    info "Installing Kyverno v${KYVERNO_VERSION} (takes ~30s)"
    helm --kube-context "kind-${CLUSTER_NAME}" install kyverno kyverno/kyverno \
        --namespace "$KYVERNO_NAMESPACE" \
        --create-namespace \
        --version "$KYVERNO_VERSION" \
        --wait \
        --timeout 3m >/dev/null
    pass "Kyverno v${KYVERNO_VERSION} installed"
  fi

  local ready
  ready=$(kubectl --context "kind-${CLUSTER_NAME}" -n "$KYVERNO_NAMESPACE" \
            get pods -l app.kubernetes.io/component=admission-controller \
            -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' \
            2>/dev/null || echo "")
  if [[ "$ready" == *"True"* ]]; then
    pass "Kyverno admission controller pod(s) ready"
  else
    fail "Kyverno admission controller not yet ready"
    info "Check: kubectl -n $KYVERNO_NAMESPACE get pods"
  fi
}

# ---------- verification ----------

verify_platform() {
  step "5. Verification"

  kubectl --context "kind-${CLUSTER_NAME}" get nodes >/dev/null
  pass "Cluster nodes reachable"

  # End-to-end test: confirm containerd can actually pull from dhi.io.
  # This proves the hosts.toml auth header is being applied and that the
  # Basic→Bearer token exchange with dhi.io is working.
  info "Pulling dhi.io/python:3.13 via containerd (proves auth works)"
  if docker exec "$NODE_NAME" crictl pull dhi.io/python:3.13 >/dev/null 2>&1; then
    pass "containerd successfully pulled dhi.io/python:3.13"
  else
    fail "Containerd pull from dhi.io failed"
    info "Debug command:"
    info "    docker exec $NODE_NAME crictl pull dhi.io/python:3.13"
    info ""
    info "Inspect hosts.toml on node:"
    info "    docker exec $NODE_NAME cat /etc/containerd/certs.d/dhi.io/hosts.toml"
    info ""
    info "Common causes:"
    info "  - Stale credentials in ~/.docker/config.json (re-run 'docker login dhi.io')"
    info "  - DHI service-side issue (try 'docker pull dhi.io/python:3.13' on the host)"
    return 1
  fi

  if [[ "$SKIP_KYVERNO" != "1" ]]; then
    local kyv_pods
    kyv_pods=$(kubectl --context "kind-${CLUSTER_NAME}" -n "$KYVERNO_NAMESPACE" \
                 get pods --no-headers 2>/dev/null | wc -l | tr -d ' ')
    pass "Kyverno: ${kyv_pods} pod(s) running"
  fi
}

# ---------- main ----------

main() {
  printf '\n%sLab 12 platform bootstrap%s\n' "$BOLD" "$RESET"
  printf '%s================================================================%s\n' "$DIM" "$RESET"

  check_prereqs
  start_cluster
  configure_dhi_auth
  install_kyverno
  verify_platform

  step "Done"
  echo ""
  printf '  %sPlatform is up.%s\n' "$GREEN" "$RESET"
  echo ""
  echo "  Cluster context:    kind-${CLUSTER_NAME}"
  echo "  Kyverno namespace:  ${KYVERNO_NAMESPACE}"
  echo "  DHI auth:           /etc/containerd/certs.d/dhi.io/hosts.toml (on node)"
  echo ""
  echo "  Next:"
  echo "    kubectl get nodes"
  echo "    kubectl -n ${KYVERNO_NAMESPACE} get pods"
  echo "    kubectl run dhi-test --image=dhi.io/python:3.13 --rm -it --restart=Never -- python -c \"print('hello')\""
  echo ""
  echo "  Tear down:    ./platform/teardown.sh   (or make down)"
  echo ""
}

main