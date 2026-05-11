#!/usr/bin/env bash
# audit-fleet.sh — Fleet-wide drift audit against trust governance criteria.
#
# Reads a fleet inventory (JSON) and produces a risk-graded drift report.
# Each service is classified CRITICAL / HIGH / MEDIUM / LOW / OK based on
# trust state (signing), operational state (patch age, CVEs), and compliance
# scope (PII, payment).
#
# DEPENDENCIES: bash + python3 (stdlib only — no external packages required).
#
# Usage:
#   ./audit-fleet.sh                              # default inventory location
#   ./audit-fleet.sh path/to/inventory.json       # explicit path
#   ./audit-fleet.sh --json                       # machine-readable output
#   ./audit-fleet.sh --json path/to/inv.json      # both
#
# Risk grading rules (in order — first matching grade wins):
#   CRITICAL  abandoned base image
#             regulated data (PII or payment) on non-verified-signed image
#             prod with patch age > 180d
#             >= 5 critical CVEs
#   HIGH      prod with unsigned image
#             prod with patch age > 90d
#             prod with any critical CVE
#   MEDIUM    prod with signed-but-unverifiable signature
#             patch age > 90d (any environment)
#             critical CVEs > 0 (any environment)
#   LOW       any non-verified signing state OR patch age > 30d
#   OK        signed_verified + recent + no findings
#
# Exit codes:
#   0  no critical findings (audit passed)
#   1  one or more critical findings
#   2  input error (file not found, parse error)

set -euo pipefail

# ---------- arg parsing ----------

INVENTORY=""
FORMAT="human"
SHOW_HELP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)        FORMAT="json"; shift ;;
    --human)       FORMAT="human"; shift ;;
    -h|--help)     SHOW_HELP=1; shift ;;
    -*)            echo "Unknown flag: $1" >&2; exit 2 ;;
    *)             INVENTORY="$1"; shift ;;
  esac
done

if [[ "$SHOW_HELP" == "1" ]]; then
  sed -n '2,32p' "$0" | sed 's/^# \?//'
  exit 0
fi

# ---------- locate inventory ----------

if [[ -z "$INVENTORY" ]]; then
  for candidate in \
      "fleet/inventory.json" \
      "labs/12-docker-hardened-images/fleet/inventory.json" \
      "$(dirname "$0")/../fleet/inventory.json"; do
    if [[ -f "$candidate" ]]; then
      INVENTORY="$candidate"
      break
    fi
  done
fi

if [[ -z "$INVENTORY" ]] || [[ ! -f "$INVENTORY" ]]; then
  echo "ERROR: inventory.json not found" >&2
  echo "" >&2
  echo "Tried these locations:" >&2
  echo "  - fleet/inventory.json" >&2
  echo "  - labs/12-docker-hardened-images/fleet/inventory.json" >&2
  echo "  - \$(dirname \$0)/../fleet/inventory.json" >&2
  echo "" >&2
  echo "Pass an explicit path: ./audit-fleet.sh path/to/inventory.json" >&2
  exit 2
fi

# ---------- delegate to Python (stdlib only) ----------

export INVENTORY FORMAT

python3 - <<'PYEOF'
import os, sys, json
from collections import Counter

INVENTORY = os.environ['INVENTORY']
FORMAT    = os.environ.get('FORMAT', 'human')

try:
    with open(INVENTORY) as f:
        data = json.load(f)
except json.JSONDecodeError as e:
    print(f"ERROR: failed to parse {INVENTORY}: {e}", file=sys.stderr)
    sys.exit(2)
except OSError as e:
    print(f"ERROR: could not read {INVENTORY}: {e}", file=sys.stderr)
    sys.exit(2)

services = data.get('services', [])
if not services:
    print(f"ERROR: no services found in {INVENTORY}", file=sys.stderr)
    sys.exit(2)

# ---------- color helpers (only when human + tty) ----------

USE_COLOR = (FORMAT == 'human') and sys.stdout.isatty()
def c(code, t):
    return f"\033[{code}m{t}\033[0m" if USE_COLOR else t

RED    = lambda t: c('31', t)
GREEN  = lambda t: c('32', t)
YELLOW = lambda t: c('33', t)
BLUE   = lambda t: c('34', t)
BOLD   = lambda t: c('1',  t)
DIM    = lambda t: c('2',  t)

# ---------- risk grading ----------

def grade(s):
    reasons = []
    sign       = s['trust']['signing_state']
    age        = s['operational']['patch_age_days']
    env        = s['compliance']['environment']
    pii        = s['compliance']['handles_pii']
    pay        = s['compliance']['handles_payment']
    origin     = s['base_image']['origin']
    crit_cves  = s['operational']['critical_cves']
    is_prod    = env == 'prod'
    is_regulated = pii or pay
    scope      = ('PII+payment' if pii and pay
                  else 'PII' if pii
                  else 'payment' if pay else None)

    # CRITICAL
    if origin == 'abandoned':
        reasons.append("abandoned base image (no maintainer)")
    if is_regulated and sign != 'signed_verified':
        reasons.append(f"{scope}-scope on {sign} image")
    if is_prod and age > 180:
        reasons.append(f"prod patch age {age}d (>180d)")
    if crit_cves >= 5:
        reasons.append(f"{crit_cves} critical CVEs")
    if reasons:
        return ('CRITICAL', reasons)

    # HIGH
    if is_prod and sign == 'unsigned':
        reasons.append("prod with unsigned image")
    if is_prod and age > 90:
        reasons.append(f"prod patch age {age}d (>90d)")
    if is_prod and crit_cves > 0:
        reasons.append(f"prod has {crit_cves} critical CVE(s)")
    if reasons:
        return ('HIGH', reasons)

    # MEDIUM
    if is_prod and sign == 'signed_unverifiable':
        reasons.append("prod with unverifiable signature (no provenance chain)")
    if age > 90:
        reasons.append(f"patch age {age}d (>90d)")
    if crit_cves > 0:
        reasons.append(f"{crit_cves} critical CVE(s)")
    if reasons:
        return ('MEDIUM', reasons)

    # LOW
    if sign != 'signed_verified':
        reasons.append(f"{sign}")
    if age > 30:
        reasons.append(f"patch age {age}d")
    if reasons:
        return ('LOW', reasons)

    return ('OK', [])

# ---------- compute ----------

graded = [(s, *grade(s)) for s in services]
counts = Counter(g for _, g, _ in graded)
for k in ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'OK'):
    counts.setdefault(k, 0)

origins = Counter(s['base_image']['origin']  for s in services)
signing = Counter(s['trust']['signing_state'] for s in services)

# ---------- JSON output ----------

if FORMAT == 'json':
    out = {
        'inventory_file': INVENTORY,
        'service_count':  len(services),
        'risk_distribution': dict(counts),
        'origin_distribution':  dict(origins),
        'signing_distribution': dict(signing),
        'services': [
            {
                'name':            s['name'],
                'team':            s['team'],
                'grade':           g,
                'reasons':         r,
                'base_image':      s['base_image']['reference'],
                'origin':          s['base_image']['origin'],
                'signing_state':   s['trust']['signing_state'],
                'patch_age_days':  s['operational']['patch_age_days'],
                'critical_cves':   s['operational']['critical_cves'],
                'environment':     s['compliance']['environment'],
                'handles_pii':     s['compliance']['handles_pii'],
                'handles_payment': s['compliance']['handles_payment'],
            }
            for s, g, r in graded
        ],
    }
    print(json.dumps(out, indent=2, default=str))
    sys.exit(1 if counts['CRITICAL'] > 0 else 0)

# ---------- human output ----------

print()
print(BOLD("Fleet Trust Audit"))
print("================================================================")
print(f"Inventory:    {INVENTORY}")
print(f"Services:     {len(services)}")
print()

print(BOLD("Distribution by axis"))
print(f"  Origins:    "
      f"dhi={origins.get('dhi',0)} · "
      f"official={origins.get('docker_hub_official',0)} · "
      f"internal={origins.get('internal_built',0)} · "
      f"abandoned={origins.get('abandoned',0)}")
print(f"  Signing:    "
      f"verified={signing.get('signed_verified',0)} · "
      f"unverifiable={signing.get('signed_unverifiable',0)} · "
      f"unsigned={signing.get('unsigned',0)}")
print()

print(BOLD("Risk distribution"))
print(f"  {RED('CRITICAL')}    {counts['CRITICAL']:>2d}")
print(f"  {YELLOW('HIGH')}        {counts['HIGH']:>2d}")
print(f"  {YELLOW('MEDIUM')}      {counts['MEDIUM']:>2d}")
print(f"  {BLUE('LOW')}         {counts['LOW']:>2d}")
print(f"  {GREEN('OK')}          {counts['OK']:>2d}")
print()

# Findings (sorted: CRITICAL > HIGH > MEDIUM > LOW)
order = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3, 'OK': 4}
findings = [(s, g, r) for s, g, r in graded if g != 'OK']
findings.sort(key=lambda x: (order[x[1]], x[0]['name']))

if findings:
    print(BOLD("Findings"))
    grade_color = {
        'CRITICAL': RED, 'HIGH': YELLOW, 'MEDIUM': YELLOW, 'LOW': BLUE,
    }
    for s, g, reasons in findings:
        gtxt = grade_color[g](f"{g:<8}")
        print(f"  {gtxt}  {s['name']:<22s}  {DIM('('+s['team']+')')}")
        print(f"            {DIM(s['base_image']['reference'])}")
        for r in reasons:
            print(f"            · {r}")
        print()

# Summary
total_findings = sum(c for k, c in counts.items() if k != 'OK')
print(BOLD("Summary"))
print(f"  {total_findings}/{len(services)} services have findings")
if counts['CRITICAL'] > 0:
    msg = f"{counts['CRITICAL']} CRITICAL service(s) require immediate attention"
    print(f"  {RED(msg)}")
if counts['HIGH'] > 0:
    msg = f"{counts['HIGH']} HIGH-risk service(s) require remediation"
    print(f"  {YELLOW(msg)}")
if counts['CRITICAL'] == 0 and counts['HIGH'] == 0:
    print(f"  {GREEN('No critical or high-risk findings')}")
print()

sys.exit(1 if counts['CRITICAL'] > 0 else 0)
PYEOF