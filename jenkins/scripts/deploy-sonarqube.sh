#!/bin/bash
# Script to deploy SonarQube to Kubernetes
# Usage: deploy-sonarqube.sh <namespace> [kubeconfig-path]

set -e

NAMESPACE="${1:-default}"
KUBECONFIG_PATH="${2:-${KCFG}}"

if [ -z "$KUBECONFIG_PATH" ]; then
    echo "Error: KUBECONFIG not provided"
    echo "Usage: $0 <namespace> [kubeconfig-path]"
    exit 1
fi

echo "========================================="
echo "Deploying SonarQube to Kubernetes"
echo "Namespace: ${NAMESPACE}"
echo "========================================="

# Check if SonarQube is already deployed
if kubectl --kubeconfig="${KUBECONFIG_PATH}" get deployment sonarqube -n "${NAMESPACE}" &>/dev/null; then
    echo "SonarQube is already deployed in namespace ${NAMESPACE}"
    echo "Skipping deployment..."
    exit 0
fi

# Apply SonarQube manifests
echo "Applying SonarQube manifests..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" apply -f k8s/sonarqube.yaml -n "${NAMESPACE}" || {
    # If namespace-specific deployment fails, try default namespace
    echo "Attempting deployment in default namespace..."
    kubectl --kubeconfig="${KUBECONFIG_PATH}" apply -f k8s/sonarqube.yaml
}

# Wait for SonarQube to be ready
echo "Waiting for SonarQube to be ready..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" wait --for=condition=available \
    --timeout=300s \
    deployment/sonarqube \
    -n "${NAMESPACE}" 2>/dev/null || {
    echo "⚠ Warning: Timeout waiting for SonarQube. It may still be starting..."
}

# Get SonarQube service URL
echo ""
echo "========================================="
echo "SonarQube Deployment Status"
echo "========================================="

kubectl --kubeconfig="${KUBECONFIG_PATH}" get pods -l app=sonarqube -n "${NAMESPACE}" || \
kubectl --kubeconfig="${KUBECONFIG_PATH}" get pods -l app=sonarqube

echo ""
echo "SonarQube Service:"
kubectl --kubeconfig="${KUBECONFIG_PATH}" get svc sonarqube -n "${NAMESPACE}" || \
kubectl --kubeconfig="${KUBECONFIG_PATH}" get svc sonarqube

echo ""
echo "========================================="
echo "✓ SonarQube deployment completed"
echo "========================================="

