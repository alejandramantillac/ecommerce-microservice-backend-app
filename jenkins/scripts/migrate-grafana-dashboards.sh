#!/bin/bash
# Script para migrar dashboards de Grafana local a Azure Managed Grafana
# Usage: ./jenkins/scripts/migrate-grafana-dashboards.sh <grafana-endpoint> <grafana-api-key> <dashboards-dir>

GRAFANA_ENDPOINT="${1}"
GRAFANA_API_KEY="${2}"
DASHBOARDS_DIR="${3:-k8s/monitoring/grafana-dashboards}"

# Validaciones críticas - deben fallar si no se cumplen
if [ -z "$GRAFANA_ENDPOINT" ] || [ -z "$GRAFANA_API_KEY" ]; then
    echo "Usage: $0 <grafana-endpoint> <grafana-api-key> [dashboards-dir]"
    echo "Example: $0 https://grafana-xxx.eastus.grafana.azure.com api-key k8s/monitoring/grafana-dashboards"
    exit 1
fi

# No usar set -e para permitir que el script continúe aunque algunos dashboards fallen
# Las funciones manejan sus propios errores y retornan códigos de salida apropiados
set +e

echo "========================================="
echo "Migrating Grafana Dashboards"
echo "Grafana Endpoint: ${GRAFANA_ENDPOINT}"
echo "Dashboards Directory: ${DASHBOARDS_DIR}"
echo "========================================="

# Check if directory exists
if [ ! -d "$DASHBOARDS_DIR" ]; then
    echo "Error: Dashboards directory not found: ${DASHBOARDS_DIR}"
    exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed"
    exit 1
fi

# Check if jq is available (for JSON processing)
if ! command -v jq &> /dev/null; then
    echo "Warning: jq is not installed. JSON processing may be limited."
    JQ_AVAILABLE=false
else
    JQ_AVAILABLE=true
fi

# Function to check if dashboard exists
dashboard_exists() {
    local dashboard_uid="$1"
    if [ -z "$dashboard_uid" ]; then
        return 1
    fi
    
    local response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
        "${GRAFANA_ENDPOINT}/api/dashboards/uid/${dashboard_uid}" 2>/dev/null || echo "")
    
    local http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" = "200" ]; then
        return 0
    else
        return 1
    fi
}

# Function to get dashboard UID from JSON
get_dashboard_uid() {
    local dashboard_file="$1"
    if [ "$JQ_AVAILABLE" = true ] && [ -f "$dashboard_file" ]; then
        local uid=$(cat "$dashboard_file" | jq -r '.uid // .dashboard.uid // empty' 2>/dev/null)
        echo "$uid"
    fi
}

# Function to create/update dashboard
upload_dashboard() {
    local dashboard_file="$1"
    local dashboard_name=$(basename "$dashboard_file" .json)
    
    echo ""
    echo "Processing dashboard: ${dashboard_name}"
    
    # Read dashboard JSON
    if [ ! -f "$dashboard_file" ]; then
        echo "  ⚠ Warning: File not found: ${dashboard_file}"
        return 1
    fi
    
    # Get dashboard UID if available
    local dashboard_uid=$(get_dashboard_uid "$dashboard_file")
    local exists=false
    
    # Check if dashboard already exists
    if [ -n "$dashboard_uid" ] && dashboard_exists "$dashboard_uid"; then
        exists=true
        echo "  Dashboard already exists (UID: ${dashboard_uid}), updating..."
    fi
    
    # Prepare dashboard payload
    # Azure Managed Grafana expects the dashboard in a specific format
    local dashboard_json=$(cat "$dashboard_file")
    
    # Update dashboard metadata for Azure Managed Grafana
    if [ "$JQ_AVAILABLE" = true ]; then
        if [ "$exists" = true ] && [ -n "$dashboard_uid" ]; then
            # Keep UID for update
            dashboard_json=$(echo "$dashboard_json" | jq "
                .id = null |
                .version = 0 |
                .overwrite = true |
                .dashboard.title = .title // .dashboard.title |
                .dashboard.uid = \"${dashboard_uid}\" |
                .dashboard.id = null |
                .dashboard.version = 0
            ")
        else
            # Remove UID for new dashboard
            dashboard_json=$(echo "$dashboard_json" | jq '
                .id = null |
                .uid = null |
                .version = 0 |
                .overwrite = true |
                .dashboard.title = .title // .dashboard.title |
                .dashboard.uid = null |
                .dashboard.id = null |
                .dashboard.version = 0
            ')
        fi
    fi
    
    # Create payload
    local payload=$(cat <<EOF
{
  "dashboard": ${dashboard_json},
  "overwrite": true,
  "folderId": 0
}
EOF
)
    
    # Upload dashboard
    local response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
        "${GRAFANA_ENDPOINT}/api/dashboards/db" \
        -d "$payload")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo "  ✓ Dashboard ${exists:+updated}${exists:-uploaded} successfully: ${dashboard_name}"
        if [ "$JQ_AVAILABLE" = true ]; then
            local new_uid=$(echo "$body" | jq -r '.uid // empty')
            if [ -n "$new_uid" ]; then
                echo "    Dashboard UID: ${new_uid}"
            fi
        fi
        return 0
    elif [ "$http_code" -eq 403 ]; then
        # Check for quota error
        if echo "$body" | grep -qi "quota\|limit"; then
            echo "  ✗ Failed: Dashboard quota reached (HTTP ${http_code})"
            echo ""
            echo "  ⚠ Your Grafana plan has reached the dashboard limit."
            echo "  Solutions:"
            echo "    1. Delete unused dashboards in Grafana UI"
            echo "    2. Upgrade to Standard SKU for higher limits"
            echo "    3. Use folder organization to manage dashboards"
            echo ""
            echo "  Response: ${body}"
            return 1
        else
            echo "  ✗ Failed: Permission denied (HTTP ${http_code})"
            echo "    Response: ${body}"
            return 1
        fi
    else
        echo "  ✗ Failed to upload dashboard: ${dashboard_name}"
        echo "    HTTP Code: ${http_code}"
        echo "    Response: ${body}"
        return 1
    fi
}

# Function to configure Prometheus datasource
configure_datasource() {
    echo ""
    echo "Configuring Prometheus datasource..."
    
    local prometheus_query_endpoint="${AZURE_PROMETHEUS_QUERY_ENDPOINT}"
    
    if [ -z "$prometheus_query_endpoint" ]; then
        echo "  ⚠ Warning: AZURE_PROMETHEUS_QUERY_ENDPOINT not set. Skipping datasource configuration."
        return 1
    fi
    
    # Check if datasource exists
    local existing_ds=$(curl -s \
        -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
        "${GRAFANA_ENDPOINT}/api/datasources/name/Prometheus" 2>/dev/null || echo "")
    
    if [ -n "$existing_ds" ] && [ "$(echo "$existing_ds" | jq -r '.id // empty' 2>/dev/null)" != "" ]; then
        local ds_id=$(echo "$existing_ds" | jq -r '.id')
        local ds_type=$(echo "$existing_ds" | jq -r '.type // empty' 2>/dev/null)
        local ds_json_data=$(echo "$existing_ds" | jq -r '.jsonData // {}' 2>/dev/null)
        local has_azure_auth=$(echo "$ds_json_data" | jq -r '.azureAuthType // empty' 2>/dev/null)
        
        # If it's a standard prometheus datasource without Azure AD auth, delete it
        # Azure will recreate it automatically with proper authentication via integration
        if [ "$ds_type" = "prometheus" ] && [ -z "$has_azure_auth" ]; then
            echo "  Removing datasource without Azure AD authentication (ID: ${ds_id})..."
            local delete_response=$(curl -s -w "\n%{http_code}" \
                -X DELETE \
                -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
                "${GRAFANA_ENDPOINT}/api/datasources/${ds_id}" 2>/dev/null || echo "")
            
            local delete_http_code=$(echo "$delete_response" | tail -n1)
            if [ "$delete_http_code" = "200" ]; then
                echo "  ✓ Datasource removed. Waiting for Azure to recreate it automatically..."
                
                # Wait up to 2 minutes for Azure to recreate
                local wait_count=0
                local max_wait=24
                
                while [ $wait_count -lt $max_wait ]; do
                    sleep 5
                    local new_ds=$(curl -s \
                        -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
                        "${GRAFANA_ENDPOINT}/api/datasources/name/Prometheus" 2>/dev/null || echo "")
                    
                    if [ -n "$new_ds" ] && [ "$(echo "$new_ds" | jq -r '.id // empty' 2>/dev/null)" != "" ]; then
                        local new_ds_json_data=$(echo "$new_ds" | jq -r '.jsonData // {}' 2>/dev/null)
                        local new_has_azure_auth=$(echo "$new_ds_json_data" | jq -r '.azureAuthType // empty' 2>/dev/null)
                        
                        if [ -n "$new_has_azure_auth" ]; then
                            echo "  ✓ Azure recreated datasource with Azure AD authentication"
                            return 0
                        fi
                    fi
                    wait_count=$((wait_count + 1))
                done
                
                echo "  ⚠ Azure did not recreate datasource automatically within timeout"
                return 1
            else
                echo "  ✗ Failed to remove datasource (HTTP ${delete_http_code})"
                return 1
            fi
        else
            echo "  ✓ Datasource exists with proper Azure AD authentication"
            return 0
        fi
    else
        # Datasource doesn't exist - Azure should create it automatically
        echo "  Datasource not found. Waiting for Azure to create it automatically..."
        
        local wait_count=0
        local max_wait=24
        
        while [ $wait_count -lt $max_wait ]; do
            sleep 5
            local new_ds=$(curl -s \
                -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
                "${GRAFANA_ENDPOINT}/api/datasources/name/Prometheus" 2>/dev/null || echo "")
            
            if [ -n "$new_ds" ] && [ "$(echo "$new_ds" | jq -r '.id // empty' 2>/dev/null)" != "" ]; then
                echo "  ✓ Datasource created automatically by Azure"
                return 0
            fi
            wait_count=$((wait_count + 1))
        done
        
        echo "  ⚠ Datasource was not created automatically within timeout"
        return 1
    fi
}

# Main execution
echo ""
echo "Step 1: Configuring Prometheus datasource..."
configure_datasource || echo "  ⚠ Continuing without datasource configuration..."

echo ""
echo "Step 2: Uploading dashboards..."
dashboard_count=0
success_count=0
failed_count=0

for dashboard_file in "${DASHBOARDS_DIR}"/*.json; do
    if [ -f "$dashboard_file" ]; then
        if upload_dashboard "$dashboard_file"; then
            ((success_count++))
        else
            ((failed_count++))
        fi
        ((dashboard_count++))
    fi
done

echo ""
echo "========================================="
echo "Migration Summary"
echo "========================================="
echo "Total dashboards processed: ${dashboard_count}"
echo "Successfully uploaded/updated: ${success_count}"
echo "Failed: ${failed_count}"
echo ""

if [ $failed_count -gt 0 ]; then
    echo "⚠ Some dashboards failed to upload."
    echo ""
    echo "Common causes:"
    echo "  - Dashboard quota reached (upgrade plan or delete unused dashboards)"
    echo "  - Permission issues (check API key permissions)"
    echo "  - Invalid dashboard JSON format"
    echo ""
    echo "Check the logs above for specific error messages."
fi

echo ""
echo "Access your dashboards at: ${GRAFANA_ENDPOINT}"
echo "========================================="

# Only fail if ALL dashboards failed
if [ $success_count -eq 0 ] && [ $dashboard_count -gt 0 ]; then
    echo ""
    echo "❌ All dashboards failed to upload. Please check the errors above."
    exit 1
elif [ $failed_count -gt 0 ]; then
    echo ""
    echo "⚠ Migration completed with ${failed_count} failure(s). Some dashboards may not be available."
    # Don't exit with error if at least some succeeded
    exit 0
fi

