output "server_fqdn" {
  value       = azurerm_postgresql_flexible_server.this.fqdn
  description = "FQDN para conectarse a la base."
}

output "administrator_login" {
  value       = azurerm_postgresql_flexible_server.this.administrator_login
  description = "Usuario administrador."
}

output "database_name" {
  value       = azurerm_postgresql_flexible_server_database.this.name
  description = "Nombre de la base creada."
}

