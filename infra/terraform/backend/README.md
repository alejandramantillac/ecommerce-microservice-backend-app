# Backend remoto en Azure

Este módulo crea los recursos necesarios para almacenar el estado de Terraform en Azure:

- Resource Group dedicado.
- Storage Account con versioning, change feed y HTTPS obligatorio.
- Container privado para los archivos `.tfstate`.

## Uso

```bash
cd infra/terraform/backend
terraform init
terraform apply \
  -var project=ecommerce \
  -var resource_group_name=tfstate-rg \
  -var storage_account_name=tfstateecomstore \
  -var container_name=tfstate
```

Anota los valores de salida (`resource_group_name`, `storage_account_name`, `container_name`). En cada ambiente (dev/staging/prod) configuras el backend `azurerm` así:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateecomstore"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
```

> Este stack se ejecuta una sola vez. Si necesitas rotar claves o cambiar la replicación, hazlo desde aquí para mantener IaC trazable.***

