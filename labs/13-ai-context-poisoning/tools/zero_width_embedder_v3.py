#!/usr/bin/env python3
"""
V3: Embed zero-width Unicode into plain text files (CLAUDE.md, .cursorrules)
No JSON parser, no field length limits
"""

import sys

ZWS = '\u200B'
ZWNBSP = '\u200C'

def embed_into_plaintext(text_file, malicious_instruction):
    
    with open(text_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Encode instruction as zero-width characters
    encoded = ''
    for char in malicious_instruction:
        byte = ord(char)
        for bit in format(byte, '08b'):
            encoded += ZWS if bit == '0' else ZWNBSP
    
    # Inject after first line - invisible to human reviewer
    lines = content.split('\n')
    lines[0] = lines[0] + encoded
    
    return '\n'.join(lines)

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 zero_width_embedder_v3.py <input_file> <instruction>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    instruction = sys.argv[2]
    
    poisoned = embed_into_plaintext(input_file, instruction)
    
    output_file = input_file + '_poisoned'
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(poisoned)
    
    print(f"[+] Output: {output_file}")
    print(f"[+] Hidden instruction: {instruction}")
    print(f"[+] Encoded length: {len(instruction) * 8} zero-width characters")
    
    # Verify it looks normal
    with open(output_file, 'r', encoding='utf-8') as f:
        verify = f.read()
    
    import re
    zw_count = len(re.findall(r'[\u200B\u200C\u200D\uFEFF]', verify))
    print(f"[✓] Verification: {zw_count} zero-width chars embedded")
    print(f"\n--- File looks like this to humans ---")
    clean_view = re.sub(r'[\u200B\u200C\u200D\uFEFF]', '', verify)
    print(clean_view)
    print("--- End ---")

if __name__ == '__main__':
    main()
