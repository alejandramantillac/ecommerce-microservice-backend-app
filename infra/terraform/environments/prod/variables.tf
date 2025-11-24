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

variable "storage_prevent_destroy" {
  description = "Evita que Terraform destruya el storage account."
  type        = bool
  default     = true
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

