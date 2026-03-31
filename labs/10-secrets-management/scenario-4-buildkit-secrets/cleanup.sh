# File: cleanup.sh
#!/bin/bash
 
echo "Cleaning up Scenario 4: BuildKit Secrets..."
 
# Remove images
docker rmi buildkit-basic:latest 2>/dev/null || true
docker rmi buildkit-npm:latest 2>/dev/null || true
docker rmi buildkit-ssh:latest 2>/dev/null || true
docker rmi buildkit-multistage:latest 2>/dev/null || true
 
# Remove any leftover secret files
cd examples
find . -name "*.secret" -delete 2>/dev/null || true
find . -name ".npmrc" -delete 2>/dev/null || true
find . -name "id_rsa" -delete 2>/dev/null || true
 
echo "Cleanup complete!"
 