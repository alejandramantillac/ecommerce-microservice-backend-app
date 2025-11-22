# Infraestructura Terraform (Azure)

Este árbol define la nube objetivo en **Microsoft Azure** utilizando Terraform 1.5+. Cumple los requisitos del proyecto: arquitectura documentada, módulos reutilizables y ambientes aislados (`staging`, `prod`). El pipeline `dev` sólo ejecuta build/tests y no requiere infraestructura en la nube.

## Estructura

```
infra/terraform/
├── backend/                # Crea el storage account y container para el estado remoto
├── modules/
│   ├── networking/         # VNet, subnets y NSG
│   ├── aks/                # Cluster AKS y node pool
│   ├── database/           # Azure Database for PostgreSQL Flexible Server
│   └── storage/            # Storage accounts para artefactos y logs
└── environments/
    ├── staging/
    └── prod/
```

## Flujo recomendado

1. **Provisionar backend**
   ```bash
   terraform -chdir=infra/terraform/backend init
   terraform -chdir=infra/terraform/backend apply \
     -var project=ecommerce \
     -var resource_group_name=tfstate-rg \
     -var storage_account_name=tfstateecomstore \
     -var container_name=tfstate
   ```
   Guarda los valores para usarlos en `backend.tf` de cada ambiente.

2. **Aplicar/destruir un ambiente**
   ```bash
   cd infra/terraform/environments/staging
   terraform init
   terraform plan  -var-file=staging.tfvars
   terraform apply -var-file=staging.tfvars
   # ejecutar pruebas…
   terraform destroy -var-file=staging.tfvars
   ```
   Usa `prod/` sólo cuando se necesite una demo, siguiendo el mismo flujo pero tras recibir aprobación.

## Diferencias entre ambientes

| Recurso        | staging (efímero)                        | prod (standby)                        |
| -------------- | ---------------------------------------- | ------------------------------------- |
| AKS node size  | `Standard_B2ms` (1 nodo fijo)            | `Standard_B2ms` (2 nodos, máx. 3)     |
| Base de datos  | `Standard_B1ms`, 20 GB, backup 7d        | `Standard_B2ms`, 32 GB, backup 14d    |
| Storage        | LRS                                      | LRS                                   |
| Red            | /16 con /21 por subconjunto              | /16 con /21 por subconjunto           |
| Observabilidad | OMS desactivado (usar logs locales)      | Activar sólo si se requiere demo      |

Las variaciones se documentan dentro de cada archivo `.tfvars`.

## Accesos e integración

- Autenticación recomendada: `az login` + `az account set` o Service Principal con certificados almacenados en Azure Key Vault/Jenkins.
- Jenkins ejecuta `terraform plan/apply/destroy` asumiendo un Service Principal distinto por ambiente.
- Los outputs (endpoints, kubeconfig, buckets) se exportan con `terraform output -json` y se guardan como credenciales en Jenkins/Key Vault.

## Documentación complementaria

- Diagrama y topología: `docs/infra/architecture/`.
- Diferencias por ambiente y políticas RBAC: `docs/infra/environments.md` (pendiente de crear).
- Procedimiento de backup de estado: `docs/infra/state-backup.md`.

> Ejecuta `terraform fmt` y `terraform validate` antes de abrir un PR. Los módulos están diseñados para reutilizarse en demos o entornos adicionales (QA, perf, etc.). Mantén `staging` encendido sólo durante las pruebas y destrúyelo inmediatamente para aprovechar el crédito gratuito de Azure.***

