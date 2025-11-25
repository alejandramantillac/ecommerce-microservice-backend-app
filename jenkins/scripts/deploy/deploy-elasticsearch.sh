#!/bin/bash
# Script to deploy Elasticsearch to Kubernetes
# Usage: ./jenkins/scripts/deploy-elasticsearch.sh <namespace> <environment> [service-type] [node-port]

set -e

NAMESPACE="${1:-staging}"
ENVIRONMENT="${2:-staging}"
SERVICE_TYPE="${3:-NodePort}"
NODE_PORT="${4:-30920}"

if [ -z "$NAMESPACE" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <namespace> <environment> [service-type] [node-port]"
    echo "Example: $0 staging staging NodePort 30920"
    exit 1
fi

echo "========================================="
echo "Deploying Elasticsearch to ${NAMESPACE}"
echo "Environment: ${ENVIRONMENT}"
echo "Service Type: ${SERVICE_TYPE}"
echo "Node Port: ${NODE_PORT}"
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
export SERVICE_TYPE
export NODE_PORT

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

# Function to substitute variables
substitute_vars() {
    local file="$1"
    if [ "$USE_ENVSUBST" = true ]; then
        envsubst < "$file"
    else
        # Replace basic variables
        local output=$(sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" \
                           -e "s/\${ENVIRONMENT}/${ENVIRONMENT}/g" \
                           -e "s/nodePort: 30920/nodePort: ${NODE_PORT}/g" \
                           -e "s/type: NodePort/type: ${SERVICE_TYPE}/g" \
                           "$file")
        # Remove nodePort if service type is ClusterIP
        if [ "$SERVICE_TYPE" = "ClusterIP" ]; then
            echo "$output" | sed '/nodePort:/d'
        else
            echo "$output"
        fi
    fi
}

# Step 1: Deploy PVC
echo ""
echo "Step 1: Deploying PersistentVolumeClaim..."
if substitute_vars k8s/logging/elasticsearch-pvc.yaml | kubectl apply -f -; then
    echo "✓ PVC deployed"
else
    echo "✗ Failed to deploy PVC"
    exit 1
fi

# Step 2: Deploy ConfigMap
echo ""
echo "Step 2: Deploying ConfigMap..."
if substitute_vars k8s/logging/elasticsearch-configmap.yaml | kubectl apply -f -; then
    echo "✓ ConfigMap deployed"
else
    echo "✗ Failed to deploy ConfigMap"
    exit 1
fi

# Step 3: Deploy Deployment and Service
echo ""
echo "Step 3: Deploying Elasticsearch Deployment and Service..."
if substitute_vars k8s/logging/elasticsearch.yaml | kubectl apply -f -; then
    echo "✓ Deployment and Service deployed"
else
    echo "✗ Failed to deploy Deployment and Service"
    exit 1
fi

# Step 4: Wait for deployment
echo ""
echo "Step 4: Waiting for Elasticsearch to be ready..."
TIMEOUT=600
ELAPSED=0
INTERVAL=10

while [ $ELAPSED -lt $TIMEOUT ]; do
    if kubectl get deployment elasticsearch -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null | grep -q "True"; then
        echo "✓ Elasticsearch is ready"
        break
    fi
    echo "  Waiting... ($ELAPSED/$TIMEOUT seconds)"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "Warning: Deployment did not become available within $TIMEOUT seconds"
    echo "Checking pod status..."
    kubectl get pods -n "${NAMESPACE}" -l app=elasticsearch
    echo ""
    echo "Checking pod logs..."
    POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD_NAME" ]; then
        echo "Pod: $POD_NAME"
        kubectl logs -n "${NAMESPACE}" "$POD_NAME" --tail=50
    fi
    echo ""
    echo "Note: Deployment may still be in progress. Check status with:"
    echo "  kubectl get pods -n ${NAMESPACE} -l app=elasticsearch"
    exit 1
fi

# Step 5: Verify deployment
echo ""
echo "Step 5: Verifying deployment..."
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$POD_NAME" ]; then
    echo "Error: Elasticsearch pod not found"
    exit 1
fi

echo "✓ Pod: $POD_NAME"

# Check pod status
POD_STATUS=$(kubectl get pod "$POD_NAME" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
if [ -n "$POD_STATUS" ]; then
    if [ "$POD_STATUS" = "Running" ]; then
        echo "✓ Pod status: $POD_STATUS"
    else
        echo "Warning: Pod status is $POD_STATUS, expected Running"
        echo "Pod events:"
        kubectl describe pod "$POD_NAME" -n "${NAMESPACE}" | tail -20
    fi
fi

# Wait a bit more for Elasticsearch to fully initialize
echo ""
echo "Waiting for Elasticsearch to fully initialize..."
sleep 30

# Step 6: Verify Elasticsearch health
echo ""
echo "Step 6: Verifying Elasticsearch health..."
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$POD_NAME" ]; then
    HEALTH=$(kubectl exec -n "${NAMESPACE}" "$POD_NAME" -- curl -s http://localhost:9200/_cluster/health 2>/dev/null || echo "")
    if echo "$HEALTH" | grep -q "green\|yellow"; then
        echo "✓ Elasticsearch cluster health: $(echo "$HEALTH" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)"
    else
        echo "Warning: Could not verify cluster health"
        echo "Response: $HEALTH"
    fi
fi

# Get service information
echo ""
echo "Service Information:"
kubectl get svc elasticsearch -n "${NAMESPACE}" || {
    echo "Error: Service not found"
    exit 1
}

# Get access URL
echo ""
if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
    echo "Waiting for LoadBalancer IP..."
    sleep 10
    LB_IP=$(kubectl get svc elasticsearch -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$LB_IP" ]; then
        echo "✓ Elasticsearch API: http://${LB_IP}:9200"
        echo "✓ Cluster Health: http://${LB_IP}:9200/_cluster/health"
    else
        LB_HOST=$(kubectl get svc elasticsearch -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$LB_HOST" ]; then
            echo "✓ Elasticsearch API: http://${LB_HOST}:9200"
            echo "✓ Cluster Health: http://${LB_HOST}:9200/_cluster/health"
        else
            echo "⚠ LoadBalancer IP not yet assigned. Check with:"
            echo "  kubectl get svc elasticsearch -n ${NAMESPACE}"
            echo "  kubectl describe svc elasticsearch -n ${NAMESPACE}"
        fi
    fi
elif [ "$SERVICE_TYPE" = "NodePort" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
    if [ -z "$NODE_IP" ]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "")
    fi
    if [ -n "$NODE_IP" ]; then
        echo "✓ Elasticsearch API: http://${NODE_IP}:${NODE_PORT}"
        echo "✓ Cluster Health: http://${NODE_IP}:${NODE_PORT}/_cluster/health"
        echo "✓ Cluster Info: http://${NODE_IP}:${NODE_PORT}/"
    else
        echo "✓ Elasticsearch API: http://<NODE_IP>:${NODE_PORT}"
        echo "✓ Cluster Health: http://<NODE_IP>:${NODE_PORT}/_cluster/health"
        echo ""
        echo "Get node IP with:"
        echo "  kubectl get nodes -o wide"
        echo "  kubectl get nodes -o jsonpath='{.items[0].status.addresses}'"
    fi
else
    echo "✓ Elasticsearch Service Type: $SERVICE_TYPE"
    echo "  Access via port-forward:"
    echo "  kubectl port-forward -n ${NAMESPACE} svc/elasticsearch 9200:9200"
    echo "  Then access: http://localhost:9200"
    echo "  Cluster Health: http://localhost:9200/_cluster/health"
fi

echo ""
echo "========================================="
echo "Elasticsearch deployment completed!"
echo "========================================="
echo ""
echo "Verification commands:"
echo "  kubectl get pods -n ${NAMESPACE} -l app=elasticsearch"
echo "  kubectl get svc -n ${NAMESPACE} elasticsearch"
echo "  kubectl logs -n ${NAMESPACE} -l app=elasticsearch"
echo ""
echo "Test Elasticsearch:"
echo "  # Cluster health"
echo "  curl http://<ELASTICSEARCH_IP>:<PORT>/_cluster/health"
echo ""
echo "  # Cluster info"
echo "  curl http://<ELASTICSEARCH_IP>:<PORT>/"
echo ""
echo "  # Create test index"
echo "  curl -X PUT http://<ELASTICSEARCH_IP>:<PORT>/test-index"
echo ""
echo "  # List indices"
echo "  curl http://<ELASTICSEARCH_IP>:<PORT>/_cat/indices?v"
echo ""

