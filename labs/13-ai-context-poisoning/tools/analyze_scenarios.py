#!/usr/bin/env python3
"""Analyze all scenario files - both V1 and V2"""

import os
import re
import json

ZERO_WIDTH_PATTERN = r'[\u200B\u200C\u200D\uFEFF]'

def analyze(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    matches = list(re.finditer(ZERO_WIDTH_PATTERN, content))
    
    # Check if JSON is valid
    try:
        json.loads(content)
        json_valid = True
    except json.JSONDecodeError:
        json_valid = False
    
    return {
        'file': os.path.basename(filepath),
        'poisoned': len(matches) > 0,
        'zero_width_count': len(matches),
        'json_valid': json_valid
    }

def main():
    print("=" * 90)
    print("LAB 13: AI CONTEXT POISONING ANALYSIS - V1 vs V2")
    print("=" * 90)
    
    print("\n--- V1: Zero-width between JSON properties (breaks JSON) ---\n")
    
    v1_scenarios = [
        'samples/scenario-a-read-env.json',
        'samples/scenario-b-shell-exec.json',
        'samples/scenario-c-git-commit.json',
        'samples/scenario-d-exfiltrate.json'
    ]
    
    print(f"{'Scenario':<35} {'Poisoned':<10} {'ZW Count':<12} {'JSON Valid':<12} {'Status':<20}")
    print("-" * 90)
    
    for scenario in v1_scenarios:
        if os.path.exists(scenario):
            r = analyze(scenario)
            detected = "✅ DETECTED" if r['poisoned'] else "❌ MISSED"
            valid = "✅ YES" if r['json_valid'] else "❌ BROKEN"
            print(f"{r['file']:<35} {str(r['poisoned']):<10} {r['zero_width_count']:<12} {valid:<12} {detected:<20}")
    
    print("\n--- V2: Zero-width inside string value (JSON stays valid) ---\n")
    
    v2_scenarios = [
        'samples/scenario-a-read-env_poisoned_v2.json',
        'samples/scenario-b-shell-exec_poisoned_v2.json',
        'samples/scenario-c-git-commit_poisoned_v2.json',
        'samples/scenario-d-exfiltrate_poisoned_v2.json'
    ]
    
    print(f"{'Scenario':<45} {'Poisoned':<10} {'ZW Count':<12} {'JSON Valid':<12} {'Status':<20}")
    print("-" * 90)
    
    for scenario in v2_scenarios:
        if os.path.exists(scenario):
            r = analyze(scenario)
            detected = "✅ DETECTED" if r['poisoned'] else "❌ MISSED"
            valid = "✅ YES" if r['json_valid'] else "❌ BROKEN"
            print(f"{r['file']:<45} {str(r['poisoned']):<10} {r['zero_width_count']:<12} {valid:<12} {detected:<20}")
    
    print()

if __name__ == '__main__':
    main()
