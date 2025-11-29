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

# Todos los mensajes informativos van a stderr
echo "=========================================" >&2
echo "Generating Grafana API Key" >&2
echo "=========================================" >&2
echo "Resource Group: ${RESOURCE_GROUP}" >&2
echo "Grafana Name: ${GRAFANA_NAME}" >&2
echo "Key Name: ${KEY_NAME}" >&2
echo "=========================================" >&2

# Verificar que Grafana existe
if ! az grafana show --name "$GRAFANA_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo "Error: Grafana '${GRAFANA_NAME}' not found in resource group '${RESOURCE_GROUP}'" >&2
    exit 1
fi

# Obtener el endpoint de Grafana
echo "" >&2
echo "Getting Grafana endpoint..." >&2
GRAFANA_INFO=$(az grafana show --name "$GRAFANA_NAME" --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null)
if [ -z "$GRAFANA_INFO" ]; then
    echo "Error: Grafana '${GRAFANA_NAME}' not found in resource group '${RESOURCE_GROUP}'" >&2
    exit 1
fi

# Extraer el endpoint de Grafana
if command -v jq &> /dev/null; then
    GRAFANA_ENDPOINT=$(echo "$GRAFANA_INFO" | jq -r '.properties.endpoint // empty' 2>/dev/null)
else
    GRAFANA_ENDPOINT=$(echo "$GRAFANA_INFO" | grep -o '"endpoint":"[^"]*' | cut -d'"' -f4)
fi

if [ -z "$GRAFANA_ENDPOINT" ] || [ "$GRAFANA_ENDPOINT" = "null" ]; then
    echo "Error: Could not get Grafana endpoint" >&2
    exit 1
fi

echo "  Grafana endpoint: ${GRAFANA_ENDPOINT}" >&2

# Obtener un token de Azure para autenticarse con Grafana
# Intentar diferentes métodos de autenticación
echo "" >&2
echo "Getting Azure access token..." >&2

# Método 1: Token para el recurso de Grafana
AZURE_TOKEN=$(az account get-access-token --resource https://grafana.azure.com --query accessToken -o tsv 2>/dev/null)

# Si no funciona, intentar con el endpoint de Grafana directamente
if [ -z "$AZURE_TOKEN" ]; then
    AZURE_TOKEN=$(az account get-access-token --resource "${GRAFANA_ENDPOINT}" --query accessToken -o tsv 2>/dev/null)
fi

# Si aún no funciona, usar token genérico de Azure
if [ -z "$AZURE_TOKEN" ]; then
    AZURE_TOKEN=$(az account get-access-token --query accessToken -o tsv 2>/dev/null)
fi

if [ -z "$AZURE_TOKEN" ]; then
    echo "Error: Could not get Azure access token" >&2
    exit 1
fi

# Azure Managed Grafana ahora usa Service Accounts en lugar de API Keys
echo "" >&2
echo "Creating Service Account '${KEY_NAME}'..." >&2

# Crear Service Account
SERVICE_ACCOUNT_BODY=$(cat <<EOF
{
  "name": "${KEY_NAME}",
  "role": "Admin",
  "isDisabled": false
}
EOF
)

SERVICE_ACCOUNT_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer ${AZURE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${SERVICE_ACCOUNT_BODY}" \
    "${GRAFANA_ENDPOINT}/api/serviceaccounts" 2>&1)

HTTP_CODE=$(echo "$SERVICE_ACCOUNT_RESPONSE" | tail -n1)
SERVICE_ACCOUNT_JSON=$(echo "$SERVICE_ACCOUNT_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "200" ]; then
    # Si el service account ya existe, intentar obtenerlo
    if echo "$SERVICE_ACCOUNT_JSON" | grep -q "already exists"; then
        echo "  Service Account already exists, retrieving it..." >&2
        SERVICE_ACCOUNTS_LIST=$(curl -s -X GET \
            -H "Authorization: Bearer ${AZURE_TOKEN}" \
            -H "Content-Type: application/json" \
            "${GRAFANA_ENDPOINT}/api/serviceaccounts/search?query=${KEY_NAME}" 2>&1)
        
        if command -v jq &> /dev/null; then
            SERVICE_ACCOUNT_ID=$(echo "$SERVICE_ACCOUNTS_LIST" | jq -r ".serviceAccounts[] | select(.name==\"${KEY_NAME}\") | .id" 2>/dev/null | head -1)
        else
            SERVICE_ACCOUNT_ID=$(echo "$SERVICE_ACCOUNTS_LIST" | grep -oE '"id":[0-9]+' | head -1 | cut -d':' -f2)
        fi
        
        if [ -z "$SERVICE_ACCOUNT_ID" ]; then
            echo "Error: Service Account exists but could not retrieve ID" >&2
            echo "Response: ${SERVICE_ACCOUNTS_LIST}" >&2
            exit 1
        fi
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        echo "" >&2
        echo "⚠ Authentication Error (HTTP ${HTTP_CODE})" >&2
        echo "Azure Managed Grafana requires manual creation of Service Accounts." >&2
        echo "Please create it manually via Grafana UI (see docs/MANUAL_GRAFANA_API_KEY.md)" >&2
        exit 1
    else
        echo "Error: Failed to create Service Account (HTTP ${HTTP_CODE})" >&2
        echo "Response: ${SERVICE_ACCOUNT_JSON}" >&2
        exit 1
    fi
else
    # Extraer el ID del Service Account creado
    if command -v jq &> /dev/null; then
        SERVICE_ACCOUNT_ID=$(echo "$SERVICE_ACCOUNT_JSON" | jq -r '.id // empty' 2>/dev/null)
    else
        SERVICE_ACCOUNT_ID=$(echo "$SERVICE_ACCOUNT_JSON" | grep -oE '"id":[0-9]+' | head -1 | cut -d':' -f2)
    fi
fi

if [ -z "$SERVICE_ACCOUNT_ID" ]; then
    echo "Error: Could not get Service Account ID" >&2
    exit 1
fi

echo "  ✓ Service Account created/found (ID: ${SERVICE_ACCOUNT_ID})" >&2

# Crear un Token para el Service Account
echo "" >&2
echo "Creating token for Service Account..." >&2
TOKEN_BODY=$(cat <<EOF
{
  "name": "${KEY_NAME}-token",
  "secondsToLive": 0
}
EOF
)

TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer ${AZURE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${TOKEN_BODY}" \
    "${GRAFANA_ENDPOINT}/api/serviceaccounts/${SERVICE_ACCOUNT_ID}/tokens" 2>&1)

TOKEN_HTTP_CODE=$(echo "$TOKEN_RESPONSE" | tail -n1)
TOKEN_JSON=$(echo "$TOKEN_RESPONSE" | sed '$d')

if [ "$TOKEN_HTTP_CODE" != "201" ] && [ "$TOKEN_HTTP_CODE" != "200" ]; then
    echo "Error: Failed to create token (HTTP ${TOKEN_HTTP_CODE})" >&2
    echo "Response: ${TOKEN_JSON}" >&2
    exit 1
fi

# Extraer el token
if command -v jq &> /dev/null; then
    API_KEY=$(echo "$TOKEN_JSON" | jq -r '.key // empty' 2>/dev/null)
else
    API_KEY=$(echo "$TOKEN_JSON" | grep -o '"key":"[^"]*' | cut -d'"' -f4)
fi

if [ -z "$API_KEY" ] || [ "$API_KEY" = "null" ]; then
    echo "Error: Could not extract token from response" >&2
    echo "Response: ${TOKEN_JSON}" >&2
    exit 1
fi

# Guardar la API key en un archivo primero (para Jenkins)
if [ -n "$WORKSPACE" ]; then
    echo "$API_KEY" > "${WORKSPACE}/.grafana-api-key" 2>/dev/null || true
fi

# Imprimir mensajes informativos a stderr (para que no interfieran con la extracción)
echo "✓ API Key (Service Account Token) generated successfully" >&2
echo "" >&2
echo "=========================================" >&2
echo "API Key: ${API_KEY}" >&2
echo "=========================================" >&2
echo "" >&2

# Imprimir SOLO la API key a stdout (para que Jenkins pueda capturarla)
echo "$API_KEY"

exit 0

