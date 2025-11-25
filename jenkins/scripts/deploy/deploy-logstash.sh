#!/bin/bash
# Script to deploy Logstash to Kubernetes
# Usage: ./jenkins/scripts/deploy-logstash.sh <namespace> <environment>

set -e

NAMESPACE="${1:-staging}"
ENVIRONMENT="${2:-staging}"

if [ -z "$NAMESPACE" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <namespace> <environment>"
    echo "Example: $0 staging staging"
    exit 1
fi

echo "========================================="
echo "Deploying Logstash to ${NAMESPACE}"
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

# Check if Elasticsearch is deployed
echo ""
echo "Checking if Elasticsearch is deployed..."
if ! kubectl get svc elasticsearch -n "${NAMESPACE}" &> /dev/null; then
    echo "Warning: Elasticsearch service not found in namespace ${NAMESPACE}"
    echo "Logstash requires Elasticsearch to be deployed first."
    echo "Please deploy Elasticsearch before deploying Logstash."
    echo ""
    echo "Deploy Elasticsearch with:"
    echo "  ./jenkins/scripts/deploy-elasticsearch.sh ${NAMESPACE} ${ENVIRONMENT}"
    exit 1
fi
echo "✓ Elasticsearch service found"

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

# Step 1: Deploy ConfigMap
echo ""
echo "Step 1: Deploying ConfigMap..."
if substitute_vars k8s/logging/logstash-configmap.yaml | kubectl apply -f -; then
    echo "✓ ConfigMap deployed"
else
    echo "✗ Failed to deploy ConfigMap"
    exit 1
fi

# Step 2: Deploy Deployment and Service
echo ""
echo "Step 2: Deploying Logstash Deployment and Service..."
if substitute_vars k8s/logging/logstash.yaml | kubectl apply -f -; then
    echo "✓ Deployment and Service deployed"
else
    echo "✗ Failed to deploy Deployment and Service"
    exit 1
fi

# Step 3: Wait for deployment
echo ""
echo "Step 3: Waiting for Logstash to be ready..."
TIMEOUT=600
ELAPSED=0
INTERVAL=10

while [ $ELAPSED -lt $TIMEOUT ]; do
    if kubectl get deployment logstash -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null | grep -q "True"; then
        echo "✓ Logstash is ready"
        break
    fi
    echo "  Waiting... ($ELAPSED/$TIMEOUT seconds)"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "Warning: Deployment did not become available within $TIMEOUT seconds"
    echo "Checking pod status..."
    kubectl get pods -n "${NAMESPACE}" -l app=logstash
    echo ""
    echo "Checking pod logs..."
    POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=logstash -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD_NAME" ]; then
        echo "Pod: $POD_NAME"
        kubectl logs -n "${NAMESPACE}" "$POD_NAME" --tail=50
    fi
    echo ""
    echo "Note: Deployment may still be in progress. Check status with:"
    echo "  kubectl get pods -n ${NAMESPACE} -l app=logstash"
    exit 1
fi

# Step 4: Verify deployment
echo ""
echo "Step 4: Verifying deployment..."
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=logstash -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$POD_NAME" ]; then
    echo "Error: Logstash pod not found"
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

# Wait a bit more for Logstash to fully initialize
echo ""
echo "Waiting for Logstash to fully initialize..."
sleep 30

# Step 5: Verify Logstash pipeline
echo ""
echo "Step 5: Verifying Logstash pipeline..."
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=logstash -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$POD_NAME" ]; then
    PIPELINE_STATUS=$(kubectl exec -n "${NAMESPACE}" "$POD_NAME" -- curl -s http://localhost:9600/_node/pipelines 2>/dev/null || echo "")
    if echo "$PIPELINE_STATUS" | grep -q "main"; then
        echo "✓ Pipeline 'main' is configured"
    else
        echo "Warning: Could not verify pipeline configuration"
        echo "Response: $PIPELINE_STATUS"
    fi
fi

# Get service information
echo ""
echo "Service Information:"
kubectl get svc logstash -n "${NAMESPACE}" || {
    echo "Error: Service not found"
    exit 1
}

echo ""
echo "========================================="
echo "Logstash deployment completed!"
echo "========================================="
echo ""
echo "Verification commands:"
echo "  kubectl get pods -n ${NAMESPACE} -l app=logstash"
echo "  kubectl get svc -n ${NAMESPACE} logstash"
echo "  kubectl logs -n ${NAMESPACE} -l app=logstash"
echo ""
echo "Test Logstash:"
echo "  # Check pipeline status"
echo "  kubectl port-forward -n ${NAMESPACE} svc/logstash 9600:9600"
echo "  curl http://localhost:9600/_node/pipelines?pretty"
echo ""
echo "  # Send test log via HTTP"
echo "  kubectl port-forward -n ${NAMESPACE} svc/logstash 8080:8080"
echo "  curl -X POST http://localhost:8080 -H 'Content-Type: application/json' -d '{\"message\":\"Test log message\"}'"
echo ""
echo "  # Verify logs in Elasticsearch"
echo "  curl http://<ELASTICSEARCH_IP>:<PORT>/logstash-*/_search?pretty"
echo ""
echo "Next steps:"
echo "  1. Deploy Filebeat (Fase 9) to collect logs from pods and send to Logstash"
echo "  2. Configure services to send logs to Logstash via HTTP or Beats"
echo "  3. Verify logs are being processed and stored in Elasticsearch"
echo ""

