#!/bin/bash
# Common deployment functions for observability stack
# Source this file in deployment scripts to avoid code duplication

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    local component_name="$1"
    
    echo "========================================="
    echo "Deploying ${component_name} to ${NAMESPACE}"
    echo "Environment: ${ENVIRONMENT}"
    [ -n "$SERVICE_TYPE" ] && echo "Service Type: ${SERVICE_TYPE}"
    [ -n "$NODE_PORT" ] && echo "Node Port: ${NODE_PORT}"
    echo "========================================="
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
        echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    # Check Kubernetes connection
    echo ""
    echo "Checking Kubernetes connection..."
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
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
    
    echo -e "${GREEN}✓${NC} Connected to Kubernetes cluster"
    CLUSTER_CONTEXT=$(kubectl config current-context)
    echo "  Current context: ${CLUSTER_CONTEXT}"
    
    # Check envsubst
    if command -v envsubst &> /dev/null; then
        USE_ENVSUBST=true
    else
        USE_ENVSUBST=false
        echo ""
        echo -e "${YELLOW}Warning: envsubst not found. Will use sed for variable substitution.${NC}"
        echo "  Install gettext package for better variable substitution:"
        echo "  - Linux: sudo apt-get install gettext-base"
        echo "  - macOS: brew install gettext"
        echo "  - Windows: Install Git Bash or use WSL"
    fi
    
    # Export variables
    export NAMESPACE
    export ENVIRONMENT
    [ -n "$SERVICE_TYPE" ] && export SERVICE_TYPE
    [ -n "$NODE_PORT" ] && export NODE_PORT
    
    # Check/create namespace
    echo ""
    echo "Checking namespace ${NAMESPACE}..."
    if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        echo -e "${YELLOW}Warning: Namespace ${NAMESPACE} does not exist${NC}"
        echo "Creating namespace ${NAMESPACE}..."
        kubectl create namespace "${NAMESPACE}"
        echo -e "${GREEN}✓${NC} Namespace created"
    else
        echo -e "${GREEN}✓${NC} Namespace exists"
    fi
}

# Variable substitution function
substitute_vars() {
    local file="$1"
    local remove_nodeport="${2:-false}"
    
    if [ "$USE_ENVSUBST" = true ]; then
        envsubst < "$file"
    else
        local output=$(sed -e "s/\${NAMESPACE}/${NAMESPACE}/g" \
                           -e "s/\${ENVIRONMENT}/${ENVIRONMENT}/g" \
                           "$file")
        
        if [ -n "$SERVICE_TYPE" ]; then
            output=$(echo "$output" | sed -e "s/type: NodePort/type: ${SERVICE_TYPE}/g")
        fi
        
        if [ -n "$NODE_PORT" ]; then
            output=$(echo "$output" | sed -e "s/nodePort: [0-9]*/nodePort: ${NODE_PORT}/g")
        fi
        
        if [ "$remove_nodeport" = "true" ] && [ "$SERVICE_TYPE" = "ClusterIP" ]; then
            output=$(echo "$output" | sed '/nodePort:/d')
        fi
        
        echo "$output"
    fi
}

# Apply resource with error handling
apply_resource() {
    local file="$1"
    local resource_name="$2"
    local remove_nodeport="${3:-false}"
    
    echo ""
    echo "Deploying ${resource_name}..."
    if substitute_vars "$file" "$remove_nodeport" | kubectl apply -f -; then
        echo -e "${GREEN}✓${NC} ${resource_name} deployed"
        return 0
    else
        echo -e "${RED}✗${NC} Failed to deploy ${resource_name}"
        return 1
    fi
}

# Wait for deployment
wait_for_deployment() {
    local deployment_name="$1"
    local timeout="${2:-300}"
    local interval="${3:-10}"
    
    echo ""
    echo "Waiting for ${deployment_name} to be ready..."
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if kubectl get deployment "$deployment_name" -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null | grep -q "True"; then
            echo -e "${GREEN}✓${NC} ${deployment_name} is ready"
            return 0
        fi
        echo "  Waiting... ($elapsed/$timeout seconds)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo -e "${YELLOW}Warning: Deployment did not become available within $timeout seconds${NC}"
    echo "Checking pod status..."
    kubectl get pods -n "${NAMESPACE}" -l app="$deployment_name"
    return 1
}

# Wait for daemonset
wait_for_daemonset() {
    local daemonset_name="$1"
    local timeout="${2:-300}"
    local interval="${3:-10}"
    
    echo ""
    echo "Waiting for ${daemonset_name} pods to be ready..."
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        local ready=$(kubectl get daemonset "$daemonset_name" -n "${NAMESPACE}" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
        local desired=$(kubectl get daemonset "$daemonset_name" -n "${NAMESPACE}" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
        
        if [ "$ready" = "$desired" ] && [ "$desired" != "0" ]; then
            echo -e "${GREEN}✓${NC} All ${daemonset_name} pods are ready ($ready/$desired)"
            return 0
        fi
        echo "  Waiting... ($elapsed/$timeout seconds) - Ready: $ready/$desired"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo -e "${YELLOW}Warning: DaemonSet did not become ready within $timeout seconds${NC}"
    return 1
}

# Verify pod status
verify_pod() {
    local app_label="$1"
    local expected_status="${2:-Running}"
    
    echo ""
    echo "Verifying deployment..."
    local pod_name=$(kubectl get pods -n "${NAMESPACE}" -l app="$app_label" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$pod_name" ]; then
        echo -e "${RED}Error: ${app_label} pod not found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Pod: $pod_name"
    
    local pod_status=$(kubectl get pod "$pod_name" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    if [ "$pod_status" = "$expected_status" ]; then
        echo -e "${GREEN}✓${NC} Pod status: $pod_status"
        return 0
    else
        echo -e "${YELLOW}Warning: Pod status is $pod_status, expected $expected_status${NC}"
        return 1
    fi
}

# Print service access information
print_service_access() {
    local service_name="$1"
    local port="$2"
    local health_path="${3:-/}"
    
    echo ""
    echo "Service Information:"
    kubectl get svc "$service_name" -n "${NAMESPACE}" || {
        echo -e "${RED}Error: Service not found${NC}"
        return 1
    }
    
    echo ""
    if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
        echo "Waiting for LoadBalancer IP..."
        sleep 10
        local lb_ip=$(kubectl get svc "$service_name" -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$lb_ip" ]; then
            echo -e "${GREEN}✓${NC} ${service_name} UI: http://${lb_ip}:${port}"
        else
            local lb_host=$(kubectl get svc "$service_name" -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
            if [ -n "$lb_host" ]; then
                echo -e "${GREEN}✓${NC} ${service_name} UI: http://${lb_host}:${port}"
            else
                echo -e "${YELLOW}⚠${NC} LoadBalancer IP not yet assigned"
            fi
        fi
    elif [ "$SERVICE_TYPE" = "NodePort" ] && [ -n "$NODE_PORT" ]; then
        local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
        if [ -z "$node_ip" ]; then
            node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "")
        fi
        if [ -n "$node_ip" ]; then
            echo -e "${GREEN}✓${NC} ${service_name} UI: http://${node_ip}:${NODE_PORT}"
        else
            echo -e "${GREEN}✓${NC} ${service_name} UI: http://<NODE_IP>:${NODE_PORT}"
        fi
    else
        echo -e "${GREEN}✓${NC} ${service_name} Service Type: ${SERVICE_TYPE:-ClusterIP}"
        echo "  Access via port-forward:"
        echo "  kubectl port-forward -n ${NAMESPACE} svc/${service_name} ${port}:${port}"
    fi
}

