#!/usr/bin/env python3
print("App running with HARDCODED secrets (BAD!)")
print("Check: docker history <image> to see leaked secrets")

with open('/app/config', 'r') as f:
    print(f.read())