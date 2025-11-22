variable "resource_group_name" {
  type        = string
  description = "Resource group destino."
}

variable "location" {
  type        = string
  description = "Región."
}

variable "virtual_network_id" {
  type        = string
  description = "ID de la VNet (para vincular DNS privado)."
  default     = null
}

variable "delegated_subnet_id" {
  type        = string
  description = "Subnet delegada para la base de datos (opcional)."
  default     = null
}

variable "private_dns_zone_id" {
  type        = string
  description = "DNS zone privada existente."
  default     = null
}

variable "server_name" {
  type        = string
  description = "Nombre del servidor flexible."
}

variable "engine_version" {
  type        = string
  description = "Versión (ej. 15)."
  default     = "15"
}

variable "sku_name" {
  type        = string
  description = "SKU (ej. Standard_D2s_v3)."
  default     = "Standard_D2s_v3"
}

variable "storage_mb" {
  type        = number
  description = "Almacenamiento en MB."
  default     = 32768
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "admin_username" {
  type        = string
  description = "Usuario administrador."
}

variable "admin_password" {
  type        = string
  description = "Contraseña."
  sensitive   = true
}

variable "availability_zone" {
  type        = string
  description = "Zona primaria."
  default     = "1"
}

variable "enable_high_availability" {
  type        = bool
  description = "Activa HA (zona redundante)."
  default     = false
}

variable "high_availability_zone" {
  type        = string
  description = "Zona secundaria."
  default     = "2"
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Permitir acceso público."
  default     = false
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "CIDRs permitidos si el acceso público está activo."
  default     = []
}

variable "database_name" {
  type        = string
  description = "Nombre de la base principal."
  default     = "appdb"
}

variable "database_collation" {
  type    = string
  default = "en_US.utf8"
}

variable "database_charset" {
  type    = string
  default = "UTF8"
}

variable "prevent_destroy" {
  type        = bool
  description = "Evitar destrucción accidental."
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

