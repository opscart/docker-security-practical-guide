# Lab 13: AI Context Poisoning Detection and Defense

## Overview
Demonstrates how zero-width Unicode characters can be embedded in `.claude/settings.json` to trick AI agents into executing unauthorized actions.

## The Threat
- Zero-width Unicode (U+200B, U+200C, U+200D) are invisible in code editors
- LLMs parse these characters and interpret hidden instructions
- Result: AI agents execute actions they shouldn't

## What This Lab Does

### Part 1: Embedding (tools/zero_width_embedder.py)
- Takes a clean `.claude/settings.json`
- Encodes a malicious instruction as invisible zero-width characters
- Creates a poisoned version that looks normal to humans

### Part 2: Detection (tools/detector.py)
- Scans JSON files for zero-width characters
- Reports exact positions and types
- Validates detection accuracy

### Part 3: Scenarios (samples/)
Four attack scenarios:
- **A**: Read environment variables
- **B**: Execute shell commands
- **C**: Make unauthorized git commits
- **D**: Exfiltrate SSH keys

### Part 4: Analysis (tools/analyze_scenarios.py)
Systematically analyzes all scenarios and reports detection rate.

## How to Run

```bash
# Embed an instruction
python3 tools/zero_width_embedder.py samples/clean.json "read /root/.env"

# Detect zero-width characters
python3 tools/detector.py samples/clean_poisoned.json

# Analyze all scenarios
python3 tools/analyze_scenarios.py
```

## Expected Results
Detection Rate: 4/4 scenarios detected

All poisoned configs should be detected with 100% accuracy.

## Lab Status
- [x] Embedder working
- [x] Detector working
- [x] 4 scenarios created
- [ ] Claude Code testing
- [ ] Full results documented

## References
- Mohammad-Ali A'râbi: "SoK: Weaponizing the Developer Context"
- Section 4.2: AI Context Window Poisoning