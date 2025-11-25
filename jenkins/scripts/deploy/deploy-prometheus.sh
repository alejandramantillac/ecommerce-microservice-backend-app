#!/bin/bash
# Script to deploy Prometheus to Kubernetes
# Usage: ./jenkins/scripts/deploy-prometheus.sh <namespace> <environment> [service-type] [node-port]

set -e

NAMESPACE="${1:-staging}"
ENVIRONMENT="${2:-staging}"
SERVICE_TYPE="${3:-NodePort}"
NODE_PORT="${4:-30909}"

if [ -z "$NAMESPACE" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <namespace> <environment> [service-type] [node-port]"
    echo "Example: $0 staging staging NodePort 30909"
    exit 1
fi

echo "========================================="
echo "Deploying Prometheus to ${NAMESPACE}"
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
CLUSTER_CONTEXT=$(eval $KUBECTL_CMD config current-context)
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
if ! eval $KUBECTL_CMD get namespace "${NAMESPACE}" &> /dev/null; then
    echo "Warning: Namespace ${NAMESPACE} does not exist"
    echo "Creating namespace ${NAMESPACE}..."
    eval $KUBECTL_CMD create namespace "${NAMESPACE}"
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
        # Fallback to sed for basic substitution
        sed "s/\${NAMESPACE}/${NAMESPACE}/g; s/\${ENVIRONMENT}/${ENVIRONMENT}/g; s/\${SERVICE_TYPE}/${SERVICE_TYPE}/g; s/\${NODE_PORT}/${NODE_PORT}/g" "$file"
    fi
}

# Step 1: Deploy RBAC
echo ""
echo "Step 1: Deploying RBAC for Prometheus..."
if substitute_vars k8s/monitoring/prometheus-rbac.yaml | eval $KUBECTL_CMD apply -f -; then
    echo "✓ RBAC deployed"
else
    echo "✗ Failed to deploy RBAC"
    exit 1
fi

# Step 2: Deploy PVC
echo ""
echo "Step 2: Deploying PersistentVolumeClaim..."
if substitute_vars k8s/monitoring/prometheus-pvc.yaml | eval $KUBECTL_CMD apply -f -; then
    echo "✓ PVC deployed"
else
    echo "✗ Failed to deploy PVC"
    exit 1
fi

# Step 3: Deploy ConfigMap
echo ""
echo "Step 3: Deploying ConfigMap..."
if substitute_vars k8s/monitoring/prometheus-configmap.yaml | eval $KUBECTL_CMD apply -f -; then
    echo "✓ ConfigMap deployed"
else
    echo "✗ Failed to deploy ConfigMap"
    exit 1
fi

# Step 4: Deploy Deployment and Service
echo ""
echo "Step 4: Deploying Prometheus Deployment and Service..."
if substitute_vars k8s/monitoring/prometheus.yaml | eval $KUBECTL_CMD apply -f -; then
    echo "✓ Deployment and Service deployed"
else
    echo "✗ Failed to deploy Deployment and Service"
    exit 1
fi

# Step 5: Wait for deployment
echo ""
echo "Step 5: Waiting for Prometheus to be ready..."
if eval $KUBECTL_CMD wait --for=condition=available --timeout=300s deployment/prometheus -n "${NAMESPACE}" 2>/dev/null; then
    echo "✓ Prometheus is ready"
else
    echo "Warning: Deployment did not become available within 300s"
    echo "Checking pod status..."
    eval $KUBECTL_CMD get pods -n "${NAMESPACE}" -l app=prometheus || true
    echo ""
    echo "Checking pod logs..."
    POD_NAME=$(eval $KUBECTL_CMD get pods -n "${NAMESPACE}" -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD_NAME" ]; then
        echo "Pod: ${POD_NAME}"
        eval $KUBECTL_CMD logs -n "${NAMESPACE}" "${POD_NAME}" --tail=50 || true
    fi
    echo ""
    echo "Note: Deployment may still be in progress. Check status with:"
    echo "  $KUBECTL_CMD get pods -n ${NAMESPACE} -l app=prometheus"
    exit 1
fi

# Step 6: Verify deployment
echo ""
echo "Step 6: Verifying deployment..."
POD_NAME=$(eval $KUBECTL_CMD get pods -n "${NAMESPACE}" -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$POD_NAME" ]; then
    echo "Error: Prometheus pod not found"
    exit 1
fi

echo "✓ Pod: ${POD_NAME}"

# Check pod status
POD_STATUS=$(eval $KUBECTL_CMD get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
if [ "$POD_STATUS" != "Running" ]; then
    echo "Warning: Pod status is ${POD_STATUS}, expected Running"
    echo "Pod events:"
    eval $KUBECTL_CMD describe pod "${POD_NAME}" -n "${NAMESPACE}" | tail -20 || true
else
    echo "✓ Pod status: ${POD_STATUS}"
fi

# Get service information
echo ""
echo "Service Information:"
eval $KUBECTL_CMD get svc prometheus -n "${NAMESPACE}" || {
    echo "Error: Service not found"
    exit 1
}

# Get access URL
echo ""
if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
    echo "Waiting for LoadBalancer IP..."
    sleep 10
    LB_IP=$(eval $KUBECTL_CMD get svc prometheus -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$LB_IP" ]; then
        echo "✓ Prometheus UI: http://${LB_IP}:9090"
        echo "✓ Targets: http://${LB_IP}:9090/targets"
    else
        LB_HOST=$(eval $KUBECTL_CMD get svc prometheus -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$LB_HOST" ]; then
            echo "✓ Prometheus UI: http://${LB_HOST}:9090"
            echo "✓ Targets: http://${LB_HOST}:9090/targets"
        else
            echo "⚠ LoadBalancer IP not yet assigned. Check with:"
            echo "  kubectl get svc prometheus -n ${NAMESPACE}"
            echo "  kubectl describe svc prometheus -n ${NAMESPACE}"
        fi
    fi
elif [ "$SERVICE_TYPE" = "NodePort" ]; then
    NODE_IP=$(eval $KUBECTL_CMD get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
    if [ -z "$NODE_IP" ]; then
        NODE_IP=$(eval $KUBECTL_CMD get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "")
    fi
    if [ -n "$NODE_IP" ]; then
        echo "✓ Prometheus UI: http://${NODE_IP}:${NODE_PORT}"
        echo "✓ Targets: http://${NODE_IP}:${NODE_PORT}/targets"
    else
        echo "✓ Prometheus UI: http://<NODE_IP>:${NODE_PORT}"
        echo "✓ Targets: http://<NODE_IP>:${NODE_PORT}/targets"
        echo ""
        echo "Get node IP with:"
        echo "  kubectl get nodes -o wide"
        echo "  kubectl get nodes -o jsonpath='{.items[0].status.addresses}'"
    fi
else
    echo "✓ Prometheus Service Type: ${SERVICE_TYPE}"
    echo "  Access via port-forward:"
    echo "  kubectl port-forward -n ${NAMESPACE} svc/prometheus 9090:9090"
    echo "  Then access: http://localhost:9090"
fi

echo ""
echo "========================================="
echo "Prometheus deployment completed!"
echo "========================================="
echo ""
echo "Verification commands:"
echo "  $KUBECTL_CMD get pods -n ${NAMESPACE} -l app=prometheus"
echo "  $KUBECTL_CMD get svc -n ${NAMESPACE} prometheus"
echo "  kubectl logs -n ${NAMESPACE} -l app=prometheus"
echo ""
echo "To check targets (after accessing UI):"
echo "  Navigate to: Status > Targets"
echo "  All services should show as 'UP'"
echo ""
