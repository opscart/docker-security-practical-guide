#!/usr/bin/env bash
# teardown.sh — Remove the trust-control-plane platform cleanly.
#
# Removes the kind cluster (which deletes all workloads, Kyverno install,
# and the containerd auth config since it lived inside the node).
#
# Safe to re-run; no-op if cluster is already gone.

set -euo pipefail

CLUSTER_NAME="dhi-trust-control-plane"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" ]] && [[ "$TERM" != "dumb" ]]; then
  GREEN="$(tput setaf 2 2>/dev/null || echo)"
  YELLOW="$(tput setaf 3 2>/dev/null || echo)"
  BOLD="$(tput bold 2>/dev/null || echo)"
  RESET="$(tput sgr0 2>/dev/null || echo)"
else
  GREEN=""; YELLOW=""; BOLD=""; RESET=""
fi

step() { printf '\n%s==>%s %s%s%s\n' "$YELLOW" "$RESET" "$BOLD" "$1" "$RESET"; }
pass() { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }

step "Removing kind cluster: $CLUSTER_NAME"
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  kind delete cluster --name "$CLUSTER_NAME"
  pass "Cluster deleted"
else
  pass "Cluster '$CLUSTER_NAME' not present"
fi

echo ""
printf '%sTeardown complete.%s\n' "$GREEN" "$RESET"
echo ""