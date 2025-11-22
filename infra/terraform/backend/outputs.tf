output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "Resource group que contiene el backend."
}

output "storage_account_name" {
  value       = azurerm_storage_account.state.name
  description = "Storage account usado para almacenar el estado."
}

output "container_name" {
  value       = azurerm_storage_container.state.name
  description = "Container donde se guardan los archivos .tfstate."
}

