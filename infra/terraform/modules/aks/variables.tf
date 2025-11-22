variable "name" {
  description = "Nombre del cluster AKS."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group destino."
  type        = string
}

variable "location" {
  description = "Región."
  type        = string
}

variable "dns_prefix" {
  description = "Prefijo DNS para el API server."
  type        = string
}

variable "kubernetes_version" {
  description = "Versión de Kubernetes."
  type        = string
  default     = "1.29.0"
}

variable "vnet_subnet_id" {
  description = "Subnet donde residirán los nodos."
  type        = string
}

variable "node_vm_size" {
  description = "Tamaño de VM para el node pool."
  type        = string
  default     = "Standard_DS2_v2"
}

variable "node_count" {
  description = "Número inicial de nodos."
  type        = number
  default     = 1
}

variable "node_min_count" {
  description = "Auto scaling mínimo."
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Auto scaling máximo."
  type        = number
  default     = 3
}

variable "enable_auto_scaling" {
  description = "Habilitar auto scaling en el node pool."
  type        = bool
  default     = false
}

variable "node_os_disk_size_gb" {
  description = "Tamaño del disco OS."
  type        = number
  default     = 100
}

variable "max_pods_per_node" {
  description = "Límite de pods por nodo."
  type        = number
  default     = 30
}

variable "enable_rbac" {
  description = "Habilitar RBAC."
  type        = bool
  default     = true
}

variable "network_plugin" {
  description = "Plugin de red (azure, kubenet)."
  type        = string
  default     = "azure"
}

variable "service_cidr" {
  description = "CIDR para servicios."
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "IP del servicio DNS."
  type        = string
  default     = "10.0.0.10"
}

variable "docker_bridge_cidr" {
  description = "CIDR del docker bridge."
  type        = string
  default     = "172.17.0.1/16"
}

variable "outbound_type" {
  description = "Tipo de salida (loadBalancer, userDefinedRouting)."
  type        = string
  default     = "loadBalancer"
}

variable "tags" {
  description = "Etiquetas."
  type        = map(string)
  default     = {}
}

