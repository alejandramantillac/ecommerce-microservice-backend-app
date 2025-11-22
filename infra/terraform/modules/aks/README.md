# Módulo `aks`

Despliega un cluster **Azure Kubernetes Service** con identidad administrada y node pool administrado.

## Entradas principales

| Variable | Descripción |
| --- | --- |
| `name`, `resource_group_name`, `location`, `dns_prefix` | Identificadores básicos. |
| `kubernetes_version` | Versión deseada. |
| `vnet_subnet_id` | Subnet donde se montan los nodos. |
| `node_vm_size`, `node_count`, `node_min_count`, `node_max_count`, `node_auto_scaling` | Parametrizan el node pool. |
| `network_plugin`, `service_cidr`, `dns_service_ip`, `docker_bridge_cidr` | Configuración de red. |
| `enable_oms_agent`, `log_analytics_workspace_id`, `log_retention_days` | Observabilidad. |
| `tags` | Etiquetas adicionales. |

## Outputs

- `cluster_name`
- `kube_config` / `kube_admin_config`
- `fqdn`
- `identity_principal_id`
- `node_resource_group`

## Ejemplo

```hcl
module "aks" {
  source              = "../../modules/aks"
  name                = "ecommerce-dev-aks"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  dns_prefix          = "ecom-dev"
  vnet_subnet_id      = module.networking.private_subnet_ids["core"]
  node_vm_size        = "Standard_DS2_v2"
  node_count          = 1
  node_min_count      = 1
  node_max_count      = 2
  tags = {
    Project = "ecommerce"
  }
}
```

