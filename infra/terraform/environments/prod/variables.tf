variable "project" {
  description = "Nombre del proyecto."
  type        = string
}

variable "environment" {
  description = "Ambiente (dev/staging/prod)."
  type        = string
}

variable "location" {
  description = "Región de Azure."
  type        = string
  default     = "eastus"
}

variable "default_tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}

variable "vnet_cidr" {
  description = "CIDR de la VNet."
  type        = string
}

variable "public_subnets" {
  description = "Subnets públicas."
  type = map(object({
    cidr = string
  }))
}

variable "private_subnets" {
  description = "Subnets privadas."
  type = map(object({
    cidr = string
  }))
}

variable "aks_subnet_key" {
  description = "Clave del mapa `private_subnets` usada por AKS."
  type        = string
  default     = "core"
}

variable "db_subnet_key" {
  description = "Clave del mapa `private_subnets` usada por la base."
  type        = string
  default     = "data"
}

variable "storage_account_name" {
  description = "Nombre del storage account (opcional)."
  type        = string
  default     = null
}

variable "artifact_container_name" {
  description = "Nombre del container de artefactos."
  type        = string
  default     = null
}

variable "logs_container_name" {
  description = "Nombre del container de logs."
  type        = string
  default     = null
}

variable "storage_replication_type" {
  description = "Tipo de replicación del storage."
  type        = string
  default     = "LRS"
}

# AKS
variable "kubernetes_version" {
  type    = string
  default = "1.32.9"
}

variable "aks_node_vm_size" {
  type    = string
  default = "Standard_DS2_v2"
}

variable "aks_node_count" {
  type    = number
  default = 1
}

variable "aks_node_min" {
  type    = number
  default = 1
}

variable "aks_node_max" {
  type    = number
  default = 2
}

variable "aks_node_os_disk_gb" {
  type    = number
  default = 100
}

variable "aks_max_pods" {
  type    = number
  default = 30
}

variable "aks_network_plugin" {
  type    = string
  default = "azure"
}

variable "aks_service_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "aks_dns_service_ip" {
  type    = string
  default = "10.0.0.10"
}

variable "aks_docker_bridge_cidr" {
  type    = string
  default = "172.17.0.1/16"
}

variable "aks_outbound_type" {
  type    = string
  default = "loadBalancer"
}

# Database
variable "db_engine_version" {
  type    = string
  default = "15"
}

variable "db_sku_name" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "db_storage_mb" {
  type    = number
  default = 32768
}

variable "db_backup_retention_days" {
  type    = number
  default = 7
}

variable "db_admin_username" {
  type = string
}

variable "db_admin_password" {
  type      = string
  sensitive = true
}

variable "db_public_network_access" {
  type    = bool
  default = false
}

variable "db_allowed_cidrs" {
  type    = list(string)
  default = []
}

variable "db_enable_ha" {
  type    = bool
  default = false
}

# Monitoring
variable "grafana_sku" {
  description = "SKU de Azure Managed Grafana (Standard o Essential)"
  type        = string
  default     = "Standard"
}

variable "grafana_public_access" {
  description = "Habilitar acceso público a Grafana"
  type        = bool
  default     = true
}

variable "grafana_zone_redundancy" {
  description = "Habilitar redundancia de zona para Grafana"
  type        = bool
  default     = false
}

variable "alert_email_receivers" {
  description = "Mapa de emails para recibir alertas"
  type        = map(string)
  default     = {}
}

variable "alert_webhook_urls" {
  description = "Mapa de URLs de webhook para alertas"
  type        = map(string)
  default     = {}
}

# Logging (ELK Stack)
variable "elasticsearch_replicas" {
  description = "Número de réplicas de Elasticsearch"
  type        = number
  default     = 1
}

variable "elasticsearch_cpu" {
  description = "CPU para Elasticsearch (0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0)"
  type        = number
  default     = 1.0
}

variable "elasticsearch_memory" {
  description = "Memoria para Elasticsearch (formato: 0.5Gi, 1Gi, 2Gi, etc.)"
  type        = string
  default     = "2Gi"
}

variable "elasticsearch_java_heap" {
  description = "Heap de Java para Elasticsearch en MB"
  type        = number
  default     = 1024
}

variable "elasticsearch_public_access" {
  description = "Habilitar acceso público a Elasticsearch"
  type        = bool
  default     = false
}

variable "logstash_replicas" {
  description = "Número de réplicas de Logstash"
  type        = number
  default     = 1
}

variable "logstash_cpu" {
  description = "CPU para Logstash"
  type        = number
  default     = 0.5
}

variable "logstash_memory" {
  description = "Memoria para Logstash"
  type        = string
  default     = "1Gi"
}

variable "kibana_replicas" {
  description = "Número de réplicas de Kibana"
  type        = number
  default     = 1
}

variable "kibana_cpu" {
  description = "CPU para Kibana"
  type        = number
  default     = 0.5
}

variable "kibana_memory" {
  description = "Memoria para Kibana"
  type        = string
  default     = "1Gi"
}

variable "kibana_public_access" {
  description = "Habilitar acceso público a Kibana"
  type        = bool
  default     = true
}

