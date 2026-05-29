#!/bin/bash

# Lab 08 - Scenario 2: Multi-Tier Network Segmentation
# Demonstrates production 3-tier architecture with proper network isolation

set -e

# Colors
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

pause() {
    echo ""
    read -p "Press Enter to continue..."
    echo ""
}

# Cleanup function
cleanup() {
    print_info "Cleaning up resources..."
    docker rm -f web app db 2>/dev/null || true
    docker network rm public-net app-net database-net 2>/dev/null || true
    print_success "Cleanup complete"
}

trap cleanup EXIT

print_header "Scenario 2: Multi-Tier Network Segmentation"

cat << EOF
${BLUE}What You'll Learn:${NC}
- Design production 3-tier architecture
- Segment web, application, and database layers
- Control inter-tier communication
- Apply principle of least privilege at network level
- Understand why flat networks are dangerous

${BLUE}Security Principle:${NC}
Network segmentation limits blast radius. If an attacker compromises
the web tier, they cannot directly reach the database tier. This forces
them through application controls and logging.

${BLUE}Real-World Context:${NC}
In 2020, a Fortune 500 company suffered a breach where attackers
compromised a web server. Because all containers were on one network,
they pivoted directly to the database and exfiltrated customer data.
Proper segmentation would have stopped this lateral movement.

EOF

pause

# Step 1: Architecture Overview
print_header "Step 1: Three-Tier Architecture Design"

cat << EOF
${BLUE}Traditional Architecture:${NC}

┌─────────────────────────────────────────────┐
│         All containers on one network        │
│  [Web] ←→ [App] ←→ [DB]                     │
│  Problem: Web can directly access DB         │
└─────────────────────────────────────────────┘

${GREEN}Segmented Architecture:${NC}

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Public Net  │     │   App Net    │     │ Database Net │
│              │     │              │     │              │
│    [Web]     │←───→│    [App]     │←───→│    [DB]      │
│              │     │              │     │              │
│ Exposed to   │     │ Internal     │     │ Internal     │
│ Internet     │     │ Only         │     │ Only         │
└──────────────┘     └──────────────┘     └──────────────┘

${BLUE}Key Points:${NC}
- Web tier: Only tier exposed to internet (port 80)
- App tier: Connected to web and database networks
- Database tier: No direct internet or web access
- App acts as secure gateway between tiers

EOF

pause

# Step 2: Create three networks
print_header "Step 2: Creating Three-Tier Networks"

print_info "Creating public-net (web tier)..."
docker network create public-net

print_info "Creating app-net (application tier)..."
docker network create app-net

print_info "Creating database-net (database tier)..."
docker network create database-net

print_success "All three networks created"

echo ""
print_info "Network configuration:"
docker network ls | grep -E "public-net|app-net|database-net"

pause

# Step 3: Deploy database (most secure tier)
print_header "Step 3: Deploying Database (Most Secure Tier)"

print_info "Starting PostgreSQL on database-net ONLY..."

docker run -d --name db \
    --network database-net \
    -e POSTGRES_PASSWORD=secret \
    -e POSTGRES_DB=appdb \
    postgres:15-alpine

print_success "Database deployed"

echo ""
print_info "Database network configuration:"
echo "  Container: db"
echo "  Network: database-net only"
echo "  IP: $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' db)"
echo "  Exposed ports: NONE (internal only)"

echo ""
print_warning "Security: Database has NO external access"
print_info "Cannot be reached from internet or host network"

pause

# Step 4: Deploy application tier
print_header "Step 4: Deploying Application Tier (Gateway)"

print_info "Building simple API application..."

# Create temporary app directory
mkdir -p /tmp/lab08-app
cat > /tmp/lab08-app/app.py << 'APPEOF'
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'tier': 'application'})

@app.route('/api/data')
def get_data():
    # In production, this would query the database
    db_host = os.environ.get('DB_HOST', 'db')
    return jsonify({
        'message': 'Data from database',
        'database': f'{db_host}:5432',
        'tier': 'application'
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
APPEOF

cat > /tmp/lab08-app/requirements.txt << 'REQEOF'
flask==3.0.0
REQEOF

cat > /tmp/lab08-app/Dockerfile << 'DOCKERFILE'
FROM python:3.11.9-alpine3.20
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
EXPOSE 5000
CMD ["python", "app.py"]
DOCKERFILE

print_info "Building application image..."
docker build -t lab08-api:latest /tmp/lab08-app > /dev/null 2>&1

print_info "Starting application tier..."
docker run -d --name app \
    --network app-net \
    -e DB_HOST=db \
    lab08-api:latest

print_success "Application deployed on app-net"

# Connect app to database network
print_info "Connecting app to database-net (so it can reach db)..."
docker network connect database-net app

print_success "Application now connected to TWO networks"

echo ""
print_info "Application network configuration:"
echo "  Container: app"
echo "  Networks:"
echo "    - app-net: $(docker inspect -f '{{(index .NetworkSettings.Networks "app-net").IPAddress}}' app)"
echo "    - database-net: $(docker inspect -f '{{(index .NetworkSettings.Networks "database-net").IPAddress}}' app)"
echo "  Can reach: web tier (app-net) AND database (database-net)"

pause

# Step 5: Deploy web tier
print_header "Step 5: Deploying Web Tier (Public-Facing)"

print_info "Starting nginx web server on public-net..."

docker run -d --name web \
    --network public-net \
    -p 8080:80 \
    nginx:alpine

print_success "Web tier deployed"

print_info "Connecting web to app-net (so it can reach app)..."
docker network connect app-net web

print_success "Web tier connected to app-net"

echo ""
print_info "Web tier network configuration:"
echo "  Container: web"
echo "  Networks:"
echo "    - public-net: $(docker inspect -f '{{(index .NetworkSettings.Networks "public-net").IPAddress}}' web)"
echo "    - app-net: $(docker inspect -f '{{(index .NetworkSettings.Networks "app-net").IPAddress}}' web)"
echo "  Exposed: Port 8080 → 80 (accessible from host)"
echo "  Can reach: app tier (app-net)"
echo "  Cannot reach: database tier (not connected)"

pause

# Step 6: Verify segmentation
print_header "Step 6: Verifying Network Segmentation"

print_info "Testing connectivity paths..."
echo ""

# Test 1: Web can reach App
print_info "Test 1: Can web tier reach app tier?"
if docker exec web nc -zv app 5000 2>&1 | grep -q "open"; then
    print_success "✓ Web → App: SUCCESS (expected)"
else
    print_warning "✗ Web → App: FAILED (unexpected)"
fi

# Test 2: Web cannot reach DB
print_info "Test 2: Can web tier reach database?"
if docker exec web nc -zv db 5432 2>&1 | grep -q "Connection refused\|bad address"; then
    print_success "✓ Web → DB: BLOCKED (expected, secure!)"
else
    print_warning "✗ Web → DB: CONNECTED (security issue!)"
fi

# Test 3: App can reach DB
print_info "Test 3: Can app tier reach database?"
if docker exec app nc -zv db 5432 2>&1 | grep -q "open"; then
    print_success "✓ App → DB: SUCCESS (expected)"
else
    print_warning "✗ App → DB: FAILED (unexpected)"
fi

echo ""
print_success "Network segmentation verified!"

pause

# Step 7: Demonstrate attack scenario
print_header "Step 7: Attack Scenario - Why This Matters"

cat << EOF
${RED}Hypothetical Attack Scenario:${NC}

${YELLOW}Without Segmentation:${NC}
1. Attacker compromises web server (SQL injection, RCE, etc.)
2. Attacker runs: docker exec web psql -h db -U postgres
3. Attacker directly accesses database
4. Game over - full data breach

${GREEN}With Segmentation (our setup):${NC}
1. Attacker compromises web server
2. Attacker tries: docker exec web psql -h db -U postgres
3. ${RED}BLOCKED${NC} - web cannot reach database network
4. Attacker must go through app tier (logged, monitored, rate-limited)
5. Defense in depth provides multiple opportunities to detect attack

EOF

print_info "Let's demonstrate what an attacker would see..."
echo ""

print_info "Simulating attacker trying to reach database from compromised web server:"
echo ""
echo "$ docker exec web nc -zv db 5432"
docker exec web nc -zv db 5432 2>&1 || print_success "Connection blocked by network segmentation!"

pause

# Step 8: Production best practices
print_header "Step 8: Production Best Practices"

cat << EOF
${GREEN}Network Architecture Patterns:${NC}

${BLUE}1. Minimize Multi-Network Containers${NC}
   Current setup:
   - Web: 2 networks (public-net, app-net)
   - App: 2 networks (app-net, database-net) ← Only gateway
   - DB: 1 network (database-net) ← Most secure
   
   Rule: Only middleware/gateways span networks

${BLUE}2. Use Internal Networks for Databases${NC}
   Next scenario will show internal networks
   - No external gateway at all
   - Even more secure than our current setup

${BLUE}3. Apply Firewall Rules${NC}
   Network segmentation + iptables rules
   - Restrict source IPs
   - Allow only specific ports
   - Log all database connections

${BLUE}4. Monitor Cross-Network Traffic${NC}
   - Log all connections between tiers
   - Alert on unexpected communication patterns
   - Use network policies in Kubernetes

${BLUE}5. Regular Security Audits${NC}
   docker network inspect <network>
   docker inspect <container> | grep Networks
   
   Verify:
   - No unexpected network connections
   - Database not on public networks
   - Web tier minimally connected

${YELLOW}Common Mistakes:${NC}
- Putting everything on default bridge (no segmentation)
- Exposing database ports to host (-p 5432:5432)
- Connecting web directly to database network
- Not documenting network architecture
- Testing in production first

EOF

pause

print_header "Scenario 2 Complete!"

cat << EOF
${GREEN}What you learned:${NC}
✓ Designed 3-tier production architecture
✓ Created segmented networks for each tier
✓ Verified isolation between tiers
✓ Understood attack scenarios and mitigations
✓ Applied principle of least privilege at network level

${BLUE}Network Architecture Summary:${NC}

public-net (exposed):
  └─ web (nginx on port 8080)

app-net (internal):
  ├─ web (can reach app)
  └─ app (gateway)

database-net (most secure):
  ├─ app (gateway)
  └─ db (completely isolated)

${BLUE}Security Benefits:${NC}
- Web compromise ≠ database access
- Multiple layers of defense
- Reduced attack surface
- Clear security boundaries
- Easy to audit and monitor

${BLUE}Next Steps:${NC}
- Run Scenario 3: Internal Networks (even more secure!)
- See how to make databases completely unreachable
- Learn when to use internal vs regular networks

EOF

print_info "Cleaning up will happen automatically on exit..."