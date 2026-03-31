# Scenario 5: Secret Scanning and Prevention

## Overview

Automated secret scanning detects accidentally committed credentials in code repositories, git history, and CI/CD pipelines. This scenario demonstrates GitLeaks for secret detection and prevention strategies.

**Time:** 15 minutes  
**Requirements:** Docker, Git

## What You'll Learn

- Scan repositories for leaked secrets with GitLeaks
- Set up pre-commit hooks to prevent commits with secrets
- Integrate secret scanning in CI/CD pipelines
- Create custom detection rules for company-specific secrets
- Remediate found secrets properly

## Prerequisites

- Docker installed
- Git repository access
- Basic understanding of git hooks

## The Problem

Developers accidentally commit secrets:
- API keys in config files
- Passwords in .env files
- Private keys in repositories
- Database credentials in code

**Impact:** Permanent exposure in git history, even after file deletion.

## Running the Demo

```bash
./demo.sh
```

This demonstrates:
1. Scanning repository for secrets
2. Detecting secrets in git history
3. Pre-commit hook prevention
4. CI/CD pipeline integration

## Key Concepts

### GitLeaks
Open-source tool that scans for:
- API keys (AWS, GitHub, Stripe, etc.)
- Database connection strings
- Private keys (SSH, PGP, RSA)
- Generic secrets (high entropy strings)

### Prevention Layers
1. `.gitignore` - Exclude sensitive files
2. Pre-commit hooks - Local prevention
3. CI/CD scanning - Automated checks
4. Periodic audits - Scheduled scans

## Common Secret Patterns

- **AWS Keys:** `AKIA[0-9A-Z]{16}`
- **GitHub Tokens:** `ghp_[a-zA-Z0-9]{36}`
- **Slack Tokens:** `xox[baprs]-[0-9]{10,12}-[a-zA-Z0-9]{24,}`
- **Private Keys:** `-----BEGIN (RSA|OPENSSH|PGP) PRIVATE KEY-----`

## Secret Remediation

### If Secret Found:
1. Remove from code immediately
2. **Rotate/revoke the secret** (critical!)
3. Rewrite git history (if needed)
4. Review access logs
5. Update documentation

### Git History Cleanup:
```bash
# WARNING: Rewrites history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env" \
  --prune-empty -- --all
```

**Critical:** Always rotate secrets even after removal.

## Cleanup

```bash
./cleanup.sh
```

## Validation

```bash
./validate.sh
```

## References

- [GitLeaks](https://github.com/gitleaks/gitleaks)
- [Pre-Commit Framework](https://pre-commit.com/)
- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

## Key Takeaways

1. **Secrets in git are permanent** - even after deletion
2. **Automate scanning** - catch before commit
3. **Pre-commit hooks** - first line of defense
4. **CI/CD integration** - mandatory checks
5. **Always rotate** - assume compromised if found