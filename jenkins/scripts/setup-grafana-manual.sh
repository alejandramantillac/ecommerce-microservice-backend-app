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

# Verificar si Grafana ya existe
if az grafana show --name "$GRAFANA_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo "Grafana '${GRAFANA_NAME}' already exists, skipping creation"
    exit 0
fi

# Crear Grafana con Azure CLI (soporta versión 11)
echo "Creating Grafana with Azure CLI..."
az grafana create \
    --name "$GRAFANA_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "$SKU" \
    --api-key-enabled true \
    --public-network-access Enabled \
    --grafana-major-version 11

echo "✓ Grafana created successfully"

# Si se proporciona el Monitor Workspace ID, integrarlo
if [ -n "$MONITOR_WORKSPACE_ID" ]; then
    echo "Integrating with Azure Monitor Workspace..."
    az grafana integration create \
        --name "$GRAFANA_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --monitor-workspace "$MONITOR_WORKSPACE_ID" || echo "Warning: Integration may already exist"
fi

echo ""
echo "========================================="
echo "Grafana setup completed!"
echo "========================================="
echo "To import to Terraform, run:"
echo "terraform import module.monitoring.azurerm_dashboard_grafana.grafana \\"
echo "  /subscriptions/SUBSCRIPTION_ID/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Dashboard/grafana/${GRAFANA_NAME}"
echo ""

