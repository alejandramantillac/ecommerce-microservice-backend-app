# Módulo `database`

Despliega **Azure Database for PostgreSQL Flexible Server** con opciones de red privada, alta disponibilidad y firewall.

## Entradas principales

| Variable | Descripción |
| --- | --- |
| `server_name`, `resource_group_name`, `location` | Identidad básica. |
| `engine_version`, `sku_name`, `storage_mb`, `backup_retention_days` | Características de cómputo/almacenamiento. |
| `admin_username`, `admin_password` | Credenciales iniciales. |
| `delegated_subnet_id`, `private_dns_zone_id`, `virtual_network_id` | Red privada (opcional). |
| `public_network_access_enabled`, `allowed_cidrs` | Acceso público controlado. |
| `enable_high_availability`, `high_availability_zone` | HA zone-redundant. |
| `database_name`, `database_collation`, `database_charset` | Ajustes de la base creada automáticamente. |

## Outputs

- `server_fqdn`
- `administrator_login`
- `database_name`

## Ejemplo

```hcl
module "database" {
  source              = "../../modules/database"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  server_name         = "ecom-dev-db"
  admin_username      = var.db_username
  admin_password      = var.db_password
  delegated_subnet_id = module.networking.private_subnet_ids["core"]
  virtual_network_id  = module.networking.vnet_id
  enable_high_availability = false
  public_network_access_enabled = false
  tags = {
    Project = "ecommerce"
  }
}
```

