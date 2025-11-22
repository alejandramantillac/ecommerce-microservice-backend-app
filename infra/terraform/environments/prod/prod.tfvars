project     = "ecommerce"
environment = "prod"
location    = "eastus2"

default_tags = {
  Owner = "platform-team"
  Tier  = "production"
}

vnet_cidr = "10.30.0.0/16"

public_subnets = {
  edge1 = { cidr = "10.30.0.0/21" }
  edge2 = { cidr = "10.30.8.0/21" }
  edge3 = { cidr = "10.30.16.0/21" }
}

private_subnets = {
  core = { cidr = "10.30.32.0/21" }
  data = { cidr = "10.30.40.0/21" }
  ops  = { cidr = "10.30.48.0/21" }
}

aks_subnet_key = "core"
db_subnet_key  = "data"

storage_replication_type = "LRS"

aks_node_vm_size    = "Standard_B2ms"
aks_node_count      = 2
aks_node_min        = 2
aks_node_max        = 3
aks_node_os_disk_gb = 80
aks_max_pods        = 30

db_admin_username        = "ecomprod"
db_admin_password        = "SuperSecureProdPwd!"
db_public_network_access = false
db_enable_ha             = false
db_backup_retention_days = 14
db_sku_name              = "Standard_B2ms"
db_storage_mb            = 32768

