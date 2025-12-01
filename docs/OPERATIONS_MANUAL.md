# Manual de Operaciones

## Descripción General

Este documento proporciona guías prácticas para los operadores del sistema, incluyendo despliegue, monitoreo, troubleshooting y recuperación ante desastres.

## Tabla de Contenidos

1. [Requisitos Previos](#requisitos-previos)
2. [Despliegue](#despliegue)
3. [Monitoreo](#monitoreo)
4. [Troubleshooting](#troubleshooting)
5. [Recuperación ante Desastres](#recuperación-ante-desastres)
6. [Operaciones Comunes](#operaciones-comunes)

## Requisitos Previos

### Herramientas Necesarias

```bash
# Kubernetes
kubectl version --client

# Azure CLI
az --version

# Helm (gestión de paquetes K8s)
helm version

# Docker
docker --version

# Git
git --version
```

### Acceso

- **Kubeconfig**: `~/.kube/config` (solicitar a DevOps)
- **Azure credentials**: Configurar con `az login`
- **Secretos de CI/CD**: Almacenados en Azure Key Vault
- **Acceso a Grafana**: Usuario `admin` en http://grafana.local:3000

## Despliegue

### Despliegue Manual a Dev

```bash
# 1. Obtener código actualizado
git clone https://github.com/SelimHorri/ecommerce-microservice-backend-app.git
cd ecommerce-microservice-backend-app

# 2. Build de servicios
./mvnw clean package -DskipTests

# 3. Construir imágenes Docker
docker-compose -f compose.yml build

# 4. Levantar ambiente
docker-compose -f compose.yml up -d

# 5. Verificar servicios
docker-compose ps
```

### Despliegue a Kubernetes (Staging/Prod)

```bash
# 1. Autenticar en Azure
az login
az aks get-credentials --resource-group rg-ecommerce-staging --name aks-staging

# 2. Verificar contexto
kubectl config current-context
# Output: aks-staging

# 3. Verificar cluster
kubectl get nodes
kubectl get namespaces

# 4. Desplegar servicios
kubectl apply -f k8s/base/
kubectl apply -f k8s/staging/

# 5. Esperar que servicios estén listos
kubectl wait --for=condition=available --timeout=300s \
  deployment/product-service -n default

# 6. Verificar despliegue
kubectl get deployments
kubectl get pods
kubectl get services
```

### Despliegue Canary

Para desplegar una versión nueva minimizando riesgo:

```bash
# 1. Desplegar nueva versión en 10% del tráfico
kubectl set image deployment/product-service \
  product-service=registry.azurecr.io/ecommerce/product-service:v1.2.0

# 2. Monitorear métricas en Grafana
# - Verificar error rate
# - Verificar latencia
# - Verificar CPU/Memoria

# 3. Si todo bien, aumentar a 50%
kubectl patch deployment product-service -p \
  '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":"50%"}}}}'

# 4. Si todo bien, aumentar a 100%
kubectl patch deployment product-service -p \
  '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":"100%"}}}}'
```

## Monitoreo

### Acceso a Dashboards

| Componente | URL | Propósito |
|------------|-----|----------|
| Grafana | http://grafana.local:3000 | Métricas |
| Kibana | http://kibana.local:5601 | Logs |
| Zipkin | http://zipkin.local:9411 | Tracing |
| Prometheus | http://prometheus.local:9090 | Alertas |
| Kubernetes | http://k8s-dashboard.local:30000 | Cluster |

### Health Checks

```bash
# Revisar salud de todos los servicios
kubectl get pods --all-namespaces

# Revisar salud de un servicio específico
kubectl describe pod product-service-xxxxx

# Ver logs de un pod
kubectl logs product-service-xxxxx
kubectl logs product-service-xxxxx --follow  # tail

# Ver eventos del cluster
kubectl get events --all-namespaces
```

### Alertas Críticas

| Alerta | Acción |
|--------|--------|
| ServiceDown | Reiniciar pod: `kubectl delete pod <pod-name>` |
| HighErrorRate | Revisar logs en Kibana |
| HighLatency | Verificar recursos en nodos |
| OutOfMemory | Escalar pod: `kubectl set resources` |
| CircuitBreakerOpen | Verificar servicio dependiente |

### Verificación de Servicios

```bash
# Verificar si servicios están registrados en Eureka
curl -s http://service-discovery:8761/eureka/apps | grep serviceName

# Verificar endpoints de un servicio
curl -s http://product-service:8080/actuator/env | jq .

# Verificar métricas
curl -s http://product-service:8080/actuator/metrics | jq .names
```

## Troubleshooting

### Pod no inicia

```bash
# 1. Ver estado del pod
kubectl describe pod product-service-xxxxx

# 2. Ver logs
kubectl logs product-service-xxxxx
kubectl logs product-service-xxxxx --previous  # logs anteriores si se reinició

# 3. Ver eventos
kubectl get events --field-selector involvedObject.name=product-service-xxxxx

# 4. Posibles causas:
# - ImagePullBackOff: Imagen no encontrada
# - CrashLoopBackOff: Aplicación no inicia
# - Pending: Esperando recursos
```

### Servicio no responde

```bash
# 1. Verificar si pod está corriendo
kubectl get pods | grep product-service

# 2. Revisar readiness probe
kubectl logs product-service-xxxxx | grep -i "ready"

# 3. Verificar conectividad de red
kubectl exec -it product-service-xxxxx -- \
  curl http://service-discovery:8761/eureka/apps

# 4. Revisar logs de aplicación
kubectl logs product-service-xxxxx --timestamps=true

# 5. Si nada funciona, reiniciar
kubectl rollout restart deployment/product-service
```

### Errores de base de datos

```bash
# 1. Verificar conexión
kubectl logs order-service-xxxxx | grep -i "database"

# 2. Verificar variables de entorno
kubectl set env pod/order-service-xxxxx --list | grep -i db

# 3. Verificar secretos
kubectl get secret app-secrets -o yaml | grep -i db

# 4. Revisar estado de base de datos
kubectl exec -it mysql-pod -- \
  mysql -u root -p $DB_PASSWORD -e "SHOW DATABASES;"
```

### Memory leaks

```bash
# 1. Monitorer memoria
kubectl top pod product-service-xxxxx --containers

# 2. Ver historial de memoria
# Acceder a Grafana: jvm_memory_used_bytes

# 3. Si hay aumento continuo: restart pod
kubectl delete pod product-service-xxxxx

# 4. Si persiste: revisar logs de aplicación
kubectl logs product-service-xxxxx | grep -i "memory\|leak"
```

## Recuperación ante Desastres

### Rollback de Versión

```bash
# 1. Ver historial de despliegues
kubectl rollout history deployment/product-service

# 2. Ver detalles de una revisión específica
kubectl rollout history deployment/product-service --revision=5

# 3. Rollback a versión anterior
kubectl rollout undo deployment/product-service

# 4. Rollback a una revisión específica
kubectl rollout undo deployment/product-service --to-revision=5

# 5. Verificar que rollback funcionó
kubectl rollout status deployment/product-service
```

### Restaurar desde Backup

```bash
# 1. Listar backups disponibles
az backup vault list -g rg-ecommerce-prod

# 2. Restaurar base de datos
az backup restore restore-azure-database \
  --resource-group rg-ecommerce-prod \
  --vault-name backup-vault-prod \
  --backup-name mysql-db-backup-2025-01-15

# 3. Restaurar volúmenes persistentes
kubectl delete pvc mysql-data
kubectl apply -f k8s/backup/mysql-data-pvc-restore.yaml

# 4. Reiniciar pods para usar datos restaurados
kubectl rollout restart deployment/order-service
```

### Desastre Total (Cluster fallido)

```bash
# 1. Crear nuevo cluster
az aks create \
  --resource-group rg-ecommerce-prod \
  --name aks-prod-new \
  --node-count 5 \
  --vm-set-type VirtualMachineScaleSets

# 2. Obtener kubeconfig
az aks get-credentials \
  --resource-group rg-ecommerce-prod \
  --name aks-prod-new

# 3. Redeploy de aplicaciones
kubectl apply -f k8s/base/
kubectl apply -f k8s/prod/

# 4. Restaurar datos desde backup
# (ver sección anterior)

# 5. Actualizar DNS para apuntar al nuevo cluster
# (actualizar CNAME en registrador de dominios)
```

## Operaciones Comunes

### Escalar Servicios

```bash
# Aumentar réplicas de un servicio
kubectl scale deployment product-service --replicas=5

# Escalar automáticamente basado en CPU
kubectl autoscale deployment product-service \
  --min=2 --max=10 --cpu-percent=80
```

### Actualizar Configuración

```bash
# Actualizar ConfigMap
kubectl edit configmap app-config

# Los cambios se aplican automáticamente con @RefreshScope

# Verificar que se aplicó
kubectl get configmap app-config -o yaml
```

### Ejecutar Comandos en Pod

```bash
# Acceder a shell del pod
kubectl exec -it product-service-xxxxx -- bash

# Ejecutar un comando
kubectl exec product-service-xxxxx -- \
  java -cp ... com.example.MigrationScript
```

### Ver Logs en Tiempo Real

```bash
# Logs de todos los pods del servicio
kubectl logs -l app=product-service --follow

# Logs con timestamps
kubectl logs product-service-xxxxx --timestamps=true --all-containers=true
```

### Revisar Eventos de Cluster

```bash
# Eventos recientes
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Eventos de un servicio específico
kubectl get events --field-selector involvedObject.name=product-service-xxxxx
```

### Cambiar Contexto/Ambiente

```bash
# Listar contextos disponibles
kubectl config get-contexts

# Cambiar a dev
kubectl config use-context aks-dev

# Cambiar a staging
kubectl config use-context aks-staging

# Cambiar a producción
kubectl config use-context aks-prod

# Verificar contexto actual
kubectl config current-context
```

## Checklist de Operaciones Diarias

- [ ] Revisar dashboards de Grafana (error rate, latencia)
- [ ] Revisar alertas en Prometheus
- [ ] Verificar `kubectl get nodes` (todos Ready)
- [ ] Verificar `kubectl get pods` (todos Running)
- [ ] Revisar logs en Kibana para errores
- [ ] Verificar capacidad de almacenamiento
- [ ] Verificar backups han completado exitosamente
- [ ] Revisar documentación de cambios pendientes

## Referencias

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
