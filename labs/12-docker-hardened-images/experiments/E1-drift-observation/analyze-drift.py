#!/usr/bin/env python3
"""analyze-drift.py — Deep fleet drift analysis for E1.

Consumes audit-fleet.sh JSON output and produces per-team, per-axis,
and per-compliance-scope rollups. The output is structured as the
"Observation" section of E1's H/E/O/C README.

Usage:
    ./analyze-drift.py                       # invoke audit-fleet.sh internally
    ./analyze-drift.py audit.json            # from saved JSON file
    audit-fleet.sh --json | ./analyze-drift.py -    # from stdin
    ./analyze-drift.py --save report.json    # save analysis as JSON
    ./analyze-drift.py --json                # emit analysis as JSON (no human print)

Exit codes:
    0  no critical findings
    1  one or more critical findings (matches audit-fleet.sh contract)
    2  input error
"""

import argparse
import json
import os
import statistics
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path


# ---------- color helpers ----------

def _color(code):
    return lambda t: f"\033[{code}m{t}\033[0m" if sys.stdout.isatty() else t

RED    = _color("31")
GREEN  = _color("32")
YELLOW = _color("33")
BLUE   = _color("34")
BOLD   = _color("1")
DIM    = _color("2")

GRADE_COLOR = {
    "CRITICAL": RED,
    "HIGH":     YELLOW,
    "MEDIUM":   YELLOW,
    "LOW":      BLUE,
    "OK":       GREEN,
}
GRADE_ORDER = ["CRITICAL", "HIGH", "MEDIUM", "LOW", "OK"]


# ---------- input ----------

def find_audit_script():
    """Locate audit-fleet.sh relative to this script."""
    here = Path(__file__).resolve().parent
    candidates = [
        here / "audit-fleet.sh",
        here.parent / "tools" / "audit-fleet.sh",
        Path("labs/12-docker-hardened-images/tools/audit-fleet.sh"),
        Path("tools/audit-fleet.sh"),
    ]
    for path in candidates:
        if path.is_file():
            return str(path)
    return None


def load_audit_data(source):
    """Load audit JSON from file path, stdin, or by invoking audit-fleet.sh."""
    if source == "-":
        return json.load(sys.stdin)

    if source:
        path = Path(source)
        if not path.is_file():
            print(f"ERROR: file not found: {source}", file=sys.stderr)
            sys.exit(2)
        with open(path) as f:
            return json.load(f)

    # No source given — invoke audit-fleet.sh
    script = find_audit_script()
    if not script:
        print("ERROR: audit-fleet.sh not found", file=sys.stderr)
        print("       Pass an explicit JSON path or pipe via stdin", file=sys.stderr)
        sys.exit(2)

    try:
        result = subprocess.run(
            [script, "--json"],
            capture_output=True,
            text=True,
            check=False,
        )
        # audit-fleet.sh exits 1 on critical findings, 2 on error
        if result.returncode == 2:
            print(result.stderr, file=sys.stderr)
            sys.exit(2)
        return json.loads(result.stdout)
    except (subprocess.SubprocessError, json.JSONDecodeError) as e:
        print(f"ERROR: failed to invoke audit-fleet.sh: {e}", file=sys.stderr)
        sys.exit(2)


# ---------- analysis primitives ----------

def origin_signing_matrix(services):
    """Cross-tabulate origin × signing_state."""
    origins = ["dhi", "docker_hub_official", "internal_built", "abandoned"]
    signings = ["signed_verified", "signed_unverifiable", "unsigned"]
    matrix = {o: {s: 0 for s in signings} for o in origins}
    for svc in services:
        matrix[svc["origin"]][svc["signing_state"]] += 1
    return origins, signings, matrix


def trust_cve_correlation(services):
    """Group by signing state, compute CVE statistics."""
    by_signing = defaultdict(list)
    for svc in services:
        by_signing[svc["signing_state"]].append(svc["critical_cves"])
    return {
        sign: {
            "service_count": len(cves),
            "avg_critical_cves": statistics.mean(cves) if cves else 0,
            "max_critical_cves": max(cves) if cves else 0,
            "total_critical_cves": sum(cves),
        }
        for sign, cves in by_signing.items()
    }


def compliance_scope_risk(services):
    """For PII and payment scopes, distribution of grades."""
    scopes = {}
    for scope_key, label in (("handles_pii", "PII"), ("handles_payment", "payment")):
        scoped = [s for s in services if s[scope_key]]
        if not scoped:
            scopes[label] = None
            continue
        grade_counts = Counter(s["grade"] for s in scoped)
        scopes[label] = {
            "services": [s["name"] for s in scoped],
            "total": len(scoped),
            "by_grade": {
                g: {
                    "count": grade_counts.get(g, 0),
                    "names": [s["name"] for s in scoped if s["grade"] == g],
                }
                for g in GRADE_ORDER
                if grade_counts.get(g, 0) > 0
            },
        }
    return scopes


def team_rollup(services):
    """Per-team summary."""
    by_team = defaultdict(list)
    for svc in services:
        by_team[svc["team"]].append(svc)
    rollup = {}
    for team, svcs in by_team.items():
        grades = [s["grade"] for s in svcs]
        worst = min(grades, key=GRADE_ORDER.index)
        rollup[team] = {
            "service_count": len(svcs),
            "worst_grade": worst,
            "grade_distribution": dict(Counter(grades)),
            "service_names": [s["name"] for s in svcs],
        }
    return rollup


def patch_age_buckets(services):
    """Histogram of patch ages."""
    buckets = [
        ("0-30d",     0,    30),
        ("31-90d",    31,   90),
        ("91-180d",   91,   180),
        ("181-365d",  181,  365),
        ("1y+",       366,  10**9),
    ]
    counts = {label: 0 for label, _, _ in buckets}
    for svc in services:
        age = svc["patch_age_days"]
        for label, lo, hi in buckets:
            if lo <= age <= hi:
                counts[label] += 1
                break
    return counts


def remediation_order(services, top_n=5):
    """Sort findings by remediation priority."""
    def priority(s):
        return (
            GRADE_ORDER.index(s["grade"]),                      # grade first
            -(int(s["handles_pii"]) + int(s["handles_payment"])),  # regulated services first
            -s["critical_cves"],                                # more CVEs first
            -s["patch_age_days"],                               # older first
        )
    findings = [s for s in services if s["grade"] != "OK"]
    findings.sort(key=priority)
    return findings[:top_n]


# ---------- formatting ----------

def fmt_human(audit):
    services = audit["services"]
    total = audit["service_count"]
    risk = audit["risk_distribution"]
    out = []

    # Header
    out.append("")
    out.append(BOLD("Fleet Drift Analysis"))
    out.append("=" * 64)
    out.append("")

    # Section 1: Summary
    out.append(BOLD("1. Fleet Summary"))
    out.append(f"   Services:      {total}")
    out.append(
        f"   Risk:          {RED(str(risk['CRITICAL'])+' CRITICAL')} · "
        f"{YELLOW(str(risk['HIGH'])+' HIGH')} · "
        f"{YELLOW(str(risk['MEDIUM'])+' MEDIUM')} · "
        f"{BLUE(str(risk['LOW'])+' LOW')} · "
        f"{GREEN(str(risk['OK'])+' OK')}"
    )
    findings_pct = round(100 * (total - risk["OK"]) / total) if total else 0
    out.append(f"   Findings:      {total - risk['OK']}/{total} services ({findings_pct}%)")
    out.append("")

    # Section 2: Origin × Signing
    out.append(BOLD("2. Origin × Signing Correlation"))
    origins, signings, matrix = origin_signing_matrix(services)
    out.append(f"   {'':<24} {'verified':>10} {'unverifiable':>14} {'unsigned':>10}  {'TOTAL':>6}")
    out.append(f"   {'-'*24} {'-'*10} {'-'*14} {'-'*10}  {'-'*6}")
    for o in origins:
        row = matrix[o]
        total_o = sum(row.values())
        if total_o == 0:
            continue
        out.append(
            f"   {o:<24} {row['signed_verified']:>10} "
            f"{row['signed_unverifiable']:>14} {row['unsigned']:>10}  {total_o:>6}"
        )
    # Totals
    col_totals = {s: sum(matrix[o][s] for o in origins) for s in signings}
    out.append(f"   {'-'*24} {'-'*10} {'-'*14} {'-'*10}  {'-'*6}")
    out.append(
        f"   {'TOTAL':<24} {col_totals['signed_verified']:>10} "
        f"{col_totals['signed_unverifiable']:>14} {col_totals['unsigned']:>10}  {total:>6}"
    )
    out.append("")
    dhi_count = sum(matrix["dhi"].values())
    if dhi_count > 0 and matrix["dhi"]["signed_verified"] == dhi_count:
        out.append(f"   {DIM('Insight: 100% of DHI services are signed_verified.')}")
        non_dhi_verified = sum(matrix[o]["signed_verified"] for o in origins if o != "dhi")
        if non_dhi_verified == 0:
            out.append(f"   {DIM('         0% of non-DHI services are signed_verified.')}")
    out.append("")

    # Section 3: Trust → CVE
    out.append(BOLD("3. Signing State → CVE Accumulation"))
    correlation = trust_cve_correlation(services)
    out.append(f"   {'Signing state':<24} {'Services':>9} {'Avg crit CVE':>13} {'Max':>6} {'Total':>7}")
    out.append(f"   {'-'*24} {'-'*9} {'-'*13} {'-'*6} {'-'*7}")
    for sign in ("signed_verified", "signed_unverifiable", "unsigned"):
        if sign not in correlation:
            continue
        c = correlation[sign]
        out.append(
            f"   {sign:<24} {c['service_count']:>9} "
            f"{c['avg_critical_cves']:>13.1f} {c['max_critical_cves']:>6} {c['total_critical_cves']:>7}"
        )
    out.append("")
    if "signed_verified" in correlation and "unsigned" in correlation:
        v = correlation["signed_verified"]["avg_critical_cves"]
        u = correlation["unsigned"]["avg_critical_cves"]
        if v < u:
            ratio = u / max(v, 0.1)
            out.append(f"   {DIM(f'Insight: Unsigned services average {ratio:.0f}× more critical CVEs than signed_verified.')}")
    out.append("")

    # Section 4: Compliance scope
    out.append(BOLD("4. Compliance Scope Risk Concentration"))
    scope_risk = compliance_scope_risk(services)
    for label, data in scope_risk.items():
        if not data:
            continue
        out.append(f"   {BOLD(label + '-handling services')}: {data['total']}")
        for g in GRADE_ORDER:
            if g not in data["by_grade"]:
                continue
            entry = data["by_grade"][g]
            pct = round(100 * entry["count"] / data["total"])
            color = GRADE_COLOR[g]
            out.append(f"     {color(g):>20s}  {entry['count']} ({pct}%)  {DIM(', '.join(entry['names']))}")
        out.append("")

    # Section 5: Per-team
    out.append(BOLD("5. Per-Team Risk Profile"))
    rollup = team_rollup(services)
    sorted_teams = sorted(
        rollup.items(),
        key=lambda kv: (GRADE_ORDER.index(kv[1]["worst_grade"]), -kv[1]["service_count"]),
    )
    out.append(f"   {'Team':<26} {'Svcs':>5}  {'Worst':<10} Distribution")
    out.append(f"   {'-'*26} {'-'*5}  {'-'*10} {'-'*30}")
    for team, info in sorted_teams:
        worst = info["worst_grade"]
        dist = ", ".join(
            f"{cnt} {g}" for g in GRADE_ORDER
            if (cnt := info["grade_distribution"].get(g, 0)) > 0
        )
        # Pad plain text to fixed visible width FIRST, then color.
        # Coloring before padding breaks alignment because ANSI codes
        # count toward the format-string width.
        worst_padded = f"{worst:<10}"
        worst_colored = GRADE_COLOR[worst](worst_padded)
        out.append(
            f"   {team:<26} {info['service_count']:>5}  "
            f"{worst_colored} {dist}"
        )
    out.append("")

    # Section 6: Patch age
    out.append(BOLD("6. Patch Age Distribution"))
    buckets = patch_age_buckets(services)
    max_count = max(buckets.values()) if buckets else 1
    for label, count in buckets.items():
        bar = "█" * count
        marker = "  " if count <= max_count else ""
        out.append(f"   {label:<10} {bar}{marker} ({count})")
    over_year = buckets.get("1y+", 0)
    if over_year > 0:
        pct = round(100 * over_year / total)
        out.append("")
        out.append(f"   {DIM(f'Insight: {over_year}/{total} services ({pct}%) have base images older than 1 year.')}")
    out.append("")

    # Section 7: Remediation order
    out.append(BOLD("7. Recommended Remediation Order (top 5)"))
    top = remediation_order(services, top_n=5)
    for i, s in enumerate(top, 1):
        scope_tags = []
        if s["handles_pii"]:     scope_tags.append("PII")
        if s["handles_payment"]: scope_tags.append("payment")
        scope_str = f" [{', '.join(scope_tags)}]" if scope_tags else ""
        grade_str = GRADE_COLOR[s["grade"]](s["grade"])
        out.append(f"   {i}. {grade_str}  {s['name']}{scope_str}")
        out.append(f"      {DIM(s['base_image'])}")
        for r in s["reasons"][:2]:
            out.append(f"      · {r}")
    out.append("")

    return "\n".join(out)


def fmt_json(audit):
    services = audit["services"]
    origins, signings, matrix = origin_signing_matrix(services)
    return {
        "input": {
            "service_count": audit["service_count"],
            "risk_distribution": audit["risk_distribution"],
        },
        "analysis": {
            "origin_signing_matrix": matrix,
            "trust_cve_correlation": trust_cve_correlation(services),
            "compliance_scope_risk": compliance_scope_risk(services),
            "team_rollup": team_rollup(services),
            "patch_age_buckets": patch_age_buckets(services),
            "remediation_order": [
                {k: s[k] for k in ("name", "grade", "team", "base_image", "reasons", "handles_pii", "handles_payment")}
                for s in remediation_order(services, top_n=10)
            ],
        },
    }


# ---------- main ----------

def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("source", nargs="?", default=None,
                   help="JSON file path, '-' for stdin, or omit to invoke audit-fleet.sh")
    p.add_argument("--json", action="store_true",
                   help="emit analysis as JSON instead of human-readable report")
    p.add_argument("--save", metavar="FILE",
                   help="save analysis as JSON to FILE (in addition to printing report)")
    args = p.parse_args()

    audit = load_audit_data(args.source)

    if args.json:
        print(json.dumps(fmt_json(audit), indent=2, default=str))
    else:
        print(fmt_human(audit))

    if args.save:
        with open(args.save, "w") as f:
            json.dump(fmt_json(audit), f, indent=2, default=str)
        print(f"{DIM('Analysis saved to:')} {args.save}")

    sys.exit(1 if audit["risk_distribution"].get("CRITICAL", 0) > 0 else 0)


if __name__ == "__main__":
    main()