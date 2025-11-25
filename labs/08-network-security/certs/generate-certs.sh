#!/bin/bash

# Lab 08 - Certificate Generation Script
# Generates self-signed certificates for TLS demo

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Generating Self-Signed Certificates${NC}"
echo -e "${BLUE}================================================${NC}\n"

# Create certs directory if it doesn't exist
CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$CERT_DIR"

echo -e "${BLUE}[INFO] Certificate directory: $CERT_DIR${NC}"

# Clean up old certificates
echo -e "${YELLOW}[CLEANUP] Removing old certificates...${NC}"
rm -f *.pem *.key *.crt *.csr *.srl 2>/dev/null || true

# Generate CA private key
echo -e "${BLUE}[1.1] Generating CA private key...${NC}"
openssl genrsa -out ca-key.pem 4096 2>/dev/null

# Generate CA certificate
echo -e "${BLUE}[1.2] Generating CA certificate...${NC}"
openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem \
    -subj "/C=US/ST=State/L=City/O=Lab08/OU=Security/CN=Lab08-CA" 2>/dev/null

# Generate server private key
echo -e "${BLUE}[1.3] Generating server private key...${NC}"
openssl genrsa -out server-key.pem 4096 2>/dev/null

# Generate server certificate signing request
echo -e "${BLUE}[1.4] Generating server CSR...${NC}"
openssl req -new -key server-key.pem -out server.csr \
    -subj "/C=US/ST=State/L=City/O=Lab08/OU=Security/CN=nginx" 2>/dev/null

# Create extensions file for server certificate
cat > extfile.cnf << EOF
subjectAltName = DNS:nginx,DNS:web,DNS:localhost,IP:127.0.0.1
extendedKeyUsage = serverAuth
EOF

# Sign server certificate with CA
echo -e "${BLUE}[1.5] Signing server certificate with CA...${NC}"
openssl x509 -req -days 365 -sha256 -in server.csr \
    -CA ca.pem -CAkey ca-key.pem -CAcreateserial \
    -out server-cert.pem -extfile extfile.cnf 2>/dev/null

# Clean up temporary files
rm -f server.csr extfile.cnf

# Set appropriate permissions
chmod 644 ca.pem server-cert.pem
chmod 600 ca-key.pem server-key.pem

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Certificate Generation Complete!${NC}"
echo -e "${GREEN}================================================${NC}\n"

echo -e "${BLUE}Generated files:${NC}"
echo "  ca.pem           - Certificate Authority (public)"
echo "  ca-key.pem       - CA private key"
echo "  server-cert.pem  - Server certificate (public)"
echo "  server-key.pem   - Server private key"
echo ""

# Display certificate information
echo -e "${BLUE}Certificate Details:${NC}"
echo ""
echo -e "${YELLOW}CA Certificate:${NC}"
openssl x509 -in ca.pem -noout -subject -issuer -dates 2>/dev/null
echo ""
echo -e "${YELLOW}Server Certificate:${NC}"
openssl x509 -in server-cert.pem -noout -subject -issuer -dates 2>/dev/null
echo ""
echo -e "${YELLOW}Subject Alternative Names:${NC}"
openssl x509 -in server-cert.pem -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name"

echo ""
echo -e "${GREEN}Certificates ready for use!${NC}"
echo ""
echo -e "${BLUE}Usage in Docker:${NC}"
echo "  docker run -v \$(pwd):/certs nginx"
echo "  Configure nginx to use:"
echo "    ssl_certificate     /certs/server-cert.pem;"
echo "    ssl_certificate_key /certs/server-key.pem;"
echo ""