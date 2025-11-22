# Módulo `storage`

Crea un Storage Account y containers de blobs para artefactos y logs.

## Entradas

| Variable | Descripción |
| --- | --- |
| `resource_group_name`, `location` | Contexto de despliegue. |
| `storage_account_name` | Debe ser único (minúsculas). |
| `replication_type` | LRS, GRS, ZRS (default LRS). |
| `artifact_container_name` | Nombre del container de artefactos (`null` = no crear). |
| `logs_container_name` | Container para logs. |
| `enable_versioning` | Controla `blob_properties.versioning_enabled`. |
| `tags` | Etiquetas adicionales. |

## Outputs

- `storage_account_name`
- `artifact_container_name`
- `logs_container_name`

## Ejemplo

```hcl
module "storage" {
  source                = "../../modules/storage"
  resource_group_name   = azurerm_resource_group.this.name
  location              = azurerm_resource_group.this.location
  storage_account_name  = "ecomdevstorage001"
  artifact_container_name = "artifacts"
  logs_container_name     = "logs"
  replication_type      = "LRS"
  tags = {
    Project = "ecommerce"
  }
}
```

