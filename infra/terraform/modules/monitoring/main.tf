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

# Nota: El endpoint real de Prometheus incluye un sufijo aleatorio que Azure agrega
# El provider de Terraform no expone esta propiedad directamente
# El script de Jenkins (commonFunctions.groovy) obtendrá el endpoint real desde Azure CLI

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

  # Asociar el DCE con el DCR para permitir remote_write
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prometheus.id

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

# Role assignment para que la Service Principal pueda enviar métricas al DCR
# Esto es necesario para que Prometheus pueda hacer remote_write al DCE/DCR
# NOTA: Se requiere el principal_id (object_id) de la Service Principal, no el client_id
# Para obtener el principal_id desde el client_id, usar:
# az ad sp show --id <client-id> --query id -o tsv
# Por ahora, este role assignment se debe hacer manualmente o mediante script
# ya que Terraform necesita el object_id (principal_id), no el client_id (appId)

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

