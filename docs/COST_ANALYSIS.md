# Análisis de Costos de Infraestructura

## Descripción General

Este documento proporciona un análisis detallado de los costos de infraestructura en Azure para los diferentes ambientes (dev, staging, prod), incluyendo estimaciones mensuales y estrategias de optimización.

## Resumen Ejecutivo

| Ambiente              | Componentes                                 | Costo Estimado              | Rango |
| --------------------- | ------------------------------------------- | --------------------------- | ----- |
| **Staging**     | AKS (3 nodos), ACR, DB, Storage             | **$450-700/mes**      | Medio |
| **Producción** | AKS (5+ nodos), ACR, DB HA, Storage Premium | **$1,200-2,000/mes**  | Alto  |
| **TOTAL**       | Todos los ambientes                         | **~$1,800-2,900/mes** | -     |

## Desglose por Componente

### 1. Azure Kubernetes Service (AKS)

#### Desarrollo

```
VM Type: Standard_B2s
Cantidad de nodos: 1
Precio por nodo: ~$0.096/hora = ~$70/mes
Costo adicional AKS: ~$15/mes (gestión del cluster)
──────────────────────────
TOTAL DEV AKS: ~$85/mes
```

#### Staging

```
VM Type: Standard_D2s_v3
Cantidad de nodos: 3 (escalado automático 1-5)
Precio por nodo: ~$0.258/hora = ~$188/nodo/mes
Nodos promedio: 3
Costo de nodos: 3 × $188 = ~$564/mes
Costo adicional AKS: ~$20/mes
──────────────────────────
TOTAL STAGING AKS: ~$584/mes
```

#### Producción

```
VM Type: Standard_D4s_v3
Cantidad de nodos: 5 (escalado automático 3-10)
Precio por nodo: ~$0.52/hora = ~$380/nodo/mes
Nodos promedio: 5
Costo de nodos: 5 × $380 = ~$1,900/mes
Costo adicional AKS: ~$30/mes
──────────────────────────
TOTAL PROD AKS: ~$1,930/mes
```

### 2. Azure Container Registry (ACR)

```
SKU: Premium (prod), Standard (stage), Basic (dev)

Dev (Basic):
- Almacenamiento: 10 GB
- Precio: ~$5 + $0.10/GB = ~$6/mes

Staging (Standard):
- Almacenamiento: 50 GB
- Precio: ~$100 + $0.10/GB = ~$105/mes

Prod (Premium):
- Almacenamiento: 100 GB
- Replicación geo: 2 regiones
- Precio: ~$250 + (2 × $0.10/GB) = ~$270/mes

──────────────────────────
TOTAL ACR: ~$381/mes
```

### 3. Azure SQL Database / MySQL

#### Desarrollo

```
Tipo: En memoria (H2) - Incluido en AKS
Costo: $0/mes
```

#### Staging

```
MySQL - Standard tier
DTU: 10 (Basic)
Almacenamiento: 5 GB
Costo: ~$35 + backups = ~$50/mes
```

#### Producción

```
MySQL - Premium tier con High Availability
DTU: 20 (Standard)
Almacenamiento: 100 GB
Replicas: Activo-Activo (2 zonas)
Backups: 35 días
Costo: ~$150 + replicas $75 + backups $30 = ~$255/mes
```

**TOTAL Base de Datos: ~$305/mes**

### 4. Azure Storage

#### Desarrollo

```
Tipo: Storage account estándar
Almacenamiento: 5 GB
Transacciones: ~100k/mes
Costo: ~$0.50/GB + ~$5 = ~$10/mes
```

#### Staging

```
Tipo: Storage account estándar
Almacenamiento: 50 GB
Transacciones: ~1M/mes
Costo: ~$0.50/GB + ~$20 = ~$45/mes
```

#### Producción

```
Tipo: Premium storage (replicado)
Almacenamiento: 500 GB
Transacciones: ~10M/mes
Replicación: Geo-redundante
Costo: ~$1/GB + ~$100 = ~$600/mes
```

**TOTAL Storage: ~$655/mes**

### 5. Otros Servicios

#### Application Gateway (Staging + Prod)

```
Staging: ~$50/mes
Prod: ~$80/mes
TOTAL: ~$130/mes
```

#### Monitoreo (Prometheus, Grafana, ELK)

```
Prometheus + Grafana: ~$50/mes (VM para alojamiento)
Elasticsearch: ~$100/mes (3 nodos)
TOTAL: ~$150/mes
```

#### Backup y Recuperación Ante Desastres

```
Azure Backup: ~$50/mes
Backup storage: ~$30/mes
TOTAL: ~$80/mes
```

#### Networking

```
VNet: Gratis
NSG: Gratis
Load Balancer: ~$20/mes
Public IPs: ~$5/mes
TOTAL: ~$25/mes
```

## Costo Total Mensual

```
┌────────────────────────────────────────┐
│       RESUMEN POR COMPONENTE            │
├────────────────────────────────────────┤
│ AKS (3 ambientes)       $2,599/mes     │
│ Container Registry      $381/mes       │
│ Base de Datos           $305/mes       │
│ Storage                 $655/mes       │
│ Application Gateway     $130/mes       │
│ Monitoreo              $150/mes       │
│ Backup/DR              $80/mes        │
│ Networking             $25/mes        │
├────────────────────────────────────────┤
│ TOTAL MENSUAL           $4,325/mes     │
├────────────────────────────────────────┤
│ Costo anual            ~$51,900/año    │
└────────────────────────────────────────┘
```

## Estrategias de Optimización

### Corto Plazo (1-3 meses)

#### 1. Tamaño de VM Apropiado

```
Cambio actual: Standard_D2s_v3 → B-series para dev
Ahorro: ~$50/mes
```

#### 2. Eliminación de Ambiente No Usado

```
Si se puede eliminar dev en producción:
Ahorro: ~$85/mes
```

#### 3. Optimización de Almacenamiento

```
Cleanup de imágenes antiguas en ACR
Reducción: 50 → 20 GB
Ahorro: ~$30/mes
```

**Ahorro Potencial Corto Plazo: ~$165/mes (3.8%)**

### Mediano Plazo (3-12 meses)

#### 1. Reserved Instances (1 año)

```
AKS Standard_D2s_v3: 30% descuento
Ahorro: ~$176/mes
```

#### 2. Spot Instances (Dev/Stage)

```
Usar Spot VMs para workloads no críticos
Riesgo: Baja (dev/stage)
Ahorro: ~$200/mes
```

#### 3. Consolidación de Bases de Datos

```
Usar MySQL flexible server en lugar de Premium
Reducción de replicas en staging
Ahorro: ~$75/mes
```

#### 4. Reducción de Retención de Backups

```
De 35 días a 14 días
Ahorro: ~$15/mes
```

**Ahorro Potencial Mediano Plazo: ~$466/mes (10.8%)**

### Largo Plazo (12+ meses)

#### 1. Multi-Cloud (FinOps)

```
Distribuir carga entre Azure + AWS
Aprovechar precios competitivos
Ahorro: ~$800/mes (18%)
```

#### 2. Serverless (Funciones Azure)

```
Reemplazar algunos microservicios con Functions
Pagar solo por uso
Ahorro: ~$300/mes (7%)
```

#### 3. Auto-scaling Avanzado con KEDA

```
Scale to zero en horarios bajos
Ahorro: ~$200/mes (4%)
```

**Ahorro Potencial Largo Plazo: ~$1,300/mes (30%)**

## Dashboard de Costos

### Cost Anomalies

Se monitorean costos inesperados:

```
Alertas automáticas si:
- Costo diario > promedio × 120%
- Nuevo servicio no presupuestado
- Recursos sin etiquetar
```

### Etiquetado de Recursos

```yaml
Todos los recursos deben tener tags:
- Environment: dev | staging | prod
- Team: devops
- Project: ecommerce
- CostCenter: ABC123
- Owner: maria@company.com
```

### Reporte Mensual

Se genera reporte con:

- Costo actual vs presupuesto
- Tendencia de costos
- Servicios más costosos
- Oportunidades de ahorro

## Presupuesto y Alertas

```
Presupuesto Mensual: $5,000
Alerta Nivel 1: 75% ($3,750) - Notificación
Alerta Nivel 2: 90% ($4,500) - Escalación
Alerta Nivel 3: 100%+ ($5,000) - Crítica

Acción si se excede:
1. Revisar gastos inesperados
2. Desactivar recursos no utilizados
3. Escalar a liderazgo
4. Revisar presupuesto para próximo mes
```

## Matriz de Decisión Costo vs Performance

| Decisión              | Costo | Performance | Recomendación       |
| ---------------------- | ----- | ----------- | -------------------- |
| Aumentar nodos en Prod | ↑↑  | ✅ Mejora   | Si latencia > umbral |
| Usar Spot Instances    | ↓↓  | ⚠️ Riesgo | Solo non-critical    |
| Reserved Instances     | ↓    | ➡️ Igual  | Sí, 1-3 años       |
| Geo-replicación       | ↑↑  | ✅ HA       | Solo Prod            |
| Auto-scaling KEDA      | ➡️  | ✅ Variable | Implementar          |

## Referencias

- [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)
- [Cost Management + Billing](https://docs.microsoft.com/en-us/azure/cost-management-billing/)
- [FinOps Foundation](https://www.finops.org/)
