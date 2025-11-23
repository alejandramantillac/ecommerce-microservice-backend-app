# Patrones de Diseño en la Arquitectura de Microservicios

Este documento describe los patrones de diseño identificados e implementados en la arquitectura de microservicios del sistema de e-commerce.

---

## 1. API Gateway Pattern

### Descripción
El patrón API Gateway proporciona un único punto de entrada para todos los clientes que interactúan con los microservicios. En lugar de que los clientes se comuniquen directamente con múltiples servicios, todos los requests pasan a través del API Gateway, que se encarga del enrutamiento, balanceo de carga y otras funcionalidades transversales.

### Implementación
**Ubicación**: `api-gateway/`

**Tecnología**: Spring Cloud Gateway

**Clase Principal**: `api-gateway/src/main/java/com/selimhorri/app/ApiGatewayApplication.java`
```java
@SpringBootApplication
@EnableEurekaClient
public class ApiGatewayApplication {
    // ...
}
```

**Configuración**: `api-gateway/src/main/resources/application.yml`

El API Gateway está configurado con:
- **Enrutamiento dinámico**: Cada servicio tiene una ruta definida usando el protocolo `lb://` (load balancing)
- **Service Discovery**: Integrado con Eureka para descubrir servicios automáticamente
- **CORS global**: Configuración CORS aplicada a todas las rutas
- **Múltiples rutas**: 7 rutas configuradas para diferentes servicios

**Ejemplo de configuración de ruta**:
```yaml
routes:
  - id: USER-SERVICE
    uri: lb://USER-SERVICE
    predicates:
    - Path=/user-service/**
```

### Propósito
- **Simplificar la interacción del cliente**: El cliente solo necesita conocer una URL base
- **Centralizar funcionalidades transversales**: Autenticación, logging, rate limiting
- **Abstraer la complejidad interna**: Los clientes no necesitan conocer la estructura interna de microservicios
- **Facilitar el balanceo de carga**: Distribuye requests entre múltiples instancias de un servicio

### Beneficios
✅ **Seguridad mejorada**: Punto único para aplicar políticas de seguridad  
✅ **Desacoplamiento**: Los servicios pueden cambiar sin afectar a los clientes  
✅ **Observabilidad**: Punto centralizado para monitoreo y logging  
✅ **Escalabilidad**: Facilita el escalamiento horizontal de servicios  

### Flujo de Request
```
Cliente → API Gateway → Eureka (descubrimiento) → Microservicio
```

---

## 2. Service Registry and Discovery Pattern

### Descripción
El patrón Service Registry and Discovery permite que los microservicios se registren automáticamente cuando inician y se descubran entre sí sin necesidad de configuración manual de URLs. Esto es esencial en arquitecturas de microservicios donde los servicios pueden escalarse horizontalmente y cambiar de ubicación.

### Implementación
**Ubicación**: `service-discovery/`

**Tecnología**: Netflix Eureka Server

**Clase Principal**: `service-discovery/src/main/java/com/selimhorri/app/ServiceDiscoveryApplication.java`
```java
@SpringBootApplication
@EnableEurekaServer
public class ServiceDiscoveryApplication {
    // ...
}
```

**Servicios Cliente**: Todos los microservicios están configurados como clientes de Eureka usando `@EnableEurekaClient`:
- `api-gateway` - `ApiGatewayApplication.java`
- `proxy-client` - `ProxyClientApplication.java`
- `user-service` - `UserServiceApplication.java`
- `product-service` - `ProductServiceApplication.java`
- `order-service` - `OrderServiceApplication.java`
- `payment-service` - `PaymentServiceApplication.java`
- `shipping-service` - `ShippingServiceApplication.java`
- `favourite-service` - `FavouriteServiceApplication.java`
- `cloud-config` - `CloudConfigApplication.java`

**Configuración en cada servicio** (`application.yml`):
```yaml
eureka:
  client:
    service-url:
      defaultZone: ${EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE:http://localhost:8761/eureka/}
    register-with-eureka: true
    fetch-registry: true
    healthcheck:
      enabled: true
```

### Propósito
- **Registro dinámico**: Los servicios se registran automáticamente al iniciar
- **Descubrimiento automático**: Los servicios encuentran otros servicios sin configuración hardcodeada
- **Escalabilidad horizontal**: Nuevas instancias se registran automáticamente
- **Health checks**: Eureka monitorea el estado de salud de los servicios

### Beneficios
✅ **Flexibilidad**: Los servicios pueden moverse o escalarse sin reconfiguración  
✅ **Resiliencia**: Si un servicio falla, Eureka lo marca como no disponible  
✅ **Load balancing**: Facilita la distribución de carga entre instancias  
✅ **Reducción de acoplamiento**: Los servicios no necesitan conocer URLs específicas  

### Flujo de Registro
```
1. Servicio inicia → 2. Se registra en Eureka → 3. Otros servicios lo descubren
```

---

## 3. External Configuration Pattern

### Descripción
El patrón External Configuration separa la configuración de la aplicación del código, permitiendo cambiar el comportamiento de la aplicación sin recompilar o redesplegar. Esto es especialmente importante en microservicios donde diferentes ambientes (dev, staging, prod) requieren configuraciones diferentes.

### Implementación
**Ubicación**: `cloud-config/`

**Tecnología**: Spring Cloud Config Server

**Clase Principal**: `cloud-config/src/main/java/com/selimhorri/app/CloudConfigApplication.java`
```java
@SpringBootApplication
@EnableEurekaClient
@EnableConfigServer
public class CloudConfigApplication {
    // ...
}
```

**Configuración del servidor**: `cloud-config/src/main/resources/application.yml`
```yaml
spring:
  cloud:
    config:
      server:
        git:
          uri: https://github.com/SelimHorri/cloud-config-server
          clone-on-start: true
```

**Uso en servicios**: Cada servicio está configurado para usar el Config Server de forma opcional:
```yaml
spring:
  config:
    import: ${SPRING_CONFIG_IMPORT:optional:configserver:http://localhost:9296}
```

La palabra clave `optional:` significa que si el Config Server no está disponible, el servicio puede iniciar usando su configuración local.

### Propósito
- **Centralización**: Toda la configuración en un solo lugar (repositorio Git)
- **Versionado**: La configuración está versionada junto con el código
- **Ambientes múltiples**: Diferentes configuraciones para dev, staging, prod
- **Actualización sin redeploy**: Cambios de configuración sin recompilar

### Beneficios
✅ **Mantenibilidad**: Un solo lugar para gestionar configuraciones  
✅ **Consistencia**: Misma configuración para todas las instancias de un servicio  
✅ **Seguridad**: Configuraciones sensibles separadas del código  
✅ **Flexibilidad**: Fácil cambio entre ambientes  

### Configuración Adicional: Kubernetes ConfigMaps
Además del Config Server, el sistema usa **Kubernetes ConfigMaps** para configuración específica de ambiente:
- `k8s/02-configmap-staging.yaml` - Configuración para staging
- `k8s/02-configmap-prod.yaml` - Configuración para producción

Estos ConfigMaps contienen variables de entorno específicas como:
- URLs de servicios
- Configuraciones JVM
- Niveles de logging
- Parámetros de Resilience4j

---

## 4. Database per Service Pattern

### Descripción
El patrón Database per Service establece que cada microservicio debe tener su propia base de datos, la cual no puede ser accedida directamente por otros servicios. Este patrón es fundamental para lograr verdadero desacoplamiento entre servicios.

### Implementación
Cada microservicio tiene su propia configuración de base de datos H2 en memoria.

**Ubicación**: `{service}/src/main/resources/application-dev.yml`

**Ejemplo - User Service**:
```yaml
spring:
  datasource:
    url: jdbc:h2:mem:ecommerce_dev_db;DB_CLOSE_ON_EXIT=FALSE
    username: sa
    password: 
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.H2Dialect
  h2:
    console:
      enabled: true
      path: /h2-console
```

**Servicios con base de datos propia**:
- `user-service` - Base de datos para usuarios, credenciales, direcciones
- `product-service` - Base de datos para productos y categorías
- `order-service` - Base de datos para órdenes y carritos
- `payment-service` - Base de datos para pagos
- `shipping-service` - Base de datos para envíos
- `favourite-service` - Base de datos para favoritos

### Propósito
- **Independencia**: Cada servicio puede elegir su tecnología de base de datos
- **Escalabilidad**: Cada servicio puede escalar su base de datos independientemente
- **Aislamiento de fallos**: Un problema en una base de datos no afecta a otros servicios
- **Evolución independiente**: Los esquemas de base de datos pueden evolucionar sin afectar otros servicios

### Beneficios
✅ **Bajo acoplamiento**: Los servicios no comparten esquemas de base de datos  
✅ **Escalabilidad independiente**: Cada servicio escala según sus necesidades  
✅ **Tecnología flexible**: Cada servicio puede usar la BD más adecuada  
✅ **Resiliencia**: Fallos aislados no afectan todo el sistema  

### Comunicación entre Servicios
Como los servicios no comparten base de datos, la comunicación se realiza a través de:
- **APIs REST**: Comunicación síncrona entre servicios
- **Feign Clients**: Clientes declarativos para llamadas HTTP (ver patrón Feign Client)

---

## 5. Distributed Tracing Pattern

### Descripción
El patrón Distributed Tracing permite rastrear un request a través de múltiples microservicios, proporcionando visibilidad completa del flujo de ejecución en un sistema distribuido. Esto es esencial para debugging y análisis de performance.

### Implementación
**Tecnología**: Zipkin + Spring Cloud Sleuth

**Configuración en cada servicio** (`application.yml`):
```yaml
spring:
  zipkin:
    base-url: ${SPRING_ZIPKIN_BASE_URL:http://localhost:9411/}
```

**Servicios configurados con tracing**:
- Todos los microservicios tienen configuración de Zipkin
- Spring Cloud Sleuth se encarga automáticamente de generar y propagar trace IDs

**Configuración por ambiente** (Kubernetes ConfigMaps):
```yaml
SPRING_ZIPKIN_BASE_URL: "http://zipkin.staging.svc.cluster.local:9411/"
SPRING_SLEUTH_SAMPLER_PROBABILITY: "0.5"  # 50% sampling para staging
```

### Propósito
- **Visibilidad**: Ver el flujo completo de un request a través de múltiples servicios
- **Debugging**: Identificar dónde ocurren errores o cuellos de botella
- **Análisis de performance**: Medir tiempos de respuesta en cada servicio
- **Correlación**: Asociar logs de diferentes servicios usando trace IDs

### Beneficios
✅ **Debugging simplificado**: Encontrar problemas en sistemas distribuidos  
✅ **Análisis de performance**: Identificar servicios lentos  
✅ **Observabilidad**: Visibilidad completa del sistema  
✅ **Correlación de logs**: Logs de diferentes servicios relacionados por trace ID  

### Flujo de Tracing
```
Request → API Gateway (trace-id: abc123) 
       → User Service (trace-id: abc123)
       → Product Service (trace-id: abc123)
       → Zipkin (muestra todo el flujo)
```

---

## 6. Feign Client Pattern

### Descripción
El patrón Feign Client proporciona una forma declarativa y simplificada de realizar llamadas HTTP entre microservicios. En lugar de usar RestTemplate o WebClient manualmente, Feign permite definir interfaces que se convierten automáticamente en clientes HTTP.

### Implementación
**Ubicación**: `proxy-client/src/main/java/com/selimhorri/app/business/*/service/`

**Habilitación**: `proxy-client/src/main/java/com/selimhorri/app/ProxyClientApplication.java`
```java
@SpringBootApplication
@EnableEurekaClient
@EnableFeignClients
public class ProxyClientApplication {
    // ...
}
```

**Feign Clients implementados** (11 interfaces):
1. `OrderClientService` - Comunicación con ORDER-SERVICE
2. `CartClientService` - Comunicación con ORDER-SERVICE (carritos)
3. `PaymentClientService` - Comunicación con PAYMENT-SERVICE
4. `ProductClientService` - Comunicación con PRODUCT-SERVICE
5. `CategoryClientService` - Comunicación con PRODUCT-SERVICE
6. `UserClientService` - Comunicación con USER-SERVICE
7. `CredentialClientService` - Comunicación con USER-SERVICE
8. `AddressClientService` - Comunicación con USER-SERVICE
9. `VerificationTokenClientService` - Comunicación con USER-SERVICE
10. `FavouriteClientService` - Comunicación con FAVOURITE-SERVICE
11. `OrderItemClientService` - Comunicación con SHIPPING-SERVICE

**Ejemplo de implementación**:
```java
@FeignClient(name = "PRODUCT-SERVICE", 
             contextId = "productClientService", 
             path = "/product-service/api/products")
public interface ProductClientService {
    
    @GetMapping
    ResponseEntity<ProductProductServiceCollectionDtoResponse> findAll();
    
    @GetMapping("/{productId}")
    ResponseEntity<ProductDto> findById(@PathVariable("productId") String productId);
    
    @PostMapping
    ResponseEntity<ProductDto> save(@RequestBody ProductDto productDto);
    
    // ... más métodos
}
```

**Integración con Service Discovery**: Los Feign Clients usan el nombre del servicio (`PRODUCT-SERVICE`) que Eureka resuelve automáticamente a la URL correcta.

### Propósito
- **Simplificación**: Reducir código boilerplate para llamadas HTTP
- **Declarativo**: Definir contratos de API como interfaces Java
- **Integración con Eureka**: Descubrimiento automático de servicios
- **Type-safe**: Compilación segura de tipos en lugar de strings

### Beneficios
✅ **Código más limpio**: Menos código que RestTemplate  
✅ **Type safety**: Errores detectados en tiempo de compilación  
✅ **Mantenibilidad**: Interfaces claras y fáciles de entender  
✅ **Integración**: Funciona automáticamente con Eureka  

### Flujo de Comunicación
```
Proxy Client → Feign Client Interface → Eureka (resuelve URL) → Microservicio
```

---

## 7. Layered Architecture Pattern

### Descripción
El patrón Layered Architecture (Arquitectura en Capas) organiza el código en capas bien definidas, cada una con responsabilidades específicas. Esto mejora la mantenibilidad, testabilidad y separación de concerns.

### Implementación
**Estructura típica en cada microservicio** (ejemplo: `user-service/`):

```
src/main/java/com/selimhorri/app/
├── resource/          # Capa de Presentación (Controllers)
│   ├── UserResource.java
│   ├── CredentialResource.java
│   └── AddressResource.java
├── service/           # Capa de Lógica de Negocio
│   ├── UserService.java (interfaz)
│   └── impl/
│       └── UserServiceImpl.java
├── repository/        # Capa de Acceso a Datos
│   ├── UserRepository.java
│   └── CredentialRepository.java
├── domain/            # Entidades de Dominio
│   ├── User.java
│   └── Credential.java
├── dto/               # Data Transfer Objects
│   └── UserDto.java
└── exception/         # Manejo de Excepciones
    └── ApiExceptionHandler.java
```

**Ejemplo de flujo**:
```java
// Capa Resource (Controller)
@RestController
@RequestMapping("/api/users")
public class UserResource {
    private final UserService userService;  // Inyección de dependencia
    
    @GetMapping("/{userId}")
    public ResponseEntity<UserDto> findById(@PathVariable String userId) {
        return ResponseEntity.ok(this.userService.findById(userId));
    }
}

// Capa Service
@Service
public class UserServiceImpl implements UserService {
    private final UserRepository userRepository;
    
    @Override
    public UserDto findById(String userId) {
        // Lógica de negocio
        return userRepository.findById(userId)
            .map(this::mapToDto)
            .orElseThrow(() -> new UserObjectNotFoundException("..."));
    }
}

// Capa Repository
public interface UserRepository extends JpaRepository<User, Integer> {
    // Métodos de acceso a datos
}
```

### Propósito
- **Separación de concerns**: Cada capa tiene una responsabilidad clara
- **Mantenibilidad**: Cambios en una capa no afectan otras
- **Testabilidad**: Cada capa puede testearse independientemente
- **Reutilización**: La lógica de negocio puede reutilizarse en diferentes contextos

### Beneficios
✅ **Organización clara**: Código estructurado y fácil de navegar  
✅ **Testabilidad**: Mocking fácil entre capas  
✅ **Mantenibilidad**: Cambios localizados en capas específicas  
✅ **Escalabilidad**: Fácil agregar nuevas funcionalidades  

---

## 8. Circuit Breaker Pattern

### Descripción
El patrón Circuit Breaker previene fallos en cascada cuando un servicio dependiente no está disponible. Actúa como un interruptor eléctrico: cuando detecta demasiados fallos, "abre el circuito" y detiene las llamadas al servicio problemático, permitiendo que el sistema se recupere.

### Implementación
**Tecnología**: Resilience4j integrado con Spring Cloud OpenFeign

**Ubicación principal**: `proxy-client/` - Servicio que realiza llamadas inter-servicios

**Configuración**: `proxy-client/src/main/resources/application.yml`
```yaml
resilience4j:
  circuitbreaker:
    instances:
      proxyService:
        register-health-indicator: true
        failure-rate-threshold: 50
        minimum-number-of-calls: 5
        wait-duration-in-open-state: 5s
        sliding-window-size: 10
        sliding-window-type: COUNT_BASED

feign:
  circuitbreaker:
    enabled: true
```

**Feign Clients con Circuit Breaker**:
Todos los Feign Clients principales tienen fallbacks implementados:
- `UserClientService` - Fallback: `UserClientServiceFallback`
- `ProductClientService` - Fallback: `ProductClientServiceFallback`
- `PaymentClientService` - Fallback: `PaymentClientServiceFallback`
- `OrderClientService` - Fallback: `OrderClientServiceFallback`
- `FavouriteClientService` - Fallback: `FavouriteClientServiceFallback`

**Ejemplo de implementación**:
```java
@FeignClient(
    name = "USER-SERVICE", 
    path = "/user-service/api/users",
    fallback = UserClientServiceFallback.class  // ← Circuit Breaker fallback
)
public interface UserClientService {
    @GetMapping
    ResponseEntity<UserUserServiceCollectionDtoResponse> findAll();
    // ... más métodos
}
```

**Clases Fallback**:
Cada fallback implementa la misma interfaz del Feign Client y proporciona respuestas por defecto cuando el servicio está no disponible:

```java
@Component
@Slf4j
public class UserClientServiceFallback implements UserClientService {
    @Override
    public ResponseEntity<UserUserServiceCollectionDtoResponse> findAll() {
        log.warn("Circuit breaker opened or USER-SERVICE unavailable.");
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(new UserUserServiceCollectionDtoResponse());
    }
    // ... implementación de todos los métodos
}
```

### Propósito
- **Prevenir fallos en cascada**: Detener llamadas a servicios que están fallando
- **Degradación elegante**: Proporcionar respuestas alternativas cuando un servicio no está disponible
- **Recuperación automática**: Intentar reconectar después de un período de tiempo (5 segundos configurado)
- **Monitoreo**: Health indicators para detectar problemas

### Beneficios
✅ **Resiliencia**: El sistema continúa funcionando aunque algunos servicios fallen  
✅ **Performance**: Evita esperas innecesarias en servicios que no responden  
✅ **Observabilidad**: Métricas claras del estado de los circuitos  
✅ **Recuperación**: Reintentos automáticos cuando el servicio se recupera  
✅ **Degradación elegante**: Respuestas HTTP 503 en lugar de timeouts o errores 500  

### Flujo de Circuit Breaker
```
1. Request → Feign Client
2. Si servicio responde → Retorna respuesta normal
3. Si servicio falla → Circuit Breaker cuenta fallos
4. Si fallos > threshold (50%) → Circuito ABIERTO
5. Circuito abierto → Fallback se ejecuta automáticamente
6. Después de wait-duration (5s) → Circuito HALF-OPEN
7. Si prueba exitosa → Circuito CERRADO (normal)
8. Si prueba falla → Circuito ABIERTO nuevamente
```

### Configuración de Parámetros
- **failure-rate-threshold: 50%**: Se abre el circuito si más del 50% de las llamadas fallan
- **minimum-number-of-calls: 5**: Mínimo de llamadas antes de evaluar el estado
- **wait-duration-in-open-state: 5s**: Tiempo antes de intentar reconectar
- **sliding-window-size: 10**: Ventana de las últimas 10 llamadas para evaluar
- **sliding-window-type: COUNT_BASED**: Basado en número de llamadas (no tiempo)

### Ubicación de Archivos
- **Fallbacks**: `proxy-client/src/main/java/com/selimhorri/app/business/*/service/fallback/`
- **Feign Clients**: `proxy-client/src/main/java/com/selimhorri/app/business/*/service/*ClientService.java`
- **Configuración**: `proxy-client/src/main/resources/application.yml`

---

## 9. Feature Toggle Pattern

### Descripción
El patrón Feature Toggle (también conocido como Feature Flag) permite habilitar o deshabilitar funcionalidades de forma dinámica sin necesidad de redeployar la aplicación. Esto es especialmente útil para testing A/B, rollouts graduales, y kill switches para features problemáticas.

### Implementación
**Tecnología**: Spring AOP + Spring Cloud Config

**Dependencias requeridas**:
- `spring-boot-starter-aop` (en `proxy-client/pom.xml`)
- `spring-cloud-starter-config` (para integración con Config Server)
- Spring Boot Actuator (heredado del pom.xml padre)

**Ubicación principal**: `proxy-client/` - Servicio que expone endpoints al cliente

**Nota importante**: La aplicación usa `context-path: /app` (configurado en `application.yml`), por lo que todos los endpoints tienen el prefijo `/app`. Por ejemplo: `/app/api/payments` en lugar de `/api/payments`.

**Componentes implementados**:
1. **Anotación `@FeatureToggle`**: Marca métodos/endpoints controlados por feature toggle
2. **FeatureToggleService**: Gestiona el estado de los features usando reflexión para mapear propiedades dinámicamente
3. **FeatureToggleAspect**: Intercepta métodos anotados usando AOP (@Around)
4. **FeatureToggleController**: Endpoint de administración para gestionar features dinámicamente
5. **FeatureToggleProperties**: Clase de configuración que mapea propiedades YAML a campos Java
6. **FeatureDisabledException**: Excepción personalizada lanzada cuando un feature está deshabilitado

**Configuración**: `proxy-client/src/main/resources/application.yml`
```yaml
feature:
  toggle:
    new-payment-method: ${FEATURE_TOGGLE_NEW_PAYMENT_METHOD:true}
    advanced-search: ${FEATURE_TOGGLE_ADVANCED_SEARCH:false}
    recommendation-engine: ${FEATURE_TOGGLE_RECOMMENDATION_ENGINE:false}
    bulk-operations: ${FEATURE_TOGGLE_BULK_OPERATIONS:true}
```

**Ejemplo de uso en PaymentController**:
```java
@PostMapping
@FeatureToggle(
    name = "new-payment-method", 
    defaultValue = true,
    message = "New payment method feature is currently disabled"
)
public ResponseEntity<PaymentDto> save(@RequestBody final PaymentDto paymentDto) {
    return ResponseEntity.ok(this.paymentClientService.save(paymentDto).getBody());
}
```

**Ejemplo de uso en ProductController**:
```java
@GetMapping
@FeatureToggle(
    name = "advanced-search", 
    defaultValue = false,
    message = "Advanced search feature is currently disabled"
)
public ResponseEntity<ProductProductServiceCollectionDtoResponse> findAll() {
    return ResponseEntity.ok(this.productClientService.findAll().getBody());
}
```

**Endpoints con Feature Toggle aplicado** (con context-path `/app`):
- `POST /app/api/payments` - Controlado por `new-payment-method` (método `save()`)
- `GET /app/api/products` - Controlado por `advanced-search` (método `findAll()`)
- `GET /app/api/favourites` - Controlado por `recommendation-engine` (método `findAll()`)

**Endpoints de administración**: `/app/api/admin/features`
- `GET /app/api/admin/features` - Listar todos los features
- `GET /app/api/admin/features/{featureName}` - Estado de un feature específico
- `POST /app/api/admin/features/{featureName}/enable` - Habilitar feature
- `POST /app/api/admin/features/{featureName}/disable` - Deshabilitar feature
- `POST /app/api/admin/features/cache/clear` - Limpiar caché

**Nota de seguridad**: Los endpoints de administración requieren rol `ADMIN` (configurado en `SecurityConfig`)

### Propósito
- **Control dinámico**: Habilitar/deshabilitar features sin redeploy
- **Testing A/B**: Probar nuevas funcionalidades con un subconjunto de usuarios
- **Rollout gradual**: Activar features progresivamente
- **Kill switch**: Desactivar rápidamente features problemáticas
- **Configuración por ambiente**: Diferentes features activos en dev/staging/prod

### Beneficios
✅ **Despliegue continuo sin riesgo**: Features pueden desplegarse deshabilitados  
✅ **Control granular**: Activar/desactivar features individuales  
✅ **Testing en producción**: Probar features con usuarios reales de forma controlada  
✅ **Rollback rápido**: Desactivar features problemáticas sin redeploy  
✅ **Configuración dinámica**: Cambios sin reiniciar la aplicación (con @RefreshScope)  

### Flujo de Feature Toggle
```
1. Request → Controller Method
2. Aspect intercepta método anotado con @FeatureToggle
3. FeatureToggleService verifica estado del feature
   ├─ Si habilitado → Ejecuta método normalmente
   └─ Si deshabilitado → Lanza FeatureDisabledException
4. ApiExceptionHandler captura excepción
5. Retorna HTTP 503 (Service Unavailable) con mensaje
```

### Configuración Dinámica
El servicio usa `@RefreshScope` en `FeatureToggleService` y `FeatureToggleProperties` para permitir actualizaciones dinámicas sin reiniciar la aplicación.

**Métodos de actualización**:
1. **Via endpoints de administración** (implementado y funcional):
   ```bash
   POST /app/api/admin/features/new-payment-method/disable
   POST /app/api/admin/features/new-payment-method/enable
   POST /app/api/admin/features/cache/clear
   ```
   Estos endpoints actualizan el cache en memoria inmediatamente.

2. **Via Spring Cloud Config** (preparado pero requiere configuración adicional):
   - El servicio tiene un listener `handleEnvironmentChange()` que escucha `EnvironmentChangeEvent`
   - Cuando detecta cambios en propiedades `feature.toggle.*`, limpia el cache automáticamente
   - Requiere que Spring Cloud Config esté configurado y que se dispare el evento de cambio
   - Los cambios se aplican sin reiniciar gracias a `@RefreshScope`

**Implementación del listener**:
```java
@EventListener
public void handleEnvironmentChange(EnvironmentChangeEvent event) {
    boolean featureToggleChanged = event.getKeys().stream()
        .anyMatch(key -> key.startsWith("feature.toggle."));
    if (featureToggleChanged) {
        clearCache();
    }
}
```

### Ubicación de Archivos
- **Anotación**: `proxy-client/src/main/java/com/selimhorri/app/feature/FeatureToggle.java`
- **Servicio**: `proxy-client/src/main/java/com/selimhorri/app/feature/service/FeatureToggleService.java`
- **Aspect**: `proxy-client/src/main/java/com/selimhorri/app/feature/aspect/FeatureToggleAspect.java`
- **Controller**: `proxy-client/src/main/java/com/selimhorri/app/feature/controller/FeatureToggleController.java`
- **Properties**: `proxy-client/src/main/java/com/selimhorri/app/feature/config/FeatureToggleProperties.java`
- **Excepción**: `proxy-client/src/main/java/com/selimhorri/app/feature/exception/FeatureDisabledException.java`
- **Configuración**: `proxy-client/src/main/resources/application.yml`
- **Dependencia AOP**: `proxy-client/pom.xml` (spring-boot-starter-aop)
- **Aplicación principal**: `proxy-client/src/main/java/com/selimhorri/app/ProxyClientApplication.java`
  - Anotaciones: `@EnableAspectJAutoProxy`, `@EnableConfigurationProperties(FeatureToggleProperties.class)`, `@RefreshScope`
- **Manejo de excepciones**: `proxy-client/src/main/java/com/selimhorri/app/exception/ApiExceptionHandler.java`
  - Método: `handleFeatureDisabledException()` - Retorna HTTP 503 (Service Unavailable)
- **Seguridad**: `proxy-client/src/main/java/com/selimhorri/app/security/SecurityConfig.java`
  - Endpoints `/app/api/admin/features/**` requieren rol `ADMIN`
- **Controllers que usan Feature Toggle**:
  - `proxy-client/src/main/java/com/selimhorri/app/business/payment/controller/PaymentController.java`
  - `proxy-client/src/main/java/com/selimhorri/app/business/product/controller/ProductController.java`
  - `proxy-client/src/main/java/com/selimhorri/app/business/favourite/controller/FavouriteController.java`
- **Tests unitarios**:
  - `proxy-client/src/test/java/com/selimhorri/app/feature/service/FeatureToggleServiceTest.java` (9 tests)
  - `proxy-client/src/test/java/com/selimhorri/app/feature/aspect/FeatureToggleAspectTest.java` (5 tests)
  - Total: 14 tests, todos pasando

---

## Resumen de Patrones Implementados

| # | Patrón | Estado | Ubicación Principal | Tecnología |
|---|--------|--------|---------------------|------------|
| 1 | API Gateway | ✅ Completo | `api-gateway/` | Spring Cloud Gateway |
| 2 | Service Registry & Discovery | ✅ Completo | `service-discovery/` | Netflix Eureka |
| 3 | External Configuration | ✅ Completo | `cloud-config/` | Spring Cloud Config |
| 4 | Database per Service | ✅ Completo | Todos los servicios | H2 + JPA |
| 5 | Distributed Tracing | ✅ Completo | Todos los servicios | Zipkin + Sleuth |
| 6 | Feign Client | ✅ Completo | `proxy-client/` | Spring Cloud OpenFeign |
| 7 | Layered Architecture | ✅ Completo | Todos los servicios | Spring Boot |
| 8 | Circuit Breaker | ✅ Completo | `proxy-client/` | Resilience4j + Feign |
| 9 | Feature Toggle | ✅ Completo | `proxy-client/` | Spring AOP + Config |

---

## Diagrama de Arquitectura

```
                    ┌─────────────┐
                    │   Cliente     │
                    └───────┬───────┘
                            │
                    ┌───────▼───────┐
                    │ API Gateway   │ ← API Gateway Pattern
                    │ (Spring Cloud)│
                    └───────┬───────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼───────┐  ┌────────▼────────┐  ┌───────▼───────┐
│ Service       │  │  Proxy Client   │  │  Cloud Config │
│ Discovery     │  │  (Feign Clients)│  │  (External    │
│ (Eureka)      │  │                 │  │   Config)     │
└───────┬───────┘  └────────┬────────┘  └───────────────┘
        │                   │
        │    ┌───────────────┼───────────────┐
        │    │               │               │
┌───────▼────▼───┐  ┌────────▼────────┐  ┌──▼────────────┐
│ User Service   │  │ Product Service │  │ Order Service │
│ (H2 Database)  │  │ (H2 Database)   │  │ (H2 Database) │
└────────────────┘  └────────────────┘  └───────────────┘
        │                   │               │
        └───────────────────┼───────────────┘
                            │
                    ┌───────▼───────┐
                    │    Zipkin     │ ← Distributed Tracing
                    │   (Tracing)   │
                    └───────────────┘
```

---

## Referencias en el Código

### Archivos Clave por Patrón

**API Gateway**:
- `api-gateway/src/main/java/com/selimhorri/app/ApiGatewayApplication.java`
- `api-gateway/src/main/resources/application.yml` (líneas 16-63)

**Service Discovery**:
- `service-discovery/src/main/java/com/selimhorri/app/ServiceDiscoveryApplication.java`
- `service-discovery/src/main/resources/application.yml` (líneas 11-18)

**External Configuration**:
- `cloud-config/src/main/java/com/selimhorri/app/CloudConfigApplication.java`
- `cloud-config/src/main/resources/application.yml` (líneas 10-15)

**Feign Clients**:
- `proxy-client/src/main/java/com/selimhorri/app/ProxyClientApplication.java`
- `proxy-client/src/main/java/com/selimhorri/app/business/*/service/*ClientService.java`

**Database per Service**:
- `{service}/src/main/resources/application-dev.yml` (líneas 12-15)

**Distributed Tracing**:
- Todos los `application.yml` contienen configuración de Zipkin

**Circuit Breaker**:
- Todos los `application.yml` contienen configuración de Resilience4j (líneas 26-38 aproximadamente)

---

## Conclusión

La arquitectura implementa **7 patrones completamente funcionales** y **1 patrón configurado pero pendiente de implementación en código**. Estos patrones trabajan juntos para crear un sistema de microservicios resiliente, escalable y mantenible.

Los patrones están bien integrados y proporcionan una base sólida para el sistema. El Circuit Breaker, aunque configurado, requiere implementación adicional en el código para estar completamente funcional.


