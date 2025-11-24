variable "resource_group_name" {
  type        = string
  description = "Resource group donde se crea el storage."
}

variable "location" {
  type        = string
  description = "Región."
}

variable "storage_account_name" {
  type        = string
  description = "Nombre único del storage account."
}

variable "replication_type" {
  type        = string
  description = "Tipo de replicación (LRS/GRS/ZRS)."
  default     = "LRS"
}

variable "artifact_container_name" {
  type        = string
  description = "Nombre del container para artefactos (null = no crear)."
  default     = null
}

variable "logs_container_name" {
  type        = string
  description = "Nombre del container para logs (null = no crear)."
  default     = null
}

variable "enable_versioning" {
  type        = bool
  description = "Habilitar versioning."
  default     = true
}

variable "prevent_destroy" {
  type        = bool
  description = "Evita que Terraform destruya accidentalmente el storage account."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Etiquetas."
  default     = {}
}

