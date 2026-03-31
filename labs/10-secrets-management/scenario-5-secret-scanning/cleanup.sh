#!/bin/bash
 
echo "Cleaning up Scenario 5: Secret Scanning..."
 
# Remove test repositories
rm -rf examples/1-gitleaks/test-repo/.git 2>/dev/null || true
rm -f examples/1-gitleaks/test-repo/leaked-secrets.txt 2>/dev/null || true
 
# Remove pre-commit config
rm -f examples/2-pre-commit/.pre-commit-config.yaml 2>/dev/null || true
 
echo "Cleanup complete!"
echo ""
echo "Note: GitLeaks Docker image retained for future use"
echo "To remove: docker rmi zricethezav/gitleaks:latest"
 