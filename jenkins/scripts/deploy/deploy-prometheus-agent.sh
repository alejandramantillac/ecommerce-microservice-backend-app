#!/bin/bash
# Script para desplegar Prometheus Agent (ligero) que envía métricas a Azure Monitor
# Usage: ./jenkins/scripts/deploy/deploy-prometheus-agent.sh <namespace> <environment> <azure-ingestion-endpoint> <azure-client-id> <azure-tenant-id> <azure-client-secret>

set -e

NAMESPACE="${1:-staging}"
ENVIRONMENT="${2:-staging}"
AZURE_INGESTION_ENDPOINT="${3}"
AZURE_CLIENT_ID="${4}"
AZURE_TENANT_ID="${5}"
AZURE_CLIENT_SECRET="${6}"

if [ -z "$NAMESPACE" ] || [ -z "$ENVIRONMENT" ] || [ -z "$AZURE_INGESTION_ENDPOINT" ] || [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_TENANT_ID" ] || [ -z "$AZURE_CLIENT_SECRET" ]; then
    echo "Usage: $0 <namespace> <environment> <azure-ingestion-endpoint> <azure-client-id> <azure-tenant-id> <azure-client-secret>"
    echo "Example: $0 staging staging https://prometheus-ws-xxx.eastus.prometheus.monitor.azure.com client-id tenant-id client-secret"
    exit 1
fi

echo "========================================="
echo "Deploying Prometheus Agent to ${NAMESPACE}"
echo "Environment: ${ENVIRONMENT}"
echo "Azure Ingestion Endpoint: ${AZURE_INGESTION_ENDPOINT}"
echo "========================================="

# Check kubectl availability
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check Kubernetes connection
echo ""
echo "Checking Kubernetes connection..."
if ! kubectl --kubeconfig="$KCFG" cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✓ Connected to Kubernetes cluster"

# Check if namespace exists
echo ""
echo "Checking namespace ${NAMESPACE}..."
if ! kubectl --kubeconfig="$KCFG" get namespace "${NAMESPACE}" &> /dev/null; then
    echo "Creating namespace ${NAMESPACE}..."
    kubectl --kubeconfig="$KCFG" create namespace "${NAMESPACE}"
    echo "✓ Namespace created"
else
    echo "✓ Namespace exists"
fi

# Check if envsubst is available
if command -v envsubst &> /dev/null; then
    USE_ENVSUBST=true
else
    USE_ENVSUBST=false
    echo ""
    echo "Warning: envsubst not found. Will use sed for variable substitution."
fi

# Export variables for envsubst
export NAMESPACE
export ENVIRONMENT
export AZURE_INGESTION_ENDPOINT
export AZURE_CLIENT_ID
export AZURE_TENANT_ID
export AZURE_CLIENT_SECRET

# Function to substitute variables
substitute_vars() {
    local file="$1"
    if [ "$USE_ENVSUBST" = true ]; then
        envsubst < "$file"
    else
        sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" \
            -e "s/\${ENVIRONMENT}/${ENVIRONMENT}/g" \
            -e "s|\${AZURE_PROMETHEUS_INGESTION_ENDPOINT}|${AZURE_INGESTION_ENDPOINT}|g" \
            -e "s/\${AZURE_CLIENT_ID}/${AZURE_CLIENT_ID}/g" \
            -e "s/\${AZURE_TENANT_ID}/${AZURE_TENANT_ID}/g" \
            -e "s/\${AZURE_CLIENT_SECRET}/${AZURE_CLIENT_SECRET}/g" \
            "$file"
    fi
}

# Step 1: Create Secret with Azure credentials
echo ""
echo "Step 1: Creating Azure Monitor credentials secret..."
kubectl --kubeconfig="$KCFG" create secret generic azure-monitor-credentials \
    --from-literal=ingestion-endpoint="${AZURE_INGESTION_ENDPOINT}" \
    --from-literal=client-id="${AZURE_CLIENT_ID}" \
    --from-literal=tenant-id="${AZURE_TENANT_ID}" \
    --from-literal=client-secret="${AZURE_CLIENT_SECRET}" \
    -n "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl --kubeconfig="$KCFG" apply -f -
echo "✓ Secret created/updated"

# Step 2: Deploy Prometheus ConfigMap with remote_write
echo ""
echo "Step 2: Deploying Prometheus ConfigMap with remote_write..."
if substitute_vars k8s/monitoring/prometheus-config-remote-write.yaml | kubectl --kubeconfig="$KCFG" apply -f -; then
    echo "✓ ConfigMap deployed"
else
    echo "✗ Failed to deploy ConfigMap"
    exit 1
fi

# Step 3: Deploy Alert Rules ConfigMap (if exists)
if [ -f "k8s/monitoring/prometheus-alerts-configmap.yaml" ]; then
    echo ""
    echo "Step 3: Deploying Alert Rules ConfigMap..."
    if substitute_vars k8s/monitoring/prometheus-alerts-configmap.yaml | kubectl --kubeconfig="$KCFG" apply -f -; then
        echo "✓ Alert Rules ConfigMap deployed"
    else
        echo "⚠ Warning: Failed to deploy Alert Rules ConfigMap"
    fi
fi

# Step 4: Deploy Prometheus Agent
echo ""
echo "Step 4: Deploying Prometheus Agent..."
if substitute_vars k8s/monitoring/prometheus-agent.yaml | kubectl --kubeconfig="$KCFG" apply -f -; then
    echo "✓ Prometheus Agent manifest applied"
    # Force rollout restart to ensure new configuration is applied
    echo "Forcing rollout restart to apply new configuration..."
    if kubectl --kubeconfig="$KCFG" rollout restart deployment/prometheus-agent -n "${NAMESPACE}" 2>/dev/null; then
        echo "✓ Rollout restart initiated"
    else
        # If rollout restart fails, delete pods to force recreation
        echo "Rollout restart not available, deleting pods to force recreation..."
        kubectl --kubeconfig="$KCFG" delete pods -n "${NAMESPACE}" -l app=prometheus-agent --grace-period=0 --force 2>/dev/null || true
        echo "✓ Old pods deleted, new pods will be created"
    fi
else
    echo "✗ Failed to deploy Prometheus Agent"
    exit 1
fi

# Step 5: Wait for deployment
echo ""
echo "Step 5: Waiting for Prometheus Agent to be ready..."
if kubectl --kubeconfig="$KCFG" wait --for=condition=available --timeout=300s deployment/prometheus-agent -n "${NAMESPACE}" 2>/dev/null; then
    echo "✓ Prometheus Agent is ready"
else
    echo "Warning: Deployment did not become available within 300s"
    echo "Checking pod status..."
    kubectl --kubeconfig="$KCFG" get pods -n "${NAMESPACE}" -l app=prometheus-agent || true
    echo ""
    echo "Checking pod logs..."
    POD_NAME=$(kubectl --kubeconfig="$KCFG" get pods -n "${NAMESPACE}" -l app=prometheus-agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD_NAME" ]; then
        echo "Pod: ${POD_NAME}"
        kubectl --kubeconfig="$KCFG" logs -n "${NAMESPACE}" "${POD_NAME}" --tail=50 || true
    fi
fi

# Step 6: Verify deployment
echo ""
echo "Step 6: Verifying deployment..."
POD_NAME=$(kubectl --kubeconfig="$KCFG" get pods -n "${NAMESPACE}" -l app=prometheus-agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$POD_NAME" ]; then
    echo "Error: Prometheus Agent pod not found"
    exit 1
fi

echo "✓ Pod: ${POD_NAME}"

POD_STATUS=$(kubectl --kubeconfig="$KCFG" get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
if [ "$POD_STATUS" = "Running" ]; then
    echo "✓ Pod status: ${POD_STATUS}"
else
    echo "Warning: Pod status is ${POD_STATUS}, expected Running"
fi

echo ""
echo "========================================="
echo "Prometheus Agent deployment completed!"
echo "========================================="
echo ""
echo "The agent is now scraping metrics and sending them to Azure Monitor Workspace."
echo "Metrics are available in Azure Managed Grafana."
echo ""
echo "Verification commands:"
echo "  kubectl --kubeconfig=\"\${KCFG}\" get pods -n ${NAMESPACE} -l app=prometheus-agent"
echo "  kubectl --kubeconfig=\"\${KCFG}\" logs -n ${NAMESPACE} -l app=prometheus-agent"
echo ""

