#!/usr/bin/env python3
import os
import time

print("=" * 50)
print("Docker Swarm Secrets Demo App")
print("=" * 50)
print()

# Read secrets from /run/secrets/
secret_dir = "/run/secrets"

try:
    with open(f"{secret_dir}/db_password", 'r') as f:
        db_password = f.read().strip()
    print(f"✓ Database password loaded: {db_password[:4]}***")
except FileNotFoundError:
    print("✗ Database password secret not found")

try:
    with open(f"{secret_dir}/api_key", 'r') as f:
        api_key = f.read().strip()
    print(f"✓ API key loaded: {api_key[:8]}***")
except FileNotFoundError:
    print("✗ API key secret not found")

print()
print("Secrets are mounted at: /run/secrets/")
print("Secret files are in-memory only (tmpfs)")
print()
print("App running... (Ctrl+C to stop)")

# Keep container alive
while True:
    time.sleep(30)