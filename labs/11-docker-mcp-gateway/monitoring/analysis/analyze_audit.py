#!/usr/bin/env python3
"""
Lab 11 — Docker MCP Gateway Audit Log Analyzer (v2)

Reads incident JSON files from the audit export directory, categorizes each
incident by scenario type, extracts decision metrics, and prints a summary
suitable for inclusion in articles or research papers.

Changes from v1:
  - Fixed substring matching for escalation detection (catches "escalate",
    "escalating", "escalation", "escalated" — previously only "escalate")
  - Expanded auto-fix markers to cover more remediation phrasings
  - Added detection of restart-then-fail vs restart-then-succeed patterns
    by checking the container status after the restart tool call
  - CSV export option for paper-grade transparency
  - Confidence flag per incident: HIGH if both markers clearly present,
    LOW if heuristic ambiguous

Usage:
    python3 analyze_audit.py <path-to-audit-export> [--csv output.csv]
"""

import argparse
import csv
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from collections import defaultdict


# Substring markers — matched case-insensitively as substrings of full text.
# Use word stems (e.g. "escalat") so we catch all morphological forms.
ESCALATION_MARKERS = [
    "escalat",          # escalate, escalating, escalation, escalated
    "manual intervention",
    "needs human",
    "requires human",
    "human operator",
]

AUTO_FIX_MARKERS = [
    "memory limit updated",
    "memory increased",
    "memory limit increased",
    "restarted successfully",
    "container recovered",
    "resources updated",
    "successfully restarted",
]

# Indicators that a restart was attempted but the container still failed
RESTART_FAILED_MARKERS = [
    "still shows as exited",
    "still exited",
    "issue persists",
    "problem persists",
    "not resolved",
]


def classify_scenario(alert: dict) -> str:
    """Map an alert dict to one of the four documented scenarios."""
    status = (alert.get("status") or "").lower()
    description = (alert.get("description") or "").lower()
    text = f"{status} {description}"

    if "oom" in text:
        return "OOMKilled"
    if "crash" in text or "crashloop" in text:
        return "CrashLoopBackOff"
    if "unhealthy" in text or "health check" in text or "healthcheck" in text:
        return "HealthCheckFailure"
    if "exit" in text or status == "exited":
        return "ExitCodeAnalysis"
    return "Unknown"


def extract_tool_calls(decision_chain: list) -> list:
    """Pull tool names from decision chain content.

    Role labels are unreliable in this schema, so parse content patterns:
      - "Tool: <name>" prefixes mark tool result blocks
      - 'call_tool("<name>"' patterns mark agent invocations
    """
    tools = []
    tool_result_pattern = re.compile(r"^Tool:\s*([a-zA-Z_]+)", re.MULTILINE)
    call_tool_pattern = re.compile(r'call_tool\(\s*["\']([a-zA-Z_]+)["\']')

    for turn in decision_chain:
        content = turn.get("content", "") or ""
        for match in tool_result_pattern.finditer(content):
            tools.append(match.group(1))
        for match in call_tool_pattern.finditer(content):
            tools.append(match.group(1))

    seen = set()
    unique = []
    for t in tools:
        if t not in seen:
            seen.add(t)
            unique.append(t)
    return unique


def detect_outcome(decision_chain: list) -> tuple:
    """Determine outcome and confidence.

    Returns (outcome, confidence) where:
      outcome: "AutoResolved" | "Escalated" | "AutoResolved+Escalated" | "Unclear"
      confidence: "HIGH" | "MEDIUM" | "LOW"
    """
    full_text = " ".join((t.get("content") or "").lower() for t in decision_chain)

    has_escalation = any(m in full_text for m in ESCALATION_MARKERS)
    has_auto_fix = any(m in full_text for m in AUTO_FIX_MARKERS)
    has_restart_failed = any(m in full_text for m in RESTART_FAILED_MARKERS)

    if has_auto_fix and has_escalation:
        outcome = "AutoResolved+Escalated"
        confidence = "HIGH"
    elif has_auto_fix and has_restart_failed:
        # Tool reported success but container actually still failed
        outcome = "Escalated" if has_escalation else "AutoResolved+Escalated"
        confidence = "MEDIUM"
    elif has_escalation and not has_auto_fix:
        outcome = "Escalated"
        confidence = "HIGH"
    elif has_auto_fix and not has_escalation:
        outcome = "AutoResolved"
        confidence = "HIGH"
    else:
        outcome = "Unclear"
        confidence = "LOW"

    return outcome, confidence


def expected_outcome(scenario: str) -> str:
    """Per-README expected outcome for each scenario."""
    return {
        "OOMKilled": "AutoResolved",
        "CrashLoopBackOff": "Escalated",
        "ExitCodeAnalysis": "AutoResolved+Escalated",
        "HealthCheckFailure": "AutoResolved",
    }.get(scenario, "Unknown")


def compute_duration(decision_chain: list) -> float:
    """Decision chain duration in seconds (first to last timestamp).

    Note: AutoGen logs all turns within microseconds of each other, so this
    metric is unreliable for MTTR analysis on this dataset.
    """
    if not decision_chain:
        return 0.0
    timestamps = []
    for turn in decision_chain:
        ts = turn.get("timestamp")
        if not ts:
            continue
        try:
            ts_clean = ts.replace("Z", "")
            timestamps.append(datetime.fromisoformat(ts_clean))
        except ValueError:
            continue
    if len(timestamps) < 2:
        return 0.0
    return (max(timestamps) - min(timestamps)).total_seconds()


def detect_quality_issues(decision_chain: list) -> list:
    """Flag known data quality issues."""
    issues = []
    contents = [(t.get("content") or "") for t in decision_chain]

    empty_count = sum(1 for c in contents if c.strip() == "")
    if empty_count > 0:
        issues.append(f"{empty_count} empty turns")

    duplicates = 0
    for i in range(1, len(contents)):
        if contents[i].strip() and contents[i].strip() == contents[i - 1].strip():
            duplicates += 1
    if duplicates > 0:
        issues.append(f"{duplicates} duplicate turns (looping)")

    return issues


def analyze(directory: Path, csv_path: Path = None) -> None:
    incident_files = sorted(directory.glob("inc-*.json"))
    if not incident_files:
        print(f"No incident files found in {directory}")
        return

    rows = []
    for file in incident_files:
        try:
            data = json.loads(file.read_text())
        except (json.JSONDecodeError, OSError) as e:
            print(f"Skipping {file.name}: {e}")
            continue

        agent_id = data.get("agent_id", "")
        if "docker" not in agent_id.lower():
            print(f"Skipping {file.name}: non-Docker agent ({agent_id})")
            continue

        decision_chain = data.get("decision_chain", [])
        scenario = classify_scenario(data.get("alert", {}))
        tools = extract_tool_calls(decision_chain)
        outcome, confidence = detect_outcome(decision_chain)
        expected = expected_outcome(scenario)
        correct = "Yes" if outcome == expected else "No" if expected != "Unknown" else "?"
        duration = compute_duration(decision_chain)
        issues = detect_quality_issues(decision_chain)

        rows.append({
            "file": file.name,
            "incident_id": data.get("incident_id", ""),
            "timestamp": data.get("timestamp", ""),
            "scenario": scenario,
            "tools": tools,
            "turns": len(decision_chain),
            "duration_s": round(duration, 2),
            "outcome": outcome,
            "expected": expected,
            "correct": correct,
            "confidence": confidence,
            "issues": issues,
            "resolved_flag": data.get("resolved", False),
        })

    print_per_incident(rows)
    print_aggregate(rows)

    if csv_path:
        export_csv(rows, csv_path)
        print(f"\nCSV exported to: {csv_path}")


def print_per_incident(rows: list) -> None:
    print("\n" + "=" * 110)
    print("PER-INCIDENT BREAKDOWN")
    print("=" * 110)
    header = (
        f"{'File':<32} {'Scenario':<22} {'Outcome':<22} "
        f"{'Match':<6} {'Conf':<6} {'Turns':<6}"
    )
    print(header)
    print("-" * 110)
    for r in rows:
        line = (
            f"{r['file']:<32} "
            f"{r['scenario']:<22} "
            f"{r['outcome']:<22} "
            f"{r['correct']:<6} "
            f"{r['confidence']:<6} "
            f"{r['turns']:<6}"
        )
        print(line)
        if r["issues"]:
            print(f"   ! issues: {', '.join(r['issues'])}")
        if r["tools"]:
            print(f"   tools: {', '.join(r['tools'])}")


def print_aggregate(rows: list) -> None:
    print("\n" + "=" * 110)
    print("AGGREGATE SUMMARY BY SCENARIO")
    print("=" * 110)

    by_scenario = defaultdict(list)
    for r in rows:
        by_scenario[r["scenario"]].append(r)

    print(f"{'Scenario':<22} {'Runs':<6} {'Correct':<10} {'Avg Turns':<12}")
    print("-" * 60)

    total_runs = 0
    total_correct = 0
    for scenario, scenario_rows in sorted(by_scenario.items()):
        runs = len(scenario_rows)
        correct = sum(1 for r in scenario_rows if r["correct"] == "Yes")
        avg_turns = sum(r["turns"] for r in scenario_rows) / runs
        correct_pct = f"{correct}/{runs}"
        print(f"{scenario:<22} {runs:<6} {correct_pct:<10} {avg_turns:<12.1f}")
        total_runs += runs
        total_correct += correct

    print("-" * 60)
    if total_runs > 0:
        overall = (total_correct / total_runs) * 100
        print(f"{'TOTAL':<22} {total_runs:<6} {total_correct}/{total_runs} ({overall:.0f}%)")


def export_csv(rows: list, csv_path: Path) -> None:
    """Export per-incident rows to CSV for paper-grade transparency."""
    fieldnames = [
        "file",
        "incident_id",
        "timestamp",
        "scenario",
        "outcome",
        "expected",
        "correct",
        "confidence",
        "turns",
        "duration_s",
        "tools",
        "issues",
        "resolved_flag",
    ]
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for r in rows:
            writer.writerow({
                **{k: r[k] for k in fieldnames if k not in ("tools", "issues")},
                "tools": "; ".join(r["tools"]),
                "issues": "; ".join(r["issues"]),
            })


def main():
    parser = argparse.ArgumentParser(
        description="Analyze Lab 11 Docker MCP Gateway audit logs"
    )
    parser.add_argument("directory", help="Path to audit export directory")
    parser.add_argument(
        "--csv",
        help="Optional path to write per-incident CSV export",
        default=None,
    )
    args = parser.parse_args()

    directory = Path(args.directory).expanduser()
    if not directory.is_dir():
        print(f"Not a directory: {directory}")
        sys.exit(1)

    csv_path = Path(args.csv).expanduser() if args.csv else None
    analyze(directory, csv_path)


if __name__ == "__main__":
    main()
