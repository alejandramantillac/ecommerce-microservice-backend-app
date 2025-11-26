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

aks_node_vm_size      = "Standard_B2ms"
aks_node_count        = 2

storage_replication_type = "LRS"

db_admin_username        = "ecomstage"
db_admin_password        = "ChangeMeStage123!"
db_public_network_access = false
db_enable_ha             = false
db_sku_name              = "Standard_D2s_v3"
db_storage_mb            = 32768
db_backup_retention_days = 7

# Monitoring - Usar Essential para staging (soporta versión 10, más económico)
grafana_sku = "Essential"

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

