#!/bin/bash
# Script para crear Grafana manualmente con Azure CLI cuando Terraform no soporta la versión requerida
# Usage: ./jenkins/scripts/setup-grafana-manual.sh <resource-group> <grafana-name> <location> <sku> <monitor-workspace-id>

set -e

RESOURCE_GROUP="${1}"
GRAFANA_NAME="${2}"
LOCATION="${3}"
SKU="${4:-Essential}"
MONITOR_WORKSPACE_ID="${5}"

if [ -z "$RESOURCE_GROUP" ] || [ -z "$GRAFANA_NAME" ] || [ -z "$LOCATION" ]; then
    echo "Usage: $0 <resource-group> <grafana-name> <location> [sku] [monitor-workspace-id]"
    echo "Example: $0 ecommerce-staging-rg ecom-stg-grafana eastus2 Essential"
    exit 1
fi

echo "========================================="
echo "Creating Azure Managed Grafana"
echo "========================================="
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Grafana Name: ${GRAFANA_NAME}"
echo "Location: ${LOCATION}"
echo "SKU: ${SKU}"
echo "========================================="

# Instalar extensión amg si no está instalada
echo "Checking for Azure CLI Grafana extension..."
if ! az extension show --name amg &>/dev/null; then
    echo "Installing Azure CLI Grafana extension (amg)..."
    az config set extension.dynamic_install_allow_preview=true
    az extension add --name amg --yes || {
        echo "Warning: Failed to install amg extension, trying alternative method..."
        az extension add --source https://aka.ms/az-amg-install --yes || {
            echo "Error: Could not install amg extension. Please install manually: az extension add --name amg"
            exit 1
        }
    }
fi

# Verificar si Grafana ya existe
if az grafana show --name "$GRAFANA_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo "Grafana '${GRAFANA_NAME}' already exists, skipping creation"
    exit 0
fi

# Crear Grafana con Azure CLI (soporta versión 11)
# Nota: La sintaxis puede variar según la versión de la extensión
echo "Creating Grafana with Azure CLI..."
# Intentar primero con versión explícita
if ! az grafana create \
    --name "$GRAFANA_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "$SKU" \
    --public-network-access Enabled \
    --grafana-major-version 11 2>&1; then
    echo "Warning: Failed with explicit version, trying without version specification..."
    # Intentar sin especificar versión (Azure usará la predeterminada v11)
    if ! az grafana create \
        --name "$GRAFANA_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "$SKU" \
        --public-network-access Enabled 2>&1; then
        echo "Error: Failed to create Grafana with Azure CLI"
        exit 1
    fi
fi

echo "✓ Grafana created successfully"

# Habilitar API keys después de la creación (opcional, Terraform lo configurará)
echo "Attempting to enable API keys (this may not be supported in all CLI versions)..."
az grafana api-key enable \
    --name "$GRAFANA_NAME" \
    --resource-group "$RESOURCE_GROUP" 2>/dev/null || \
az grafana update \
    --name "$GRAFANA_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --api-key Enabled 2>/dev/null || \
echo "Note: API keys will be configured by Terraform after import"

# Si se proporciona el Monitor Workspace ID, integrarlo
if [ -n "$MONITOR_WORKSPACE_ID" ]; then
    echo "Integrating with Azure Monitor Workspace..."
    az grafana integration create \
        --name "$GRAFANA_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --monitor-workspace "$MONITOR_WORKSPACE_ID" || echo "Warning: Integration may already exist or failed"
fi

echo ""
echo "========================================="
echo "Grafana setup completed!"
echo "========================================="
echo "To import to Terraform, run:"
echo "terraform import module.monitoring.azurerm_dashboard_grafana.grafana \\"
echo "  /subscriptions/SUBSCRIPTION_ID/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Dashboard/grafana/${GRAFANA_NAME}"
echo ""

