#!/bin/bash
# examples/secret-rotation/app-with-reload.py
# Tier 2: Application with SIGHUP reload support

echo "#!/usr/bin/env python3
import os
import signal
import time

class SecretManager:
    def __init__(self):
        self.load_secrets()
    
    def load_secrets(self):
        print('Loading secrets...')
        try:
            with open('/run/secrets/db_password', 'r') as f:
                self.db_password = f.read().strip()
            print(f'✓ Password loaded: {self.db_password[:4]}***')
        except FileNotFoundError:
            print('✗ Secret not found')
    
    def reload(self, signum, frame):
        print('\\n[SIGHUP] Reloading secrets...')
        self.load_secrets()
        print('[SIGHUP] Reload complete')

if __name__ == '__main__':
    manager = SecretManager()
    signal.signal(signal.SIGHUP, manager.reload)
    
    print('App running. Send SIGHUP to reload: kill -HUP', os.getpid())
    
    while True:
        time.sleep(5)
" > /tmp/app-with-reload.py

cat /tmp/app-with-reload.py