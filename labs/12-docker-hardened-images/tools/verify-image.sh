#!/usr/bin/env bash
# verify-image.sh — Verify cryptographic trust signals on a Docker Hardened Image.
#
# Validates four trust-layer signals on a DHI image:
#   1. Attestation discovery  — image is published with attestations attached
#   2. CycloneDX SBOM         — component manifest is signed and complete
#   3. SLSA provenance        — build process is cryptographically verifiable
#   4. OpenVEX                — vulnerability disclosure is signed
#
# Usage:
#   ./verify-image.sh                          # defaults to dhi.io/python:3.13
#   ./verify-image.sh dhi.io/node:24
#   VERBOSE=1 ./verify-image.sh dhi.io/...     # show full tool output
#
# Prerequisites:
#   - docker (with Docker Scout CLI 1.18.2+ — bundled with Docker Desktop)
#   - Authenticated to dhi.io: `docker login dhi.io` (Docker Hub creds or PAT)
#
# Why docker scout (not pure cosign):
#   DHI signatures and attestations are stored in registry.scout.docker.com,
#   NOT at the conventional <image>.sig location next to dhi.io/<image>:<tag>.
#   Pure `cosign verify dhi.io/python:3.13` cannot find them. Docker's own
#   docs document the actual cosign-equivalent command as:
#
#     cosign verify \
#       registry.scout.docker.com/docker/dhi-python@sha256:<digest> \
#       --key https://registry.scout.docker.com/keyring/dhi/latest.pub \
#       --insecure-ignore-tlog=true
#
#   `docker scout attest get --verify --skip-tlog` wraps this two-step
#   discover+verify flow. Verbose mode prints the cosign-equivalent command
#   that Docker Scout used internally, preserving the cosign-as-verifier
#   story for the lab. Vendor-neutrality of the cryptographic primitive
#   (cosign) is preserved; only attestation discovery is Docker-specific.
#
# Exit codes:
#   0  all trust signals verified
#   1  one or more verifications failed
#   2  missing prerequisite

set -euo pipefail

IMAGE="${1:-dhi.io/python:3.13}"
VERBOSE="${VERBOSE:-0}"

# ---------- color output ----------

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" ]] && [[ "$TERM" != "dumb" ]]; then
  GREEN="$(tput setaf 2 2>/dev/null || echo)"
  RED="$(tput setaf 1 2>/dev/null || echo)"
  YELLOW="$(tput setaf 3 2>/dev/null || echo)"
  DIM="$(tput dim 2>/dev/null || echo)"
  BOLD="$(tput bold 2>/dev/null || echo)"
  RESET="$(tput sgr0 2>/dev/null || echo)"
else
  GREEN=""; RED=""; YELLOW=""; DIM=""; BOLD=""; RESET=""
fi

pass() { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
fail() { printf '  %s✗%s %s\n' "$RED"   "$RESET" "$1"; }
info() { printf '  %s·%s %s\n' "$YELLOW" "$RESET" "$1"; }
dim()  { printf '  %s%s%s\n'   "$DIM"   "$1" "$RESET"; }

# ---------- prerequisite checks ----------

check_prereqs() {
  if ! command -v docker >/dev/null 2>&1; then
    fail "Missing prerequisite: docker"
    exit 2
  fi
  if ! docker scout version >/dev/null 2>&1; then
    fail "docker scout CLI is not available"
    info "Docker Scout ships with Docker Desktop. Check 'docker scout version'."
    info "If missing: https://docs.docker.com/scout/install/"
    exit 2
  fi
}

# ---------- attestation listing ----------

list_attestations() {
  printf '\n%s1. Attestation discovery%s\n' "$BOLD" "$RESET"
  local out
  if out=$(docker scout attest list "$IMAGE" 2>&1); then
    pass "Attestations listed for $IMAGE"
    if [[ "$VERBOSE" == "1" ]]; then
      printf '%s' "$out" | sed 's/^/      /'
    else
      info "$(printf '%s' "$out" | head -1)"
      info "(run with VERBOSE=1 to see the full attestation listing)"
    fi
    return 0
  else
    fail "Could not list attestations"
    printf '%s' "$out" | sed 's/^/      /'
    return 1
  fi
}

# ---------- attestation verification ----------

verify_attestation() {
  local predicate_type="$1" label="$2" heading="$3"
  printf '\n%s%s%s\n' "$BOLD" "$heading" "$RESET"
  dim "predicate-type: $predicate_type"

  local out
  if out=$(docker scout attest get \
              --predicate-type "$predicate_type" \
              --verify --skip-tlog \
              "$IMAGE" 2>&1); then
    pass "$label verified"
    if [[ "$VERBOSE" == "1" ]]; then
      local cosign_line
      cosign_line=$(printf '%s' "$out" | grep -E 'cosign verify' | head -1 || true)
      [[ -n "$cosign_line" ]] && info "Cosign equivalent: ${cosign_line# }"
    fi
    return 0
  else
    fail "$label verification failed"
    printf '%s' "$out" | sed 's/^/      /'
    return 1
  fi
}

# ---------- main ----------

printf '\n%sVerifying trust layer for: %s%s\n' "$BOLD" "$IMAGE" "$RESET"
echo "================================================================"
[[ "$VERBOSE" == "1" ]] && info "VERBOSE mode on"

check_prereqs

PASSES=0
FAILS=0

if list_attestations; then PASSES=$((PASSES + 1)); else FAILS=$((FAILS + 1)); fi

# DHI predicate types (from Docker docs):
#   https://cyclonedx.org/bom/v1.6              CycloneDX SBOM
#   https://slsa.dev/provenance/v0.2            SLSA provenance v0.2
#   https://openvex.dev/ns/v0.2.0               OpenVEX vulnerability disclosure
#   https://scout.docker.com/sbom/v0.1          Docker Scout SBOM format
#   https://scout.docker.com/tests/v0.1         Docker Scout test results

if verify_attestation \
     "https://cyclonedx.org/bom/v1.6" \
     "CycloneDX SBOM attestation" \
     "2. CycloneDX SBOM"; then
  PASSES=$((PASSES + 1))
else
  FAILS=$((FAILS + 1))
fi

if verify_attestation \
     "https://slsa.dev/provenance/v0.2" \
     "SLSA provenance attestation" \
     "3. SLSA provenance"; then
  PASSES=$((PASSES + 1))
else
  FAILS=$((FAILS + 1))
fi

if verify_attestation \
     "https://openvex.dev/ns/v0.2.0" \
     "OpenVEX vulnerability disclosure" \
     "4. OpenVEX"; then
  PASSES=$((PASSES + 1))
else
  FAILS=$((FAILS + 1))
fi

echo ""
echo "================================================================"
printf '%sTrust verification report%s\n' "$BOLD" "$RESET"
echo "  Image:    $IMAGE"
printf '  Passed:   %s%d/4%s\n' "$GREEN" "$PASSES" "$RESET"
printf '  Failed:   %s%d/4%s\n' "$RED"   "$FAILS"  "$RESET"

if [[ $FAILS -eq 0 ]]; then
  printf '  Result:   %sTRUSTED%s — all trust-layer signals verified\n' "$GREEN" "$RESET"
  echo ""
  echo "  Re-run with VERBOSE=1 to see the underlying cosign verification commands."
  exit 0
else
  printf '  Result:   %sUNVERIFIED%s — one or more trust signals failed\n' "$RED" "$RESET"
  echo ""
  echo "  For diagnosis, re-run with VERBOSE=1 to see full tool output:"
  echo "    VERBOSE=1 $0 $IMAGE"
  echo ""
  echo "  Common causes:"
  echo "    - Not authenticated:        run 'docker login dhi.io'"
  echo "    - Predicate-type mismatch:  DHI may use a different version (e.g. v1.0 SLSA)"
  echo "    - Stale Docker Scout CLI:   --skip-tlog requires 1.18.2+; check 'docker scout version'"
  exit 1
fi