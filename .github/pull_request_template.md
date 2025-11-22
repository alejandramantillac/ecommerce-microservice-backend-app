# Plantilla de Pull Request

## Resumen

- **Historia / Ticket**: `ED-###`
- **Contexto**: qué problema se resuelve y por qué.
- **Impacto**: servicios o pipelines afectados.

## Cambios

- Punto 1
- Punto 2

## Evidencias

- Jenkins build: `<URL>`
- Reportes Sonar/Trivy: `<URL>`
- Capturas o logs relevantes.

## Checklist

- [ ] Historia enlazada en el título o descripción (`[DEVOPS-###]`).
- [ ] Branch cumple convención (`feature/`, `release/`, `hotfix/`).
- [ ] Pruebas unitarias y de integración ejecutadas localmente.
- [ ] Pipeline de Jenkins (dev/stage) en verde.
- [ ] SonarQube sin issues críticas/nuevas vulnerabilidades.
- [ ] Trivy sin vulnerabilidades HIGH/CRITICAL nuevas.
- [ ] Pruebas E2E/performance (si aplica) adjuntas.
- [ ] Documentación actualizada.
- [ ] Plan de rollback o justificación de no aplicar.-
