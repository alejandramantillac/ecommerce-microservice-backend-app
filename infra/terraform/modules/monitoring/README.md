# Módulo de Monitoring - Azure Managed Services

Este módulo despliega servicios gestionados de Azure para monitoreo:
- **Azure Monitor Workspace**: Prometheus gestionado
- **Azure Managed Grafana**: Grafana gestionado
- **Data Collection Rules**: Para recolección de métricas desde AKS
- **Action Groups**: Para alertas

## Uso

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  aks_cluster_id      = module.aks.cluster_id

  grafana_sku              = "Standard"
  grafana_public_access    = true
  grafana_zone_redundancy   = false

  alert_email_receivers = {
    team = "team@example.com"
  }

  alert_webhook_urls = {
    slack = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
  }

  tags = local.base_tags
}
```

## Outputs

- `prometheus_workspace_id`: ID del workspace de Prometheus
- `prometheus_ingestion_endpoint`: Endpoint para enviar métricas
- `prometheus_query_endpoint`: Endpoint para consultar métricas
- `grafana_endpoint`: URL de Grafana
- `action_group_id`: ID del grupo de acciones para alertas

