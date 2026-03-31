#!/bin/bash

echo "Cleaning up Lab 10 - Scenario 1..."

# Stop and remove containers
cd examples/2-env-vars && docker compose down 2>/dev/null || true
cd ../4-volume-files && docker compose down 2>/dev/null || true

# Remove images
docker rmi lab10-hardcoded:latest 2>/dev/null || true
docker rmi lab10-buildargs:latest 2>/dev/null || true
docker rmi lab10-envvars-app 2>/dev/null || true
docker rmi lab10-volumes-app 2>/dev/null || true

# Remove git repo
cd ../5-git-history && rm -rf .git 2>/dev/null || true

# Remove generated secret files
cd ../4-volume-files && rm -f secrets/api_key.txt 2>/dev/null || true

echo "Cleanup complete!"