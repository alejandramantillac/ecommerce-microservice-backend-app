#!/bin/bash
# Script to generate self-signed TLS certificates for Ingress
# Usage: ./01-generate-self-signed-cert.sh <namespace> [domain-or-ip]
# Example: ./01-generate-self-signed-cert.sh staging api-staging.example.com
# Example: ./01-generate-self-signed-cert.sh prod 172.168.101.82

set -e

NAMESPACE="${1:-}"
DOMAIN_OR_IP="${2:-localhost}"

if [ -z "$NAMESPACE" ]; then
    echo "Usage: $0 <namespace> [domain-or-ip]"
    echo "  namespace: staging or prod"
    echo "  domain-or-ip: (optional) domain name or IP address for certificate, defaults to localhost"
    exit 1
fi

if [ "$NAMESPACE" != "staging" ] && [ "$NAMESPACE" != "prod" ]; then
    echo "Error: Namespace must be 'staging' or 'prod'"
    exit 1
fi

CERT_DIR="certs"
SECRET_NAME="tls-secret-${NAMESPACE}"
OUTPUT_FILE="02-tls-secret-${NAMESPACE}.yaml"

echo "========================================="
echo "Generating self-signed TLS certificate"
echo "Namespace: ${NAMESPACE}"
echo "Domain/IP: ${DOMAIN_OR_IP}"
echo "========================================="

# Create certs directory
mkdir -p "${CERT_DIR}"

# Generate private key
echo "Generating private key..."
openssl genrsa -out "${CERT_DIR}/${NAMESPACE}.key" 2048

# Check if DOMAIN_OR_IP is an IP address
if [[ "$DOMAIN_OR_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    # It's an IP address
    echo "Detected IP address: ${DOMAIN_OR_IP}"
    SUBJECT_ALT_NAME="IP.1 = ${DOMAIN_OR_IP}"
    CN="${DOMAIN_OR_IP}"
else
    # It's a domain name
    echo "Detected domain name: ${DOMAIN_OR_IP}"
    SUBJECT_ALT_NAME="DNS.1 = ${DOMAIN_OR_IP}"$'\n'"DNS.2 = *.${DOMAIN_OR_IP}"
    CN="${DOMAIN_OR_IP}"
fi

# Generate certificate signing request
echo "Generating certificate signing request..."
openssl req -new -key "${CERT_DIR}/${NAMESPACE}.key" -out "${CERT_DIR}/${NAMESPACE}.csr" \
    -subj "/CN=${CN}/O=Ingress Controller"

# Generate self-signed certificate (valid for 365 days)
echo "Generating self-signed certificate..."
openssl x509 -req -days 365 -in "${CERT_DIR}/${NAMESPACE}.csr" \
    -signkey "${CERT_DIR}/${NAMESPACE}.key" \
    -out "${CERT_DIR}/${NAMESPACE}.crt" \
    -extensions v3_req \
    -extfile <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
${SUBJECT_ALT_NAME}
EOF
)

# Encode to base64
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    KEY_B64=$(cat "${CERT_DIR}/${NAMESPACE}.key" | base64)
    CRT_B64=$(cat "${CERT_DIR}/${NAMESPACE}.crt" | base64)
else
    # Linux
    KEY_B64=$(cat "${CERT_DIR}/${NAMESPACE}.key" | base64 -w 0)
    CRT_B64=$(cat "${CERT_DIR}/${NAMESPACE}.crt" | base64 -w 0)
fi

# Generate Kubernetes Secret YAML
cat > "${OUTPUT_FILE}" <<EOF
# TLS Secret for ${NAMESPACE^} Environment
# Generated on: $(date)
# Domain/IP: ${DOMAIN_OR_IP}
#
# IMPORTANT: This is a self-signed certificate for development/testing.
# For production, use a valid certificate from Let's Encrypt or Azure Key Vault.
#
# Apply: kubectl apply -f ${OUTPUT_FILE}

apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
  labels:
    environment: ${NAMESPACE}
    managed-by: jenkins
type: kubernetes.io/tls
data:
  tls.key: ${KEY_B64}
  tls.crt: ${CRT_B64}
EOF

echo ""
echo "✓ Certificate generated successfully"
echo "  Certificate: ${CERT_DIR}/${NAMESPACE}.crt"
echo "  Private Key: ${CERT_DIR}/${NAMESPACE}.key"
echo "  Secret YAML: ${OUTPUT_FILE}"
echo ""
echo "⚠ IMPORTANT:"
echo "  - This is a self-signed certificate (browser will show warning)"
echo "  - For production, use Let's Encrypt or Azure Key Vault"
echo "  - Certificate files are in: ${CERT_DIR}/"
echo ""
echo "To apply: kubectl apply -f ${OUTPUT_FILE}"
echo ""
