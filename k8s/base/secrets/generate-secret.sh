#!/bin/bash
# Script to generate Kubernetes secrets
# Usage: generate-secret.sh <environment> [secret-key]
# Example: generate-secret.sh staging
# Example: generate-secret.sh prod "my-custom-secret-key"

set -e

ENVIRONMENT="${1:-}"
SECRET_KEY="${2:-}"

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <environment> [secret-key]"
    echo "  environment: staging or prod"
    echo "  secret-key: (optional) custom secret key, otherwise generates random"
    exit 1
fi

if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo "Error: Environment must be 'staging' or 'prod'"
    exit 1
fi

OUTPUT_FILE="03-secret-${ENVIRONMENT}.yaml"

# Generate secret key if not provided
if [ -z "$SECRET_KEY" ]; then
    echo "Generating secure random secret key..."
    if command -v openssl &> /dev/null; then
        SECRET_KEY=$(openssl rand -base64 32)
    elif command -v base64 &> /dev/null; then
        SECRET_KEY=$(head -c 32 /dev/urandom | base64)
    else
        echo "Error: Need openssl or base64 to generate random key"
        exit 1
    fi
    echo "Generated secret key: ${SECRET_KEY}"
else
    echo "Using provided secret key"
fi

# Encode secret key
ENCODED=$(echo -n "$SECRET_KEY" | base64)

# Generate YAML file
cat > "${OUTPUT_FILE}" <<EOF
# Kubernetes Secret for ${ENVIRONMENT^} Environment
# Generated on: $(date)
# 
# IMPORTANT: Store the secret key securely!
# Secret Key: ${SECRET_KEY}
#
# Apply: kubectl apply -f ${OUTPUT_FILE}

apiVersion: v1
kind: Secret
metadata:
  name: micro-secrets
  namespace: ${ENVIRONMENT}
  labels:
    environment: ${ENVIRONMENT}
    managed-by: jenkins
type: Opaque
data:
  JWT_SECRET_KEY: ${ENCODED}
EOF

echo ""
echo "✓ Secret generated: ${OUTPUT_FILE}"
echo ""
echo "⚠ IMPORTANT: Store the secret key securely!"
echo "   Secret Key: ${SECRET_KEY}"
echo ""
echo "To apply: kubectl apply -f ${OUTPUT_FILE}"
echo ""

