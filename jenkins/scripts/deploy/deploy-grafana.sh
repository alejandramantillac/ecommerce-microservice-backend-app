#!/bin/bash
# Script to deploy Grafana to Kubernetes
# Usage: ./jenkins/scripts/deploy-grafana.sh <namespace> <environment> [service-type] [node-port]

set -e

NAMESPACE="${1:-staging}"
ENVIRONMENT="${2:-staging}"
SERVICE_TYPE="${3:-NodePort}"
NODE_PORT="${4:-30300}"

if [ -z "$NAMESPACE" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <namespace> <environment> [service-type] [node-port]"
    echo "Example: $0 staging staging NodePort 30300"
    exit 1
fi

echo "========================================="
echo "Deploying Grafana to ${NAMESPACE}"
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
        # Fallback to sed for basic substitution
        local output=$(sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" \
                           -e "s/\${ENVIRONMENT}/${ENVIRONMENT}/g" \
                           -e "s/nodePort: 30300/nodePort: ${NODE_PORT}/g" \
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
if substitute_vars k8s/monitoring/grafana-pvc.yaml | kubectl apply -f -; then
    echo "✓ PVC deployed"
else
    echo "✗ Failed to deploy PVC"
    exit 1
fi

# Step 2: Deploy Datasources ConfigMap
echo ""
echo "Step 2: Deploying Datasources ConfigMap..."
if substitute_vars k8s/monitoring/grafana-datasources-configmap.yaml | kubectl apply -f -; then
    echo "✓ Datasources ConfigMap deployed"
else
    echo "✗ Failed to deploy Datasources ConfigMap"
    exit 1
fi

# Step 3: Deploy Dashboards Provider ConfigMap
echo ""
echo "Step 3: Deploying Dashboards Provider ConfigMap..."
if substitute_vars k8s/monitoring/grafana-dashboards-provider-configmap.yaml | kubectl apply -f -; then
    echo "✓ Dashboards Provider ConfigMap deployed"
else
    echo "✗ Failed to deploy Dashboards Provider ConfigMap"
    exit 1
fi

# Step 4: Deploy Dashboards ConfigMap
echo ""
echo "Step 4: Deploying Dashboards ConfigMap..."
if substitute_vars k8s/monitoring/grafana-dashboards-configmap.yaml | kubectl apply -f -; then
    echo "✓ Dashboards ConfigMap deployed"
else
    echo "✗ Failed to deploy Dashboards ConfigMap"
    exit 1
fi

# Step 5: Deploy Deployment and Service
echo ""
echo "Step 5: Deploying Grafana Deployment and Service..."
if substitute_vars k8s/monitoring/grafana.yaml | kubectl apply -f -; then
    echo "✓ Deployment and Service deployed"
else
    echo "✗ Failed to deploy Deployment and Service"
    exit 1
fi

# Step 6: Wait for deployment
echo ""
echo "Step 6: Waiting for Grafana to be ready..."
TIMEOUT=300
ELAPSED=0
INTERVAL=5

while [ $ELAPSED -lt $TIMEOUT ]; do
    if kubectl get deployment grafana -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null | grep -q "True"; then
        echo "✓ Grafana is ready"
        break
    fi
    echo "  Waiting... ($ELAPSED/$TIMEOUT seconds)"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "Warning: Deployment did not become available within $TIMEOUT seconds"
    echo "Checking pod status..."
    kubectl get pods -n "${NAMESPACE}" -l app=grafana
    echo ""
    echo "Checking pod logs..."
    POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD_NAME" ]; then
        echo "Pod: $POD_NAME"
        kubectl logs -n "${NAMESPACE}" "$POD_NAME" --tail=50
    fi
    echo ""
    echo "Note: Deployment may still be in progress. Check status with:"
    echo "  kubectl get pods -n ${NAMESPACE} -l app=grafana"
    exit 1
fi

# Step 7: Verify deployment
echo ""
echo "Step 7: Verifying deployment..."
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$POD_NAME" ]; then
    echo "Error: Grafana pod not found"
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

# Get service information
echo ""
echo "Service Information:"
kubectl get svc grafana -n "${NAMESPACE}" || {
    echo "Error: Service not found"
    exit 1
}

# Get access URL
echo ""
if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
    echo "Waiting for LoadBalancer IP..."
    sleep 10
    LB_IP=$(kubectl get svc grafana -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$LB_IP" ]; then
        echo "✓ Grafana UI: http://${LB_IP}:3000"
        echo "  Login: admin/admin"
    else
        LB_HOST=$(kubectl get svc grafana -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$LB_HOST" ]; then
            echo "✓ Grafana UI: http://${LB_HOST}:3000"
            echo "  Login: admin/admin"
        else
            echo "⚠ LoadBalancer IP not yet assigned. Check with:"
            echo "  kubectl get svc grafana -n ${NAMESPACE}"
            echo "  kubectl describe svc grafana -n ${NAMESPACE}"
        fi
    fi
elif [ "$SERVICE_TYPE" = "NodePort" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
    if [ -z "$NODE_IP" ]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "")
    fi
    if [ -n "$NODE_IP" ]; then
        echo "✓ Grafana UI: http://${NODE_IP}:${NODE_PORT}"
        echo "  Login: admin/admin"
    else
        echo "✓ Grafana UI: http://<NODE_IP>:${NODE_PORT}"
        echo "  Login: admin/admin"
        echo ""
        echo "Get node IP with:"
        echo "  kubectl get nodes -o wide"
        echo "  kubectl get nodes -o jsonpath='{.items[0].status.addresses}'"
    fi
else
    echo "✓ Grafana Service Type: $SERVICE_TYPE"
    echo "  Access via port-forward:"
    echo "  kubectl port-forward -n ${NAMESPACE} svc/grafana 3000:3000"
    echo "  Then access: http://localhost:3000"
    echo "  Login: admin/admin"
fi

echo ""
echo "========================================="
echo "Grafana deployment completed!"
echo "========================================="
echo ""
echo "Verification commands:"
echo "  kubectl get pods -n ${NAMESPACE} -l app=grafana"
echo "  kubectl get svc -n ${NAMESPACE} grafana"
echo "  kubectl logs -n ${NAMESPACE} -l app=grafana"
echo ""
echo "To verify dashboards:"
echo "  1. Access Grafana UI"
echo "  2. Login with admin/admin"
echo "  3. Navigate to Dashboards > System Overview"
echo "  4. Verify datasource: Configuration > Data Sources > Prometheus"
echo ""

