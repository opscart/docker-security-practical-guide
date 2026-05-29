# Lab Thesis

## Core Claim

Hardened container images are necessary but not sufficient for production security in regulated environments. The security outcomes teams want — admission enforcement, drift detection, audit readiness, vendor portability — are properties of the **trust control plane** surrounding the image, not of the image itself.

## What This Lab Proves

A three-layer architectural pattern (Supply Chain → Trust → Enforcement) produces those outcomes independently of which hardened-image vendor supplies the base. The same Kyverno policies, the same drift audit, and the same SBOM verification operate identically across Docker Hardened Images, Chainguard, and self-built images signed against a project-owned identity.

This is the **substitution test**: if swapping your image vendor requires a structural rewrite of your admission policies and audits, you have a product dependency. If it requires only updating an identity matcher, you have the pattern.

## What This Lab Does Not Claim

- That hardened images offer no value — they do, specifically in reducing base CVE counts.
- That this pattern addresses runtime kernel exploits, application-level vulnerabilities, or insider compromise of signing keys. Those require separate controls.
- That the pattern is appropriate for every workload. The cost is real. See [migration-playbook.md](migration-playbook.md) for where it earns its keep.

## Companion Article

[The Container Trust Control Plane: Why Hardened Images Aren't Enough](https://opscart.com/docker-security-guide/) — published on OpsCart and DZone.