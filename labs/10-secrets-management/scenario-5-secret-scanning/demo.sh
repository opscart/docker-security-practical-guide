#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Scenario 5: Secret Scanning${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Pull GitLeaks image
echo "Pulling GitLeaks Docker image..."
docker pull zricethezav/gitleaks:latest > /dev/null 2>&1
echo -e "${GREEN}✓ GitLeaks ready${NC}"
echo ""

# Example 1: Basic repository scan
echo -e "${YELLOW}[1/4] Example 1: Scanning Repository for Secrets${NC}"
echo "Creating test repository with leaked secrets..."
echo ""

cd examples/1-gitleaks/test-repo

# Initialize git if not already
if [ ! -d .git ]; then
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
fi

# Create file with REAL secrets that GitLeaks will detect
cat > leaked-secrets.txt << 'EOF'
# Configuration file
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
github_token = ghp_1234567890abcdefghijklmnopqrstuv
stripe_key = sk_test_FAKE1234567890DEMO_NOT_REAL_SECRET
database_url = postgresql://admin:SuperSecret123@db.example.com:5432/prod
EOF

git add leaked-secrets.txt
git commit -m "Add configuration (OOPS - has secrets!)" 2>/dev/null || true

echo "Running GitLeaks scan..."
echo ""

docker run -v $(pwd):/path zricethezav/gitleaks:latest detect \
  --source /path \
  --no-git \
  --verbose || true

echo ""
echo -e "${RED}✗ Secrets detected!${NC}"
echo ""

echo "Press ENTER to continue..."
read

# Example 2: Git history scan
echo -e "${YELLOW}[2/4] Example 2: Scanning Git History${NC}"
echo "Even deleted secrets remain in git history..."
echo ""

# Delete the secrets file
rm leaked-secrets.txt
git commit -am "Remove secrets (too late!)" 2>/dev/null || true

echo "File deleted, but scanning git history:"
echo ""

docker run -v $(pwd):/path zricethezav/gitleaks:latest detect \
  --source /path \
  --log-opts="--all" \
  --verbose || true

echo ""
echo -e "${RED}✗ Secrets still found in git history!${NC}"
echo ""

cd ../../..

echo "Press ENTER to continue..."
read

# Example 3: Pre-commit hook
echo -e "${YELLOW}[3/4] Example 3: Pre-Commit Hook (Simulation)${NC}"
echo "Demonstrating pre-commit hook that prevents secret commits..."
echo ""

cd examples/2-pre-commit

# Create the config file right before showing it
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
EOF

echo "Pre-commit configuration:"
cat .pre-commit-config.yaml
echo ""

echo -e "${GREEN}With this hook installed:${NC}"
echo "  git commit → GitLeaks scan → BLOCK if secrets found"
echo ""
echo "To install: pre-commit install"
echo ""

cd ../..

echo "Press ENTER to continue..."
read

# Example 4: CI/CD Integration
echo -e "${YELLOW}[4/4] Example 4: CI/CD Pipeline Integration${NC}"
echo "Example pipeline configurations..."
echo ""

echo "GitHub Actions (.github/workflows/secrets-scan.yml):"
cat examples/3-ci-cd/github-actions.yml
echo ""

echo "Azure DevOps (azure-pipeline.yml):"
cat examples/3-ci-cd/azure-pipeline.yml
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Summary: Secret Scanning Demo Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "✓ Repository scanned for secrets"
echo "✓ Git history scanned (secrets persist!)"
echo "✓ Pre-commit hook configuration shown"
echo "✓ CI/CD integration examples provided"
echo ""
echo -e "${YELLOW}Key Insights:${NC}"
echo "  - Secrets in git are PERMANENT (even after deletion)"
echo "  - Pre-commit hooks prevent accidental commits"
echo "  - CI/CD scanning catches secrets before merge"
echo "  - Always rotate secrets if found in git"
echo ""
echo -e "${YELLOW}Prevention Layers:${NC}"
echo "  1. .gitignore (exclude .env, config files)"
echo "  2. Pre-commit hooks (local prevention)"
echo "  3. CI/CD scanning (automated checks)"
echo "  4. Periodic audits (scheduled scans)"
echo ""
echo "Run ./cleanup.sh to remove test repositories."
echo ""
echo -e "${GREEN}Lab 10 Complete!${NC} All 5 scenarios finished."