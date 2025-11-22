project     = "ecommerce"
environment = "staging"
location    = "eastus2"

default_tags = {
  Owner = "devops-team"
  Stage = "staging"
}

vnet_cidr = "10.20.0.0/16"

public_subnets = {
  edge1 = { cidr = "10.20.0.0/21" }
  edge2 = { cidr = "10.20.8.0/21" }
}

private_subnets = {
  core = { cidr = "10.20.32.0/21" }
  data = { cidr = "10.20.40.0/21" }
}

aks_subnet_key = "core"
db_subnet_key  = "data"

aks_node_vm_size = "Standard_B2ms"
aks_node_count   = 1
aks_node_min     = 1
aks_node_max     = 1

storage_replication_type = "LRS"

db_admin_username        = "ecomstage"
db_admin_password        = "ChangeMeStage123!"
db_public_network_access = false
db_enable_ha             = false
db_sku_name              = "Standard_B1ms"
db_storage_mb            = 20480
db_backup_retention_days = 7

