# Analysis — Lab 11 Audit Log Datasets

This directory contains the audit log datasets and analysis tooling used to
validate the Docker MCP Gateway remediation agent across the four documented
failure scenarios.

The data is organized into two phases that map to the engineering iteration
described in the [main lab README](../../README.md): **before-fixes** captures
development-phase incidents discovered while applying Challenges 1–9, and
**after-fixes** captures formal validation runs with all documented fixes
applied.

---

## Structure

```
analysis/
├── analyze_audit.py          # Audit log analyzer (parses incident JSON)
├── README.md                  # This file
├── before-fixes/              # Development-phase data (n=7)
│   ├── inc-*.json             # 7 incident records
│   └── results.csv            # Per-incident analysis output
└── after-fixes/               # Post-fix validation data (n=6)
    ├── inc-*.json             # 6 incident records
    └── results.csv            # Per-incident analysis output
```

---

## Dataset descriptions

### `before-fixes/` (n = 7)

Captured during initial development of the agent. These runs surfaced the
issues documented as Challenges 1–9 in the main README. Notable conditions:

| Setting | Value at capture time |
|---------|----------------------|
| Model | `gpt-3.5-turbo` |
| `max_consecutive_auto_reply` | `10` (caused looping — Challenge 9) |
| OOMKilled test container `--memory-swap` | not yet set to `-1` (caused the swap-limit error — Challenge 3) |
| CrashLoopBackOff system prompt | initial version (caused over-eager restart — Challenge 6) |

Two further incident files (`inc-20260502-164705.json`, `inc-20260502-171256.json`)
from a separate Kubernetes experiment using `k8s-ops-agent-001` were excluded
from this dataset to keep the analysis Docker-scoped.

### `after-fixes/` (n = 6)

Captured after applying all README-documented fixes:

| Setting | Value at capture time |
|---------|----------------------|
| Model | `gpt-3.5-turbo` |
| `max_consecutive_auto_reply` | `3` |
| OOMKilled test container `--memory-swap` | `-1` (unlimited) |
| CrashLoopBackOff system prompt | tightened with explicit no-restart rule |

Six runs were captured: 2× OOMKilled, 1× CrashLoopBackOff, 1× ExitCodeAnalysis,
2× HealthCheckFailure.

---

## Methodology

Each incident JSON is classified into one of four scenarios based on
`alert.status` and `alert.description`:

- **OOMKilled** — container killed by the kernel OOM reaper
- **CrashLoopBackOff** — container repeatedly crashing on start
- **ExitCodeAnalysis** — container exited with non-zero code (single exit)
- **HealthCheckFailure** — container running but failing health checks

Expected agent behavior per scenario (from main README):

| Scenario | Expected outcome |
|----------|------------------|
| OOMKilled | `AutoResolved` (increase memory) |
| CrashLoopBackOff | `Escalated` (do not auto-restart) |
| ExitCodeAnalysis | `AutoResolved+Escalated` (try restart, escalate if still failing) |
| HealthCheckFailure | `AutoResolved` (restart unhealthy container) |

The analyzer matches actual agent behavior against expected behavior using
substring markers in the decision chain text (the role labels in the source
schema are unreliable). A `Match: Yes` indicates the agent followed the
documented expected behavior for that scenario.

---

## Headline results

| Phase | Runs | Correct | Avg turns/incident |
|-------|------|---------|--------------------|
| Before fixes | 7 | 3/7 (**43%**) | 22.7 |
| After fixes | 6 | 6/6 (**100%**) | 11.7 |

**Correctness** measures alignment with documented expected behavior per
scenario. **Average turns per incident** roughly halved between phases, mostly
attributable to the `max_consecutive_auto_reply` reduction (Challenge 9).

---

## Reproducibility

To re-run the analysis on either dataset:

```bash
# Before-fixes dataset
python3 analyze_audit.py before-fixes/

# After-fixes dataset with CSV export
python3 analyze_audit.py after-fixes/ --csv after-fixes/results.csv
```

The analyzer requires only the Python standard library — no external
dependencies. Tested with Python 3.11+.

---

## Known limitations

- **Sample sizes are small** (n=7 and n=6). These results validate that the
  expected behavior is reproducible across the four scenarios but do not
  support statistical claims about reliability under load or at scale.
- **Duration metric is unreliable.** AutoGen records all decision-chain
  timestamps within microseconds of each other, so per-incident `duration_s`
  does not represent wall-clock MTTR. Capturing real MTTR would require
  external timing instrumentation.
- **Role labels in source incident JSON are inverted in places** — content
  tagged `"role": "assistant"` sometimes contains tool output, and content
  tagged `"role": "tool_result"` sometimes contains agent reasoning. The
  analyzer parses content patterns rather than role labels to work around
  this.
- **Outcome detection is heuristic, not deterministic.** The analyzer reports
  a confidence flag (HIGH/MEDIUM/LOW) per incident; HIGH-confidence rows are
  the basis for the headline results above.

---

## Files for paper-grade transparency

The CSV exports (`before-fixes/results.csv`, `after-fixes/results.csv`) contain
per-incident classification, outcome, expected outcome, match, confidence,
turn count, tool calls, and quality flags. They are committed alongside the
raw incident JSON so any reader can verify the analysis end-to-end.