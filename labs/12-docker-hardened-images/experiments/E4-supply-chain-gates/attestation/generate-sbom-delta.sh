#!/usr/bin/env bash
# generate-sbom-delta.sh — compute the SBOM delta between a DHI base image
# and an application image built on top of it.
#
# This is the article's most credibility-building artifact: concrete numbers
# showing "DHI gives us a clean base; here's exactly what our app adds on
# top." Reproducible by anyone with docker + syft + jq.
#
# Output: a JSON document with three keys —
#   base_only:     packages in DHI base but not in app image
#                  (should be empty for well-behaved multi-stage builds)
#   added_by_app:  packages present in app image but not in DHI base
#                  (these are what our application contributes)
#   shared:        packages in both (DHI base packages that survive into the app)
#
# Usage:
#   ./generate-sbom-delta.sh dhi.io/python:3.13 ghcr.io/opscart/dhi-sample-app:latest
#   ./generate-sbom-delta.sh dhi.io/python:3.13 ghcr.io/opscart/dhi-sample-app:latest --json
#
# Prerequisites: docker (or skopeo) + syft + jq.

set -euo pipefail

# ---------- arg parsing ----------

BASE_IMAGE="${1:-}"
APP_IMAGE="${2:-}"
OUTPUT_FORMAT="human"

if [[ "${3:-}" == "--json" ]]; then
  OUTPUT_FORMAT="json"
fi

if [[ -z "$BASE_IMAGE" ]] || [[ -z "$APP_IMAGE" ]]; then
  cat <<EOF
Usage: $0 <base-image> <app-image> [--json]

Examples:
  $0 dhi.io/python:3.13 ghcr.io/opscart/docker-security-practical-guide/dhi-sample-app:latest
  $0 dhi.io/python:3.13 ghcr.io/opscart/.../dhi-sample-app:latest --json

Compares two SBOMs and reports what packages the app image adds on top
of the DHI base.
EOF
  exit 2
fi

# ---------- color output ----------

if [[ -t 1 ]] && [[ "$OUTPUT_FORMAT" == "human" ]] && command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" ]] && [[ "$TERM" != "dumb" ]]; then
  GREEN="$(tput setaf 2 2>/dev/null || echo)"
  YELLOW="$(tput setaf 3 2>/dev/null || echo)"
  BLUE="$(tput setaf 4 2>/dev/null || echo)"
  BOLD="$(tput bold 2>/dev/null || echo)"
  DIM="$(tput dim 2>/dev/null || echo)"
  RESET="$(tput sgr0 2>/dev/null || echo)"
else
  GREEN=""; YELLOW=""; BLUE=""; BOLD=""; DIM=""; RESET=""
fi

step() { [[ "$OUTPUT_FORMAT" == "human" ]] && printf '%s==>%s %s\n' "$YELLOW" "$RESET" "$1" >&2; }
note() { [[ "$OUTPUT_FORMAT" == "human" ]] && printf '%s    %s%s\n' "$DIM" "$1" "$RESET" >&2; }

# ---------- prereqs ----------

for cmd in syft jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    case "$cmd" in
      syft) echo "  Install: brew install syft   (or see https://github.com/anchore/syft)" >&2 ;;
      jq)   echo "  Install: brew install jq" >&2 ;;
    esac
    exit 2
  fi
done

# ---------- SBOM generation ----------

TMPDIR_SBOM=$(mktemp -d)
trap 'rm -rf "$TMPDIR_SBOM"' EXIT

step "Generating SBOM for base image: $BASE_IMAGE"
syft "$BASE_IMAGE" -o cyclonedx-json="$TMPDIR_SBOM/base.json" 2>/dev/null || {
  echo "ERROR: syft failed for $BASE_IMAGE" >&2
  echo "Common cause: not authenticated to dhi.io (run 'docker login dhi.io')" >&2
  exit 1
}
base_count=$(jq '.components | length' "$TMPDIR_SBOM/base.json")
note "Base packages: $base_count"

step "Generating SBOM for app image: $APP_IMAGE"
syft "$APP_IMAGE" -o cyclonedx-json="$TMPDIR_SBOM/app.json" 2>/dev/null || {
  echo "ERROR: syft failed for $APP_IMAGE" >&2
  exit 1
}
app_count=$(jq '.components | length' "$TMPDIR_SBOM/app.json")
note "App packages:  $app_count"

# ---------- delta computation ----------

# Extract package keys as "name@version" so we can use jq set ops.
# CycloneDX v1.6 puts package name in .name and version in .version.

step "Computing delta"

jq -r '.components[]? | "\(.name)@\(.version // "?")"' "$TMPDIR_SBOM/base.json" \
  | sort -u > "$TMPDIR_SBOM/base.keys"
jq -r '.components[]? | "\(.name)@\(.version // "?")"' "$TMPDIR_SBOM/app.json" \
  | sort -u > "$TMPDIR_SBOM/app.keys"

# Set operations via comm:
#   comm -23: lines unique to first file (base_only)
#   comm -13: lines unique to second file (added_by_app)
#   comm -12: lines common to both (shared)
comm -23 "$TMPDIR_SBOM/base.keys" "$TMPDIR_SBOM/app.keys" > "$TMPDIR_SBOM/base_only.txt"
comm -13 "$TMPDIR_SBOM/base.keys" "$TMPDIR_SBOM/app.keys" > "$TMPDIR_SBOM/added.txt"
comm -12 "$TMPDIR_SBOM/base.keys" "$TMPDIR_SBOM/app.keys" > "$TMPDIR_SBOM/shared.txt"

base_only_count=$(wc -l < "$TMPDIR_SBOM/base_only.txt" | tr -d ' ')
added_count=$(wc -l    < "$TMPDIR_SBOM/added.txt" | tr -d ' ')
shared_count=$(wc -l   < "$TMPDIR_SBOM/shared.txt" | tr -d ' ')

# ---------- output ----------

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  jq -n \
    --arg base "$BASE_IMAGE" \
    --arg app "$APP_IMAGE" \
    --slurpfile base_only_arr <(jq -R 'split("@") | {name: .[0], version: .[1]}' "$TMPDIR_SBOM/base_only.txt" | jq -s '.') \
    --slurpfile added_arr     <(jq -R 'split("@") | {name: .[0], version: .[1]}' "$TMPDIR_SBOM/added.txt"     | jq -s '.') \
    --slurpfile shared_arr    <(jq -R 'split("@") | {name: .[0], version: .[1]}' "$TMPDIR_SBOM/shared.txt"    | jq -s '.') \
    '{
      base_image:    $base,
      app_image:     $app,
      counts: {
        base_total:    '"$base_count"',
        app_total:     '"$app_count"',
        base_only:     '"$base_only_count"',
        added_by_app:  '"$added_count"',
        shared:        '"$shared_count"'
      },
      base_only:    ($base_only_arr[0] // []),
      added_by_app: ($added_arr[0] // []),
      shared:       ($shared_arr[0] // [])
    }'
  exit 0
fi

# Human-readable
printf '\n%sSBOM Delta Report%s\n' "$BOLD" "$RESET"
printf '%s================================================================%s\n' "$DIM" "$RESET"
printf '  %sBase:%s  %s\n' "$BOLD" "$RESET" "$BASE_IMAGE"
printf '  %sApp:%s   %s\n' "$BOLD" "$RESET" "$APP_IMAGE"
echo ""
printf '  %sPackages in base:%s        %s%d%s\n' "$BOLD" "$RESET" "$BLUE" "$base_count" "$RESET"
printf '  %sPackages in app:%s         %s%d%s\n' "$BOLD" "$RESET" "$BLUE" "$app_count"  "$RESET"
echo ""
printf '  %sShared (in both):%s        %s%d%s\n'  "$BOLD" "$RESET" "$GREEN"  "$shared_count"    "$RESET"
printf '  %sAdded by app:%s            %s%d%s\n'  "$BOLD" "$RESET" "$YELLOW" "$added_count"     "$RESET"
printf '  %sIn base, dropped:%s        %s%d%s\n'  "$BOLD" "$RESET" "$DIM"    "$base_only_count" "$RESET"
echo ""

if [[ $added_count -gt 0 ]]; then
  printf '%sPackages added on top of the DHI base:%s\n' "$BOLD" "$RESET"
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    printf '  %s+%s %s\n' "$YELLOW" "$RESET" "$pkg"
  done < "$TMPDIR_SBOM/added.txt"
  echo ""
fi

if [[ $base_only_count -gt 0 ]]; then
  printf '%sPackages dropped from the base (likely build-stage artifacts):%s\n' "$BOLD" "$RESET"
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    printf '  %s-%s %s\n' "$DIM" "$RESET" "$pkg"
  done < "$TMPDIR_SBOM/base_only.txt"
  echo ""
fi

printf '%sInterpretation:%s\n' "$BOLD" "$RESET"
echo "  Every package in 'added_by_app' is something YOUR application is responsible"
echo "  for. The DHI base gives you the rest. This is the supply-chain delta you"
echo "  attest, scan, and accept when you deploy the app image."
echo ""