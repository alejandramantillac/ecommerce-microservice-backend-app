terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80"  # Permitir versiones más recientes que soporten Grafana v11
    }
  }
}

locals {
  # Sanitizar nombres para cumplir con restricciones de Azure
  # Grafana: 2-23 caracteres, solo letras, números y guiones, debe empezar con letra
  # Acortar el prefijo si es necesario para que el nombre completo sea <= 23 caracteres
  name_prefix_short = replace(replace(lower(var.name_prefix), "ecommerce", "ecom"), "staging", "stg")
  grafana_name = length("${local.name_prefix_short}-grafana") > 23 ? "${substr(local.name_prefix_short, 0, 15)}-grafana" : "${local.name_prefix_short}-grafana"
  
  # Prometheus workspace: similar pero puede ser más largo
  prometheus_ws_name = "${var.name_prefix}-prometheus-ws"
}

# Azure Monitor Workspace (Prometheus gestionado)
# Nota: Los providers (Microsoft.Monitor, Microsoft.Dashboard, microsoft.insights) 
# se registran automáticamente por Azure cuando se crean los recursos que los necesitan.
# No es necesario registrarlos manualmente.
resource "azurerm_monitor_workspace" "prometheus" {
  name                = local.prometheus_ws_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Azure Managed Grafana
# IMPORTANTE: Hay una incompatibilidad: Azure requiere v11 pero el provider solo acepta v9/v10
# Solución: Crear Grafana con Azure CLI primero (ver jenkins/scripts/setup-grafana-manual.sh)
# Luego importar a Terraform: terraform import module.monitoring.azurerm_dashboard_grafana.grafana <resource-id>
# 
# Si Grafana ya existe, este recurso lo gestionará. Si no existe, debe crearse manualmente primero.
resource "azurerm_dashboard_grafana" "grafana" {
  name                              = local.grafana_name
  resource_group_name               = var.resource_group_name
  location                          = var.location
  api_key_enabled                   = true
  # deterministic_outbound_ip_enabled solo está disponible en SKU Standard
  deterministic_outbound_ip_enabled = var.grafana_sku == "Standard" ? true : false
  public_network_access_enabled     = var.grafana_public_access
  sku                               = var.grafana_sku
  # Usar "10" temporalmente - Azure lo actualizará a "11" automáticamente o debe crearse con CLI primero
  grafana_major_version             = "10"
  # zone_redundancy_enabled solo está disponible en SKU Standard
  zone_redundancy_enabled           = var.grafana_sku == "Standard" ? var.grafana_zone_redundancy : false
  
  lifecycle {
    # Ignorar cambios en la versión ya que Azure la gestiona
    ignore_changes = [grafana_major_version]
  }

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.prometheus.id
  }

  tags = var.tags
}

# Role assignment para que Grafana pueda leer del Monitor Workspace
resource "azurerm_role_assignment" "grafana_monitor_reader" {
  scope                = azurerm_monitor_workspace.prometheus.id
  role_definition_name  = "Monitoring Reader"
  principal_id          = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}

# Role assignment para que Grafana pueda escribir métricas (opcional)
resource "azurerm_role_assignment" "grafana_monitor_data_publisher" {
  scope                = azurerm_monitor_workspace.prometheus.id
  role_definition_name  = "Monitoring Metrics Publisher"
  principal_id          = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}

# Data Collection Rule para Prometheus scraping desde AKS
resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                = "${local.name_prefix_short}-prom-dcr"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.prometheus.id
      name               = "prometheus-ws"
    }
  }

  data_sources {
    prometheus_forwarder {
      name    = "prometheus-ds"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["prometheus-ws"]
    transform_kql = "source"
  }

  tags = var.tags
}

# Data Collection Endpoint para el agente
resource "azurerm_monitor_data_collection_endpoint" "prometheus" {
  name                = "${local.name_prefix_short}-prom-dce"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"
  tags                = var.tags
}

# Asociación del DCR con el cluster AKS
resource "azurerm_monitor_data_collection_rule_association" "aks" {
  name                    = "${local.name_prefix_short}-aks-dcr"
  target_resource_id      = var.aks_cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus.id
  description             = "Association for Prometheus metrics collection from AKS"
}

# Azure Monitor Action Group para alertas
resource "azurerm_monitor_action_group" "alerts" {
  name                = "${local.name_prefix_short}-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "ecom-alerts"  # Máximo 12 caracteres
  enabled             = true

  dynamic "email_receiver" {
    for_each = var.alert_email_receivers
    content {
      name          = "email-${email_receiver.key}"
      email_address = email_receiver.value
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.alert_webhook_urls
    content {
      name        = "webhook-${webhook_receiver.key}"
      service_uri = webhook_receiver.value
    }
  }

  tags = var.tags
}

# Service Account de Grafana para Jenkins
# Usamos null_resource con local-exec porque Azure Managed Grafana
# requiere autenticación específica que es más fácil manejar con scripts
resource "null_resource" "grafana_service_account" {
  depends_on = [azurerm_dashboard_grafana.grafana]

  triggers = {
    grafana_id          = azurerm_dashboard_grafana.grafana.id
    grafana_name        = azurerm_dashboard_grafana.grafana.name
    service_account_name = "jenkins-migration"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Obtener el endpoint de Grafana
      GRAFANA_ENDPOINT="${azurerm_dashboard_grafana.grafana.endpoint}"
      GRAFANA_NAME="${azurerm_dashboard_grafana.grafana.name}"
      RESOURCE_GROUP="${var.resource_group_name}"
      SERVICE_ACCOUNT_NAME="jenkins-migration"
      
      # Verificar que Grafana esté listo
      echo "Waiting for Grafana to be ready..."
      sleep 30
      
      # Intentar crear Service Account usando Azure CLI y API REST
      # Primero obtener token de Azure
      AZURE_TOKEN=$(az account get-access-token --resource https://grafana.azure.com --query accessToken -o tsv 2>/dev/null || echo "")
      
      if [ -z "$AZURE_TOKEN" ]; then
        echo "Warning: Could not get Azure token. Service Account will need to be created manually."
        echo "See docs/MANUAL_GRAFANA_API_KEY.md for instructions"
        exit 0
      fi
      
      # Crear Service Account
      SERVICE_ACCOUNT_RESPONSE=$(curl -s -w "\n%%{http_code}" -X POST \
        -H "Authorization: Bearer ${AZURE_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${SERVICE_ACCOUNT_NAME}\",\"role\":\"Admin\",\"isDisabled\":false}" \
        "${GRAFANA_ENDPOINT}/api/serviceaccounts" 2>&1)
      
      HTTP_CODE=$(echo "$SERVICE_ACCOUNT_RESPONSE" | tail -n1)
      SERVICE_ACCOUNT_JSON=$(echo "$SERVICE_ACCOUNT_RESPONSE" | sed '$d')
      
      if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "✓ Service Account created successfully"
      elif echo "$SERVICE_ACCOUNT_JSON" | grep -q "already exists"; then
        echo "✓ Service Account already exists"
      else
        echo "Warning: Could not create Service Account automatically (HTTP ${HTTP_CODE})"
        echo "Response: ${SERVICE_ACCOUNT_JSON}"
        echo "Please create it manually via Grafana UI (see docs/MANUAL_GRAFANA_API_KEY.md)"
      fi
    EOT

    interpreter = ["bash", "-c"]
  }

  # Cleanup: eliminar Service Account cuando se destruya el recurso (opcional)
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Note: Service Account 'jenkins-migration' should be deleted manually from Grafana UI if needed"
    EOT

    interpreter = ["bash", "-c"]
  }
}

# Token del Service Account de Grafana
# Este recurso crea el token para el Service Account
resource "null_resource" "grafana_service_account_token" {
  depends_on = [null_resource.grafana_service_account]

  triggers = {
    grafana_id          = azurerm_dashboard_grafana.grafana.id
    service_account_id  = null_resource.grafana_service_account.id
    token_name          = "jenkins-migration-token"
  }

  provisioner "local-exec" {
    command = <<-EOT
      GRAFANA_ENDPOINT="${azurerm_dashboard_grafana.grafana.endpoint}"
      GRAFANA_NAME="${azurerm_dashboard_grafana.grafana.name}"
      RESOURCE_GROUP="${var.resource_group_name}"
      SERVICE_ACCOUNT_NAME="jenkins-migration"
      TOKEN_NAME="jenkins-migration-token"
      
      # Obtener token de Azure
      AZURE_TOKEN=$(az account get-access-token --resource https://grafana.azure.com --query accessToken -o tsv 2>/dev/null || echo "")
      
      if [ -z "$AZURE_TOKEN" ]; then
        echo "Warning: Could not get Azure token. Token will need to be created manually."
        exit 0
      fi
      
      # Buscar el Service Account
      SERVICE_ACCOUNTS_LIST=$(curl -s -X GET \
        -H "Authorization: Bearer ${AZURE_TOKEN}" \
        -H "Content-Type: application/json" \
        "${GRAFANA_ENDPOINT}/api/serviceaccounts/search?query=${SERVICE_ACCOUNT_NAME}" 2>&1)
      
      # Extraer ID del Service Account
      if command -v jq &> /dev/null; then
        SERVICE_ACCOUNT_ID=$(echo "$SERVICE_ACCOUNTS_LIST" | jq -r ".serviceAccounts[] | select(.name==\"${SERVICE_ACCOUNT_NAME}\") | .id" 2>/dev/null | head -1)
      else
        SERVICE_ACCOUNT_ID=$(echo "$SERVICE_ACCOUNTS_LIST" | grep -oE '"id":[0-9]+' | head -1 | cut -d':' -f2)
      fi
      
      if [ -z "$SERVICE_ACCOUNT_ID" ]; then
        echo "Warning: Could not find Service Account. Please create it manually first."
        exit 0
      fi
      
      # Crear Token
      TOKEN_RESPONSE=$(curl -s -w "\n%%{http_code}" -X POST \
        -H "Authorization: Bearer ${AZURE_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${TOKEN_NAME}\",\"secondsToLive\":0}" \
        "${GRAFANA_ENDPOINT}/api/serviceaccounts/${SERVICE_ACCOUNT_ID}/tokens" 2>&1)
      
      TOKEN_HTTP_CODE=$(echo "$TOKEN_RESPONSE" | tail -n1)
      TOKEN_JSON=$(echo "$TOKEN_RESPONSE" | sed '$d')
      
      if [ "$TOKEN_HTTP_CODE" = "201" ] || [ "$TOKEN_HTTP_CODE" = "200" ]; then
        # Extraer el token
        if command -v jq &> /dev/null; then
          API_KEY=$(echo "$TOKEN_JSON" | jq -r '.key // empty' 2>/dev/null)
        else
          API_KEY=$(echo "$TOKEN_JSON" | grep -o '"key":"[^"]*' | cut -d'"' -f4)
        fi
        
        if [ -n "$API_KEY" ] && [ "$API_KEY" != "null" ]; then
          echo "✓ Token created successfully"
          echo ""
          echo "========================================="
          echo "Grafana API Token (Service Account Token)"
          echo "========================================="
          echo "Token: ${API_KEY}"
          echo "========================================="
          echo ""
          echo "IMPORTANT: Save this token! It's only shown once."
          echo "Add it to Jenkins as credential 'GRAFANA_API_KEY'"
        else
          echo "Warning: Token created but could not extract it from response"
        fi
      else
        echo "Warning: Could not create token automatically (HTTP ${TOKEN_HTTP_CODE})"
        echo "Response: ${TOKEN_JSON}"
        echo "Please create it manually via Grafana UI (see docs/MANUAL_GRAFANA_API_KEY.md)"
      fi
    EOT

    interpreter = ["bash", "-c"]
  }
}

