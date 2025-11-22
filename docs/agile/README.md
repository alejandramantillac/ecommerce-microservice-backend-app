## Manual de Entrega Ágil

### Visión del producto

- Modernizar el backend de ecommerce para promover microservicios de Dev → Staging → Prod con observabilidad total y guardas de calidad automáticas.
- Garantizar una experiencia confiable de marketplace: catálogos rápidos, checkout resiliente y pagos/envíos auditables.
- Tratar cada mejora de DevOps (IaC, CI/CD, pruebas, monitoreo) como valor directo para el usuario: releases más veloces, menos incidentes y métricas claras.

### Marco de trabajo: Scrum

- **Duración del sprint:** 2 semanas, con inicio lunes 09:00 cada quincena.
- **Cadencia de liberación:** cada sprint termina con un incremento desplegable en staging.
- **Enfoque:** seleccionar 1–2 temas del enunciado por sprint (ej. Terraform + Observabilidad) para asegurar profundidad.

### Roles y responsabilidades

- **Product Owner:** prioriza backlog, define metas y acepta historias terminadas.
- **Scrum Master:** facilita ceremonias, remueve bloqueos y cuida la disciplina Scrum.
- **Equipo DevOps/Plataforma:** implementa IaC, pipelines, seguridad y confiabilidad.
- **QA/Automatización:** amplía pruebas de integración/E2E/rendimiento y valida evidencias.
- **Stakeholders:** docentes/clientes que dan retroalimentación en la review.

### Ceremonias y cadencia

| Ceremonia       | Momento                  | Participantes           | Objetivo                                                 |
| --------------- | ------------------------ | ----------------------- | -------------------------------------------------------- |
| Sprint Planning | Día 1 – 2 h            | PO, SM, equipo completo | Alinear meta, elegir historias y desglosar tareas.       |
| Daily Scrum     | Lun–Vie 09:15 – 15 min | Equipo                  | Revisar avance y exponer impedimentos.                   |
| Refinamiento    | Mitad del sprint – 1 h  | PO + equipo             | Preparar backlog próximo, detallar criterios y estimar. |
| Sprint Review   | Jueves final – 1 h      | Equipo + stakeholders   | Demostrar incremento y registrar feedback.               |
| Retrospectiva   | Viernes final – 45 min  | Equipo                  | Analizar proceso y acordar mejoras.                      |

### Artefactos y responsables

- **Product Backlog:** tablero Jira/Trello (`<insert board URL>`), propiedad del PO.
- **Sprint Backlog:** historias en la columna *Sprint comprometido*, responsabilidad compartida.
- **Definition of Ready / Done:** detalladas abajo, se validan en refinamiento y review.
- **Hub documental:** carpeta `/docs` más wiki/Confluence (`<insert doc hub>`).

### Herramientas y comunicación

- **Seguimiento:** tablero Jira/Trello/GitHub Projects (`<insert board URL>`).
- **Canal de daily:** Slack/Teams `#devops-scrum`.
- **Evidencias CI/CD:** pipelines Jenkins (`Jenkinsfile.*`) enlazados a cada historia.
- **Diseño/documentación:** `/docs` + pizarras colaborativas (Miro/FigJam).

### Acuerdos de trabajo

**Definition of Ready**

- Valor claro vinculado al enunciado o release.
- Criterios de aceptación escritos; ideas de prueba anotadas.
- Dependencias técnicas identificadas.
- Estimada en story points (Fibonacci).
- Mockups o diagramas adjuntos o referenciados.

**Definition of Done**

- Merge a `develop` mediante PR con al menos dos aprobaciones.
- Pruebas unitarias e integración verdes en el pipeline de dev.
- SonarQube y Trivy sin fallos bloqueantes.
- Despliegue validado en staging y evidencia compartida en el canal del sprint.
- Documentación actualizada (README, runbooks, diagramas o bitácora).

**Estimación y flujo**

- Story points (1,2,3,5,8,13); tareas internas pueden estimarse en horas.
- Límite de WIP individual: 2 historias activas.
- Bloqueos >24 h se escalan en el daily y el SM coordina la resolución.

**Calidad y guardas CI/CD**

- Toda PR incluye el identificador del ticket (`[DEVOPS-123]`).
- Pipeline de dev verde antes del merge; pipeline de staging verde antes de la review.
- Regresiones reabren la historia hasta corregirse.
- Fallos de seguridad/observabilidad se atienden dentro del mismo sprint.

### Referencias rápidas

- Tablero/backlog: [https://valoracionpreanestesica.atlassian.net/jira/software/projects/ED](https://valoracionpreanestesica.atlassian.net/jira/software/projects/ED)
- Canal de daily: `#devops-daily` at: [slack](https://app.slack.com/client/T09U79BJUE5)
- Bitácoras de sprint: `docs/agile/sprint-logs/`
- Para contribuir sigue la [estrategia de branching definida en `docs/branching-strategy.md`](docs/branching-strategy.md).
