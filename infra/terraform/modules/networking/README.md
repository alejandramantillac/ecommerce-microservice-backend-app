# Módulo `networking`

Crea la red base en Azure: VNet, subnets públicas/privadas y NSG asociados. Opcionalmente delega las subnets privadas para AKS.

## Variables clave

| Variable | Descripción |
| --- | --- |
| `name` | Prefijo (`ecommerce-dev`). |
| `resource_group_name` / `location` | Donde se despliega la red. |
| `vnet_cidr` | CIDR principal (ej. `10.10.0.0/16`). |
| `public_subnets` | Mapa `{ zona = { cidr } }`. |
| `private_subnets` | Mapa para workloads internos. |
| `enable_private_delegation` | Si `true`, delega subnets para AKS. |
| `public/private_subnet_service_endpoints` | Service endpoints opcionales. |
| `tags` | Etiquetas adicionales. |

## Outputs

- `vnet_id`
- `public_subnet_ids`
- `private_subnet_ids`

## Ejemplo

```hcl
module "networking" {
  source              = "../../modules/networking"
  name                = "ecommerce-dev"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  vnet_cidr           = "10.10.0.0/16"

  public_subnets = {
    az1 = { cidr = "10.10.0.0/22" }
    az2 = { cidr = "10.10.4.0/22" }
  }

  private_subnets = {
    core = { cidr = "10.10.16.0/22" }
  }

  tags = {
    Project = "ecommerce"
  }
}
```

