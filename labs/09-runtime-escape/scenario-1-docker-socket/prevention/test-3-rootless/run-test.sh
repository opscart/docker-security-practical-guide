#!/bin/bash

# Test 3: Rootless Docker Prevention
# Tests impact reduction when using rootless Docker

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RESULTS_FILE="test-results.txt"
ARTIFACTS_DIR="./artifacts"

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$RESULTS_FILE"
}

echo -e "${BLUE}"
cat << "EOF"
════════════════════════════════════════════════════
  TEST 3: Rootless Docker Impact Reduction
════════════════════════════════════════════════════
EOF
echo -e "${NC}"

# Initialize
mkdir -p "$ARTIFACTS_DIR"
> "$RESULTS_FILE"

echo -e "${YELLOW}"
cat << "WARNING"
NOTE: This test demonstrates the concept of rootless Docker
      but doesn't actually install it (requires system changes).
      
      Instead, we'll simulate what happens when an escape occurs
      in rootless mode by running tests as a non-root user.

      For actual rootless Docker installation:
      curl -fsSL https://get.docker.com/rootless | sh
WARNING
echo -e "${NC}"

log "Starting rootless Docker simulation test..."

# STEP 1: Show current user context
log "STEP 1: Showing current Docker daemon user context..."
echo ""
echo -e "${YELLOW}Current Docker daemon is running as:${NC}"
docker info 2>/dev/null | grep -A 2 "Server Version" | tee "$ARTIFACTS_DIR/docker-daemon-info.txt"

# STEP 2: Simulate the escape with user restrictions
log "STEP 2: Simulating escape attempt with non-root restrictions..."

cat > "$ARTIFACTS_DIR/comparison.txt" << 'COMPARISON'
Rootless Docker Impact Comparison
==================================

1: Standard Docker (root daemon)
------------------------------------------
When escape succeeds:
✗ Attacker lands as: root
✗ Can read: /etc/shadow, SSH keys, all files
✗ Can write: /etc/passwd, crontabs, system files
✗ Can install: Backdoors, rootkits, malware
✗ Impact: TOTAL SYSTEM COMPROMISE

Example commands that work:
  cat /etc/shadow                  # Works - full access
  echo "backdoor" >> /etc/crontab  # Works - can modify
  useradd -m attacker              # Works - can create users

2: Rootless Docker (non-root daemon)
----------------------------------------------
When escape succeeds:
✓ Attacker lands as: regular user (e.g., 'jenkins')
✓ Can read: Only files owned by that user
✓ Can write: Only to user's home directory
✓ Cannot install: System-wide backdoors
✓ Impact: LIMITED TO USER SCOPE

Example commands that FAIL:
  cat /etc/shadow                  # Permission denied
  echo "backdoor" >> /etc/crontab  # Permission denied
  useradd -m attacker              # Permission denied

Commands that still work:
  cat ~/.ssh/config                # User's own files
  cat ~/.bash_history              # User's history
  ls /home/jenkins                 # User's directory

The attack still succeeds (container escape happens)
but the damage is contained to the user's scope.
COMPARISON

cat "$ARTIFACTS_DIR/comparison.txt"

# STEP 3: Demonstrate permission differences
log "STEP 3: Testing permission differences..."

echo ""
echo -e "${BLUE}Standard Docker (root) - What attacker can do:${NC}"
cat > "$ARTIFACTS_DIR/root-capabilities.txt" << 'ROOT_CAP'
After escape with root Docker:
✓ Read /etc/shadow
✓ Read /root/.ssh/id_rsa
✓ Write to /etc/passwd
✓ Write to /etc/crontab
✓ Create new users
✓ Install packages
✓ Modify system files
✓ Access all containers
✓ Read all container secrets
✓ Install persistent backdoors
ROOT_CAP

cat "$ARTIFACTS_DIR/root-capabilities.txt"

echo ""
echo -e "${BLUE}Rootless Docker (user) - What attacker CANNOT do:${NC}"
cat > "$ARTIFACTS_DIR/rootless-limitations.txt" << 'ROOTLESS_CAP'
After escape with rootless Docker:
✗ Cannot read /etc/shadow (permission denied)
✗ Cannot read /root/.ssh/id_rsa (permission denied)
✗ Cannot write to /etc/passwd (permission denied)
✗ Cannot write to /etc/crontab (permission denied)
✗ Cannot create new users (permission denied)
✗ Cannot install system packages (permission denied)
✗ Cannot modify system files (permission denied)
✗ Limited container access (only user's containers)
✗ Cannot read other users' secrets
✗ Cannot install system-wide backdoors

What attacker CAN still do:
✓ Read user's own SSH keys (~/.ssh/)
✓ Read user's history (~/.bash_history)
✓ Access user's containers
✓ Read environment variables of user's processes
✓ Modify files in user's home directory
ROOTLESS_CAP

cat "$ARTIFACTS_DIR/rootless-limitations.txt"

# Generate summary
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

cat > "$ARTIFACTS_DIR/summary.txt" << SUMMARY
Rootless Docker Test Results
=============================
Date: $(date)

Concept:
Rootless Docker runs the Docker daemon as a non-root user instead of root.
When an escape attack succeeds, the attacker lands as that user, not root.

Impact Comparison:

┌────────────────────────┬─────────────────┬──────────────────────┐
│ Access                 │ Root Docker     │ Rootless Docker      │
├────────────────────────┼─────────────────┼──────────────────────┤
│ System files (/etc/)   │ FULL ACCESS     │ DENIED               │
│ Other users' files     │ FULL ACCESS     │ DENIED               │
│ Install backdoors      │ YES             │ NO (user-level only) │
│ Create users           │ YES             │ NO                   │
│ Read /etc/shadow       │ YES             │ NO                   │
│ User's own files       │ YES             │ YES                  │
│ User's containers      │ YES             │ YES                  │
└────────────────────────┴─────────────────┴──────────────────────┘

Key Finding:
Rootless Docker does NOT prevent the escape attack - the container
can still break out. However, it significantly limits the blast radius
by ensuring the attacker lands as a non-root user.

This is "defense in depth" - the escape succeeds, but the damage
is contained.

Trade-offs:
Pros:
+ Reduces impact of successful escape
+ Limits system-wide compromise
+ No configuration changes to containers needed
+ Transparent to applications

Cons:
- Some Docker features unavailable (privileged containers, cgroups v1)
- Slightly more complex setup
- May have performance implications
- Network port binding <1024 restricted

Recommendation:
Use rootless Docker for:
✓ Development environments
✓ CI/CD runners
✓ Build servers
✓ Any environment where containers might be untrusted

Avoid rootless Docker for:
✗ Production workloads requiring privileged containers
✗ Environments needing full Docker feature compatibility
✗ Systems where cgroups v1 is required

Installation:
  curl -fsSL https://get.docker.com/rootless | sh

Artifacts Generated:
- docker-daemon-info.txt: Current Docker daemon information
- comparison.txt: Side-by-side scenario comparison
- root-capabilities.txt: What root Docker allows
- rootless-limitations.txt: What rootless Docker blocks
- summary.txt: This summary file
SUMMARY

cat "$ARTIFACTS_DIR/summary.txt"

# Correct Interactive Pause for Test 3 (Rootless)
# Test 3 is CONCEPTUAL - no containers are running
# So the manual exploration is about SIMULATING the concepts

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Want to Try Manual Simulation?${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}This was a conceptual demonstration (no containers running).${NC}"
echo -e "${YELLOW}But you can manually simulate the concepts!${NC}"
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ Manual Simulation Commands                      │${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "  ${GREEN}Open a NEW terminal and try these:${NC}"
echo ""
echo -e "  ${YELLOW}1. Simulate ROOT Docker (current):${NC}"
echo -e "     docker run -it --rm ubuntu:22.04 bash"
echo ""
echo -e "     ${BLUE}# Inside container (you'll be root):${NC}"
echo -e "     whoami                 ${GREEN}# Shows: root${NC}"
echo -e "     cat /etc/shadow        ${GREEN}# Works - full access ✓${NC}"
echo -e "     apt-get update         ${GREEN}# Works - can install ✓${NC}"
echo -e "     exit"
echo ""
echo -e "  ${YELLOW}2. Simulate ROOTLESS (non-root user):${NC}"
echo -e "     docker run -it --rm --user 1000:1000 ubuntu:22.04 bash"
echo ""
echo -e "     ${BLUE}# Inside container (you'll be non-root):${NC}"
echo -e "     whoami                 ${GREEN}# Shows: 1000 or 'I have no name!'${NC}"
echo -e "     cat /etc/shadow        ${RED}# Permission denied ✗${NC}"
echo -e "     apt-get update         ${RED}# Permission denied ✗${NC}"
echo -e "     exit"
echo ""
echo -e "  ${YELLOW}3. Compare Side-by-Side:${NC}"
echo -e "     ${BLUE}Open TWO terminals and run both commands${NC}"
echo -e "     ${BLUE}Try the same operations in each${NC}"
echo -e "     ${BLUE}See the permission differences!${NC}"
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ What You Should See                             │${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "  ${GREEN}Root container:${NC}"
echo -e "  ✅ Can read /etc/shadow"
echo -e "  ✅ Can install packages"
echo -e "  ✅ Can create users"
echo ""
echo -e "  ${GREEN}Non-root container:${NC}"
echo -e "  ❌ Cannot read /etc/shadow (permission denied)"
echo -e "  ❌ Cannot install packages (permission denied)"
echo -e "  ❌ Cannot create users (permission denied)"
echo ""
echo -e "  ${BLUE}This demonstrates the rootless concept:${NC}"
echo -e "  Even if escape succeeds, landing as non-root limits damage!"
echo ""
echo -e "${YELLOW}See MANUAL-CONCEPTS.md for detailed simulation guide${NC}"
echo ""
echo -e "${YELLOW}Press ENTER to finish (no cleanup needed - conceptual test)${NC}"
read -r

echo ""
log "Test complete. Results saved to: $ARTIFACTS_DIR/"
echo ""
echo -e "${GREEN}✅ Conceptual demonstration complete!${NC}"
echo -e "${GREEN}Try the manual simulation above to see it yourself.${NC}"
echo ""

echo ""
log "Test complete. Results saved to: $ARTIFACTS_DIR/"
echo ""
echo -e "${YELLOW}Note: This was a conceptual demonstration.${NC}"
echo -e "${YELLOW}To actually install rootless Docker:${NC}"
echo -e "${YELLOW}  curl -fsSL https://get.docker.com/rootless | sh${NC}"
echo ""
