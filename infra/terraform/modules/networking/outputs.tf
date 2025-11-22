output "vnet_id" {
  value       = azurerm_virtual_network.this.id
  description = "ID de la VNet."
}

output "public_subnet_ids" {
  value       = { for k, v in azurerm_subnet.public : k => v.id }
  description = "IDs de subnets públicas."
}

output "private_subnet_ids" {
  value       = { for k, v in azurerm_subnet.private : k => v.id }
  description = "IDs de subnets privadas."
}

