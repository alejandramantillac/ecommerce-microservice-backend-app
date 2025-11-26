variable "name_prefix" {
  description = "Prefijo para nombres de recursos"
  type        = string
}

variable "resource_group_name" {
  description = "Nombre del resource group"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
}

variable "aks_cluster_id" {
  description = "ID del cluster AKS para asociar el data collection rule"
  type        = string
}

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

variable "tags" {
  description = "Tags para los recursos"
  type        = map(string)
  default     = {}
}

