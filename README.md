# Docker Security: A Practical Guide

A comprehensive, hands-on guide to Docker security best practices with real-world examples and lab exercises.

## 🎯 What You'll Learn

This guide takes you from basic Docker security concepts to advanced hardening techniques through practical, reproducible lab exercises. Each lab builds on previous knowledge while remaining self-contained.

### Core Topics Covered

- **Security Auditing**: Using Docker Bench Security for CIS compliance
- **Secure Images**: Building hardened, minimal container images
- **Least Privilege**: Implementing proper access controls
- **Image Signing**: Verifying container authenticity
- **Network Security**: Isolating and securing container communications
- **AI/ML Security**: Protecting machine learning workloads
- **Supply Chain Security**: SBOM generation and vulnerability scanning
- **Network Architecture**: Multi-tier segmentation and encryption

## 📚 Lab Structure

### Level 1: Fundamentals (Labs 01-06)

Foundation labs covering essential Docker security concepts.

---

### [Lab 01: Security Auditing with Docker Bench](./labs/01-docker-bench-security/)

**What You'll Learn:**
- Run comprehensive security audits using Docker Bench Security
- Understand CIS Docker Benchmark compliance checks
- Identify common security misconfigurations
- Fix vulnerable container configurations

**Key Concepts:**
- Privileged container detection
- Network namespace isolation
- Capability management
- Security profile enforcement

**Time:** 30-45 minutes

---

### [Lab 02: Secure Container Configurations](./labs/02-secure-configs/)

**What You'll Learn:**
- Compare insecure vs secure container configurations
- Understand and apply Linux capabilities
- Implement read-only filesystems
- Use tmpfs for required write operations
- Apply security options like no-new-privileges

**Key Concepts:**
- Linux capability system
- Read-only root filesystems
- Capability dropping (drop all, add specific)
- tmpfs mounts with noexec and nosuid
- Container hardening without breaking functionality

**Time:** 45-60 minutes

---

### [Lab 03: Least Privilege Containers](./labs/03-least-privilege/)

**What You'll Learn:**
- Run containers as non-root users
- Drop unnecessary Linux capabilities
- Implement read-only filesystems
- Configure security contexts

**Key Concepts:**
- User namespace remapping
- Capability dropping
- Resource constraints
- Security policies

**Time:** 30-45 minutes

---

### [Lab 04: Image Signing and Verification](./labs/04-image-signing/)

**What You'll Learn:**
- Sign container images with Cosign
- Verify image signatures before deployment
- Implement Docker Content Trust
- Enforce signing policies
- Manage signing keys securely

**Key Concepts:**
- Digital signatures and cryptographic verification
- Cosign and Sigstore project
- Docker Content Trust (DCT)
- Keyless signing with OIDC
- Supply chain attack prevention
- Policy enforcement for signed images

**Time:** 45-60 minutes

---

### [Lab 05: Network Security Basics](./labs/05-network-security/)

**What You'll Learn:**
- Configure secure Docker networks
- Implement network policies
- Use service mesh patterns
- Secure inter-container communication

**Key Concepts:**
- Custom bridge networks
- Network segmentation
- Encrypted communication
- Traffic control

**Time:** 30-45 minutes

---

### [Lab 06: AI Model Security](./labs/06-ai-model-security/)

**What You'll Learn:**
- Secure containerized machine learning workloads
- Set appropriate resource limits for ML containers
- Implement input validation and rate limiting
- Protect model intellectual property
- Monitor ML container behavior
- Deploy ML models securely in production

**Key Concepts:**
- Resource management for ML workloads
- Model extraction and adversarial attacks
- API authentication and authorization
- Input validation for ML endpoints
- Model encryption and access control
- Monitoring and anomaly detection for ML services

**Time:** 60-90 minutes

---

### Level 2: Advanced Security (Labs 07-08)

Advanced labs covering supply chain security and comprehensive network security.

---

### [Lab 07: Supply Chain Security with SBOM](./labs/07-supply-chain-sbom/)

**What You'll Learn:**
- Generate Software Bill of Materials (SBOM) using Syft
- Scan SBOMs for vulnerabilities with Grype
- Compare SBOM versions to track changes
- Integrate SBOM generation into CI/CD pipelines
- Meet compliance requirements (Executive Order 14028)

**Key Concepts:**
- SBOM formats (SPDX, CycloneDX, Syft JSON)
- Supply chain transparency
- Vulnerability management
- Dependency tracking
- CVE detection and remediation
- CI/CD security automation

**Key Tools:**
- **Syft**: SBOM generation
- **Grype**: Vulnerability scanning
- **Azure DevOps** and **GitHub Actions**: CI/CD integration

**Time:** 45-60 minutes

**Why This Matters:**
- Required for US federal software (EO 14028)
- Enables rapid response to vulnerabilities (e.g., Log4Shell)
- Provides complete software inventory
- Supports compliance audits (PCI DSS, SOC 2)

---

### [Lab 08: Docker Network Security (5 Scenarios)](./labs/08-network-security/)

**What You'll Learn:**
- Implement network isolation between containers
- Design multi-tier segmented architectures
- Use internal networks for complete database isolation
- Configure TLS encryption for container-to-container communication
- Identify and fix 8 common network misconfigurations

**5 Interactive Scenarios:**

**Scenario 1: Network Isolation** (3-4 minutes)
- Create isolated networks with DNS resolution
- Implement gateway containers spanning multiple networks
- Understand network boundaries

**Scenario 2: Multi-Tier Segmentation** (4-5 minutes)
- Design 3-tier architecture (web/app/database)
- Force traffic through monitored gateways
- Prevent direct web-to-database access

**Scenario 3: Internal Networks** (3-4 minutes)
- Use internal networks with no external gateway
- Achieve complete database isolation
- Meet PCI DSS and HIPAA requirements

**Scenario 4: TLS Encryption** (4-5 minutes)
- Generate self-signed certificates
- Configure nginx with TLS
- Implement encrypted container communication
- Understand TLS performance implications

**Scenario 5: Common Misconfigurations** (3-4 minutes)
- Learn 8 common network security mistakes:
  1. Using default bridge network (no DNS)
  2. Using `--network host` (bypasses security)
  3. Exposing unnecessary ports (databases)
  4. No resource limits (DoS risk)
  5. Running as root
  6. Using `--privileged` mode
  7. Flat network architecture
  8. No health checks

**Key Concepts:**
- Defense in depth
- Network segmentation
- Zero-trust architecture
- TLS/mTLS implementation
- Resource management
- Security misconfiguration prevention

**Time:** 18-22 minutes (all scenarios) or 3-5 minutes each

**Why This Matters:**
- Prevents lateral movement during breaches
- Meets compliance requirements
- Protects sensitive data in transit
- Enables zero-trust architectures
- Real-world production patterns

---

## 🚀 Getting Started

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Linux, macOS, or Windows with WSL2
- Basic Docker knowledge
- Terminal/command line familiarity

### Quick Start

1. **Clone the repository:**
```bash
git clone https://github.com/opscart/docker-security-practical-guide.git
cd docker-security-practical-guide
```

2. **Start with Lab 01:**
```bash
cd labs/01-docker-bench-security
./run-audit.sh
```

3. **Follow along with the README in each lab directory**

## 📖 How to Use This Guide

### For Beginners

1. Start with Lab 01 to understand security auditing
2. Progress sequentially through Level 1 (Labs 01-06)
3. Complete all exercises before moving forward
4. Review the "Common Issues" sections
5. Move to Level 2 (Labs 07-08) for advanced topics

### For Experienced Users

1. Jump to specific labs based on your needs
2. Use as a reference for security patterns
3. Adapt examples to your use cases
4. Focus on Level 2 labs for advanced techniques
5. Contribute improvements via pull requests

### For Security Auditors

1. Use Lab 01 for baseline security assessments
2. Reference CIS Benchmark mappings
3. Lab 07 for supply chain compliance
4. Lab 08 for network architecture reviews
5. Adapt checklists for your compliance needs
6. Document findings using provided templates

### For DevOps/Platform Engineers

1. Lab 07 for CI/CD security integration
2. Lab 08 for production network architecture
3. Use automation scripts in your pipelines
4. Implement security best practices from all labs

## 🔧 Lab Setup

Each lab is self-contained and includes:

- `README.md`: Comprehensive guide with theory and practice
- `docker-compose.yml`: Ready-to-run configurations
- Scripts: Automation for common tasks
- Examples: Both vulnerable and secure configurations
- CI/CD configs: Azure DevOps and GitHub Actions (Labs 07-08)

### Running a Lab

```bash
# Navigate to lab directory
cd labs/XX-lab-name

# Review the README
cat README.md

# Run the lab exercise
./run-demo.sh  # or specific lab script

# Clean up
./cleanup.sh
```

## 🎓 Learning Path

### Level 1: Fundamentals
```
Lab 01: Security Auditing (CIS Benchmark)
    ↓
Lab 02: Secure Configurations (Capabilities, Read-only FS)
    ↓
Lab 03: Least Privilege (Non-root, Resource Limits)
    ↓
Lab 04: Image Signing (Cosign, Content Trust)
    ↓
Lab 05: Network Security Basics (Custom Networks)
    ↓
Lab 06: AI/ML Security (Model Protection)
```

### Level 2: Advanced
```
Lab 07: Supply Chain Security
         (SBOM, Vulnerability Scanning)
    ↓
Lab 08: Network Security
         (5 Scenarios: Isolation to Encryption)
```

**Estimated Time:** 
- Level 1 (Labs 01-06): 4-6 hours
- Level 2 (Labs 07-08): 2-3 hours
- Complete guide: 6-9 hours
- With practice exercises: 10-15 hours

## 🛠️ Tools & Technologies

### Security Tools Used

**Level 1:**
- **Docker Bench Security**: CIS compliance auditing
- **Trivy**: Vulnerability scanning
- **Cosign**: Container signing
- **Anchore**: Image analysis
- **Notary**: Content trust

**Level 2:**
- **Syft**: SBOM generation (Lab 07)
- **Grype**: Vulnerability scanning (Lab 07)
- **OpenSSL**: Certificate generation (Lab 08)
- **nginx**: TLS configuration (Lab 08)

### Technologies Covered

- Docker Engine & Docker Compose
- Linux Security Modules (AppArmor, SELinux)
- Seccomp profiles
- User namespaces
- Capability systems
- Docker networking (bridge, internal, overlay)
- TLS/mTLS encryption
- CI/CD integration (Azure DevOps, GitHub Actions)

## 📝 Best Practices Summary

### Image Security
- Use minimal base images (alpine, distroless)
- Scan for vulnerabilities regularly
- Generate and maintain SBOMs (Lab 07)
- Sign and verify images (Lab 04)
- Use specific tags, never `latest`
- Implement multi-stage builds

### Runtime Security
- Run as non-root user (Lab 03)
- Drop unnecessary capabilities (Lab 02)
- Use read-only filesystems (Lab 02)
- Enable security profiles
- Set resource limits (Lab 08)
- Implement health checks (Lab 08)

### Network Security
- Use custom bridge networks (Lab 08)
- Implement multi-tier segmentation (Lab 08)
- Use internal networks for databases (Lab 08)
- Avoid host network mode (Lab 08)
- Encrypt traffic with TLS (Lab 08)
- Control ingress/egress

### Supply Chain Security (Lab 07)
- Generate SBOMs for all images
- Scan regularly for vulnerabilities
- Track dependency changes
- Automate in CI/CD pipelines
- Meet compliance requirements
- Respond quickly to CVEs

### Secrets Management
- Never hardcode credentials
- Use Docker secrets or external vaults
- Rotate secrets regularly
- Limit secret access scope
- Audit secret usage

### Operational Security
- Regular security audits (Lab 01)
- Keep Docker updated
- Monitor container behavior
- Log security events
- Incident response plan
- Track SBOM and vulnerability changes (Lab 07)

## 🏗️ Architecture Patterns

### Multi-Tier Segmentation (Lab 08)
```
┌──────────────┐       ┌──────────────┐       ┌─────────────────┐
│  Public Net  │       │   App Net    │       │  Database Net   │
│              │       │              │       │   (INTERNAL)    │
│    [Web]     │◄─────►│    [App]     │◄─────►│      [DB]       │
│   :8443      │  TLS  │              │       │   No Gateway    │
└──────────────┘       └──────────────┘       └─────────────────┘
     ▲
     │
  Internet
```

### Supply Chain Security (Lab 07)
```
[Container] → [Syft] → [SBOM] → [Grype] → [Security Report]
                ↓
        [SPDX/CycloneDX/JSON]
                ↓
           [CVE Database]
                ↓
        [Critical/High/Medium/Low]
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add your improvements
4. Test thoroughly
5. Submit a pull request

### Contribution Ideas

- Additional lab exercises
- Security tool integrations
- Cloud platform examples (AWS, Azure, GCP)
- Kubernetes security labs
- Advanced threat scenarios
- Additional SBOM formats
- More network security patterns

## 📚 Additional Resources

### Official Documentation
- [Docker Security](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Docker Bench Security](https://github.com/docker/docker-bench-security)
- [Syft (SBOM Generation)](https://github.com/anchore/syft)
- [Grype (Vulnerability Scanning)](https://github.com/anchore/grype)

### Security Standards
- [NIST Container Security](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)
- [OWASP Docker Top 10](https://owasp.org/www-project-docker-top-10/)
- [CIS Controls](https://www.cisecurity.org/controls)
- [Executive Order 14028](https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/) - SBOM Requirements

### SBOM Resources (Lab 07)
- [SPDX Specification](https://spdx.dev/)
- [CycloneDX Standard](https://cyclonedx.org/)
- [CISA SBOM Resources](https://www.cisa.gov/sbom)
- [NTIA SBOM Minimum Elements](https://www.ntia.gov/report/2021/minimum-elements-software-bill-materials-sbom)

### Network Security Resources (Lab 08)
- [Docker Network Documentation](https://docs.docker.com/network/)
- [Container Network Security](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [TLS Best Practices](https://wiki.mozilla.org/Security/Server_Side_TLS)

### Community Resources
- [Docker Security Subreddit](https://reddit.com/r/docker)
- [Docker Community Slack](https://dockercommunity.slack.com)
- [Stack Overflow Docker Tag](https://stackoverflow.com/questions/tagged/docker)
- [CNCF Slack](https://slack.cncf.io/)

## 🐛 Troubleshooting

### Common Issues

**Issue: Permission denied running scripts**
```bash
chmod +x script-name.sh
```

**Issue: Docker daemon not running**
```bash
sudo systemctl start docker
```

**Issue: Port already in use**
```bash
docker ps  # Check running containers
docker-compose down  # Stop services
lsof -i :PORT  # Find process using port
```

**Issue: Image pull failures**
```bash
docker login  # Authenticate if needed
docker pull image-name  # Manual pull to test
```

**Issue: Syft/Grype not found (Lab 07)**
```bash
# Install Syft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Install Grype
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
```

**Issue: Certificate generation fails (Lab 08)**
```bash
# Ensure OpenSSL is installed
openssl version

# Check certificate generation script
cd labs/08-network-security/certs
chmod +x generate-certs.sh
./generate-certs.sh
```

**Issue: Network already exists (Lab 08)**
```bash
# Clean up all networks
cd labs/08-network-security
./cleanup.sh
```

## 📊 Lab Completion Status

Track your progress:

- [ ] Lab 01: Security Auditing ⏱️ 30-45 min
- [ ] Lab 02: Secure Configurations ⏱️ 45-60 min
- [ ] Lab 03: Least Privilege ⏱️ 30-45 min
- [ ] Lab 04: Image Signing ⏱️ 45-60 min
- [ ] Lab 05: Network Security Basics ⏱️ 30-45 min
- [ ] Lab 06: AI/ML Security ⏱️ 60-90 min
- [ ] Lab 07: Supply Chain Security (SBOM) ⏱️ 45-60 min
- [ ] Lab 08: Network Security (5 Scenarios) ⏱️ 18-22 min

**Total Time:** 6-9 hours

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details

## ✨ Acknowledgments

- Docker team for security tools and documentation
- CIS for the Docker Benchmark
- OWASP for security guidelines
- Anchore team for Syft and Grype (Lab 07)
- Sigstore project for Cosign (Lab 04)
- Open source security community
- CNCF for cloud native security standards

## 📧 Contact & Support

- **Author**: Shamsher Khan
- **GitHub**: [@opscart](https://github.com/opscart)
- **Website**: [opscart.com](https://opscart.com)
- **Issues**: [Report issues](https://github.com/opscart/docker-security-practical-guide/issues)
- **Discussions**: [GitHub Discussions](https://github.com/opscart/docker-security-practical-guide/discussions)

### Professional Background
- Senior DevOps Engineer
- IEEE Senior Member
- 15+ years IT experience
- 10+ years Cloud & DevOps specialization
- Published author on DZone and technical publications

## 🌟 Star This Repository!

If you find this guide helpful:
1. ⭐ Star the repository
2. 🔀 Fork for your own learning
3. 📢 Share with your team
4. 💬 Provide feedback
5. 🤝 Contribute improvements

---

## 📈 What's Next?

### Upcoming Labs (Planned)

- **Lab 09**: Secrets Management with HashiCorp Vault
- **Lab 10**: Runtime Security with Falco
- **Lab 11**: Kubernetes Security Fundamentals
- **Lab 12**: Container Registry Security

### Stay Updated

- Watch this repository for updates
- Follow [@opscart](https://github.com/opscart) on GitHub
- Join discussions in the Issues tab

---

**🎯 From fundamentals to advanced patterns, this guide has everything you need to secure your Docker deployments in production.**

---

**⭐ If you find this guide helpful, please star the repository!**

**🔒 Remember: Security is a journey, not a destination. Keep learning, keep improving!**
