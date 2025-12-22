# Lab 09 Testing Guide - Docker Socket Escape

# Lab 09 Testing Guide - Docker Socket Escape

## ⚠️ STOP HERE If Following an Article

**Minimal Path (Recommended for Article Readers):**

If you are following the associated article, stop after completing:
1. ✅ `./setup.sh` 
2. ✅ `cd scenario-1-docker-socket`
3. ✅ `./exploit.sh`

**That's it!** You've completed the docker socket escape demonstration.

The additional testing steps below are for:
- Lab maintainers validating changes
- Advanced users exploring manual execution
- Article authors preparing content

---

## 🎯 Quick Start Testing (5 minutes)

This guide helps you test Lab 09 locally before publishing the article.

### Prerequisites Check

```bash
# Verify Docker is running
docker --version
docker ps

# Should see Docker version and no errors
```

### Option 1: Quick Automated Test (Recommended)

```bash
# 1. Navigate to lab directory
cd docker-security-practical-guide/labs/09-runtime-escape

# 2. Run setup
./setup.sh

# 3. Test Scenario 1 (Docker Socket Escape)
cd scenario-1-docker-socket
./exploit.sh

# When prompted, type 'y' to continue

# 4. Observe the output - should show:
#    ✓ Container created
#    ✓ Docker CLI installed
#    ✓ Host access achieved
#    ✓ Artifacts generated

# 5. Cleanup
./cleanup.sh
cd ../..
./cleanup.sh
```

**Expected Time:** 3-5 minutes

### Option 2: Manual Testing (Learning Path)

```bash
# 1. Navigate to lab
cd docker-security-practical-guide/labs/09-runtime-escape/scenario-1-docker-socket

# 2. Open manual steps
cat manual-steps.md

# 3. Follow steps 1-10 manually
# Copy and paste each command
# Observe the outputs

# 4. Cleanup when done
./cleanup.sh
```

**Expected Time:** 20-25 minutes

---

## 📋 Test Checklist

Use this to verify everything works:

### Setup Phase
- [ ] `./setup.sh` runs without errors
- [ ] Ubuntu image downloads successfully
- [ ] Artifact directories created
- [ ] Scripts are executable

### Exploit Phase (Automated)
- [ ] `./exploit.sh` runs with user confirmation
- [ ] Vulnerable container created
- [ ] Docker CLI installs in container
- [ ] Host containers are listed from within container
- [ ] Escape container created successfully
- [ ] Host access demonstrated (hostname, ps, etc.)
- [ ] Proof file created on host
- [ ] Artifacts generated in ./artifacts/

### Exploit Phase (Manual)
- [ ] Can create vulnerable container
- [ ] Can access container with `docker exec`
- [ ] Can install docker inside container
- [ ] Can run `docker ps` from inside container
- [ ] Can create privileged escape container
- [ ] Can execute `chroot /host bash`
- [ ] Can read `/etc/shadow` on host
- [ ] Can create proof file on real host filesystem

### Cleanup Phase
- [ ] `./cleanup.sh` removes all containers
- [ ] No lab containers remain (`docker ps -a`)
- [ ] Proof files removed
- [ ] Option to keep/remove artifacts

---

## 🔍 What to Look For

### Success Indicators

**When running exploit.sh, you should see:**
```
[+] STEP 1: Creating vulnerable container with docker.sock mounted
[+] Container created: vulnerable-container
[+] STEP 2: Installing Docker CLI inside compromised container
[+] Docker CLI installed successfully
[+] STEP 3: Verifying Docker socket access from container
[+] Docker socket access confirmed
[+] STEP 4: Gathering host system information
[+] Host reconnaissance complete
[+] STEP 5: Creating privileged escape container
[+] Escape container created: escape-container
[!] ═══════════════════════════════════════════════════
[!]   CRITICAL: Now have ROOT access to HOST machine
[!] ═══════════════════════════════════════════════════
[*] Host hostname: <YOUR_HOST_NAME>
```

### Artifacts Generated

After running exploit.sh, check `scenario-1-docker-socket/artifacts/`:
```bash
ls -la scenario-1-docker-socket/artifacts/

# Should contain:
# - exploit.log              (full attack transcript)
# - host_docker_info.txt     (docker info from host)
# - host_containers.txt      (list of host containers)
# - docker_events.log        (docker events during attack)
# - iocs.json                (indicators of compromise)
```

---

## 🐛 Troubleshooting

### Issue: "Docker is not installed"
```bash
# Install Docker Desktop or Docker Engine
# Mac: brew install --cask docker
# Linux: sudo apt-get install docker.io
```

### Issue: "Cannot connect to Docker daemon"
```bash
# Start Docker
# Mac: Open Docker Desktop app
# Linux: sudo systemctl start docker

# Verify
docker ps
```

### Issue: "Permission denied: /var/run/docker.sock"
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and log back in
# Or use sudo:
sudo docker ps
```

### Issue: "exploit.sh: Permission denied"
```bash
# Make scripts executable
chmod +x exploit.sh
chmod +x cleanup.sh
```

### Issue: "Container already exists"
```bash
# Clean up first
./cleanup.sh

# Or manually
docker rm -f vulnerable-container escape-container
```

### Issue: Script hangs at "apt-get update"
```bash
# Network issue - wait a bit or:
docker exec vulnerable-container pkill apt-get

# Then re-run or continue manually
```

---

## 📊 Testing on Different Platforms

### macOS (Docker Desktop)

✅ **Fully Supported**

```bash
# Works perfectly on Mac
# Docker runs in VM but exploit still works
# Host in this context = Docker Desktop VM
```

**Note:** When you escape to "host", you're in the Docker Desktop VM, not your Mac. This is still a complete escape from container perspective.

### Linux (Native Docker)

✅ **Fully Supported**

```bash
# This is the "purest" test environment
# Direct container to actual host escape
# Most realistic scenario
```

### Windows (WSL2 + Docker Desktop)

✅ **Supported**

```bash
# Run from WSL2 terminal
# Docker commands work identically
# Escape is to Docker Desktop VM (like Mac)
```

**Note:** Some output may look slightly different but functionality is identical.

---

## 🎬 Screenshot Opportunities

For your article, capture screenshots at these moments:

1. **Before exploit:** `docker ps` showing normal containers
2. **During exploit:** Output showing docker commands from inside container
3. **Escape success:** Hostname change and `ps aux` showing host processes
4. **Proof file:** `cat /root/PWNED_PROOF.txt` on actual host
5. **Artifacts:** `ls artifacts/` showing generated files
6. **Cleanup:** `docker ps -a` showing no lab containers

---

## 📝 Documentation Tips

While testing, document:

### For Your Article:
- [ ] Command outputs (copy/paste into article)
- [ ] Error messages encountered (troubleshooting section)
- [ ] Time taken for each step
- [ ] Platform-specific notes
- [ ] Real-world examples you thought of

### For GitHub README:
- [ ] Any bugs found
- [ ] Additional safety warnings needed
- [ ] Improvements to scripts
- [ ] Better explanations needed

---

## ⏱️ Time Tracking

Track how long each part takes:

| Phase | Expected | Actual | Notes |
|-------|----------|--------|-------|
| Setup | 2 min | ____ | |
| Scenario 1 Auto | 5 min | ____ | |
| Scenario 1 Manual | 25 min | ____ | |
| Cleanup | 1 min | ____ | |

---

## ✅ Final Validation

Before publishing, confirm:

- [ ] All scripts run without errors
- [ ] All safety warnings are clear
- [ ] Cleanup removes everything
- [ ] Documentation is accurate
- [ ] Time estimates are realistic
- [ ] Prerequisites are listed
- [ ] Troubleshooting covers common issues
- [ ] Tested on your actual platform

---

## 🚀 Ready to Publish?

Once all tests pass:

1. ✅ Move lab to your repo: `labs/09-runtime-escape/`
2. ✅ Update main README to include Lab 09
3. ✅ Write article with real outputs from your tests
4. ✅ Include screenshots from your testing session
5. ✅ Link to GitHub repo in article
6. ✅ Mention testing platform in article

---

## 💡 Article Content Suggestions

Based on testing, your article should include:

### Introduction (from testing)
- Actual time it took you
- Real containers you found during escape
- Actual hostname change you observed

### Technical Details (from artifacts)
- Real docker events logs
- Actual IOCs generated
- Real system information gathered

### Screenshots (from your session)
- Before/during/after states
- Actual proof files
- Real artifacts generated

### Troubleshooting (from your experience)
- Issues you encountered
- How you solved them
- Platform-specific notes

---

## 📧 Need Help?

If you encounter issues during testing:

1. Check the troubleshooting section above
2. Verify Docker is running: `docker ps`
3. Check script permissions: `ls -la *.sh`
4. Try manual steps to isolate issue
5. Check Docker logs: `docker logs vulnerable-container`

---

**Happy Testing! 🎯**

Remember: Test everything thoroughly before publishing. Your readers will appreciate the accuracy!