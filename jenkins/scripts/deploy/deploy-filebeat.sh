#!/bin/bash
# Script to deploy Filebeat to Kubernetes
# Usage: ./jenkins/scripts/deploy-filebeat.sh <namespace> <environment>

set -e

NAMESPACE="${1:-staging}"
ENVIRONMENT="${2:-staging}"

if [ -z "$NAMESPACE" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <namespace> <environment>"
    echo "Example: $0 staging staging"
    exit 1
fi

echo "========================================="
echo "Deploying Filebeat to ${NAMESPACE}"
echo "Environment: ${ENVIRONMENT}"
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
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Verify kubectl is configured: kubectl config current-context"
    echo "2. Check kubeconfig file: kubectl config view"
    echo "3. Verify cluster is running: kubectl cluster-info"
    echo "4. If using remote cluster, ensure VPN/network connection is active"
    echo "5. If using local cluster (minikube/kind), ensure it's running"
    echo ""
    echo "For local development with minikube:"
    echo "  minikube start"
    echo ""
    echo "For local development with kind:"
    echo "  kind create cluster"
    echo ""
    exit 1
fi

echo "✓ Connected to Kubernetes cluster"
CLUSTER_CONTEXT=$(kubectl config current-context)
echo "  Current context: ${CLUSTER_CONTEXT}"

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

# Check if namespace exists
echo ""
echo "Checking namespace ${NAMESPACE}..."
if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
    echo "Warning: Namespace ${NAMESPACE} does not exist"
    echo "Creating namespace ${NAMESPACE}..."
    kubectl create namespace "${NAMESPACE}"
    echo "✓ Namespace created"
else
    echo "✓ Namespace exists"
fi

# Check if Logstash is deployed
echo ""
echo "Checking if Logstash is deployed..."
if ! kubectl get svc logstash -n "${NAMESPACE}" &> /dev/null; then
    echo "Warning: Logstash service not found in namespace ${NAMESPACE}"
    echo "Filebeat requires Logstash to be deployed first."
    echo "Please deploy Logstash before deploying Filebeat."
    echo ""
    echo "Deploy Logstash with:"
    echo "  ./jenkins/scripts/deploy-logstash.sh ${NAMESPACE} ${ENVIRONMENT}"
    exit 1
fi
echo "✓ Logstash service found"

# Function to substitute variables
substitute_vars() {
    local file="$1"
    if [ "$USE_ENVSUBST" = true ]; then
        envsubst < "$file"
    else
        # Replace basic variables
        sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" \
            -e "s/\${ENVIRONMENT}/${ENVIRONMENT}/g" \
            "$file"
    fi
}

# Step 1: Deploy RBAC
echo ""
echo "Step 1: Deploying RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding)..."
if substitute_vars k8s/logging/filebeat-rbac.yaml | kubectl apply -f -; then
    echo "✓ RBAC deployed"
else
    echo "✗ Failed to deploy RBAC"
    exit 1
fi

# Step 2: Deploy ConfigMap
echo ""
echo "Step 2: Deploying ConfigMap..."
if substitute_vars k8s/logging/filebeat-configmap.yaml | kubectl apply -f -; then
    echo "✓ ConfigMap deployed"
else
    echo "✗ Failed to deploy ConfigMap"
    exit 1
fi

# Step 3: Deploy DaemonSet
echo ""
echo "Step 3: Deploying Filebeat DaemonSet..."
if substitute_vars k8s/logging/filebeat-daemonset.yaml | kubectl apply -f -; then
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
    READY=$(kubectl get daemonset filebeat -n "${NAMESPACE}" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get daemonset filebeat -n "${NAMESPACE}" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
    
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
    kubectl get pods -n "${NAMESPACE}" -l app=filebeat
    echo ""
    echo "Checking pod logs..."
    POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=filebeat -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD_NAME" ]; then
        echo "Pod: $POD_NAME"
        kubectl logs -n "${NAMESPACE}" "$POD_NAME" --tail=50
    fi
    echo ""
    echo "Note: DaemonSet may still be in progress. Check status with:"
    echo "  kubectl get daemonset -n ${NAMESPACE} filebeat"
    echo "  kubectl get pods -n ${NAMESPACE} -l app=filebeat"
    exit 1
fi

# Step 5: Verify deployment
echo ""
echo "Step 5: Verifying deployment..."
DAEMONSET_STATUS=$(kubectl get daemonset filebeat -n "${NAMESPACE}" -o jsonpath='{.status}' 2>/dev/null || echo "")
if [ -z "$DAEMONSET_STATUS" ]; then
    echo "Error: Filebeat DaemonSet not found"
    exit 1
fi

READY=$(kubectl get daemonset filebeat -n "${NAMESPACE}" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
DESIRED=$(kubectl get daemonset filebeat -n "${NAMESPACE}" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
echo "✓ DaemonSet status: $READY/$DESIRED pods ready"

# List pods
echo ""
echo "Filebeat Pods:"
kubectl get pods -n "${NAMESPACE}" -l app=filebeat

# Check pod statuses
PODS=$(kubectl get pods -n "${NAMESPACE}" -l app=filebeat -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [ -n "$PODS" ]; then
    for POD in $PODS; do
        POD_STATUS=$(kubectl get pod "$POD" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
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
echo "  kubectl get daemonset -n ${NAMESPACE} filebeat"
echo "  kubectl get pods -n ${NAMESPACE} -l app=filebeat"
echo "  kubectl logs -n ${NAMESPACE} -l app=filebeat"
echo ""
echo "Next steps:"
echo "  1. Verify logs are being collected:"
echo "     kubectl logs -n ${NAMESPACE} -l app=filebeat | head -20"
echo ""
echo "  2. Verify logs are being sent to Logstash:"
echo "     kubectl logs -n ${NAMESPACE} -l app=logstash | grep -i 'beats'"
echo ""
echo "  3. Verify logs in Elasticsearch:"
echo "     curl http://<ELASTICSEARCH_IP>:<PORT>/logstash-*/_search?pretty&size=5"
echo ""
echo "  4. Verify logs in Kibana:"
echo "     - Access Kibana UI"
echo "     - Go to Discover"
echo "     - Select index pattern: logstash-*"
echo "     - Verify logs are visible with Kubernetes metadata"
echo ""

