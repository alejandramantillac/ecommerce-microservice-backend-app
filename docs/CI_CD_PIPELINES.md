# CI/CD Pipeline - Jenkins & Azure DevOps

## Descripción General

Este documento describe la configuración completa de CI/CD para el proyecto de microservicios, incluyendo pipelines para múltiples ambientes (dev, staging, prod), análisis de código, escaneo de seguridad y despliegue automático.

## Visión General del Pipeline

```
┌─────────────────┐
│  Git Push       │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│         Jenkinsfile.dev (Desarrollo)            │
├─────────────────────────────────────────────────┤
│ ✓ Build & Test                                  │
│ ✓ SonarQube Analysis                            │
│ ✓ Trivy Scan                                    │
│ ✓ Push to Registry                              │
│ ✓ Deploy to Dev AKS                             │
└────────┬────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│      Jenkinsfile.stage (Staging)                │
├─────────────────────────────────────────────────┤
│ ✓ Build & Test (mismos tests)                   │
│ ✓ SonarQube Analysis                            │
│ ✓ Trivy Scan                                    │
│ ✓ Performance Testing                           │
│ ✓ Deploy to Staging AKS                         │
│ ✓ E2E Testing                                   │
└────────┬────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│     Jenkinsfile.prod (Producción)               │
├─────────────────────────────────────────────────┤
│ ✓ Build & Test                                  │
│ ✓ SonarQube Analysis                            │
│ ✓ Trivy Scan                                    │
│ ✓ Generate Release Notes                        │
│ ✓ Manual Approval                               │
│ ✓ Deploy to Prod AKS                            │
│ ✓ Health Checks                                 │
└────────────────────────────────────────────────┘
```

## Estrutura de Jenkinsfiles

### Jenkinsfile.dev - Pipeline de Desarrollo

**Triggers**: Cualquier push a la rama `develop`

**Stages**:

1. **Checkout**: Obtiene el código del repositorio
2. **Build**: `mvnw clean package` para todos los servicios
3. **Unit Tests**: Ejecuta pruebas unitarias
4. **SonarQube Analysis**: Escaneo de código estático
5. **Trivy Scan**: Escaneo de vulnerabilidades en imágenes Docker
6. **Push Images**: Sube imágenes a Azure Container Registry
7. **Deploy to Dev**: Despliegue automático a AKS dev
8. **Smoke Tests**: Validación rápida del despliegue

**Duración típica**: 15-20 minutos

### Jenkinsfile.stage - Pipeline de Staging

**Triggers**: Merges a `release/*` o manual trigger

**Stages**:

1. **Checkout**: Obtiene el código
2. **Build**: Build completo con tests
3. **SonarQube Analysis**: Análisis de calidad
4. **Trivy Scan**: Escaneo de seguridad
5. **Integration Tests**: Pruebas de integración entre servicios
6. **Build Docker Images**: Construcción de imágenes
7. **Push to Registry**: Sube a ACR
8. **Deploy to Staging**: Despliegue a AKS staging
9. **Smoke Tests**: Validación básica
10. **Performance Tests**: Pruebas de rendimiento con Locust
11. **E2E Tests**: Pruebas end-to-end completas
12. **Security Tests**: Pruebas de seguridad (OWASP ZAP)

**Duración típica**: 45-60 minutos

### Jenkinsfile.prod - Pipeline de Producción

**Triggers**: Merges a `main` (requiere PR aprobado)

**Stages**:

1. **Checkout**: Obtiene el código
2. **Build**: Build con todos los tests
3. **SonarQube Analysis**: Análisis de código
4. **Trivy Scan**: Escaneo de vulnerabilidades
5. **Generate Release Notes**: Crea release notes automáticamente
6. **Approval Gate**: Requiere aprobación manual
7. **Create Git Tag**: Crea tag con versión semántica
8. **Build Production Images**: Imágenes optimizadas para producción
9. **Push to Registry**: Sube a ACR
10. **Deploy to Production**: Despliegue a AKS prod
11. **Health Checks**: Validación completa
12. **Smoke Tests**: Validación funcional
13. **Notify Slack**: Notificación a equipo

**Duración típica**: 50-70 minutos (incluyendo aprobación)

### Jenkinsfile.security - Pipeline de Seguridad

**Triggers**: Scheduled (diario) o manual

**Stages**:

1. **Container Scanning**: Escaneo profundo de imágenes
2. **OWASP ZAP**: Escaneo de seguridad web
3. **Dependency Check**: Análisis de dependencias vulnerables
4. **Generate Security Report**: Genera reporte de seguridad

## Análisis de Código - SonarQube

### Configuración

```properties
# sonar-project.properties
sonar.projectKey=ecommerce-microservice-backend
sonar.projectName=E-Commerce Microservices
sonar.projectVersion=${BUILD_NUMBER}
sonar.sources=src/main/java
sonar.tests=src/test/java
sonar.java.binaries=target/classes
sonar.qualitygate.wait=true
sonar.qualitygate.timeout=300
```

### Quality Gate

Las métricas mínimas requeridas para pasar:

- **Coverage**: Mínimo 50% (objetivo 80%)
- **Duplicated Lines**: Máximo 5%
- **Code Smells**: Máximo 10
- **Vulnerabilidades**: 0
- **Security Hotspots**: Máximo 5

### Resultados

Los resultados se publican en:
- Dashboard de SonarQube: `http://sonarqube.local:9000`
- Reporte en Jenkins: Pestaña "SonarQube" en cada build

## Escaneo de Vulnerabilidades - Trivy

### Configuración

```bash
trivy image --severity HIGH,CRITICAL \
  --exit-code 1 \
  registry.azurecr.io/ecommerce/product-service:latest
```

### Severidades

| Severidad | Acción |
|-----------|--------|
| CRITICAL  | ❌ Bloquea despliegue |
| HIGH      | ❌ Bloquea despliegue (puede ignorarse con aprobación) |
| MEDIUM    | ⚠️ Advierte pero permite |
| LOW       | ℹ️ Informativo |

### Reportes

Los reportes de Trivy se guardan en:
- `target/trivy-report.json`
- `target/trivy-report.html`

Consultables en Jenkins como artefacto.

## Pruebas Completas

### Unitarias

- **Framework**: JUnit 5 + Mockito
- **Coverage mínimo**: 50%
- **Comando**: `mvnw test`
- **Reporte**: `target/site/jacoco/index.html`

### Integración

- **Framework**: TestContainers + JUnit 5
- **Cobertura**: Servicios y repositorios
- **Comando**: `mvnw verify`

### E2E

- **Framework**: RestAssured + JUnit 5
- **Alcance**: Flujos completos de usuario
- **Ambientes**: Staging y Producción
- **Localización**: `tests/e2e/`

### Rendimiento

- **Framework**: Locust (Python)
- **Ubicación**: `tests/performance/`
- **Métricas**: Response time, throughput, error rate
- **Ejecución**: Automática en staging

### Seguridad

- **Herramienta**: OWASP ZAP
- **Tests**: SQL injection, XSS, CSRF
- **Umbral**: 0 vulnerabilidades críticas

## Gestión de Artefactos

### Versionado Semántico

El versionado se calcula automáticamente en base a:

```
MAJOR.MINOR.PATCH-BUILD_NUMBER
```

Ejemplos:
- `1.0.0-123` - Build 123 de v1.0.0
- `1.1.0-456` - Build 456 de v1.1.0
- `2.0.0-789` - Build 789 de v2.0.0

### Publicación de Release Notes

Al desplegar a producción, se generan automáticamente:

```markdown
# Release v1.2.3

## Features
- DEVOPS-123: Nueva funcionalidad de búsqueda avanzada
- DEVOPS-125: Mejorada escalabilidad de producto service

## Bug Fixes
- DEVOPS-120: Corregido timeout en payment service
- DEVOPS-122: Corregido error de concurrencia en order service

## Performance
- Reducido tiempo de respuesta del producto service en 20%
- Optimizada consulta de búsqueda de productos

## Security
- Actualizado Spring Security a v5.7.0
- Corregida vulnerabilidad CVE-2021-12345

## Gracias
Creador: John Doe
Revisores: Jane Smith, Bob Johnson
```

## Notificaciones y Alertas

### Slack

Se envían notificaciones a `#devops-pipelines`:

```
✅ Build exitoso de develop
Proyecto: ecommerce-microservice-backend
Rama: develop
Commit: abc123de...
Autor: Juan Developer
Duración: 18 minutos
URL: http://jenkins.local:8080/job/ecommerce-dev/123/
```

### Fallos

```
❌ Build fallido
Proyecto: ecommerce-microservice-backend
Rama: release/v1.2
Etapa fallida: SonarQube Analysis
Error: Quality Gate failed
Revisar: http://jenkins.local:8080/job/ecommerce-stage/456/console
```

## Rollback y Recuperación

### Rollback Manual

```bash
# Verificar versiones desplegadas
kubectl rollout history deployment/product-service

# Rollback a versión anterior
kubectl rollout undo deployment/product-service --to-revision=5

# Verificar estado
kubectl rollout status deployment/product-service
```

### Rollback Automático

Habilitado mediante el Jenkinsfile cuando falla health check post-despliegue:

```groovy
stage('Health Checks') {
  steps {
    script {
      if (!healthCheckPassed) {
        echo "Health check failed, rolling back..."
        sh 'kubectl rollout undo deployment/product-service'
      }
    }
  }
}
```

## Mejores Prácticas

1. **Commits pequeños**: Un cambio por commit
2. **Mensajes claros**: Siga la convención `[TICKET] descripción`
3. **Pruebas locales**: Ejecute tests localmente antes de push
4. **PR Reviews**: Mínimo 2 aprobaciones antes de merge
5. **Monitoreo**: Revise logs de pipeline para despliegues
6. **Documentación**: Actualice docs en el mismo PR que el código
7. **Secretos**: Use Azure Key Vault, nunca hardcodee

## Archivos Principales

- `Jenkinsfile.dev` - Pipeline de desarrollo
- `Jenkinsfile.stage` - Pipeline de staging
- `Jenkinsfile.prod` - Pipeline de producción
- `Jenkinsfile.security` - Pipeline de seguridad
- `jenkins/scripts/` - Scripts compartidos
- `jenkins/shared-lib/` - Librería compartida
- `pom.xml` - Configuración de pruebas y análisis
- `sonar-project.properties` - Configuración SonarQube
