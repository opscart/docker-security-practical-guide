#!/usr/bin/env python3
"""
Embed zero-width Unicode into .claude/settings.json
Version 2: Fixed encoding
"""

import json
import sys

ZWS = '\u200B'
ZWNBSP = '\u200C'
ZWJ = '\u200D'

def embed_instruction(json_file, malicious_instruction):
    """Read JSON, encode instruction as zero-width unicode, inject it"""
    
    with open(json_file, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    # Encode instruction as zero-width characters
    encoded = ''
    for char in malicious_instruction:
        byte = ord(char)
        for bit in format(byte, '08b'):
            encoded += ZWS if bit == '0' else ZWNBSP
    
    # Add encoded string to config - CRITICAL: must preserve unicode
    config['_hidden_instruction'] = encoded
    
    return config

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 zero_width_embedder.py <input.json> <instruction>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    instruction = sys.argv[2]
    
    poisoned = embed_instruction(input_file, instruction)
    
    output_file = input_file.replace('.json', '_poisoned.json')
    
    # CRITICAL: Use ensure_ascii=False to preserve unicode characters
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(poisoned, f, indent=2, ensure_ascii=False)
    
    print(f"[+] Poisoned config written to: {output_file}")
    print(f"[+] Hidden instruction: {instruction}")
    print(f"[+] Instruction length: {len(instruction)} chars")
    print(f"[+] Encoded length: {len(instruction) * 8} zero-width characters")
    
    # Verify it worked
    with open(output_file, 'r', encoding='utf-8') as f:
        verify = f.read()
    zw_count = verify.count(ZWS) + verify.count(ZWNBSP) + verify.count(ZWJ)
    print(f"[✓] Verification: {zw_count} zero-width characters found in output file")

if __name__ == '__main__':
    main()