resource "azurerm_private_dns_zone" "postgres" {
  count = var.private_dns_zone_id == null && var.delegated_subnet_id != null ? 1 : 0

  name                = "${var.server_name}.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                          = var.server_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = var.engine_version
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  backup_retention_days         = var.backup_retention_days
  administrator_login           = var.admin_username
  administrator_password        = var.admin_password
  zone                          = var.availability_zone
  create_mode                   = "Default"
  public_network_access_enabled = var.public_network_access_enabled

  high_availability {
    mode                      = var.enable_high_availability ? "ZoneRedundant" : "Disabled"
    standby_availability_zone = var.enable_high_availability ? var.high_availability_zone : null
  }

  dynamic_network {
    count = var.delegated_subnet_id != null ? 1 : 0
    content {
      network {
        delegated_subnet_id = var.delegated_subnet_id
        private_dns_zone_id = var.private_dns_zone_id != null
          ? var.private_dns_zone_id
          : azurerm_private_dns_zone.postgres[0].id
      }
    }
  }

  tags = merge(var.tags, {
    Name = var.server_name
  })
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.this.id
  collation = var.database_collation
  charset   = var.database_charset
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allowed_cidrs" {
  for_each = var.public_network_access_enabled ? toset(var.allowed_cidrs) : []

  name             = replace(each.value, "/", "-")
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = cidrhost(each.value, 0)
  end_ip_address   = cidrhost(each.value, -1)
}

