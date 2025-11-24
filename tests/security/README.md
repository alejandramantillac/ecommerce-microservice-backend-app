# Pruebas de Seguridad con OWASP ZAP

## 📋 Descripción

Este directorio contiene las pruebas de seguridad implementadas usando **OWASP ZAP (Zed Attack Proxy)** para escanear vulnerabilidades en las APIs REST del e-commerce.

## 🎯 Objetivo

Detectar vulnerabilidades de seguridad comunes según **OWASP Top 10**:
- Inyección SQL
- Autenticación rota
- Exposición de datos sensibles
- XML External Entities (XXE)
- Control de acceso roto
- Configuración de seguridad incorrecta
- Cross-Site Scripting (XSS)
- Deserialización insegura
- Componentes con vulnerabilidades conocidas
- Logging y monitoreo insuficientes

## 🏗️ Arquitectura

```
tests/security/
├── README.md                    # Esta documentación
├── zap-baseline-scan.sh         # Escaneo rápido (baseline)
├── zap-full-scan.sh            # Escaneo completo (full scan)
├── zap-api-scan.sh             # Escaneo específico de API
└── generate-zap-report.py      # Generador de reportes HTML
```

## 🚀 Uso

### Windows PowerShell

#### Escaneo Rápido (Baseline)
```powershell
.\zap-baseline-scan.ps1 -TargetUrl http://172.193.110.101:8080
```

#### Escaneo Completo (Full Scan)
```powershell
.\zap-full-scan.ps1 -TargetUrl http://172.193.110.101:8080
```

### Linux/Mac/Git Bash

#### Escaneo Rápido (Baseline)
```bash
chmod +x zap-baseline-scan.sh
./zap-baseline-scan.sh http://172.193.110.101:8080
```

#### Escaneo Completo (Full Scan)
```bash
chmod +x zap-full-scan.sh
./zap-full-scan.sh http://172.193.110.101:8080
```

#### Escaneo de API Específica
```bash
chmod +x zap-api-scan.sh
./zap-api-scan.sh http://172.193.110.101:8080 /api/products
```

## 📊 Reportes

Los reportes se generan en formato:
- **HTML**: `zap-report.html` (visual)
- **JSON**: `zap-report.json` (máquina)
- **XML**: `zap-report.xml` (CI/CD)

## ⚙️ Integración con Jenkins

Los escaneos se ejecutan automáticamente en los pipelines de CI/CD después de los tests de integración y E2E.

## 📝 Notas

- **Baseline Scan**: Rápido (~2-5 min), detecta vulnerabilidades críticas
- **Full Scan**: Completo (~10-30 min), análisis exhaustivo
- **API Scan**: Específico para endpoints REST, incluye autenticación

