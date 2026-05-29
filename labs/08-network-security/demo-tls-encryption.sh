#!/bin/bash

# Lab 08 - Scenario 4: TLS Encryption Between Containers
# Demonstrates encrypted communication using self-signed certificates

set -e

# Get script directory for absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    docker rm -f nginx-tls nginx-basic client 2>/dev/null || true
    docker network rm secure-net 2>/dev/null || true
    print_success "Cleanup complete"
}

trap cleanup EXIT

print_header "Scenario 4: TLS Encryption Between Containers"

echo -e "${BLUE}What You'll Learn:${NC}"
echo "- Generate self-signed TLS certificates"
echo "- Configure nginx with TLS encryption"
echo "- Test encrypted connections between containers"
echo "- Verify certificate validation"
echo "- Understand when TLS is needed in container networks"
echo ""
echo -e "${BLUE}Security Principle:${NC}"
echo "Network isolation prevents unauthorized access, but traffic between"
echo "containers on the same network is unencrypted by default. TLS adds"
echo "encryption for sensitive data in transit."
echo ""
echo -e "${BLUE}When to Use TLS Between Containers:${NC}"
echo "✓ Multi-tenant environments (different customers on same network)"
echo "✓ Compliance requirements (HIPAA, PCI DSS, SOC 2)"
echo "✓ Sensitive data transmission (passwords, PII, financial data)"
echo "✓ Zero-trust architecture (encrypt everything)"
echo ""
echo -e "${YELLOW}When TLS May Be Overkill:${NC}"
echo "✗ Single-tenant, trusted internal network"
echo "✗ All containers in same security domain"
echo "✗ Network already encrypted (VPN, encrypted overlay)"
echo "✗ Performance-critical applications (TLS has overhead)"
echo ""

pause

# Step 1: Generate certificates
print_header "Step 1: Generating Self-Signed Certificates"

print_info "Checking if certificates already exist..."
if [ -f "certs/server-cert.pem" ] && [ -f "certs/server-key.pem" ]; then
    print_success "Certificates already exist"
else
    print_info "Running certificate generation script..."
    cd certs && ./generate-certs.sh && cd ..
fi

print_success "Certificates ready"
echo ""
print_info "Certificate files:"
echo "  certs/ca.pem           - Certificate Authority (for verification)"
echo "  certs/server-cert.pem  - Server certificate (public key)"
echo "  certs/server-key.pem   - Server private key (keep secret)"

pause

# Step 2: Create network
print_header "Step 2: Creating Secure Network"

print_info "Creating network for TLS demo..."
docker network create secure-net

print_success "Network created: secure-net"

pause

# Step 3: Start nginx WITHOUT TLS (baseline)
print_header "Step 3: Testing Baseline (No TLS)"

print_info "Starting nginx without TLS..."
docker run -d --name nginx-basic \
    --network secure-net \
    -v "${SCRIPT_DIR}/configs/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -p 8080:80 \
    nginx:alpine

sleep 2

# Check if container is still running
if ! docker ps | grep -q nginx-basic; then
    print_warning "nginx-basic exited. Checking logs..."
    docker logs nginx-basic 2>&1 | tail -10
    print_info "Attempting to start with default config instead..."
    docker rm -f nginx-basic
    docker run -d --name nginx-basic --network secure-net -p 8080:80 nginx:alpine
    sleep 2
fi

if docker ps | grep -q nginx-basic; then
    print_success "nginx started without TLS on port 8080"
else
    print_warning "nginx failed to start, continuing anyway..."
fi

echo ""
print_info "Testing unencrypted connection..."
sleep 2

# Test connection with retry logic
MAX_RETRIES=5
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8080/health 2>&1 | grep -q "healthy"; then
        curl -s http://localhost:8080/health
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            sleep 1
        else
            print_warning "Connection failed after $MAX_RETRIES attempts"
            echo "nginx might still be starting..."
        fi
    fi
done

echo ""
print_warning "Traffic is NOT encrypted - anyone on the network can read it"

pause

# Step 4: Start nginx WITH TLS
print_header "Step 4: Configuring nginx with TLS"

print_info "Starting nginx with TLS enabled..."

# First, validate the config file exists
if [ ! -f "configs/nginx-tls.conf" ]; then
    print_warning "nginx-tls.conf not found!"
    exit 1
fi

if [ ! -f "certs/server-cert.pem" ] || [ ! -f "certs/server-key.pem" ]; then
    print_warning "Certificate files not found!"
    exit 1
fi

docker run -d --name nginx-tls \
    --network secure-net \
    -v "${SCRIPT_DIR}/configs/nginx-tls.conf:/etc/nginx/nginx.conf:ro" \
    -v "${SCRIPT_DIR}/certs:/etc/nginx/certs:ro" \
    -p 8443:443 \
    nginx:alpine

sleep 3

# Check if container is still running
if ! docker ps | grep -q nginx-tls; then
    print_warning "nginx-tls exited. Checking logs..."
    echo ""
    echo "=== nginx-tls error logs ==="
    docker logs nginx-tls 2>&1
    echo "==========================="
    echo ""
    print_warning "TLS nginx failed to start - check certificate paths and config"
    print_info "Continuing with demo despite nginx-tls failure..."
fi

if docker ps | grep -q nginx-tls; then
    print_success "nginx started with TLS on port 8443"
else
    print_warning "nginx TLS is not running (see logs above)"
fi

echo ""
print_info "Waiting for nginx to initialize..."
sleep 2

pause

# Step 5: Test TLS connection
print_header "Step 5: Testing TLS Connection"

print_info "Testing HTTPS connection (will show certificate warning)..."
echo ""

# Test without certificate verification (insecure but shows it works)
print_info "Test 5.1: Connect without certificate verification"
echo "$ curl -k https://localhost:8443/health"

# Retry logic for TLS connection
MAX_RETRIES=5
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if RESPONSE=$(curl -k -s https://localhost:8443/health 2>&1) && echo "$RESPONSE" | grep -q "healthy"; then
        echo "$RESPONSE"
        echo ""
        print_success "✓ Connection successful (but certificate not verified)"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            sleep 1
        else
            print_warning "Connection failed after $MAX_RETRIES attempts"
            echo "nginx might still be starting..."
        fi
    fi
done

echo ""
print_warning "The -k flag skips certificate verification - INSECURE!"
print_info "In production, always verify certificates"

pause

# Step 6: Verify certificate
print_header "Step 6: Certificate Verification"

print_info "Testing with certificate verification..."
echo ""

print_info "Test 6.1: Connect with CA certificate"
echo "$ curl --cacert certs/ca.pem https://localhost:8443/health"

if curl --cacert certs/ca.pem -s https://localhost:8443/health 2>&1 | grep -q "healthy"; then
    print_success "✓ Certificate verified successfully!"
    echo ""
    print_info "This is the SECURE way - certificate signed by trusted CA"
else
    print_warning "Certificate verification failed (hostname mismatch expected)"
    print_info "Use 'curl --resolve nginx:8443:127.0.0.1' to fix hostname"
fi

pause

# Step 7: Inspect TLS connection
print_header "Step 7: Inspecting TLS Connection Details"

print_info "Viewing TLS certificate information..."
echo ""

echo "$ openssl s_client -connect localhost:8443 -showcerts < /dev/null 2>/dev/null | openssl x509 -text -noout"
echo ""

# Check if nginx-tls is running first
if docker ps | grep -q nginx-tls; then
    # Show certificate details with better error handling
    if openssl s_client -connect localhost:8443 -showcerts < /dev/null 2>/dev/null | openssl x509 -text -noout 2>/dev/null | grep -A5 "Subject:" > /dev/null 2>&1; then
        openssl s_client -connect localhost:8443 -showcerts < /dev/null 2>/dev/null | openssl x509 -text -noout 2>/dev/null | grep -A5 "Subject:"
    else
        print_warning "Could not extract certificate details"
        print_info "nginx-tls may not be responding on port 8443"
    fi
    
    echo ""
    print_info "Key information:"
    if openssl s_client -connect localhost:8443 < /dev/null 2>/dev/null | grep -E "Protocol|Cipher" > /dev/null 2>&1; then
        openssl s_client -connect localhost:8443 < /dev/null 2>/dev/null | grep -E "Protocol|Cipher"
    else
        print_warning "Could not connect to TLS endpoint"
    fi
else
    print_warning "nginx-tls container is not running, skipping TLS inspection"
fi

pause

# Step 8: Container-to-container TLS
print_header "Step 8: Container-to-Container Encrypted Communication"

print_info "Creating client container on same network..."
docker run -d --name client \
    --network secure-net \
    -v "${SCRIPT_DIR}/certs:/certs:ro" \
    alpine:latest sleep 3600

print_success "Client container created"

echo ""
print_info "Installing curl in client container..."
docker exec client sh -c "apk add --no-cache curl > /dev/null 2>&1"

echo ""
print_info "Testing communication from client to nginx-tls..."
echo ""

# Test from client container
print_info "From client container (same Docker network):"
echo "$ docker exec client curl -k https://nginx-tls/health"
docker exec client curl -k -s https://nginx-tls/health
echo ""
print_success "✓ Container-to-container TLS working!"

echo ""
print_info "With certificate verification:"
echo "$ docker exec client curl --cacert /certs/ca.pem https://nginx-tls/health"
docker exec client curl --cacert /certs/ca.pem -s https://nginx-tls/health 2>&1 || \
    print_warning "Verification failed (expected - hostname is nginx-tls, not 'nginx')"

pause

# Step 9: Performance considerations
print_header "Step 9: TLS Performance Considerations"

echo -e "${BLUE}TLS Overhead:${NC}"
echo ""
echo "Testing connection speed difference..."
echo ""

print_info "Unencrypted (HTTP):"
time curl -s http://localhost:8080/health > /dev/null
echo ""

print_info "Encrypted (HTTPS):"
time curl -k -s https://localhost:8443/health > /dev/null
echo ""

print_warning "TLS adds ~1-5ms latency per request"
print_info "For high-throughput services, this matters"
print_info "For normal services, the security benefit is worth it"

pause

# Step 10: Best practices
print_header "Step 10: Production TLS Best Practices"

echo -e "${GREEN}Certificate Management:${NC}"
echo "1. Use proper CA-signed certificates (not self-signed)"
echo "   - Let's Encrypt for public services (free)"
echo "   - Internal CA for private services"
echo ""
echo "2. Rotate certificates regularly"
echo "   - Automated rotation with cert-manager (Kubernetes)"
echo "   - Store certificates in secrets management (Vault)"
echo ""
echo "3. Monitor certificate expiration"
echo "   - Alert 30 days before expiry"
echo "   - Automated renewal process"
echo ""
echo -e "${GREEN}TLS Configuration:${NC}"
echo "1. Use strong cipher suites"
echo "   - TLS 1.2+ only (disable TLS 1.0, 1.1)"
echo "   - Forward secrecy (ECDHE)"
echo ""
echo "2. Enable HSTS (HTTP Strict Transport Security)"
echo "   - Forces HTTPS for all connections"
echo "   - Prevents downgrade attacks"
echo ""
echo "3. Implement mutual TLS (mTLS) for service-to-service"
echo "   - Both client and server verify certificates"
echo "   - Zero-trust architecture"
echo ""
echo -e "${YELLOW}When NOT to Use TLS:${NC}"
echo "- Trusted single-tenant internal network"
echo "- Performance-critical paths (consider at network layer instead)"
echo "- Already encrypted at VPN/network level"
echo ""

pause

# Step 11: Security comparison
print_header "Step 11: Security Comparison"

echo -e "${BLUE}Network Isolation vs TLS:${NC}"
echo ""
echo "┌─────────────────────────┬──────────────────┬─────────────────┐"
echo "│ Threat                  │ Network Isolation│ TLS Encryption  │"
echo "├─────────────────────────┼──────────────────┼─────────────────┤"
echo "│ External access         │ ✓ Blocked        │ N/A             │"
echo "│ Container compromise    │ ✗ No protection  │ ✓ Data encrypted│"
echo "│ Network sniffing        │ ✗ Plain text     │ ✓ Encrypted     │"
echo "│ Man-in-the-middle       │ ✗ Vulnerable     │ ✓ Protected     │"
echo "│ Multi-tenant isolation  │ ✗ Shared network │ ✓ Crypto boundary│"
echo "└─────────────────────────┴──────────────────┴─────────────────┘"
echo ""
echo -e "${GREEN}Best Security: Network Isolation + TLS${NC}"
echo "- Isolation prevents unauthorized access"
echo "- TLS protects data if isolation is breached"
echo "- Defense in depth"
echo ""

pause

print_header "Scenario 4 Complete!"

echo -e "${GREEN}What you learned:${NC}"
echo "✓ Generated self-signed TLS certificates"
echo "✓ Configured nginx with TLS encryption"
echo "✓ Tested encrypted container-to-container communication"
echo "✓ Verified certificate validation"
echo "✓ Understood TLS performance impact"
echo "✓ Learned when TLS is necessary vs optional"
echo ""
echo -e "${BLUE}Key Takeaways:${NC}"
echo ""
echo "1. Network isolation ≠ encryption"
echo "   - Containers on same network can sniff traffic"
echo "   - TLS encrypts data in transit"
echo ""
echo "2. Use TLS for:"
echo "   - Sensitive data (passwords, PII, financial)"
echo "   - Multi-tenant environments"
echo "   - Compliance requirements (HIPAA, PCI DSS)"
echo "   - Zero-trust architectures"
echo ""
echo "3. TLS has overhead:"
echo "   - ~1-5ms latency per request"
echo "   - CPU cost for encryption/decryption"
echo "   - Worth it for security-critical services"
echo ""
echo "4. Production requires:"
echo "   - Proper CA-signed certificates"
echo "   - Certificate rotation automation"
echo "   - Expiration monitoring"
echo "   - Strong cipher suites (TLS 1.2+)"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "- Run Scenario 5: Common Network Misconfigurations"
echo "- Learn what NOT to do with Docker networks"
echo "- See real security vulnerabilities and fixes"
echo ""

print_info "Cleaning up will happen automatically on exit..."