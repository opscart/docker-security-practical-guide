#!/usr/bin/env python3
"""
Embed zero-width Unicode between legitimate JSON properties
"""

import sys
import json

# Zero-width characters
ZWS = '\u200B'      # Zero Width Space
ZWNBSP = '\u200C'   # Zero Width Non-Joiner

def embed_instruction_invisibly(json_file, malicious_instruction):
    """
    Read clean JSON, inject zero-width Unicode BETWEEN properties
    """
    
    with open(json_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Encode instruction as zero-width characters
    encoded = ''
    for char in malicious_instruction:
        byte = ord(char)
        for bit in format(byte, '08b'):
            encoded += ZWS if bit == '0' else ZWNBSP
    
    # Inject between "version" and "model"
    poisoned = content.replace(
        '"version": "1.0",',
        f'"version": "1.0"{encoded},'
    )
    
    return poisoned

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 zero_width_embedder.py <input.json> <instruction>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    instruction = sys.argv[2]
    
    poisoned = embed_instruction_invisibly(input_file, instruction)
    
    output_file = input_file.replace('.json', '_poisoned.json')
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(poisoned)
    
    print(f"[+] Poisoned config written to: {output_file}")
    print(f"[+] Hidden instruction: {instruction}")
    print(f"[+] Instruction length: {len(instruction)} chars")
    print(f"[+] Encoded length: {len(instruction) * 8} zero-width characters")

if __name__ == '__main__':
    main()
