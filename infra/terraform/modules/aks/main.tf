resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix

  kubernetes_version = var.kubernetes_version

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_vm_size
    node_count           = var.node_count
    min_count            = var.enable_auto_scaling ? var.node_min_count : null
    max_count            = var.enable_auto_scaling ? var.node_max_count : null
    vnet_subnet_id       = var.vnet_subnet_id
    os_disk_size_gb      = var.node_os_disk_size_gb
    type                 = "VirtualMachineScaleSets"
    orchestrator_version = var.kubernetes_version
    max_pods             = var.max_pods_per_node
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control_enabled = var.enable_rbac

  network_profile {
    network_plugin = var.network_plugin
    dns_service_ip = var.dns_service_ip
    service_cidr   = var.service_cidr
    outbound_type  = var.outbound_type
  }
  tags = merge(var.tags, {
    Name = var.name
  })
}

