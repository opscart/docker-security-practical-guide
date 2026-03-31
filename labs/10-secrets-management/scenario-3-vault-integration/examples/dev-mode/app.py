#!/usr/bin/env python3
import hvac
import os
import sys
import time

print("=" * 60)
print("Vault Integration Demo App")
print("=" * 60)
print()

# Configuration
vault_url = os.environ.get('VAULT_ADDR', 'http://vault:8200')
vault_token = os.environ.get('VAULT_TOKEN', 'myroot')

print(f"Vault Address: {vault_url}")
print(f"Token: {vault_token[:6]}***")
print()

# Wait for Vault to be ready
print("Waiting for Vault to be ready...")
for i in range(10):
    try:
        client = hvac.Client(url=vault_url, token=vault_token)
        if client.is_authenticated():
            print("✓ Connected to Vault")
            break
    except:
        time.sleep(2)
else:
    print("✗ Failed to connect to Vault")
    sys.exit(1)

print()

# Read database credentials
try:
    print("Reading database credentials from Vault...")
    db_secret = client.secrets.kv.v2.read_secret_version(path='db')
    db_data = db_secret['data']['data']
    
    print(f"✓ Database credentials loaded:")
    print(f"  Host: {db_data.get('host', 'N/A')}")
    print(f"  Port: {db_data.get('port', 'N/A')}")
    print(f"  Username: {db_data.get('username', 'N/A')}")
    print(f"  Password: {db_data.get('password', 'N/A')[:4]}***")
    print()
except Exception as e:
    print(f"✗ Failed to read database credentials: {e}")
    print()

# Read API credentials
try:
    print("Reading API credentials from Vault...")
    api_secret = client.secrets.kv.v2.read_secret_version(path='api')
    api_data = api_secret['data']['data']
    
    print(f"✓ API credentials loaded:")
    print(f"  Endpoint: {api_data.get('endpoint', 'N/A')}")
    print(f"  Key: {api_data.get('key', 'N/A')[:8]}***")
    print()
except Exception as e:
    print(f"✗ Failed to read API credentials: {e}")
    print()

print("=" * 60)
print("Key Insights:")
print("=" * 60)
print("1. Secrets fetched at runtime (not baked into image)")
print("2. Application authenticates with Vault token")
print("3. Secrets can be rotated without rebuilding image")
print("4. All access logged in Vault audit trail")
print()
print("App would now connect to database and API...")
print("(In production, secrets would have TTL and auto-rotate)")
print()
print("App running... (will exit in 10 seconds)")
time.sleep(10)