output "elasticsearch_endpoint" {
  description = "Endpoint de Elasticsearch"
  value       = azurerm_container_app.elasticsearch.ingress[0].fqdn != null ? "http://${azurerm_container_app.elasticsearch.ingress[0].fqdn}" : ""
}

output "elasticsearch_internal_endpoint" {
  description = "Endpoint interno de Elasticsearch (para uso dentro de la VNet)"
  value       = "${azurerm_container_app.elasticsearch.name}.${azurerm_container_app_environment.elk.default_domain}"
}

output "kibana_endpoint" {
  description = "Endpoint de Kibana"
  value       = azurerm_container_app.kibana.ingress[0].fqdn != null ? "http://${azurerm_container_app.kibana.ingress[0].fqdn}" : ""
}

output "logstash_endpoint" {
  description = "Endpoint interno de Logstash"
  value       = "${azurerm_container_app.logstash.name}.${azurerm_container_app_environment.elk.default_domain}"
}

output "container_app_environment_id" {
  description = "ID del Container Apps Environment"
  value       = azurerm_container_app_environment.elk.id
}

output "log_analytics_workspace_id" {
  description = "ID del Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.elk.id
}

output "log_analytics_workspace_customer_id" {
  description = "Customer ID (Workspace ID) del Log Analytics Workspace para Filebeat"
  value       = azurerm_log_analytics_workspace.elk.workspace_id
}

output "log_analytics_workspace_primary_shared_key" {
  description = "Primary Shared Key del Log Analytics Workspace para Filebeat"
  value       = azurerm_log_analytics_workspace.elk.primary_shared_key
  sensitive   = true
}

