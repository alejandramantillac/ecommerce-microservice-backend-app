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

# Validar que el endpoint no esté vacío
if [ -z "$AZURE_INGESTION_ENDPOINT" ] || [ "$AZURE_INGESTION_ENDPOINT" = "" ]; then
    echo "ERROR: AZURE_INGESTION_ENDPOINT is empty or not set!"
    echo "Please check that the monitoring outputs were loaded correctly."
    exit 1
fi

echo "✓ Validated endpoint: ${AZURE_INGESTION_ENDPOINT}"

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
    
    # Preferir envsubst si está disponible (más confiable para URLs con query parameters)
    if command -v envsubst &> /dev/null; then
        # Exportar variables para envsubst
        # IMPORTANTE: La variable en el template es AZURE_PROMETHEUS_INGESTION_ENDPOINT
        export AZURE_PROMETHEUS_INGESTION_ENDPOINT="$AZURE_INGESTION_ENDPOINT"
        # Usar envsubst con lista explícita de variables (entre comillas simples para evitar expansión)
        # Esto asegura que solo estas variables se sustituyan, preservando el resto del contenido
        envsubst '$NAMESPACE $ENVIRONMENT $AZURE_PROMETHEUS_INGESTION_ENDPOINT $AZURE_CLIENT_ID $AZURE_TENANT_ID $AZURE_CLIENT_SECRET' < "$file"
    else
        # Fallback a Python si está disponible (mejor para URLs complejas)
        if command -v python3 &> /dev/null; then
            python3 <<PYTHON_SCRIPT
import sys
import os

with open('$file', 'r') as f:
    content = f.read()

# Reemplazar variables de forma segura, preservando query parameters
# Usar os.environ para evitar problemas con caracteres especiales
namespace = '${NAMESPACE}'
environment = '${ENVIRONMENT}'
endpoint = '${AZURE_INGESTION_ENDPOINT}'
client_id = '${AZURE_CLIENT_ID}'
tenant_id = '${AZURE_TENANT_ID}'
client_secret = '${AZURE_CLIENT_SECRET}'

replacements = {
    '\${NAMESPACE}': namespace,
    '\${ENVIRONMENT}': environment,
    '\${AZURE_PROMETHEUS_INGESTION_ENDPOINT}': endpoint,
    '\${AZURE_CLIENT_ID}': client_id,
    '\${AZURE_TENANT_ID}': tenant_id,
    '\${AZURE_CLIENT_SECRET}': client_secret
}

for pattern, replacement in replacements.items():
    content = content.replace(pattern, replacement)

sys.stdout.write(content)
PYTHON_SCRIPT
        elif command -v perl &> /dev/null; then
            # Usar perl con escape adecuado para query parameters
            # Escapar solo caracteres que causan problemas en regex, preservar = y ?
            ESCAPED_ENDPOINT=$(printf '%s\n' "$AZURE_INGESTION_ENDPOINT" | perl -pe 's/([\\[\\]\.\*^\$\(\)\+\?\{\|\/])/\\$1/g')
            ESCAPED_CLIENT_ID=$(printf '%s\n' "$AZURE_CLIENT_ID" | perl -pe 's/([\\[\\]\.\*^\$\(\)\+\?\{\|\/])/\\$1/g')
            ESCAPED_TENANT_ID=$(printf '%s\n' "$AZURE_TENANT_ID" | perl -pe 's/([\\[\\]\.\*^\$\(\)\+\?\{\|\/])/\\$1/g')
            ESCAPED_CLIENT_SECRET=$(printf '%s\n' "$AZURE_CLIENT_SECRET" | perl -pe 's/([\\[\\]\.\*^\$\(\)\+\?\{\|\/])/\\$1/g')
            perl -pe "s|\\\$\{NAMESPACE\}|${NAMESPACE}|g; s|\\\$\{ENVIRONMENT\}|${ENVIRONMENT}|g; s|\\\$\{AZURE_PROMETHEUS_INGESTION_ENDPOINT\}|${ESCAPED_ENDPOINT}|g; s|\\\$\{AZURE_CLIENT_ID\}|${ESCAPED_CLIENT_ID}|g; s|\\\$\{AZURE_TENANT_ID\}|${ESCAPED_TENANT_ID}|g; s|\\\$\{AZURE_CLIENT_SECRET\}|${ESCAPED_CLIENT_SECRET}|g" "$file"
        else
            # Usar sed como último recurso - requiere escape cuidadoso
            # Escapar caracteres especiales pero preservar = y ? para query parameters
            ESCAPED_ENDPOINT=$(printf '%s\n' "$AZURE_INGESTION_ENDPOINT" | sed 's/[[\.*^$()+{|]/\\&/g' | sed 's|/|\\/|g')
            ESCAPED_CLIENT_ID=$(printf '%s\n' "$AZURE_CLIENT_ID" | sed 's/[[\.*^$()+{|]/\\&/g' | sed 's|/|\\/|g')
            ESCAPED_TENANT_ID=$(printf '%s\n' "$AZURE_TENANT_ID" | sed 's/[[\.*^$()+{|]/\\&/g' | sed 's|/|\\/|g')
            ESCAPED_CLIENT_SECRET=$(printf '%s\n' "$AZURE_CLIENT_SECRET" | sed 's/[[\.*^$()+{|]/\\&/g' | sed 's|/|\\/|g')
            sed -e "s|\${NAMESPACE}|${NAMESPACE}|g" \
                -e "s|\${ENVIRONMENT}|${ENVIRONMENT}|g" \
                -e "s|\${AZURE_PROMETHEUS_INGESTION_ENDPOINT}|${ESCAPED_ENDPOINT}|g" \
                -e "s|\${AZURE_CLIENT_ID}|${ESCAPED_CLIENT_ID}|g" \
                -e "s|\${AZURE_TENANT_ID}|${ESCAPED_TENANT_ID}|g" \
                -e "s|\${AZURE_CLIENT_SECRET}|${ESCAPED_CLIENT_SECRET}|g" \
                "$file"
        fi
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
# Verificar que la sustitución funciona correctamente
TEMP_CONFIG=$(mktemp)
substitute_vars k8s/monitoring/prometheus-config-remote-write.yaml > "$TEMP_CONFIG"
# Verificar que la URL fue sustituida correctamente
if grep -q '\${AZURE_PROMETHEUS_INGESTION_ENDPOINT}' "$TEMP_CONFIG"; then
    echo "ERROR: Variable substitution failed. AZURE_PROMETHEUS_INGESTION_ENDPOINT not replaced in ConfigMap"
    echo "Endpoint value: ${AZURE_INGESTION_ENDPOINT}"
    echo "Debug: Showing remote_write section:"
    grep -A 5 "remote_write" "$TEMP_CONFIG" || true
    rm -f "$TEMP_CONFIG"
    exit 1
fi

# Verificar que la URL contiene el query parameter api-version
if ! grep -q "api-version=2021-11-01-preview" "$TEMP_CONFIG"; then
    echo "WARNING: URL may be truncated. Expected api-version=2021-11-01-preview in endpoint"
    echo "Debug: Showing remote_write URL:"
    grep -A 2 "url:" "$TEMP_CONFIG" | head -3 || true
    echo "Original endpoint: ${AZURE_INGESTION_ENDPOINT}"
fi

# Verificar que el query parameter completo está presente (si el endpoint lo incluye)
if [[ "$AZURE_INGESTION_ENDPOINT" == *"api-version=2021-11-01-preview"* ]]; then
    if ! grep -q "api-version=2021-11-01-preview" "$TEMP_CONFIG"; then
        echo "ERROR: Query parameter 'api-version=2021-11-01-preview' was truncated during substitution"
        echo "Original endpoint: ${AZURE_INGESTION_ENDPOINT}"
        echo "Debug: Showing remote_write section:"
        grep -A 1 "remote_write:" "$TEMP_CONFIG" | grep "url:" || true
        rm -f "$TEMP_CONFIG"
        exit 1
    fi
fi

# Verificar que la URL contiene https://
if ! grep -q "url: 'https://" "$TEMP_CONFIG"; then
    echo "ERROR: URL in remote_write does not start with https://"
    echo "Debug: Showing remote_write section:"
    grep -A 3 "remote_write" "$TEMP_CONFIG" | head -5
    rm -f "$TEMP_CONFIG"
    exit 1
fi

echo "✓ URL substitution verified"

# Mostrar la URL que se va a usar (para debugging)
echo "Debug: URL that will be used:"
grep -A 1 "remote_write:" "$TEMP_CONFIG" | grep "url:" || true

# Eliminar el ConfigMap existente si existe para forzar la actualización
if kubectl --kubeconfig="$KCFG" get configmap prometheus-config -n "${NAMESPACE}" &>/dev/null; then
    echo "Deleting existing ConfigMap to force update..."
    kubectl --kubeconfig="$KCFG" delete configmap prometheus-config -n "${NAMESPACE}" || true
    sleep 2
fi

# Aplicar el nuevo ConfigMap
if kubectl --kubeconfig="$KCFG" apply -f "$TEMP_CONFIG"; then
    echo "✓ ConfigMap deployed"
    
    # Verificar que la URL se aplicó correctamente
    echo "Verifying ConfigMap was updated correctly..."
    ACTUAL_URL=$(kubectl --kubeconfig="$KCFG" get configmap prometheus-config -n "${NAMESPACE}" -o jsonpath='{.data.prometheus\.yml}' | grep -A 1 "remote_write:" | grep "url:" | sed "s/.*url: '\(.*\)'.*/\1/" || echo "")
    if [[ "$ACTUAL_URL" == *"https://"* ]]; then
        echo "✓ ConfigMap verified: URL starts with https://"
        # Verificar que el query parameter completo está presente
        if [[ "$ACTUAL_URL" == *"api-version=2021-11-01-preview"* ]]; then
            echo "✓ Query parameter completo presente"
        elif [[ "$ACTUAL_URL" == *"api-version"* ]]; then
            echo "⚠ WARNING: Query parameter está truncado (falta el valor)"
            echo "  Actual: ${ACTUAL_URL}"
            echo "  Esperado: ${AZURE_INGESTION_ENDPOINT}"
            echo "  Diferencia: Falta '=2021-11-01-preview'"
        else
            echo "⚠ Warning: No se encontró query parameter api-version"
        fi
        echo "  URL completa: ${ACTUAL_URL}"
    else
        echo "⚠ Warning: ConfigMap URL may not be correct. Actual: ${ACTUAL_URL}"
        echo "Expected: ${AZURE_INGESTION_ENDPOINT}"
    fi
else
    echo "✗ Failed to deploy ConfigMap"
    rm -f "$TEMP_CONFIG"
    exit 1
fi
rm -f "$TEMP_CONFIG"

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

