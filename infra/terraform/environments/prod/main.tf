locals {
  name_prefix = "${var.project}-${var.environment}"
  base_tags = merge(var.default_tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  })
  sanitized_name  = substr(
    replace(
      replace(
        replace(lower(local.name_prefix), "_", ""),
        "-", ""
      ),
      ".", ""
    ),
    0,
    20
  )
  storage_account_name = var.storage_account_name != null ? var.storage_account_name : "${local.sanitized_name}sa"
  artifact_container   = var.artifact_container_name != null ? var.artifact_container_name : "artifacts"
  logs_container       = var.logs_container_name != null ? var.logs_container_name : "logs"
}

resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}-rg"
  location = var.location

  tags = local.base_tags
}

module "networking" {
  source = "../../modules/networking"

  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  vnet_cidr           = var.vnet_cidr
  public_subnets      = var.public_subnets
  private_subnets     = var.private_subnets
  tags                = local.base_tags
}

module "storage" {
  source = "../../modules/storage"

  resource_group_name     = azurerm_resource_group.this.name
  location                = azurerm_resource_group.this.location
  storage_account_name    = local.storage_account_name
  replication_type        = var.storage_replication_type
  artifact_container_name = local.artifact_container
  logs_container_name     = local.logs_container
  tags                    = local.base_tags
}

module "aks" {
  source = "../../modules/aks"

  name                 = "${local.name_prefix}-aks"
  resource_group_name  = azurerm_resource_group.this.name
  location             = azurerm_resource_group.this.location
  dns_prefix           = "${local.sanitized_name}-dns"
  kubernetes_version   = var.kubernetes_version
  vnet_subnet_id       = module.networking.private_subnet_ids[var.aks_subnet_key]
  node_vm_size         = var.aks_node_vm_size
  node_count           = var.aks_node_count
  node_os_disk_size_gb = var.aks_node_os_disk_gb
  max_pods_per_node    = var.aks_max_pods
  network_plugin       = var.aks_network_plugin
  service_cidr         = var.aks_service_cidr
  dns_service_ip       = var.aks_dns_service_ip
  docker_bridge_cidr   = var.aks_docker_bridge_cidr
  outbound_type        = var.aks_outbound_type
  tags                 = local.base_tags

  depends_on = [module.networking]
}

module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  aks_cluster_id      = module.aks.cluster_id

  grafana_sku            = var.grafana_sku
  grafana_public_access  = var.grafana_public_access
  grafana_zone_redundancy = var.grafana_zone_redundancy

  alert_email_receivers = var.alert_email_receivers
  alert_webhook_urls    = var.alert_webhook_urls

  tags = local.base_tags
}


