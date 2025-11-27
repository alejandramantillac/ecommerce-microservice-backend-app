# TLS Implementation with NGINX Ingress Controller

Este directorio contiene la configuración para implementar TLS/HTTPS en los servicios expuestos públicamente usando NGINX Ingress Controller.

## Arquitectura

```
Internet → Azure LoadBalancer → NGINX Ingress Controller → Services (ClusterIP)
                                    ↓
                            TLS Termination (HTTPS)
```

## Archivos

- `00-nginx-ingress-controller.yaml` - Instalación del NGINX Ingress Controller
- `01-generate-self-signed-cert.sh` - Script para generar certificados autofirmados
- `02-tls-secret-staging.yaml` - Secret con certificado TLS para staging
- `02-tls-secret-prod.yaml` - Secret con certificado TLS para producción
- `03-ingress-staging.yaml` - Ingress resource para staging
- `03-ingress-prod.yaml` - Ingress resource para producción

## Instalación

### Paso 1: Instalar NGINX Ingress Controller

```bash
kubectl apply -f k8s/ingress/00-nginx-ingress-controller.yaml
```

Esperar a que el LoadBalancer obtenga una IP pública:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

**Nota**: Azure creará automáticamente un LoadBalancer. Puede tardar 2-5 minutos.

### Paso 2: Generar Certificados TLS

#### Opción A: Certificados Autofirmados (Desarrollo/Testing)

```bash
cd k8s/ingress
chmod +x 01-generate-self-signed-cert.sh

# Para staging
./01-generate-self-signed-cert.sh staging localhost

# Para producción
./01-generate-self-signed-cert.sh prod localhost
```

Esto generará:
- `certs/staging.key` y `certs/staging.crt`
- `certs/prod.key` y `certs/prod.crt`
- `02-tls-secret-staging.yaml` (listo para aplicar)
- `02-tls-secret-prod.yaml` (listo para aplicar)

#### Opción B: Usar Let's Encrypt (Producción)

1. Instalar cert-manager:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

2. Crear ClusterIssuer:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

3. Modificar Ingress para usar cert-manager:
```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
```

### Paso 3: Aplicar Secrets TLS

```bash
# Staging
kubectl apply -f k8s/ingress/02-tls-secret-staging.yaml

# Producción
kubectl apply -f k8s/ingress/02-tls-secret-prod.yaml
```

### Paso 4: Aplicar Ingress Resources

```bash
# Staging
kubectl apply -f k8s/ingress/03-ingress-staging.yaml

# Producción
kubectl apply -f k8s/ingress/03-ingress-prod.yaml
```

## Configuración de DNS

### Obtener IP del LoadBalancer

```bash
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"
```

### Configurar DNS

**Si tienes un dominio:**
1. Crear registro A en tu DNS:
   - `api-staging.tudominio.com` → IP del LoadBalancer
   - `api.tudominio.com` → IP del LoadBalancer

2. Actualizar los archivos de Ingress:
   - Cambiar `api-staging.local` por `api-staging.tudominio.com` en `03-ingress-staging.yaml`
   - Cambiar `api.local` por `api.tudominio.com` en `03-ingress-prod.yaml`

**Si NO tienes dominio (solo para testing):**
- Usar la IP directamente: `https://<INGRESS_IP>`
- O modificar `/etc/hosts`:
  ```
  <INGRESS_IP> api-staging.local
  <INGRESS_IP> api.local
  ```

## Verificación

### Verificar Ingress Controller

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### Verificar Ingress Resources

```bash
kubectl get ingress -n staging
kubectl get ingress -n prod
kubectl describe ingress api-gateway-ingress -n staging
```

### Probar HTTPS

```bash
# Obtener IP del Ingress
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Probar (con certificado autofirmado, ignorar warning)
curl -k https://${INGRESS_IP}/actuator/health

# O con dominio (si configurado)
curl -k https://api-staging.example.com/actuator/health
```

## Integración con Jenkins

El pipeline de Jenkins aplica automáticamente los recursos de Ingress durante el despliegue.

Ver: `jenkins/shared-lib/vars/commonFunctions.groovy` → función `applyIngress()`

El Ingress se aplica **después** de desplegar los servicios para asegurar que existan.

## Características Implementadas

✅ **TLS/HTTPS**: Todos los servicios expuestos usan HTTPS  
✅ **Redirección HTTP → HTTPS**: Automática  
✅ **CORS**: Configurado en Ingress  
✅ **Certificados Autofirmados**: Para desarrollo/testing  
✅ **Listo para Let's Encrypt**: Fácil migración a certificados válidos  
✅ **Integración con Azure**: LoadBalancer creado automáticamente  

## Troubleshooting

### Ingress Controller no obtiene IP

```bash
# Verificar eventos
kubectl describe svc -n ingress-nginx ingress-nginx-controller

# Verificar logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Certificado no se aplica

```bash
# Verificar secret existe
kubectl get secret tls-secret-staging -n staging

# Verificar Ingress referencia el secret correcto
kubectl describe ingress api-gateway-ingress -n staging
```

### Error 502 Bad Gateway

- Verificar que el servicio `api-gateway` existe y está corriendo
- Verificar que el puerto en Ingress coincide con el servicio
- Verificar logs del Ingress Controller:
  ```bash
  kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
  ```

### Certificado autofirmado muestra advertencia

Esto es normal. Para producción:
- Usar Let's Encrypt con cert-manager
- O usar Azure Key Vault con certificados válidos

### Error: IngressClass "nginx" not found

Asegúrate de que el IngressClass fue creado:
```bash
kubectl get ingressclass
```

Si no existe, el archivo `00-nginx-ingress-controller.yaml` lo crea automáticamente.

## Mejoras Futuras

1. **Integración con Azure Key Vault** para certificados
2. **cert-manager con Let's Encrypt** para renovación automática
3. **WAF (Web Application Firewall)** con Azure Application Gateway
4. **Rate Limiting** en Ingress
5. **IP Whitelisting** para servicios internos
6. **Multiple Ingress** para diferentes servicios (zipkin, etc.)

## Notas de Seguridad

⚠️ **Certificados Autofirmados**:
- Solo para desarrollo/testing
- Los navegadores mostrarán advertencia
- No recomendado para producción

✅ **Producción**:
- Usar certificados válidos (Let's Encrypt o Azure Key Vault)
- Configurar renovación automática
- Monitorear expiración de certificados
- Considerar WAF para protección adicional

## Costos

- **NGINX Ingress Controller**: Gratis (se ejecuta en el cluster)
- **Azure LoadBalancer**: ~$0.025/hora (~$18/mes) por LoadBalancer
- **Certificados Let's Encrypt**: Gratis
- **Azure Key Vault**: ~$0.03/10,000 operaciones

**Recomendación**: Un solo LoadBalancer para el Ingress Controller es más económico que múltiples LoadBalancers por servicio.

