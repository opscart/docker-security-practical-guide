#!/usr/bin/env bash
# debug-distroless.sh — attach a debug shell to a running distroless pod.
#
# Wraps `kubectl debug` with sensible defaults for the trust-control-plane
# pattern: debug containers come from a trusted registry, target the
# application container's namespaces, and exit cleanly.
#
# Usage:
#   ./debug-distroless.sh <pod-name> [-n <namespace>] [-i <debug-image>]
#
# Examples:
#   ./debug-distroless.sh dhi-app
#   ./debug-distroless.sh dhi-app -n production
#   ./debug-distroless.sh dhi-app -i internal-registry.corp/debug-toolkit:v3
#
# Defaults:
#   namespace:     default
#   debug image:   busybox:1.37 (substitute your trusted internal debug image)
#
# Exit codes:
#   0  debug session completed normally
#   1  pod not found or not running
#   2  argument error

set -euo pipefail

# ---------- defaults ----------

POD=""
NAMESPACE="default"
DEBUG_IMAGE="busybox:1.37"
SHELL_CMD="sh"

# ---------- arg parsing ----------

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace)   NAMESPACE="$2"; shift 2 ;;
    -i|--image)       DEBUG_IMAGE="$2"; shift 2 ;;
    -s|--shell)       SHELL_CMD="$2"; shift 2 ;;
    -h|--help)        sed -n '2,18p' "$0" | sed 's/^# \?//'; exit 0 ;;
    -*)               echo "Unknown flag: $1" >&2; exit 2 ;;
    *)                POD="$1"; shift ;;
  esac
done

if [[ -z "$POD" ]]; then
  echo "ERROR: pod name required" >&2
  echo "Usage: $0 <pod-name> [-n <namespace>] [-i <debug-image>]" >&2
  exit 2
fi

# ---------- color output ----------

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" ]] && [[ "$TERM" != "dumb" ]]; then
  GREEN="$(tput setaf 2 2>/dev/null || echo)"
  YELLOW="$(tput setaf 3 2>/dev/null || echo)"
  RED="$(tput setaf 1 2>/dev/null || echo)"
  BOLD="$(tput bold 2>/dev/null || echo)"
  DIM="$(tput dim 2>/dev/null || echo)"
  RESET="$(tput sgr0 2>/dev/null || echo)"
else
  GREEN=""; YELLOW=""; RED=""; BOLD=""; DIM=""; RESET=""
fi

step() { printf '\n%s==>%s %s%s%s\n' "$YELLOW" "$RESET" "$BOLD" "$1" "$RESET"; }
pass() { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
fail() { printf '  %s✗%s %s\n' "$RED" "$RESET" "$1"; }
info() { printf '  %s·%s %s\n' "$DIM" "$RESET" "$1"; }

# ---------- pre-flight ----------

step "Pre-flight"

if ! command -v kubectl >/dev/null 2>&1; then
  fail "kubectl not found in PATH"
  exit 2
fi
pass "kubectl: $(command -v kubectl)"

# Confirm pod exists and is Running
POD_STATUS=$(kubectl -n "$NAMESPACE" get pod "$POD" \
               -o jsonpath='{.status.phase}' 2>/dev/null || echo "")

if [[ -z "$POD_STATUS" ]]; then
  fail "Pod '$POD' not found in namespace '$NAMESPACE'"
  echo ""
  echo "  Tried: kubectl -n $NAMESPACE get pod $POD" >&2
  echo "  Hint:  kubectl -n $NAMESPACE get pods    # to list available pods" >&2
  exit 1
fi

if [[ "$POD_STATUS" != "Running" ]]; then
  fail "Pod '$POD' is not Running (current: $POD_STATUS)"
  echo ""
  echo "  kubectl debug requires a Running pod. For crashloop scenarios," >&2
  echo "  use one of these instead:" >&2
  echo "    kubectl logs --previous $POD                        # last container logs" >&2
  echo "    kubectl describe pod $POD                           # events + state" >&2
  echo "    kubectl debug $POD --copy-to=$POD-debug --image=<dev-variant>" >&2
  exit 1
fi
pass "Pod '$POD' is Running in namespace '$NAMESPACE'"

# Show the trust state of the application BEFORE we attach a debug container
APP_IMAGE=$(kubectl -n "$NAMESPACE" get pod "$POD" \
              -o jsonpath='{.spec.containers[0].image}')
info "App image (unchanged by this script): $APP_IMAGE"

# ---------- launch ----------

step "Attaching ephemeral debug container"
info "Debug image: $DEBUG_IMAGE"
info "Target container: $POD (PID and network namespaces shared)"
info "Shell: $SHELL_CMD"
echo ""
echo "  When you're done, type 'exit' to close the debug shell."
echo "  The application container ($POD) is unaffected by anything you do here."
echo ""

# --target makes the debug container share the application container's
# PID namespace. Without --target, you'd only see the debug container's own
# processes, which defeats the purpose.
kubectl -n "$NAMESPACE" debug \
  -it "$POD" \
  --image="$DEBUG_IMAGE" \
  --target="$POD" \
  --image-pull-policy=Never \
  -- "$SHELL_CMD" \
  || true   # don't fail if user exits non-zero (e.g., curl returned non-200)

# ---------- post-flight ----------

step "Post-flight"

# Confirm application container is still healthy
POST_STATUS=$(kubectl -n "$NAMESPACE" get pod "$POD" \
                -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
POST_IMAGE=$(kubectl -n "$NAMESPACE" get pod "$POD" \
               -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || echo "")

if [[ "$POST_STATUS" == "Running" ]] && [[ "$POST_IMAGE" == "$APP_IMAGE" ]]; then
  pass "Application pod still Running, image unchanged ($POST_IMAGE)"
else
  fail "Pod state changed during debug session"
  info "Status: $POD_STATUS → $POST_STATUS"
  info "Image:  $APP_IMAGE → $POST_IMAGE"
fi

# List ephemeral containers that ran (audit trail)
EPHEMERAL_COUNT=$(kubectl -n "$NAMESPACE" get pod "$POD" \
                    -o jsonpath='{.spec.ephemeralContainers[*].name}' 2>/dev/null | wc -w | tr -d ' ')
info "Ephemeral containers attached during session: $EPHEMERAL_COUNT"
info "(Run 'kubectl describe pod $POD' for full audit detail)"

echo ""