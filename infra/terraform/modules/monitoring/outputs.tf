output "prometheus_workspace_id" {
  description = "ID del Azure Monitor Workspace (Prometheus)"
  value       = azurerm_monitor_workspace.prometheus.id
}

output "prometheus_workspace_name" {
  description = "Nombre del Azure Monitor Workspace"
  value       = azurerm_monitor_workspace.prometheus.name
}

output "prometheus_ingestion_endpoint" {
  description = "Endpoint de ingesta de Prometheus"
  value       = azurerm_monitor_workspace.prometheus.ingestion_endpoint
}

output "prometheus_query_endpoint" {
  description = "Endpoint de consulta de Prometheus"
  value       = azurerm_monitor_workspace.prometheus.query_endpoint
}

output "grafana_id" {
  description = "ID de Azure Managed Grafana"
  value       = azurerm_dashboard_grafana.grafana.id
}

output "grafana_endpoint" {
  description = "URL de Azure Managed Grafana"
  value       = azurerm_dashboard_grafana.grafana.endpoint
}

output "grafana_name" {
  description = "Nombre de Azure Managed Grafana"
  value       = azurerm_dashboard_grafana.grafana.name
}

output "action_group_id" {
  description = "ID del Action Group para alertas"
  value       = azurerm_monitor_action_group.alerts.id
}

output "data_collection_rule_id" {
  description = "ID del Data Collection Rule"
  value       = azurerm_monitor_data_collection_rule.prometheus.id
}

output "data_collection_endpoint_id" {
  description = "ID del Data Collection Endpoint"
  value       = azurerm_monitor_data_collection_endpoint.prometheus.id
}

