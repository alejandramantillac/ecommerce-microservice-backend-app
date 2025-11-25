variable "name" {
  description = "Prefijo amigable (ej. ecommerce-dev)."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group donde se desplegará la red."
  type        = string
}

variable "location" {
  description = "Región de Azure."
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR principal de la VNet."
  type        = string
}

variable "public_subnets" {
  description = "Mapa de subnets públicas (key => { cidr })."
  type = map(object({
    cidr = string
  }))
}

variable "private_subnets" {
  description = "Mapa de subnets privadas (key => { cidr })."
  type = map(object({
    cidr = string
  }))
  default = {}
}

variable "public_subnet_service_endpoints" {
  description = "Service endpoints aplicados a subnets públicas."
  type        = list(string)
  default     = []
}

variable "private_subnet_service_endpoints" {
  description = "Service endpoints aplicados a subnets privadas."
  type        = list(string)
  default     = ["Microsoft.Storage", "Microsoft.Sql"]
}

variable "enable_private_delegation" {
  description = "Delegar subnets privadas para AKS."
  type        = bool
  default     = false
}

variable "subnet_propagation_wait" {
  description = "Tiempo de espera antes de asociar NSG o delegar subnets (para evitar errores de propagación en Azure)."
  type        = string
  default     = "30s"
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}

