#!/bin/bash
# Script para migrar dashboards de Grafana local a Azure Managed Grafana
# Usage: ./jenkins/scripts/migrate-grafana-dashboards.sh <grafana-endpoint> <grafana-api-key> <dashboards-dir>

set -e

GRAFANA_ENDPOINT="${1}"
GRAFANA_API_KEY="${2}"
DASHBOARDS_DIR="${3:-k8s/monitoring/grafana-dashboards}"

if [ -z "$GRAFANA_ENDPOINT" ] || [ -z "$GRAFANA_API_KEY" ]; then
    echo "Usage: $0 <grafana-endpoint> <grafana-api-key> [dashboards-dir]"
    echo "Example: $0 https://grafana-xxx.eastus.grafana.azure.com api-key k8s/monitoring/grafana-dashboards"
    exit 1
fi

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
    
    # Prepare dashboard payload
    # Azure Managed Grafana expects the dashboard in a specific format
    local dashboard_json=$(cat "$dashboard_file")
    
    # Update dashboard metadata for Azure Managed Grafana
    if [ "$JQ_AVAILABLE" = true ]; then
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
        echo "  ✓ Dashboard uploaded successfully: ${dashboard_name}"
        if [ "$JQ_AVAILABLE" = true ]; then
            local dashboard_uid=$(echo "$body" | jq -r '.uid // empty')
            if [ -n "$dashboard_uid" ]; then
                echo "    Dashboard UID: ${dashboard_uid}"
            fi
        fi
        return 0
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
    
    # Get Prometheus query endpoint from environment or parameter
    local prometheus_query_endpoint="${AZURE_PROMETHEUS_QUERY_ENDPOINT}"
    
    if [ -z "$prometheus_query_endpoint" ]; then
        echo "  ⚠ Warning: AZURE_PROMETHEUS_QUERY_ENDPOINT not set. Skipping datasource configuration."
        echo "    You may need to configure the Prometheus datasource manually in Grafana."
        return 1
    fi
    
    local datasource_payload=$(cat <<EOF
{
  "name": "Prometheus",
  "type": "prometheus",
  "access": "proxy",
  "url": "${prometheus_query_endpoint}",
  "isDefault": true,
  "jsonData": {
    "timeInterval": "30s",
    "httpMethod": "POST"
  }
}
EOF
)
    
    # Check if datasource already exists
    local existing_ds=$(curl -s \
        -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
        "${GRAFANA_ENDPOINT}/api/datasources/name/Prometheus" || echo "")
    
    if [ -n "$existing_ds" ] && [ "$(echo "$existing_ds" | jq -r '.id // empty' 2>/dev/null)" != "" ]; then
        local ds_id=$(echo "$existing_ds" | jq -r '.id')
        echo "  Updating existing Prometheus datasource (ID: ${ds_id})..."
        
        local response=$(curl -s -w "\n%{http_code}" \
            -X PUT \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
            "${GRAFANA_ENDPOINT}/api/datasources/${ds_id}" \
            -d "$datasource_payload")
        
        local http_code=$(echo "$response" | tail -n1)
        if [ "$http_code" -eq 200 ]; then
            echo "  ✓ Datasource updated successfully"
            return 0
        else
            echo "  ✗ Failed to update datasource (HTTP ${http_code})"
            return 1
        fi
    else
        echo "  Creating new Prometheus datasource..."
        
        local response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
            "${GRAFANA_ENDPOINT}/api/datasources" \
            -d "$datasource_payload")
        
        local http_code=$(echo "$response" | tail -n1)
        if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
            echo "  ✓ Datasource created successfully"
            return 0
        else
            echo "  ✗ Failed to create datasource (HTTP ${http_code})"
            return 1
        fi
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
echo "Successfully uploaded: ${success_count}"
echo "Failed: ${failed_count}"
echo ""
echo "Access your dashboards at: ${GRAFANA_ENDPOINT}"
echo "========================================="

if [ $failed_count -gt 0 ]; then
    exit 1
fi

