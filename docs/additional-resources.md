# Additional Resources

This document contains curated external references used across the Docker Security Practical Guide. Official documentation, standards, and primary research are preferred over secondary summaries.

Links were reviewed when this file was prepared. External sites may reorganize content over time; report broken links through the repository issue tracker.

## Docker and Container Security

### Official Docker Documentation

- [Docker Engine security](https://docs.docker.com/engine/security/)
- [Docker daemon attack surface](https://docs.docker.com/engine/security/#docker-daemon-attack-surface)
- [Rootless mode](https://docs.docker.com/engine/security/rootless/)
- [Docker seccomp security profiles](https://docs.docker.com/engine/security/seccomp/)
- [Docker AppArmor security profiles](https://docs.docker.com/engine/security/apparmor/)
- [Docker resource constraints](https://docs.docker.com/engine/containers/resource_constraints/)
- [Docker networking](https://docs.docker.com/engine/network/)
- [Docker Build secrets](https://docs.docker.com/build/building/secrets/)
- [Docker Scout](https://docs.docker.com/scout/)
- [Docker Hardened Images](https://docs.docker.com/dhi/)

### Benchmarks and Guidance

- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Docker Bench for Security](https://github.com/docker/docker-bench-security)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [NIST SP 800-190: Application Container Security Guide](https://csrc.nist.gov/pubs/sp/800/190/final)

## Linux Isolation and Runtime Security

- [Linux namespaces documentation](https://man7.org/linux/man-pages/man7/namespaces.7.html)
- [Linux capabilities documentation](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Linux seccomp documentation](https://www.kernel.org/doc/html/latest/userspace-api/seccomp_filter.html)
- [Linux control groups v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)
- [AppArmor documentation](https://apparmor.net/)
- [SELinux project](https://selinuxproject.org/)
- [gVisor documentation](https://gvisor.dev/docs/)
- [Kata Containers documentation](https://katacontainers.io/docs/)
- [Firecracker documentation](https://firecracker-microvm.github.io/)

## Vulnerability Scanning and SBOM

### Tools

- [Trivy documentation](https://trivy.dev/)
- [Syft](https://github.com/anchore/syft)
- [Grype](https://github.com/anchore/grype)
- [Docker Scout vulnerability analysis](https://docs.docker.com/scout/explore/)

### Standards

- [SPDX](https://spdx.dev/)
- [CycloneDX](https://cyclonedx.org/)
- [CISA SBOM resources](https://www.cisa.gov/sbom)
- [NTIA minimum elements for an SBOM](https://www.ntia.gov/report/2021/minimum-elements-software-bill-materials-sbom)

## Signing, Provenance, and Software Supply Chain

- [Sigstore documentation](https://docs.sigstore.dev/)
- [Cosign documentation](https://docs.sigstore.dev/cosign/)
- [SLSA specification](https://slsa.dev/spec/)
- [in-toto](https://in-toto.io/)
- [OpenVEX](https://openvex.dev/)
- [GitHub artifact attestations](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations)
- [NIST Secure Software Development Framework](https://csrc.nist.gov/Projects/ssdf)
- [OpenSSF Scorecard](https://securityscorecards.dev/)

## Kubernetes Security and Policy

### Official Documentation

- [Kubernetes security concepts](https://kubernetes.io/docs/concepts/security/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Security contexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Seccomp in Kubernetes](https://kubernetes.io/docs/tutorials/security/seccomp/)
- [NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Ephemeral containers](https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/)
- [Auditing](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)

### Policy and Runtime Tools

- [Kyverno documentation](https://kyverno.io/docs/)
- [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/)
- [Open Policy Agent](https://www.openpolicyagent.org/docs/latest/)
- [Falco documentation](https://falco.org/docs/)
- [Cilium network policy](https://docs.cilium.io/en/stable/security/policy/)

## Secrets Management

- [Docker Swarm secrets](https://docs.docker.com/engine/swarm/secrets/)
- [HashiCorp Vault documentation](https://developer.hashicorp.com/vault/docs)
- [BuildKit secret mounts](https://docs.docker.com/build/building/secrets/)
- [GitLeaks](https://github.com/gitleaks/gitleaks)
- [GitHub secret scanning](https://docs.github.com/en/code-security/secret-scanning)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

## AI Agents, MCP, and Sandbox Security

- [Model Context Protocol specification](https://modelcontextprotocol.io/specification/)
- [Microsoft AutoGen documentation](https://microsoft.github.io/autogen/)
- [Docker Sandboxes documentation](https://docs.docker.com/ai/sandboxes/)
- [OWASP Top 10 for LLM Applications](https://genai.owasp.org/llm-top-10/)
- [MITRE ATLAS](https://atlas.mitre.org/)
- [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)

## Cloud-Native Security Guidance

- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/tree/main/security-whitepaper)
- [CNCF Security Technical Advisory Group](https://tag-security.cncf.io/)
- [Kubernetes security best practices](https://kubernetes.io/docs/concepts/security/)
- [NSA and CISA Kubernetes Hardening Guidance](https://www.cisa.gov/resources-tools/resources/kubernetes-hardening-guidance)

## Primary Research and Technical Papers

### Container Isolation and Trusted Execution

- [SCONE: Secure Linux Containers with Intel SGX](https://www.usenix.org/conference/osdi16/technical-sessions/presentation/arnautov) — OSDI 2016
- [Container Security: Issues, Challenges, and the Road Ahead](https://ieeexplore.ieee.org/document/7579198)
- [NIST SP 800-190: Application Container Security Guide](https://csrc.nist.gov/pubs/sp/800/190/final)

The previous resource file labeled the Arnautov link as “Understanding Container Security” and pointed to a USENIX Security 2016 path. That reference was incorrect. The authentic paper is **SCONE: Secure Linux Containers with Intel SGX**, published at OSDI 2016.

### Project Research

See [Publications and Research](./publications-and-research.md) for Shamsher Khan's arXiv, TechRxiv, Zenodo, CNCF, and practitioner publications connected to these labs.

## Project and Author Channels

- [OpsCart Docker Security Guide](https://opscart.com/guides-tutorials/docker-security-guide/)
- [OpsCart container articles](https://opscart.com/category/containers/)
- [DZone author profile](https://dzone.com/authors/shamsherkhan-1)
- [dev.to author profile](https://dev.to/shamsher_khan)
- [Medium author profile](https://medium.com/@shams.khan22)
- [CNCF: When Kubernetes Restarts Your Pod — And When It Doesn't](https://www.cncf.io/blog/2026/03/17/when-kubernetes-restarts-your-pod-and-when-it-doesnt/)
- [CNCF: What `kubectl debug` Doesn't Tell You](https://www.cncf.io/blog/2026/05/18/what-kubectl-debug-doesnt-tell-you-the-silent-evidence-gap/)

## Link Maintenance

When adding a reference:

1. Prefer an official project, standards body, publisher, or paper page.
2. Avoid unofficial mirrors when a primary source is available.
3. Use the publication's real title.
4. Add a short description only when the link's relevance is not obvious.
5. Recheck external links when updating a related lab.
