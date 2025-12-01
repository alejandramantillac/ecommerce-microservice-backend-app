# Infraestructura como Código - Terraform

## Descripción General

Este documento describe la configuración de infraestructura como código (IaC) usando Terraform para desplegar la aplicación de e-commerce en Azure. La infraestructura sigue un enfoque modular que permite reutilización de código y gestión de múltiples ambientes (dev, staging, prod).

## Estructura Modular

```
infra/terraform/
├── main.tf                 # Configuración principal
├── variables.tf            # Definición de variables
├── outputs.tf              # Outputs de la infraestructura
├── terraform.tfvars        # Valores de variables (local)
├── terraform.tfvars.prod   # Valores para producción
├── terraform.tfvars.stage  # Valores para staging
├── backend/
│   ├── main.tf             # Configuración del backend en Azure Storage
│   ├── variables.tf        # Variables del backend
│   └── outputs.tf          # Outputs del backend
├── modules/
│   ├── resource-group/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── kubernetes/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── container-registry/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── networking/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
```

### Backend Remoto

El estado de Terraform se almacena en Azure Storage para permitir colaboración en equipo y seguridad:

- **Storage Account**: Almacena archivos `.tfstate`
- **Container**: Aislamiento por ambiente
- **Acceso**: Controlado por Azure AD y claves de acceso

**Configuración del backend**:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatexxxxxxxx"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}
```

## Ambientes

### Desarrollo (dev)

- **AKS**: 1-2 nodos (escalado automático deshabilitado)
- **Bases de datos**: H2 en memoria (sin persistencia)
- **Almacenamiento**: Ninguno
- **Monitoring**: Stack mínimo
- **Costo estimado**: $50-100/mes

### Staging

- **AKS**: 3 nodos (escalado 1-5)
- **Bases de datos**: MySQL administrado
- **Almacenamiento**: Azure Storage
- **Monitoring**: Stack completo
- **Costo estimado**: $200-300/mes

### Producción

- **AKS**: 5+ nodos (escalado 3-10)
- **Bases de datos**: MySQL con failover automático
- **Almacenamiento**: Azure Storage con replicación
- **Monitoring**: Stack completo + alertas
- **Costo estimado**: $500-800/mes

## Componentes Principales

### 1. Grupo de Recursos (Resource Group)

```hcl
module "resource_group" {
  source = "./modules/resource-group"
  
  environment = var.environment
  location    = var.azure_region
  
  tags = {
    Environment = var.environment
    Project     = "ecommerce"
  }
}
```

**Propósito**: Contenedor lógico para agrupar todos los recursos de Azure por ambiente.

### 2. Kubernetes (AKS)

```hcl
module "kubernetes" {
  source = "./modules/kubernetes"
  
  environment         = var.environment
  cluster_name        = "aks-${var.environment}"
  resource_group_name = module.resource_group.name
  location            = var.azure_region
  node_count          = var.node_count[var.environment]
  vm_size             = var.vm_size[var.environment]
}
```

**Características**:
- Escalado automático de nodos (dev: deshabilitado)
- Integración con Azure Container Registry
- Network Policy habilitado
- RBAC habilitado

### 3. Container Registry (ACR)

```hcl
module "container_registry" {
  source = "./modules/container-registry"
  
  environment         = var.environment
  registry_name       = "acr${var.environment}"
  resource_group_name = module.resource_group.name
  location            = var.azure_region
  sku                 = var.acr_sku[var.environment]
}
```

**Propósito**: Almacenar imágenes Docker de los microservicios.

### 4. Networking

```hcl
module "networking" {
  source = "./modules/networking"
  
  environment         = var.environment
  location            = var.azure_region
  resource_group_name = module.resource_group.name
  vnet_cidr           = var.vnet_cidr
}
```

**Componentes**:
- Virtual Network (VNet)
- Subnets para diferentes componentes
- Network Security Groups (NSG)
- Application Gateway (opcional)

## Variables de Configuración

### terraform.tfvars (Desarrollo)

```hcl
environment   = "dev"
azure_region  = "eastus"
node_count    = 1
vm_size       = "Standard_B2s"
acr_sku       = "Basic"
vnet_cidr     = "10.0.0.0/16"
```

### terraform.tfvars.stage (Staging)

```hcl
environment   = "stage"
azure_region  = "eastus"
node_count    = 3
vm_size       = "Standard_D2s_v3"
acr_sku       = "Standard"
vnet_cidr     = "10.1.0.0/16"
```

### terraform.tfvars.prod (Producción)

```hcl
environment   = "prod"
azure_region  = "eastus"
node_count    = 5
vm_size       = "Standard_D4s_v3"
acr_sku       = "Premium"
vnet_cidr     = "10.2.0.0/16"
```

## Deployed Resources (Outputs)

Los outputs principales incluyen:

- **Resource Group**: Nombre del grupo de recursos creado
- **Storage Account**: Nombre de la cuenta de almacenamiento del backend
- **Container Name**: Nombre del contenedor de estado
- **AKS Cluster**: Nombre y credenciales del cluster Kubernetes
- **Container Registry**: URL de login del registro de contenedores
- **Kubeconfig**: Archivo de configuración para kubectl

## Despliegue

### Inicializar Terraform

```bash
# Con backend remoto configurado
terraform init

# O sin backend remoto (local)
terraform init -backend=false
```

### Planificar Cambios

```bash
# Para desarrollo
terraform plan -var-file="terraform.tfvars" -out=dev.tfplan

# Para staging
terraform plan -var-file="terraform.tfvars.stage" -out=stage.tfplan

# Para producción
terraform plan -var-file="terraform.tfvars.prod" -out=prod.tfplan
```

### Aplicar Configuración

```bash
terraform apply dev.tfplan
terraform apply stage.tfplan
terraform apply prod.tfplan
```

### Destruir Recursos

```bash
# ADVERTENCIA: Esto eliminará todos los recursos
terraform destroy -var-file="terraform.tfvars"
```

## Mejores Prácticas

1. **Versionado de módulos**: Usar ramas o tags para versionar módulos reutilizables
2. **Validación**: Ejecutar `terraform validate` en cada cambio
3. **Formatteo**: Usar `terraform fmt` para mantener consistencia
4. **State locking**: Usar backend remoto con state locking habilitado
5. **Secrets management**: Usar Azure Key Vault para datos sensibles
6. **Documentación**: Mantener actualizadas las variables y outputs
7. **Testing**: Usar Terratest para testing de módulos
8. **CI/CD**: Ejecutar `terraform plan` en PRs y `apply` solo en main

## Referencias

- [Terraform Docs](https://www.terraform.io/docs)
- [Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Backend Remoto](docs/backend-output-details.md)
