#!/usr/bin/env python3
"""Detect zero-width unicode in JSON files"""

import re
import sys

ZERO_WIDTH_PATTERN = r'[\u200B\u200C\u200D\uFEFF]'

def scan_file(filepath):
    """Scan for zero-width characters"""
    
    # CRITICAL: Read as UTF-8
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    matches = list(re.finditer(ZERO_WIDTH_PATTERN, content))
    
    if not matches:
        print(f"[✓] {filepath}: CLEAN (no zero-width characters)")
        return True
    
    print(f"[!] {filepath}: POISONED - {len(matches)} zero-width characters found")
    
    for i, match in enumerate(matches[:20]):
        char_code = ord(match.group())
        char_name = {
            0x200B: 'ZERO WIDTH SPACE (U+200B)',
            0x200C: 'ZERO WIDTH NON-JOINER (U+200C)',
            0x200D: 'ZERO WIDTH JOINER (U+200D)',
            0xFEFF: 'ZERO WIDTH NO-BREAK SPACE (U+FEFF)'
        }.get(char_code, f'UNKNOWN (U+{char_code:04X})')
        
        print(f"  [{i+1}] Position {match.start()}: {char_name}")
    
    if len(matches) > 20:
        print(f"  ... and {len(matches) - 20} more")
    
    return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 detector.py <file.json>")
        sys.exit(1)
    
    is_clean = scan_file(sys.argv[1])
    sys.exit(0 if is_clean else 1)

if __name__ == '__main__':
    main()