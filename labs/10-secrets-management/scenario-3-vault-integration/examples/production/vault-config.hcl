# File: examples/production/vault-config.hcl
# Production Vault Configuration (Tier 2 - Linux VM)

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/vault.crt"
  tls_key_file  = "/vault/tls/vault.key"
}

api_addr = "https://vault.example.com:8200"
cluster_addr = "https://127.0.0.1:8201"
ui = true

# Enable audit logging
# vault audit enable file file_path=/vault/logs/audit.log

# Seal configuration (auto-unseal with cloud KMS in production)
# seal "awskms" {
#   region     = "us-east-1"
#   kms_key_id = "your-kms-key-id"
# }