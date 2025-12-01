# Seguridad

## Descripción General

Este documento detalla la estrategia de seguridad implementada en la arquitectura de microservicios, incluyendo gestión de secretos, escaneo de vulnerabilidades, RBAC, TLS y prácticas de seguridad.

## 1. Gestión de Secretos

### Azure Key Vault

Todos los secretos se almacenan en Azure Key Vault y nunca en el código:

**Secretos almacenados**:
- Credenciales de bases de datos
- Claves API
- Certificados TLS
- Tokens de autenticación
- Credenciales de Container Registry

**Configuración en Spring**:

```properties
azure.keyvault.enabled=true
azure.keyvault.vault-uri=https://<vault-name>.vault.azure.net/
azure.keyvault.tenant-id=${AZURE_TENANT_ID}
azure.keyvault.client-id=${AZURE_CLIENT_ID}
azure.keyvault.client-secret=${AZURE_CLIENT_SECRET}
```

**Acceso a secretos en aplicación**:

```java
@Component
public class SecretProvider {
  private final KeyVaultClient keyVaultClient;
  
  public String getDatabasePassword() {
    return keyVaultClient.getSecret(
      "https://keyvault.vault.azure.net/", 
      "db-password"
    ).getValue();
  }
}
```

### Kubernetes Secrets

Para desarrollo, se usan Kubernetes Secrets (en producción, usar Azure Key Vault):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  DB_PASSWORD: cGFzc3dvcmQxMjM=  # base64 encoded
  API_KEY: YWJjZGVmZ2hpams=
```

**Referencia en Pod**:

```yaml
spec:
  containers:
  - name: product-service
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: DB_PASSWORD
```

## 2. Autenticación y Autorización

### OAuth2 + JWT

El proxy-client implementa OAuth2 con JWT para autenticación:

**Token JWT contiene**:
- `sub`: ID del usuario
- `email`: Email del usuario
- `roles`: Array de roles (ADMIN, USER, CUSTOMER)
- `iat`: Issued at timestamp
- `exp`: Expiration timestamp

**Validación en API Gateway**:

```java
@Component
public class JwtTokenValidator {
  
  public Claims validateToken(String token) {
    return Jwts.parserBuilder()
      .setSigningKey(getSigningKey())
      .build()
      .parseClaimsJws(token)
      .getBody();
  }
}
```

### Flujo de Autenticación

```
1. Usuario → POST /auth/login (username, password)
2. Proxy Client valida credenciales
3. Genera JWT con roles
4. Retorna token
5. Cliente almacena token localmente
6. Siguientes requests incluyen: Authorization: Bearer {token}
7. API Gateway valida JWT en cada request
```

## 3. Control de Acceso - RBAC

### Roles Implementados

| Rol | Permisos | Servicios |
|-----|----------|-----------|
| ADMIN | Todas las operaciones | Todos |
| PRODUCT_ADMIN | Crear/editar/eliminar productos | Product Service |
| USER_ADMIN | Gestionar usuarios | User Service |
| ORDER_ADMIN | Gestionar órdenes | Order Service |
| CUSTOMER | Crear órdenes, ver favoritos | Order, Product, Favourite |
| USER | Ver perfil, cambiar contraseña | User Service |

### Configuración en Spring Security

```java
@Configuration
@EnableGlobalMethodSecurity(prePostEnabled = true)
public class SecurityConfig extends WebSecurityConfigurerAdapter {
  
  @Override
  protected void configure(HttpSecurity http) throws Exception {
    http
      .authorizeRequests()
      .antMatchers("/api/admin/**").hasRole("ADMIN")
      .antMatchers("/api/products/**").hasAnyRole("USER", "CUSTOMER")
      .antMatchers("/api/orders").hasRole("CUSTOMER")
      .anyRequest().authenticated()
      .and()
      .oauth2ResourceServer()
      .jwt();
  }
}
```

**Anotaciones en métodos**:

```java
@GetMapping("/{id}")
@PreAuthorize("hasRole('USER')")
public ResponseEntity<ProductDto> getProduct(@PathVariable String id) {
  // Solo usuarios autenticados
}

@PostMapping
@PreAuthorize("hasRole('PRODUCT_ADMIN')")
public ResponseEntity<ProductDto> createProduct(@RequestBody ProductDto dto) {
  // Solo admins de productos
}
```

## 4. TLS/HTTPS

### Certificados

**En desarrollo**: Self-signed certificates (generados automáticamente)
**En producción**: Let's Encrypt via Azure Application Gateway

**Configuración en Spring Boot**:

```properties
server.ssl.enabled=true
server.ssl.key-store=classpath:keystore.jks
server.ssl.key-store-password=${TLS_KEYSTORE_PASSWORD}
server.ssl.key-store-type=JKS
server.ssl.key-alias=tomcat
server.ssl.key-password=${TLS_KEY_PASSWORD}
```

### mTLS entre Servicios

Cuando un servicio necesita comunicarse con otro de forma segura:

```properties
feign.client.config.default.ssl-enabled=true
feign.client.config.default.trust-store=${TRUST_STORE_PATH}
feign.client.config.default.trust-store-password=${TRUST_STORE_PASSWORD}
```

## 5. Escaneo Continuo de Vulnerabilidades

### Trivy

Escanea imágenes Docker durante la construcción:

```bash
# Escaneo en pipeline CI/CD
trivy image --severity HIGH,CRITICAL \
  --exit-code 1 \
  --format json \
  --output trivy-report.json \
  registry.azurecr.io/ecommerce/product-service:latest

# Reporte
trivy image --list-all-pkgs \
  registry.azurecr.io/ecommerce/product-service:latest
```

**Vulnerabilidades bloqueantes**: CRITICAL + HIGH
**Vulnerabilidades advertencias**: MEDIUM + LOW

### OWASP Dependency-Check

Escanea dependencias Maven:

```bash
mvn dependency-check:check \
  -Ddependency-check.reportFormat=HTML \
  -Ddependency-check.reportOutputDirectory=target/
```

### SonarQube Security

Análisis de seguridad en código fuente:

- SQL Injection detection
- Cross-site Scripting (XSS)
- Cross-Site Request Forgery (CSRF)
- Insecure cryptography
- Hard-coded credentials

**Quality Gate**: 0 vulnerabilidades críticas

## 6. Network Security

### Network Policies en Kubernetes

Aislamiento de tráfico entre pods:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-gateway
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-gateway
```

### Firewall Rules

**Azure NSG (Network Security Group)**:

```yaml
# Permitir tráfico HTTP desde Internet
- protocol: Tcp
  sourcePortRange: '*'
  destinationPortRange: '80'
  sourceAddressPrefix: '*'
  destinationAddressPrefix: '*'
  access: Allow
  priority: 100

# Denegar todo lo demás
- protocol: '*'
  sourcePortRange: '*'
  destinationPortRange: '*'
  sourceAddressPrefix: '*'
  destinationAddressPrefix: '*'
  access: Deny
  priority: 900
```

## 7. Auditoría y Logging

### Audit Logging

Todos los cambios significativos se registran:

```java
@Component
public class AuditLogger {
  
  public void logAction(String action, String resource, String user) {
    logger.info("AUDIT: user={}, action={}, resource={}, timestamp={}", 
      user, action, resource, LocalDateTime.now());
  }
}
```

**Eventos auditados**:
- Cambios de datos de usuario
- Creación/eliminación de órdenes
- Cambios de precios de productos
- Acceso a datos sensibles

### Audit Trail en Base de Datos

```java
@Entity
@Table(name = "audit_logs")
public class AuditLog {
  @Id
  private Long id;
  private String action;
  private String resource;
  private String userId;
  private LocalDateTime timestamp;
  private String ipAddress;
  private String userAgent;
}
```

## 8. Política de Contraseñas

### Requisitos

```properties
# Longitud mínima
password.min.length=12

# Debe contener: mayúsculas, minúsculas, números, símbolos
password.require.uppercase=true
password.require.lowercase=true
password.require.digits=true
password.require.special.chars=true

# Expiración
password.expiration.days=90
password.history.count=5  # No reutilizar últimas 5

# Bloqueo por intentos fallidos
password.max.attempts=5
password.lockout.duration.minutes=15
```

## 9. Validación de Entrada

Prevención de inyecciones y ataques:

```java
@RestController
@RequestMapping("/api/products")
public class ProductController {
  
  @PostMapping
  public ResponseEntity<ProductDto> create(
    @Valid @RequestBody ProductDto dto) {  // @Valid valida
    // ...
  }
}

@Data
public class ProductDto {
  @NotBlank(message = "Name is required")
  @Size(min = 3, max = 100)
  private String name;
  
  @NotNull
  @Min(0)
  @Max(1000000)
  private BigDecimal price;
  
  @Email(message = "Invalid email")
  private String manufacturerEmail;
}
```

## 10. Datos Sensibles

### PII (Personally Identifiable Information)

Protección de datos personales:

```java
@Entity
@Table(name = "users")
public class User {
  @Id
  private Long id;
  
  @JsonIgnore  // No serializar
  private String password;
  
  @JsonProperty(access = READ_ONLY)
  private String email;  // Solo lectura
  
  @JsonProperty(access = WRITE_ONLY)
  private String newPassword;  // Solo escritura
  
  // Encriptación en BD
  @Convert(converter = EncryptedAttributeConverter.class)
  private String ssn;  // Social Security Number
}
```

### Enmascaramiento

```java
// En respuestas API
public class UserResponseDto {
  private String email;  // user@***.com
  private String phone;  // +1 (***) ***-1234
  
  public UserResponseDto(User user) {
    this.email = maskEmail(user.getEmail());
    this.phone = maskPhone(user.getPhone());
  }
  
  private String maskEmail(String email) {
    String[] parts = email.split("@");
    return parts[0].substring(0, 1) + "***@" + parts[1];
  }
}
```

## 11. Mejores Prácticas de Seguridad

1. **Nunca hardcodee secretos**: Usar variables de entorno o vaults
2. **Principio de menor privilegio**: Roles mínimos necesarios
3. **Defensa en profundidad**: Múltiples capas de seguridad
4. **Validar entrada**: Whitelist, no blacklist
5. **Encriptar en tránsito**: TLS/HTTPS siempre
6. **Encriptar en reposo**: Datos sensibles en BD
7. **Logging y monitoreo**: Auditar cambios
8. **Actualizaciones de seguridad**: Mantener dependencias al día
9. **Pruebas de seguridad**: OWASP ZAP, pentest
10. **Incidentes**: Plan de respuesta documentado

## 12. Cumplimiento Normativo

### GDPR (General Data Protection Regulation)

- ✅ Derecho al olvido: Eliminar datos de usuario
- ✅ Portabilidad: Exportar datos en formato abierto
- ✅ Consentimiento: Rastrear consentimiento del usuario
- ✅ Notificación: Alertas ante brechas de seguridad

### PCI DSS (Payment Card Industry)

- ✅ No almacenar números de tarjeta completos
- ✅ Encritar datos de tarjeta
- ✅ Usar tokenización con proveedor de pagos
- ✅ Auditar acceso a datos de tarjeta

## Checklist de Seguridad

- [ ] Todos los secretos en Key Vault
- [ ] TLS habilitado en todos los servicios
- [ ] RBAC configurado y testeado
- [ ] Escaneo de vulnerabilidades en CI/CD
- [ ] Logs de auditoría activos
- [ ] Network policies configuradas
- [ ] Validación de entrada en todos los endpoints
- [ ] PII enmascarada en respuestas
- [ ] Contraseñas encriptadas (bcrypt/argon2)
- [ ] Datos sensibles encriptados en BD
- [ ] Pruebas de seguridad ejecutadas
- [ ] Documentación de incidentes actualizada
