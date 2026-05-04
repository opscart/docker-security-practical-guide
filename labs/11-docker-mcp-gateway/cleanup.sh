#!/bin/bash
# cleanup.sh - Full cleanup

echo "Cleaning up Lab 11..."

# Stop services
docker-compose down -v

# Remove secrets
rm -rf security-pipeline/auth/secrets/

# Remove audit logs
rm -rf monitoring/audit-logs/*

# Remove .env (optional)
# rm .env

echo "Cleanup complete!"
echo "Run ./setup.sh to start fresh"
