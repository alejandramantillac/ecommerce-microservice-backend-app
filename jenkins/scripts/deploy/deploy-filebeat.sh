#!/bin/bash
# Script to deploy Filebeat to Kubernetes
# Usage: ./jenkins/scripts/deploy-filebeat.sh <namespace> <environment> <logstash-endpoint>

set -e

NAMESPACE="${1:-staging}"
ENVIRONMENT="${2:-staging}"
LOGSTASH_ENDPOINT="${3}"

if [ -z "$NAMESPACE" ] || [ -z "$ENVIRONMENT" ] || [ -z "$LOGSTASH_ENDPOINT" ]; then
    echo "Usage: $0 <namespace> <environment> <logstash-endpoint>"
    echo "Example: $0 staging staging ecom-stg-logstash.bluewave-faea5f9b.eastus2.azurecontainerapps.io"
    exit 1
fi

echo "========================================="
echo "Deploying Filebeat to ${NAMESPACE}"
echo "Environment: ${ENVIRONMENT}"
echo "Logstash Endpoint: ${LOGSTASH_ENDPOINT}"
echo "========================================="

# Check kubectl availability
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
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

# Check if envsubst is available (for variable substitution)
if command -v envsubst &> /dev/null; then
    USE_ENVSUBST=true
else
    USE_ENVSUBST=false
    echo ""
    echo "Warning: envsubst not found. Will use sed for variable substitution."
    echo "  Install gettext package for better variable substitution:"
    echo "  - Linux: sudo apt-get install gettext-base"
    echo "  - macOS: brew install gettext"
    echo "  - Windows: Install Git Bash or use WSL"
fi

# Export variables for envsubst
export NAMESPACE
export ENVIRONMENT
export LOGSTASH_ENDPOINT

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

# Function to substitute variables
substitute_vars() {
    local file="$1"
    if [ "$USE_ENVSUBST" = true ]; then
        envsubst < "$file"
    else
        # Escapar caracteres especiales para sed
        local escaped_logstash_endpoint=$(echo "$LOGSTASH_ENDPOINT" | sed 's/[[\.*^$()+?{|]/\\&/g')
        
        # Replace basic variables
        sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" \
            -e "s/\${ENVIRONMENT}/${ENVIRONMENT}/g" \
            -e "s/\${LOGSTASH_ENDPOINT}/${escaped_logstash_endpoint}/g" \
            "$file"
    fi
}

# Step 1: Deploy RBAC
echo ""
echo "Step 1: Deploying RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding)..."
if substitute_vars k8s/logging/filebeat-rbac.yaml | kubectl --kubeconfig="$KCFG" apply -f -; then
    echo "✓ RBAC deployed"
else
    echo "✗ Failed to deploy RBAC"
    exit 1
fi

# Step 2: Deploy ConfigMap
echo ""
echo "Step 2: Deploying ConfigMap..."

# Validate that Logstash endpoint is not empty
if [ -z "$LOGSTASH_ENDPOINT" ]; then
    echo "✗ Error: Logstash endpoint is empty"
    exit 1
fi

# Generate ConfigMap with substituted variables
CONFIGMAP_YAML=$(substitute_vars k8s/logging/filebeat-configmap.yaml)

# Verify that substitution worked (check for remaining ${} variables)
if echo "$CONFIGMAP_YAML" | grep -q '\${LOGSTASH_ENDPOINT'; then
    echo "✗ Error: Variable substitution failed. ConfigMap still contains unresolved LOGSTASH_ENDPOINT variable"
    exit 1
fi

# Apply ConfigMap
if echo "$CONFIGMAP_YAML" | kubectl --kubeconfig="$KCFG" apply -f -; then
    echo "✓ ConfigMap deployed"
    
    # Verify ConfigMap has correct configuration
    echo ""
    echo "  Verifying ConfigMap configuration..."
    sleep 2  # Wait for ConfigMap to be available
    CONFIGMAP_OUTPUT=$(kubectl --kubeconfig="$KCFG" get configmap filebeat-config -n "${NAMESPACE}" -o jsonpath='{.data.filebeat\.yml}' 2>/dev/null || echo "")
    if echo "$CONFIGMAP_OUTPUT" | grep -q "output.logstash"; then
        LOGSTASH_HOST_CHECK=$(echo "$CONFIGMAP_OUTPUT" | grep -A 1 "output.logstash" | grep "hosts" | sed "s/.*hosts: \[//" | sed "s/\].*//" | tr -d '"' || echo "")
        if [ -n "$LOGSTASH_HOST_CHECK" ] && [[ ! "$LOGSTASH_HOST_CHECK" == *"\${"* ]]; then
            echo "✓ ConfigMap correctly configured for Logstash output"
            echo "  Logstash endpoint: ${LOGSTASH_HOST_CHECK}"
        else
            echo "⚠ Warning: ConfigMap has Logstash output but endpoint may not be substituted"
        fi
    else
        echo "⚠ Warning: ConfigMap may not have Logstash output configured"
        echo "  Current output configuration:"
        echo "$CONFIGMAP_OUTPUT" | grep -A 5 "output\." || echo "  No output section found"
    fi
    
    # Restart Filebeat pods to pick up new configuration
    echo ""
    echo "  Restarting Filebeat pods to apply new configuration..."
    if kubectl --kubeconfig="$KCFG" get daemonset filebeat -n "${NAMESPACE}" &>/dev/null; then
        kubectl --kubeconfig="$KCFG" delete pods -n "${NAMESPACE}" -l app=filebeat --grace-period=30 --timeout=60s 2>/dev/null || true
        echo "✓ Pods restart initiated"
    else
        echo "  No existing Filebeat DaemonSet found, will be created in next step"
    fi
else
    echo "✗ Failed to deploy ConfigMap"
    exit 1
fi

# Step 3: Deploy DaemonSet
echo ""
echo "Step 3: Deploying Filebeat DaemonSet..."
if substitute_vars k8s/logging/filebeat-daemonset.yaml | kubectl --kubeconfig="$KCFG" apply -f -; then
    echo "✓ DaemonSet deployed"
else
    echo "✗ Failed to deploy DaemonSet"
    exit 1
fi

# Step 4: Wait for DaemonSet
echo ""
echo "Step 4: Waiting for Filebeat pods to be ready..."
TIMEOUT=300
ELAPSED=0
INTERVAL=10

while [ $ELAPSED -lt $TIMEOUT ]; do
    READY=$(kubectl --kubeconfig="$KCFG" get daemonset filebeat -n "${NAMESPACE}" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl --kubeconfig="$KCFG" get daemonset filebeat -n "${NAMESPACE}" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
    
    if [ "$READY" = "$DESIRED" ] && [ "$DESIRED" != "0" ]; then
        echo "✓ All Filebeat pods are ready ($READY/$DESIRED)"
        break
    fi
    echo "  Waiting... ($ELAPSED/$TIMEOUT seconds) - Ready: $READY/$DESIRED"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "Warning: DaemonSet did not become ready within $TIMEOUT seconds"
    echo "Checking pod status..."
    kubectl --kubeconfig="$KCFG" get pods -n "${NAMESPACE}" -l app=filebeat
    echo ""
    echo "Checking pod logs..."
    POD_NAME=$(kubectl --kubeconfig="$KCFG" get pods -n "${NAMESPACE}" -l app=filebeat -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD_NAME" ]; then
        echo "Pod: $POD_NAME"
        kubectl --kubeconfig="$KCFG" logs -n "${NAMESPACE}" "$POD_NAME" --tail=50
    fi
    echo ""
    echo "Note: DaemonSet may still be in progress. Check status with:"
    echo "  kubectl --kubeconfig=\"\${KCFG}\" get daemonset -n ${NAMESPACE} filebeat"
    echo "  kubectl --kubeconfig=\"\${KCFG}\" get pods -n ${NAMESPACE} -l app=filebeat"
    exit 1
fi

# Step 5: Verify deployment
echo ""
echo "Step 5: Verifying deployment..."
DAEMONSET_STATUS=$(kubectl --kubeconfig="$KCFG" get daemonset filebeat -n "${NAMESPACE}" -o jsonpath='{.status}' 2>/dev/null || echo "")
if [ -z "$DAEMONSET_STATUS" ]; then
    echo "Error: Filebeat DaemonSet not found"
    exit 1
fi

READY=$(kubectl --kubeconfig="$KCFG" get daemonset filebeat -n "${NAMESPACE}" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
DESIRED=$(kubectl --kubeconfig="$KCFG" get daemonset filebeat -n "${NAMESPACE}" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
echo "✓ DaemonSet status: $READY/$DESIRED pods ready"

# List pods
echo ""
echo "Filebeat Pods:"
kubectl --kubeconfig="$KCFG" get pods -n "${NAMESPACE}" -l app=filebeat

# Check pod statuses
PODS=$(kubectl --kubeconfig="$KCFG" get pods -n "${NAMESPACE}" -l app=filebeat -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [ -n "$PODS" ]; then
    for POD in $PODS; do
        POD_STATUS=$(kubectl --kubeconfig="$KCFG" get pod "$POD" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [ "$POD_STATUS" = "Running" ]; then
            echo "✓ Pod $POD: $POD_STATUS"
        else
            echo "⚠ Pod $POD: $POD_STATUS"
        fi
    done
fi

echo ""
echo "========================================="
echo "Filebeat deployment completed!"
echo "========================================="
echo ""
echo "Verification commands:"
echo "  kubectl --kubeconfig=\"\${KCFG}\" get daemonset -n ${NAMESPACE} filebeat"
echo "  kubectl --kubeconfig=\"\${KCFG}\" get pods -n ${NAMESPACE} -l app=filebeat"
echo "  kubectl --kubeconfig=\"\${KCFG}\" logs -n ${NAMESPACE} -l app=filebeat"
echo ""
echo "Next steps:"
echo "  1. Verify logs are being collected:"
echo "     kubectl --kubeconfig=\"\${KCFG}\" logs -n ${NAMESPACE} -l app=filebeat | head -20"
echo ""
echo "  2. Verify logs are being sent to Logstash:"
echo "     - Check Filebeat logs for successful connections to Logstash"
echo "     - Verify no errors related to Logstash connection"
echo ""
echo "  3. Verify Logstash is forwarding to Azure Log Analytics:"
echo "     - Check Logstash logs in Azure Container Apps"
echo "     - Verify Logstash is configured to send to Azure Log Analytics"
echo ""
echo "  4. Verify logs in Azure Log Analytics:"
echo "     - Go to Azure Portal > Log Analytics Workspace"
echo "     - Query: Filebeat_CL | take 10"
echo "     - Verify logs are visible with Kubernetes metadata"
echo ""
echo "  5. Check Filebeat configuration:"
echo "     kubectl --kubeconfig=\"\${KCFG}\" get configmap filebeat-config -n ${NAMESPACE} -o yaml | grep -A 5 output"
echo ""

