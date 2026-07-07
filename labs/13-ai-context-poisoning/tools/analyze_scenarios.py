#!/usr/bin/env python3
"""Analyze all scenario files"""

import os
import re
import json

ZERO_WIDTH_PATTERN = r'[\u200B\u200C\u200D\uFEFF]'

def analyze(filepath):
    """Analyze one file"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    matches = list(re.finditer(ZERO_WIDTH_PATTERN, content))
    
    try:
        config = json.loads(content)
        instruction = config.get('_hidden_instruction', '')
    except:
        instruction = "N/A"
    
    return {
        'file': os.path.basename(filepath),
        'poisoned': len(matches) > 0,
        'zero_width_count': len(matches),
        'instruction_detected': instruction[:50] if instruction else "None"
    }

def main():
    print("=" * 80)
    print("LAB 13: AI CONTEXT POISONING ANALYSIS")
    print("=" * 80)
    print()
    
    scenarios = [
        'samples/scenario-a-read-env.json',
        'samples/scenario-b-shell-exec.json',
        'samples/scenario-c-git-commit.json',
        'samples/scenario-d-exfiltrate.json'
    ]
    
    results = []
    for scenario in scenarios:
        if os.path.exists(scenario):
            result = analyze(scenario)
            results.append(result)
    
    # Print table
    print(f"{'Scenario':<30} {'Poisoned':<12} {'Zero-Width Count':<20} {'Status':<20}")
    print("-" * 80)
    
    for r in results:
        status = "✅ DETECTED" if r['poisoned'] else "❌ MISSED"
        print(f"{r['file']:<30} {str(r['poisoned']):<12} {r['zero_width_count']:<20} {status:<20}")
    
    print()
    print(f"Detection Rate: {sum(1 for r in results if r['poisoned'])}/{len(results)} scenarios detected")
    print()

if __name__ == '__main__':
    main()