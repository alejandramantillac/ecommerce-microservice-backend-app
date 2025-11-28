#!/bin/bash
# Script para generar API Key de Grafana automáticamente
# Usage: ./jenkins/scripts/generate-grafana-api-key.sh <resource-group> <grafana-name> <key-name>

set -e

RESOURCE_GROUP="${1}"
GRAFANA_NAME="${2}"
KEY_NAME="${3:-jenkins-migration}"

if [ -z "$RESOURCE_GROUP" ] || [ -z "$GRAFANA_NAME" ]; then
    echo "Usage: $0 <resource-group> <grafana-name> [key-name]"
    echo "Example: $0 ecommerce-staging-rg ecom-stg-grafana jenkins-migration"
    exit 1
fi

echo "========================================="
echo "Generating Grafana API Key"
echo "========================================="
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Grafana Name: ${GRAFANA_NAME}"
echo "Key Name: ${KEY_NAME}"
echo "========================================="

# Verificar que Grafana existe
if ! az grafana show --name "$GRAFANA_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo "Error: Grafana '${GRAFANA_NAME}' not found in resource group '${RESOURCE_GROUP}'"
    exit 1
fi

# Eliminar API key existente si existe (para evitar duplicados)
echo ""
echo "Checking for existing API key '${KEY_NAME}'..."
if az grafana api-key list --name "$GRAFANA_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='${KEY_NAME}'].name" -o tsv 2>/dev/null | grep -q "^${KEY_NAME}$"; then
    echo "  Found existing API key '${KEY_NAME}', deleting it..."
    az grafana api-key delete \
        --name "$GRAFANA_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --key "$KEY_NAME" \
        --yes 2>/dev/null || true
    echo "  ✓ Old API key deleted"
fi

# Generar nueva API key
echo ""
echo "Generating new API key '${KEY_NAME}'..."
API_KEY_RESPONSE=$(az grafana api-key create \
    --name "$GRAFANA_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --key "$KEY_NAME" \
    --role Admin \
    --time-to-live 0 \
    -o json 2>&1)

if [ $? -eq 0 ]; then
    # Extraer la API key de la respuesta
    API_KEY=$(echo "$API_KEY_RESPONSE" | grep -o '"key":"[^"]*' | cut -d'"' -f4)
    
    if [ -z "$API_KEY" ]; then
        # Intentar otro método de extracción
        API_KEY=$(echo "$API_KEY_RESPONSE" | jq -r '.key // empty' 2>/dev/null || echo "")
    fi
    
    if [ -n "$API_KEY" ]; then
        # Guardar la API key en un archivo primero (para Jenkins)
        if [ -n "$WORKSPACE" ]; then
            echo "$API_KEY" > "${WORKSPACE}/.grafana-api-key" 2>/dev/null || true
        fi
        
        # Imprimir mensajes informativos a stderr (para que no interfieran con la extracción)
        echo "✓ API Key generated successfully" >&2
        echo "" >&2
        echo "=========================================" >&2
        echo "API Key: ${API_KEY}" >&2
        echo "=========================================" >&2
        echo "" >&2
        
        # Imprimir SOLO la API key a stdout (para que Jenkins pueda capturarla)
        echo "$API_KEY"
        
        exit 0
    else
        echo "Error: Could not extract API key from response"
        echo "Response: ${API_KEY_RESPONSE}"
        exit 1
    fi
else
    echo "Error: Failed to generate API key"
    echo "Response: ${API_KEY_RESPONSE}"
    exit 1
fi

