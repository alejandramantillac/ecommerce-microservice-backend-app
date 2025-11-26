terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

# Azure Monitor Workspace (Prometheus gestionado)
resource "azurerm_monitor_workspace" "prometheus" {
  name                = "${var.name_prefix}-prometheus-ws"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Azure Managed Grafana
resource "azurerm_dashboard_grafana" "grafana" {
  name                              = "${var.name_prefix}-grafana"
  resource_group_name               = var.resource_group_name
  location                          = var.location
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = true
  public_network_access_enabled     = var.grafana_public_access
  sku                               = var.grafana_sku
  grafana_major_version             = "10"
  zone_redundancy_enabled           = var.grafana_zone_redundancy

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
  name                = "${var.name_prefix}-prometheus-dcr"
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
  name                = "${var.name_prefix}-prometheus-dce"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"
  tags                = var.tags
}

# Asociación del DCR con el cluster AKS
resource "azurerm_monitor_data_collection_rule_association" "aks" {
  name                    = "${var.name_prefix}-aks-dcr-assoc"
  target_resource_id      = var.aks_cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus.id
  description             = "Association for Prometheus metrics collection from AKS"
}

# Azure Monitor Action Group para alertas
resource "azurerm_monitor_action_group" "alerts" {
  name                = "${var.name_prefix}-alerts-ag"
  resource_group_name = var.resource_group_name
  short_name          = "ecom-alerts"
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

