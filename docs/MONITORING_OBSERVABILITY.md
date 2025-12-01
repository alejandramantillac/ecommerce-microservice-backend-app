# Observabilidad y Monitoreo

## Descripción General

Este documento describe la arquitectura de observabilidad completa implementada para el sistema de microservicios, incluyendo monitoreo de métrica, recopilación de logs, tracing distribuido y alertas.

## Stack de Observabilidad

```
┌──────────────────────────────────────────────────────────┐
│               Capas de Observabilidad                    │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Presentación                                           │
│  ├─ Grafana (Dashboards de Métricas)                    │
│  ├─ Kibana (Análisis de Logs)                           │
│  └─ Jaeger/Zipkin (Tracing Distribuido)                 │
│                                                          │
│  Agregación                                             │
│  ├─ Prometheus (Series de tiempo)                       │
│  ├─ ELK Stack (Elasticsearch, Logstash)                 │
│  └─ Zipkin (Spans distribuidos)                         │
│                                                          │
│  Instrumentación                                        │
│  ├─ Spring Boot Actuator (Métricas)                     │
│  ├─ Logback (Logs)                                      │
│  └─ Spring Cloud Sleuth (Tracing)                       │
│                                                          │
│  Aplicación (Microservicios)                            │
│  └─ 10 servicios instrumentados                         │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## 1. Métricas - Prometheus + Grafana

### Prometheus

**Configuración**:
- **Puerto**: 9090
- **Scrape interval**: 15 segundos
- **Retention**: 15 días
- **URL**: `http://prometheus.local:9090`

**Targets configurados**:
- API Gateway (8080)
- Proxy Client (8900)
- User Service (8700)
- Product Service (8701)
- Order Service (8702)
- Payment Service (8703)
- Shipping Service (8704)
- Favourite Service (8705)
- Cloud Config (8888)
- Service Discovery (8761)

**Métricas recopiladas**:

```
# JVM Metrics
jvm_memory_used_bytes
jvm_memory_max_bytes
jvm_gc_pause_seconds
jvm_threads_live_threads

# HTTP Metrics
http_server_requests_seconds
http_requests_total
http_requests_duration_seconds

# Circuit Breaker (Resilience4j)
resilience4j_circuitbreaker_calls_total
resilience4j_circuitbreaker_state
resilience4j_circuitbreaker_failure_rate

# Database Metrics
jdbc_connections_active
jdbc_connections_max
```

### Grafana

**Configuración**:
- **Puerto**: 3000
- **Usuario admin**: admin / admin (cambiar en prod)
- **Data source**: Prometheus
- **URL**: `http://grafana.local:3000`

**Dashboards implementados**:

#### 1. Dashboard de Infraestructura
- CPU/Memoria del sistema
- Uso de red
- Salud de hosts Kubernetes
- Disponibilidad de servicios

#### 2. Dashboard de Aplicación
- Requests por segundo (RPS)
- Latencia P50/P95/P99
- Tasa de errores
- Saturación de recursos

#### 3. Dashboard de Microservicios
- Métricas por servicio
- Circuit breaker status
- Connection pool status
- Cache hit rate

#### 4. Dashboard de Negocio
- Órdenes procesadas
- Ingresos por hora
- Tasa de conversión
- Productos más vendidos

### Alertas de Prometheus

**Reglas principales**:

```yaml
# Alertas críticas
- HighErrorRate: error_rate > 5% por 5 minutos
- HighLatency: p95_latency > 1000ms por 10 minutos
- CircuitBreakerOpen: circuitbreaker_state == OPEN por 2 minutos
- OutOfMemory: jvm_memory_used / jvm_memory_max > 90% por 5 minutos
- ServiceDown: up == 0 por 1 minuto
```

## 2. Logs - ELK Stack

### Elasticsearch

**Configuración**:
- **Puerto**: 9200
- **Cluster name**: elastic-cluster
- **Shards**: 3 (por índice)
- **Replicas**: 1
- **Retention**: 30 días

**Índices**:
```
ecommerce-logs-2025.01.01
ecommerce-logs-2025.01.02
...
```

### Logstash

**Configuración**:
- **Puerto**: 5000 (TCP), 5001 (UDP)
- **Pipelines**: 1 (centralizado)

**Transformaciones**:
- Parsing de logs JSON
- Enriquecimiento con trazas
- Normalización de timestamps
- Geolocalización de IPs

**Filtros**:
```
input {
  tcp {
    port => 5000
    codec => json
  }
}

filter {
  if [type] == "application" {
    # Parsing adicional
    mutate {
      add_field => { "[@metadata][index_name]" => "ecommerce-logs-%{+YYYY.MM.dd}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "%{[@metadata][index_name]}"
  }
}
```

### Kibana

**Configuración**:
- **Puerto**: 5601
- **URL**: `http://kibana.local:5601`

**Características**:
- Búsqueda full-text de logs
- Visualizaciones automáticas
- Análisis de series de tiempo
- Alertas basadas en logs

**Saved Searches importantes**:

1. **Errors últimas 24h**
   ```
   level: ERROR AND @timestamp: [now-24h TO now]
   ```

2. **Latencia alta**
   ```
   duration_ms: [1000 TO *] AND @timestamp: [now-1h TO now]
   ```

3. **Fallos de autenticación**
   ```
   event: "LOGIN_FAILED" AND @timestamp: [now-24h TO now]
   ```

4. **Circuit Breaker disparados**
   ```
   pattern: "CircuitBreakerOpened" AND @timestamp: [now-24h TO now]
   ```

## 3. Tracing Distribuido - Zipkin

### Configuración

**Puerto**: 9411
**URL**: `http://zipkin.local:9411`

**Sampler**: 
- Development: 100% (todos los traces)
- Staging: 50%
- Production: 10%

### Instrumentación

Cada servicio está configurado con:

```yaml
spring:
  sleuth:
    sampler:
      probability: 1.0  # En desarrollo
  zipkin:
    base-url: http://zipkin:9411/
    enabled: true
```

### Traces Capturados

Ejemplo de un trace de orden:

```
Trace ID: abc123def456

Span 1: api-gateway (GET /api/orders)
  Duration: 150ms
  
Span 2: order-service (POST /orders)
  Duration: 140ms
  
  Span 2.1: payment-service (POST /payments)
    Duration: 80ms
    
  Span 2.2: product-service (GET /products)
    Duration: 40ms
    
  Span 2.3: user-service (GET /users/{id})
    Duration: 20ms

Span 3: api-gateway (response)
  Duration: 10ms
```

### Análisis

**Endpoints en Zipkin**:
- Service dependencies: Visualizar relaciones entre servicios
- Latency analysis: Identificar servicios lentos
- Error analysis: Rastrear errores a través del sistema
- Trace search: Buscar traces específicos

## 4. Health Checks

### Liveness Probe

Verifica si el servicio está activo:

```yaml
livenessProbe:
  httpGet:
    path: /app/actuator/health/liveness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

### Readiness Probe

Verifica si el servicio está listo para recibir tráfico:

```yaml
readinessProbe:
  httpGet:
    path: /app/actuator/health/readiness
    port: 8080
  initialDelaySeconds: 20
  periodSeconds: 5
  timeoutSeconds: 5
  failureThreshold: 3
```

### Health Indicators

**Endpoints de salud**:

```
GET /app/actuator/health
GET /app/actuator/health/liveness
GET /app/actuator/health/readiness
GET /app/actuator/health/dependencies
GET /app/actuator/health/circuitbreakers
```

**Respuesta de ejemplo**:

```json
{
  "status": "UP",
  "components": {
    "circuitBreakers": {
      "status": "UP",
      "details": {
        "proxyService": {
          "status": "UP",
          "details": {
            "state": "CLOSED",
            "failureRate": "0%"
          }
        }
      }
    },
    "discoveryComposite": {
      "status": "UP",
      "components": {
        "discoveryClient": {
          "status": "UP",
          "details": {
            "services": ["user-service", "product-service", ...]
          }
        }
      }
    },
    "diskSpace": {
      "status": "UP",
      "details": {
        "total": 1000000000,
        "free": 500000000,
        "threshold": 10000000
      }
    }
  }
}
```

## 5. Métricas de Negocio

Además de métricas técnicas, se implementan métricas de negocio:

```java
// Registro de métrica de negocio
meterRegistry.counter("orders.created", 
  "status", "completed",
  "user_type", "premium").increment();

// Registro de latencia
meterRegistry.timer("checkout.duration")
  .record(checkoutTime, TimeUnit.MILLISECONDS);
```

**Métricas capturadas**:
- Órdenes completadas por hora
- Ingresos por transacción
- Tasa de abandono de carrito
- Productos más populares
- Tiempo promedio de entrega

## 6. Alertas

### Canales de Notificación

- **Slack**: #devops-alerts
- **Email**: ops-team@company.com
- **PagerDuty**: Para oncall engineers

### Ejemplos de Alertas

**Severidad: CRÍTICA**
- Servicio no disponible
- Tasa de error > 10%
- P95 latency > 2 segundos
- Circuit breaker abierto > 5 minutos

**Severidad: ALTA**
- Tasa de error > 5%
- P95 latency > 1 segundo
- CPU > 80%
- Memoria > 85%

**Severidad: MEDIA**
- Tasa de error > 1%
- P95 latency > 500ms
- CPU > 60%

**Severidad: BAJA**
- Tasa de error > 0.1%
- P95 latency > 200ms

## 7. Dashboards Principales

### Sistema

- Estado de cluster Kubernetes
- Node CPU/Memoria/Disk
- Network I/O
- Pod restarts

### Aplicación

- Requests per second
- Latency distribution
- Error rate by endpoint
- Active connections

### Negocio

- Revenue
- Orders
- Conversion rate
- Top products

## Referencias y Acceso

| Componente | URL | Usuario | Password |
|------------|-----|---------|----------|
| Prometheus | http://prometheus:9090 | - | - |
| Grafana | http://grafana:3000 | admin | admin |
| Elasticsearch | http://elasticsearch:9200 | - | - |
| Kibana | http://kibana:5601 | - | - |
| Zipkin | http://zipkin:9411 | - | - |

**Nota**: En producción cambiar contraseñas y usar autenticación OAuth2/OIDC.
