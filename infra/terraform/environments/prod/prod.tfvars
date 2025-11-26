project     = "ecommerce"
environment = "prod"
location    = "centralus"

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

aks_node_vm_size      = "Standard_D2s_v3"
aks_node_count        = 2
aks_node_os_disk_gb   = 80
aks_max_pods          = 30

db_admin_username        = "ecomprod"
db_admin_password        = "SuperSecureProdPwd!"
db_public_network_access = false
db_enable_ha             = false
db_backup_retention_days = 14
db_sku_name              = "Standard_D2s_v3"
db_storage_mb            = 32768

# Logging (ELK Stack) - Desplegado en Azure Container Apps (fuera del cluster)
elasticsearch_replicas     = 1
elasticsearch_cpu           = 1.0
elasticsearch_memory        = "2Gi"
elasticsearch_java_heap     = 1024
elasticsearch_public_access = false  # Solo acceso interno desde AKS

logstash_replicas = 1
logstash_cpu      = 0.5
logstash_memory   = "1Gi"

kibana_replicas      = 1
kibana_cpu           = 0.5
kibana_memory        = "1Gi"
kibana_public_access = true  # Acceso público para visualización

