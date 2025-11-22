output "storage_account_name" {
  value       = azurerm_storage_account.this.name
  description = "Nombre del storage account."
}

output "artifact_container_name" {
  value       = try(azurerm_storage_container.artifact[0].name, null)
  description = "Container de artefactos."
}

output "logs_container_name" {
  value       = try(azurerm_storage_container.logs[0].name, null)
  description = "Container de logs."
}

