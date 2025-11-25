# Lab 07: Supply Chain Security with SBOM

## 🎯 What You'll Learn

Generate and manage Software Bill of Materials (SBOM) to track container dependencies, identify vulnerabilities in your supply chain, and meet compliance requirements. This lab demonstrates practical SBOM generation, vulnerability scanning, and CI/CD integration.

**Key Outcomes:**
- Generate SBOMs in multiple formats (SPDX, CycloneDX)
- Scan SBOMs for vulnerabilities with industry-standard tools
- Integrate SBOM generation into CI/CD pipelines
- Compare SBOMs across image versions to track dependency changes
- Sign and verify SBOMs for supply chain integrity

## 📋 Prerequisites

- Docker Engine 20.10+
- macOS, Linux, or Windows with WSL2
- 20-30 minutes
- Completed Lab 04 (Image Signing) - optional but recommended

## Quick Start

```bash
# Clone the repository (if not already done)
git clone https://github.com/opscart/docker-security-practical-guide.git
cd docker-security-practical-guide/labs/07-supply-chain-sbom

# Run the automated demo (interactive mode with 2 pauses)
./run-demo.sh

# Or run in automatic mode (no pauses, completes in ~5 minutes)
./run-demo.sh --auto

# Or follow step-by-step below
```

## 🔍 Understanding the Problem

### Real-World Supply Chain Attacks

**Log4Shell (CVE-2021-44228)**
- Discovered December 2021
- Affected millions of Java applications
- Organizations spent days identifying vulnerable systems
- **Those with SBOMs identified exposure in hours, not days**

**SolarWinds (2020)**
- Supply chain compromise at build time
- Malicious code inserted into trusted software
- Affected 18,000+ organizations
- Detection took 9+ months

**event-stream npm package (2018)**
- Legitimate package hijacked
- Malicious code added to steal cryptocurrency
- Downloaded 8 million times before detection

### Why SBOMs Matter

Think of an SBOM as a **nutrition label for software** - it lists every ingredient (dependency) in your container:

- 📦 **Transparency**: Know exactly what's in your images
- 🔍 **Vulnerability Management**: Quickly identify affected systems
- 📊 **Compliance**: Meet regulatory requirements (CISA EO 14028)
- 🔄 **Dependency Tracking**: Monitor changes across versions
- 🛡️ **Risk Assessment**: Understand your attack surface

### The Challenge

**Without SBOM:**
```
New vulnerability announced → Check all 500 containers →
Manually inspect each image → Hope you find everything →
Takes days or weeks
```

**With SBOM:**
```
New vulnerability announced → Query SBOM database →
Identify affected containers in minutes → Patch immediately
```

## 🛠️ Tools We'll Use

| Tool | Purpose | Why This Tool |
|------|---------|---------------|
| **Syft** | SBOM generation | Fast, supports multiple formats, maintained by Anchore |
| **Grype** | Vulnerability scanning | Works directly with SBOMs, comprehensive CVE database |
| **Cosign** | SBOM signing | Industry standard, keyless signing support |

## 📖 Step-by-Step Lab

### Part 1: Install Tools

The lab scripts will auto-install, but here's how to do it manually:

```bash
# Install Syft (SBOM generator)
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Install Grype (vulnerability scanner)
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Verify installation
syft version
grype version
```

### Part 2: Generate Your First SBOM

Let's start with a simple example - the nginx image:

```bash
# Generate SBOM in table format (human-readable)
./generate-sbom.sh nginx:latest table

# Generate SBOM in SPDX JSON format (industry standard)
./generate-sbom.sh nginx:latest spdx-json

# Generate SBOM in CycloneDX format (OWASP standard)
./generate-sbom.sh nginx:latest cyclonedx-json
```

**What you'll see:**
- Complete list of packages in the image
- Version numbers for each package
- Package type (deb, apk, npm, etc.)
- File locations

**Example Output (table format):**
```
NAME                    VERSION      TYPE 
adduser                 3.118        deb       
apt                     2.2.4        deb       
base-files              11.1+deb11u9 deb       
libc6                   2.31-13      deb
nginx                   1.21.6       deb
openssl                 1.1.1n       deb
...
```

### Part 3: Understand SBOM Formats

We've generated SBOMs in three formats. Let's understand when to use each:

```bash
# View SPDX SBOM (industry standard, regulatory compliance)
cat output/nginx-latest-spdx.json | jq '.packages[] | {name: .name, version: .versionInfo}'

# View CycloneDX SBOM (OWASP standard, security-focused)
cat output/nginx-latest-cyclonedx.json | jq '.components[] | {name: .name, version: .version}'
```

**Format Comparison:**

| Format | Best For | Key Features |
|--------|----------|--------------|
| **SPDX** | Legal compliance, licensing | ISO standard, comprehensive metadata |
| **CycloneDX** | Security analysis | Vulnerability data, dependency graphs |
| **Syft JSON** | Automation, tooling | Native format, fastest processing |

### Part 4: Scan for Vulnerabilities

Now that we have an SBOM, let's scan it for known vulnerabilities:

```bash
# Scan using the SBOM directly
./scan-sbom.sh output/nginx-latest-spdx.json

# Or scan the image directly (Grype generates SBOM internally)
grype nginx:latest

# Filter by severity
grype nginx:latest --fail-on high
```

**Understanding the Output:**

```
NAME        INSTALLED  FIXED-IN  TYPE  VULNERABILITY  SEVERITY 
openssl     1.1.1n     1.1.1t    deb   CVE-2023-0464  High      
libssl1.1   1.1.1n     1.1.1t    deb   CVE-2023-0464  High      
nginx       1.21.6     1.22.1    deb   CVE-2022-41741 Medium
```

**Key columns:**
- **NAME**: Vulnerable package
- **INSTALLED**: Current version in your image
- **FIXED-IN**: Version that patches the vulnerability
- **VULNERABILITY**: CVE identifier
- **SEVERITY**: Risk level (Critical, High, Medium, Low)

### Part 5: Build and Scan a Custom Application

Let's build a sample application and scan it:

```bash
# Build the sample Node.js application
./build-sample-app.sh

# Generate SBOM for our custom app
syft myapp:latest -o spdx-json > output/myapp-sbom.json

# Scan for vulnerabilities
grype sbom:./output/myapp-sbom.json --fail-on critical

# View detailed report
grype sbom:./output/myapp-sbom.json -o json | jq
```

### Part 6: Compare SBOMs Across Versions

One of the most powerful uses of SBOMs is tracking changes:

```bash
# Generate SBOMs for different versions
syft nginx:1.21 -o json > output/nginx-1.21-sbom.json
syft nginx:1.22 -o json > output/nginx-1.22-sbom.json

# Compare them
./compare-sboms.sh output/nginx-1.21-sbom.json output/nginx-1.22-sbom.json
```

**This shows you:**
- ✅ New packages added
- ⬆️ Packages updated (with version changes)
- ❌ Packages removed
- 🔴 New vulnerabilities introduced
- ✅ Vulnerabilities fixed

**Example comparison output:**
```
=== SBOM Comparison Report ===

📦 Packages Added (3):
  + libfoo-1.2.3
  + libbar-2.0.1
  + libnew-0.5.0

⬆️ Packages Updated (5):
  ~ openssl: 1.1.1n → 1.1.1t (FIXES CVE-2023-0464)
  ~ nginx: 1.21.6 → 1.22.1
  ~ libc6: 2.31-13 → 2.31-15

❌ Packages Removed (1):
  - libold-1.0.0

🔴 New Vulnerabilities: 0
✅ Vulnerabilities Fixed: 2
```

### Part 7: Sign and Verify SBOMs

SBOMs are critical security artifacts - they should be signed to prevent tampering:

```bash
# Generate and sign SBOM in one step
./sign-sbom.sh myapp:latest

# This creates:
# - myapp-sbom.json (the SBOM)
# - myapp-sbom.json.sig (the signature)
```

**Verify SBOM integrity:**
```bash
./verify-sbom.sh myapp-sbom.json myapp-sbom.json.sig
```

**Attach SBOM to the container image:**
```bash
# Using Cosign attestations
cosign attest --predicate output/myapp-sbom.json --key cosign.key myapp:latest

# Verify attestation
cosign verify-attestation --key cosign.pub myapp:latest | jq
```

### Part 8: CI/CD Integration

The real power comes from automating SBOM generation in your pipeline.

#### Azure DevOps Pipeline

See `azure-pipelines.yml` for complete example:

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: Docker@2
  displayName: 'Build Container'
  inputs:
    command: build
    Dockerfile: '**/Dockerfile'
    tags: |
      $(Build.BuildId)

- script: |
    # Install Syft and Grype
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
    
    # Generate SBOM
    syft myapp:$(Build.BuildId) -o spdx-json > sbom.json
    
    # Scan for critical/high vulnerabilities
    grype sbom:./sbom.json --fail-on high
    
  displayName: 'Generate SBOM and Security Scan'
  
- task: PublishBuildArtifacts@1
  displayName: 'Publish SBOM Artifact'
  inputs:
    pathToPublish: 'sbom.json'
    artifactName: 'sbom'
```

#### GitHub Actions

See `.github/workflows/sbom-scan.yml`:

```yaml
name: SBOM Generation and Scan

on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build image
        run: docker build -t myapp:latest .
      
      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: myapp:latest
          format: spdx-json
          output-file: sbom.spdx.json
      
      - name: Scan vulnerabilities
        uses: anchore/scan-action@v3
        with:
          sbom: sbom.spdx.json
          fail-build: true
          severity-cutoff: high
          
      - name: Upload SBOM
        uses: actions/upload-artifact@v3
        with:
          name: sbom
          path: sbom.spdx.json
```

## 🎓 Production Best Practices

### 1. SBOM Generation Timing

**✅ DO:**
- Generate SBOM during build (part of CI/CD)
- Store SBOM alongside image in registry
- Version SBOMs with images (same tag)

**❌ DON'T:**
- Generate SBOM only at deployment
- Store SBOMs separately from images
- Skip SBOM for "internal" images

### 2. Vulnerability Management

**✅ DO:**
- Scan SBOMs regularly (daily for production)
- Set severity thresholds (block on Critical/High)
- Track vulnerability trends over time
- Auto-update base images when patches available

**❌ DON'T:**
- Ignore "Low" severity (can be exploited in chains)
- Scan only once at build time
- Allow vulnerable images in production

### 3. SBOM Storage and Access

**✅ DO:**
- Store SBOMs in artifact repository (Artifactory, Nexus)
- Implement RBAC for SBOM access
- Keep SBOMs for all deployed versions
- Enable SBOM search/query across organization

**❌ DON'T:**
- Store SBOMs inside container images
- Make SBOMs publicly accessible
- Delete old SBOMs (needed for forensics)

### 4. Compliance and Auditing

**✅ DO:**
- Generate SBOMs in SPDX format (regulatory compliance)
- Include license information
- Track SBOM generation in audit logs
- Provide SBOMs to customers (if contractual)

**❌ DON'T:**
- Use proprietary SBOM formats only
- Skip license compliance checks
- Modify SBOMs after generation (sign them!)

## 🔧 Real-World Use Cases

### Fortune 500 Pharmaceutical Company Example

**Challenge**: FDA 21 CFR Part 11 compliance requires complete software traceability.

**Solution**:
```bash
# Generate SBOM for drug dosage calculator app
syft pharma-calculator:2.1.0 -o spdx-json > calculator-sbom.json

# Sign SBOM for FDA audit trail
cosign sign-blob --key fda-signing-key.key calculator-sbom.json > calculator-sbom.sig

# Store in validated artifact repository
# Attach to regulatory submission package
```

**Result**: 
- Complete dependency traceability for FDA submissions
- 3-hour vulnerability assessment (previously 3 days)
- Automated compliance reporting

### Incident Response Scenario

**Scenario**: CVE-2024-XXXXX announced in libssl at 9 AM

```bash
# 9:05 AM - Query all SBOMs for affected package
grep -r "libssl.*1.1.1n" sbom-archive/ | cut -d: -f1

# 9:10 AM - List affected production services
./find-vulnerable-services.sh CVE-2024-XXXXX

# 9:15 AM - Emergency patch pipeline triggered
# 10:00 AM - All critical services patched and redeployed
```

**Without SBOMs**: Would take 2-3 days to manually audit all containers.

## 🐛 Troubleshooting

### Issue: "Error: failed to fetch image"

```bash
# Solution: Pull the image first
docker pull nginx:latest
syft nginx:latest
```

### Issue: "permission denied" on macOS

```bash
# Solution: Ensure tools are executable and in PATH
chmod +x /usr/local/bin/syft
chmod +x /usr/local/bin/grype

# Or install via Homebrew
brew install syft grype
```

### Issue: Grype shows too many "Low" vulnerabilities

```bash
# Solution: Filter by severity
grype nginx:latest --fail-on high

# Or create a .grype.yaml config
cat > .grype.yaml <<EOF
fail-on-severity: high
ignore:
  - vulnerability: CVE-2024-XXXXX  # Known false positive
    fix-state: wont-fix
EOF
```

### Issue: SBOM comparison shows no differences but versions changed

```bash
# Check SBOM format is consistent
syft --version
# Ensure same Syft version generated both SBOMs

# Use normalized format
syft nginx:1.21 -o json > v1.json
syft nginx:1.22 -o json > v2.json
./compare-sboms.sh v1.json v2.json
```

## 🧹 Cleanup

```bash
# Remove generated SBOMs and test images
./cleanup.sh

# Manual cleanup
rm -rf output/
docker rmi myapp:latest nginx:latest
```

## 🔗 Additional Resources

### Official Documentation
- [Syft Documentation](https://github.com/anchore/syft)
- [Grype Documentation](https://github.com/anchore/grype)
- [SPDX Specification](https://spdx.dev/)
- [CycloneDX Specification](https://cyclonedx.org/)

### Standards and Guidelines
- [CISA SBOM Resources](https://www.cisa.gov/sbom)
- [NTIA Minimum Elements for SBOM](https://www.ntia.gov/files/ntia/publications/sbom_minimum_elements_report.pdf)
- [Executive Order 14028](https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/)

### Related Labs
- **Lab 03**: Vulnerability Scanning (complements this lab)
- **Lab 04**: Image Signing (used for SBOM verification)
- **Lab 08**: Network Security (container isolation and secure communication) - Coming Soon

## 📝 Summary

You've learned to:
- ✅ Generate SBOMs in multiple industry-standard formats
- ✅ Scan SBOMs for vulnerabilities using Grype
- ✅ Compare SBOMs to track dependency changes
- ✅ Sign and verify SBOMs for integrity
- ✅ Integrate SBOM generation into CI/CD pipelines
- ✅ Implement production-ready SBOM management

**Key Takeaways:**
1. SBOMs are essential for modern software supply chain security
2. Automated SBOM generation in CI/CD is a must-have
3. Regular SBOM scanning detects vulnerabilities before deployment
4. Signed SBOMs provide audit trail and prevent tampering
5. SBOM comparison helps track security posture over time

## 🚀 Next Steps

1. **Implement in your CI/CD**: Add SBOM generation to your pipeline today
2. **Scan existing images**: Generate and scan SBOMs for all production images
3. **Establish baselines**: Document current vulnerability state
4. **Create dashboards**: Visualize SBOM data and vulnerability trends
5. **Move to Lab 08**: Learn Docker network security and container isolation

---

**⭐ Found this lab helpful? Star the repository!**

**🐛 Found an issue? [Open an issue on GitHub](https://github.com/opscart/docker-security-practical-guide/issues)**

**💬 Questions? [Start a discussion](https://github.com/opscart/docker-security-practical-guide/discussions)**