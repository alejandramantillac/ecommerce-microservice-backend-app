output "cluster_name" {
  value       = azurerm_kubernetes_cluster.this.name
  description = "Nombre del cluster."
}

output "kube_admin_config" {
  value       = azurerm_kubernetes_cluster.this.kube_admin_config_raw
  description = "Kubeconfig del usuario admin (base64)."
  sensitive   = true
}

output "kube_config" {
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  description = "Kubeconfig del usuario estándar."
  sensitive   = true
}

output "fqdn" {
  value       = azurerm_kubernetes_cluster.this.fqdn
  description = "FQDN público del API server."
}

output "identity_principal_id" {
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
  description = "Principal ID de la identidad administrada."
}

output "node_resource_group" {
  value       = azurerm_kubernetes_cluster.this.node_resource_group
  description = "Resource group que contiene los nodos/recursos auxiliares."
}

