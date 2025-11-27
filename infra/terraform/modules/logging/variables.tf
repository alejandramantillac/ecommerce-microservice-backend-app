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

variable "vnet_subnet_id" {
  description = "ID de la subnet para integración con VNet (opcional)"
  type        = string
  default     = ""
}

# Elasticsearch configuration
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

# Logstash configuration
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

# Kibana configuration
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

variable "tags" {
  description = "Tags para los recursos"
  type        = map(string)
  default     = {}
}

