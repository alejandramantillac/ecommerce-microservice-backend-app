# Gestión de Cambios y Release Notes

## Descripción General

Este documento define el proceso formal de Change Management para el proyecto, incluyendo evaluación de cambios, aprobaciones, planes de rollback y generación automática de release notes.

## Proceso de Change Management

### Fases del Cambio

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────┐
│   Planning  │────▶│ Assessment   │────▶│   Approval   │────▶│ Execute  │
└─────────────┘     └──────────────┘     └──────────────┘     └──────────┘
       │                    │                     │                  │
       │                    │                     │                  │
       ▼                    ▼                     ▼                  ▼
   Definir cambio    Evaluar impacto      Revisar por CAB      Desplegar
   Crear RFC         Riesgos              Obtener firmas       Monitorear
   Asignar equipo    Rollback plan        Schedule             Validar
   Documentar        Testing required     Communication        Cerrar
```

## 1. Request for Change (RFC)

### Información Requerida

Toda solicitud de cambio debe incluir:

**Sección 1: Información Básica**
- **ID del RFC**: Auto-generado (RFC-2025-001, RFC-2025-002, etc.)
- **Título**: Descripción concisa del cambio
- **Fecha solicitada**: Cuándo se solicita
- **Fecha objetivo**: Cuándo se desea desplegar
- **Solicitante**: Quién solicita el cambio
- **Propietario del cambio**: Quién es responsable

**Sección 2: Descripción Detallada**
- **Descripción**: Qué se cambia y por qué
- **Justificación**: Beneficios esperados
- **Alcance**: Qué servicios/componentes afecta
- **Dependencias**: Otros cambios relacionados

**Sección 3: Análisis de Impacto**
- **Servicios afectados**: Lista de microservicios
- **BD afectadas**: Cambios de esquema necesarios
- **APIs afectadas**: Cambios en contratos
- **Usuarios afectados**: Número aproximado
- **Riesgo**: Bajo / Medio / Alto / Crítico

**Sección 4: Plan de Testing**
- **Pruebas requeridas**: Unitarias, integración, E2E
- **Ambientes de testing**: Dev, Staging, Prod
- **Criterios de aceptación**: Qué se debe validar
- **Datos de prueba**: Qué datos se necesitan

**Sección 5: Plan de Rollback**
- **Procedimiento**: Pasos para revertir
- **Tiempo estimado**: Cuánto toma deshacer
- **Punto de no retorno**: Desde cuándo no se puede rollback
- **Datos a preservar**: Qué debe guardarse

**Sección 6: Plan de Comunicación**
- **Afectados**: Quién se ve impactado
- **Notificación**: Cómo y cuándo avisar
- **Documentación**: Qué se actualiza
- **Soporte**: Quién brinda soporte

### Template RFC

```markdown
# RFC-2025-XXX: [Título del Cambio]

## Información Básica
- **ID**: RFC-2025-001
- **Fecha solicitada**: 2025-01-15
- **Fecha objetivo**: 2025-01-20 22:00 UTC
- **Solicitante**: Juan Developer (juan@company.com)
- **Propietario**: María DevOps (maria@company.com)
- **Prioridad**: High

## Descripción
Actualizar Spring Boot de v2.7.0 a v3.0.0 para mejorar performance y seguridad.

## Análisis de Impacto
- **Riesgo**: Alto (cambio major de versión)
- **Servicios afectados**: Todos (10 servicios)
- **BD afectadas**: Ninguno
- **APIs afectadas**: Ninguno (compatible)
- **Users afectados**: Interno (no impacta usuarios)

## Plan de Testing
- Unit tests: ✓ Todos pasan
- Integration tests: ✓ Todos pasan
- E2E tests: ✓ Flujo de orden completo
- Performance: ✓ Baseline 10% mejor
- Security: ✓ OWASP ZAP limpio

## Plan de Rollback
**Procedimiento**:
1. Crear snapshot de base de datos
2. Revertir imágenes Docker a v2.7.0
3. `kubectl rollout undo deployment/product-service`
4. Validar con smoke tests

**Tiempo**: 15 minutos
**Punto de no retorno**: 30 minutos después de despliegue

## Aprobaciones
- [ ] Arquitecto: 
- [ ] Release Manager:
- [ ] Product Owner:
- [ ] Security:
```

## 2. Change Advisory Board (CAB)

### Integrantes Mínimos

| Rol | Responsabilidad | Puede rechazar |
|-----|-----------------|----------------|
| Release Manager | Coordina cambios | ✅ Sí |
| Architect | Evalúa impacto técnico | ✅ Sí |
| Security Lead | Revisa seguridad | ✅ Sí |
| Product Owner | Impacto en negocio | ✅ Sí |
| Infrastructure | Impacto en infra | ⚠️ Advierte |
| QA Lead | Cobertura de tests | ⚠️ Advierte |

### Criterios de Aprobación

**Cambios Low-Risk** (ej: bugfix, documentación):
- ✅ Aprobación Release Manager
- ✅ Despliegue inmediato posible

**Cambios Medium-Risk** (ej: nueva feature, actualización menor):
- ✅ Aprobación Release Manager + Architect + QA
- ✅ Despliegue en horario laboral
- ✅ Monitoreo activo

**Cambios High-Risk** (ej: actualización major, cambio arquitectura):
- ✅ Aprobación completa del CAB
- ✅ Despliegue en ventana de mantenimiento programado
- ✅ Equipo oncall disponible
- ✅ Comunicación preventiva a usuarios

**Cambios Críticos** (ej: migraciones, cambios de BD):
- ✅ CAB aprobación + Security Lead
- ✅ Despliegue con autoridades de negocio presentes
- ✅ Rollback tested previamente
- ✅ Backup validado

## 3. Ventanas de Despliegue

### Horarios Permitidos

| Ambiente | Día | Horario | Duración máx |
|----------|-----|---------|-------------|
| Dev | Cualquier | 24/7 | No aplica |
| Staging | L-V | 10:00-12:00 UTC | 2 horas |
| Staging | V | 22:00 UTC | 4 horas |
| Prod | L-J | 22:00-02:00 UTC | 2 horas |
| Prod | Sábado | 02:00-06:00 UTC | 4 horas |
| Prod | Domingo | No permitido | N/A |

**Excepciones**: Hotfix para incidentes críticos (requiere aprobación Release Manager)

## 4. Generación Automática de Release Notes

### Proceso

```bash
# 1. Los commits siguen convención (ver conventional-commits.md)
git commit -m "feat(product): agregar búsqueda avanzada"
git commit -m "fix(order): corregir timeout en Payment Service"
git commit -m "perf(api-gateway): optimizar serialización JSON"

# 2. Pipeline extrae commits entre versiones
# Usando: git log v1.0.0..v1.1.0 --oneline

# 3. Agrupa por tipo
# Features:
# - feat(product): agregar búsqueda avanzada

# Bug Fixes:
# - fix(order): corregir timeout en Payment Service

# Performance:
# - perf(api-gateway): optimizar serialización JSON

# 4. Genera Release Notes en Markdown
# 5. Publica en repositorio (GitHub Releases)
# 6. Notifica a stakeholders
```

### Template de Release Notes

```markdown
# Release v1.2.0

**Released**: 2025-01-20

## ✨ Features

### Payment Service
- **DEVOPS-123**: Integración con nueva pasarela de pagos
- **DEVOPS-125**: Soporte para múltiples monedas
- **DEVOPS-128**: Webhooks para notificaciones de pago

### Product Service
- **DEVOPS-145**: Búsqueda avanzada con filtros
- **DEVOPS-147**: Recomendaciones personalizadas con IA

## 🐛 Bug Fixes

### Order Service
- **DEVOPS-120**: Corregido timeout en creación de órdenes
- **DEVOPS-122**: Corregido race condition en inventario

### API Gateway
- **DEVOPS-150**: Corregido bug de caché CORS

## 📈 Performance

- Reducido latencia P95 en Product Service de 800ms a 600ms (-25%)
- Optimizada consulta de búsqueda con índices adicionales (-40% CPU)
- Mejorado throughput de Payment Service 15% con pooling

## 🔒 Security

- Actualizado Spring Security a v5.8.0
- Parche para CVE-2021-44228 (Log4Shell)
- Mejorada validación de entrada en todos los endpoints

## 📚 Documentation

- Actualizada guía de operaciones
- Nuevos ejemplos de API en Swagger
- Documentación de feature toggles

## 🙏 Contributors

- **Code**: Juan Developer, María Engineer
- **Review**: Carlos Architect, Sofia QA
- **Release**: Roberto DevOps

## 📥 Installation

```bash
# Using Docker Compose
docker-compose -f compose.yml up --no-deps --build product-service

# Using Kubernetes
kubectl set image deployment/product-service \
  product-service=registry.azurecr.io/ecommerce/product-service:v1.2.0
```

## ⚠️ Breaking Changes

- **API**: Removido endpoint `GET /api/products/search` (usar `/api/products?q=query`)
- **Database**: Requerida migración de schema (ejecutada automáticamente)

## 🔄 Migration Guide

Ver: [Guía de Migración v1.1 → v1.2](docs/migrations/v1.1-to-v1.2.md)

## 🐛 Known Issues

- Occasional timeout en búsqueda con >100k resultados (en investigación)

## 📞 Support

- Issues: https://github.com/SelimHorri/ecommerce-microservice-backend-app/issues
- Chat: #ecommerce-support en Slack
- Escalation: devops@company.com
```

## 5. Etiquetado de Releases

### Convención de Tags

```
vMAJOR.MINOR.PATCH

Ejemplos:
v1.0.0      (Release inicial)
v1.0.1      (Patch - bugfix)
v1.1.0      (Minor - nueva feature compatible)
v2.0.0      (Major - cambios incompatibles)

Pre-releases:
v1.1.0-alpha.1
v1.1.0-beta.2
v1.1.0-rc.1
```

### Generación de Tags en Pipeline

```groovy
// En Jenkinsfile.prod
stage('Generate Release Notes') {
  steps {
    script {
      // Calcular versión
      def version = commonFunctions.calculateVersion()
      
      // Generar release notes
      def releaseNotes = commonFunctions.generateReleaseNotes(
        previousVersion: env.PREVIOUS_VERSION,
        currentVersion: version,
        commits: env.COMMITS
      )
      
      // Crear tag
      sh """
        git tag -a v${version} -m '${releaseNotes}'
        git push origin v${version}
      """
      
      // Publicar en GitHub
      sh """
        gh release create v${version} \
          --title 'Release ${version}' \
          --notes '${releaseNotes}'
      """
    }
  }
}
```

## 6. Planes de Rollback

### Estrategia General

```
┌─────────────────────────────────────────────┐
│  Monitoreo Post-Despliegue (30 minutos)    │
├─────────────────────────────────────────────┤
│ Si error_rate > 5%  ──▶ Iniciar rollback   │
│ Si latency > 2s     ──▶ Iniciar rollback   │
│ Si fallos críticos  ──▶ Rollback inmediato │
└─────────────────────────────────────────────┘
```

### Rollback Manual

```bash
# 1. Verificar versión anterior
kubectl rollout history deployment/product-service

# 2. Ejecutar rollback
kubectl rollout undo deployment/product-service --to-revision=5

# 3. Verificar estado
kubectl rollout status deployment/product-service
kubectl get pods

# 4. Validar con smoke tests
./tests/smoke-tests.sh

# 5. Notificar al CAB
slack_message "Rollback completed for product-service"

# 6. Generar incident report
./scripts/generate-rollback-report.sh
```

### Rollback Automático

Habilitado si falla readiness probe después de despliegue:

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  # Readiness probe fail ──▶ K8s detiene rollout
  # Health check fail  ──▶ Pipeline ejecuta undo automático
```

## 7. Documentación de Cambios

Cada cambio debe documentarse en:

```
docs/changes/
├── 2025-01/
│   ├── RFC-2025-001-spring-boot-upgrade.md
│   ├── RFC-2025-002-payment-integration.md
│   └── RFC-2025-003-search-optimization.md
└── 2025-02/
```

**Contenido mínimo**:
- Descripción del cambio
- Servicios afectados
- Cambios de API (si aplica)
- Migraciones de BD (si aplica)
- Rollback procedure
- Resultado (exitoso / fallido / parcial)

## 8. Comunicación

### Plantilla de Notificación Pre-Despliegue

```
Asunto: 🚀 Despliegue Programado: Título del cambio

Equipo,

Se programó un despliegue para:
**Fecha/Hora**: 2025-01-20 22:00 UTC
**Duración estimada**: 30 minutos
**Impacto**: Bajo (cambios internos)
**Servicios afectados**: Product Service, Order Service

**Qué cambia**:
- Nueva funcionalidad de búsqueda avanzada
- Optimización de latencia (-25%)

**Qué NO cambia**:
- API pública (compatible)
- Datos de usuario (migraran automáticamente)

**Rollback plan**: Disponible (< 15 minutos)

**Contacto para preguntas**: María DevOps (maria@company.com)

Gracias,
DevOps Team
```

### Plantilla Post-Despliegue

```
✅ Despliegue Exitoso

Versión: v1.2.0
Fecha: 2025-01-20 22:15 UTC
Duración: 15 minutos
Servicios desplegados: 3

Métricas:
- Error rate: 0.05% (normal)
- Latencia P95: 620ms (mejor que antes)
- CPU: 45% (dentro de límites)

Release notes: https://github.com/.../releases/tag/v1.2.0

Próximo paso: Monitoreo por 24 horas
```

## Checklist Pre-Despliegue

- [ ] RFC aprobado por CAB
- [ ] Todos los tests pasando
- [ ] SonarQube quality gate OK
- [ ] Trivy scan sin vulnerabilidades críticas
- [ ] Release notes generadas
- [ ] Rollback plan testeado
- [ ] Comunicación enviada
- [ ] Equipo oncall confirmado
- [ ] Backup de BD completado
- [ ] Monitoreo configurado
