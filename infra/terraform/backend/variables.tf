variable "project" {
  description = "Nombre del proyecto para etiquetar recursos."
  type        = string
}

variable "resource_group_name" {
  description = "Nombre del resource group donde vivirá el backend."
  type        = string
}

variable "location" {
  description = "Región de Azure."
  type        = string
  default     = "eastus"
}

variable "storage_account_name" {
  description = "Nombre único del storage account (3-24 caracteres, minúsculas)."
  type        = string
}

variable "container_name" {
  description = "Nombre del container de blobs que guardará el estado."
  type        = string
  default     = "tfstate"
}

variable "account_replication_type" {
  description = "Tipo de replicación (LRS, GRS, ZRS...)."
  type        = string
  default     = "LRS"
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}

