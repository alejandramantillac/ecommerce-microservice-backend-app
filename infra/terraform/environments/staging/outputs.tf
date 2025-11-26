output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "public_subnets" {
  value = module.networking.public_subnet_ids
}

output "private_subnets" {
  value = module.networking.private_subnet_ids
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_kube_config" {
  value     = module.aks.kube_config
  sensitive = true
}

output "storage_account_name" {
  value = module.storage.storage_account_name
}

output "prometheus_workspace_id" {
  value = module.monitoring.prometheus_workspace_id
}

output "prometheus_ingestion_endpoint" {
  value       = module.monitoring.prometheus_ingestion_endpoint
  sensitive   = true
}

output "prometheus_query_endpoint" {
  value       = module.monitoring.prometheus_query_endpoint
  sensitive   = true
}

output "grafana_endpoint" {
  value = module.monitoring.grafana_endpoint
}

output "grafana_name" {
  value = module.monitoring.grafana_name
}

