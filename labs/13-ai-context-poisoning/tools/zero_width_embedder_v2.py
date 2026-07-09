#!/usr/bin/env python3
"""
V2: Embed zero-width Unicode INSIDE a string value
JSON remains valid - parser accepts it
LLM reads string and sees hidden instruction
"""

import sys
import json

ZWS = '\u200B'
ZWNBSP = '\u200C'

def embed_instruction_invisibly(json_file, malicious_instruction):
    
    with open(json_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Encode instruction
    encoded = ''
    for char in malicious_instruction:
        byte = ord(char)
        for bit in format(byte, '08b'):
            encoded += ZWS if bit == '0' else ZWNBSP
    
    # Inject INSIDE the model string value
    # JSON remains valid
    poisoned = content.replace(
        '"claude-opus-4-5"',
        f'"claude-opus-4-5{encoded}"'
    )
    
    return poisoned

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 zero_width_embedder_v2.py <input.json> <instruction>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    instruction = sys.argv[2]
    
    poisoned = embed_instruction_invisibly(input_file, instruction)
    
    output_file = input_file.replace('.json', '_poisoned_v2.json')
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(poisoned)
    
    print(f"[+] Output: {output_file}")
    print(f"[+] Hidden instruction: {instruction}")
    print(f"[+] Encoded length: {len(instruction) * 8} zero-width characters")
    
    # Verify JSON is still valid
    try:
        with open(output_file, 'r', encoding='utf-8') as f:
            json.load(f)
        print(f"[✓] JSON valid - Claude Code parser will accept this")
    except json.JSONDecodeError as e:
        print(f"[!] JSON invalid - {e}")

if __name__ == '__main__':
    main()
