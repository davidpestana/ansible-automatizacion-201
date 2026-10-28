# Automatización de procesos con Ansible

[Siguiente página →](labs/M01-fundamentos-arquitectura/00-que-es-ansible.md)

## Objetivo general

Al finalizar el curso, el alumno automatiza con Ansible la instalación, la configuración, el despliegue y la
operación de servicios en varios nodos y entornos, con roles reutilizables, ejecuciones estandarizadas y
validadas, lanzadas desde un controlador central o desde un pipeline.

## Enfoque

Ansible es una herramienta de código abierto para la automatización de TI que permite configurar servidores,
desplegar aplicaciones y gestionar infraestructuras a gran escala de forma sencilla. El curso la recorre de los
fundamentos a la operación en equipo: inventarios, playbooks, variables y plantillas, roles, control de la
ejecución, despliegues, operaciones de día 2 y orquestación; y se cierra con la gobernanza de un proyecto
Ansible (Makefile, ansible-lint, modo check y pull requests), su ejecución centralizada en AWX y su integración
en un pipeline de CI/CD con un flujo GitOps básico.

Cada módulo explica primero los conceptos y después los aplica. Las demostraciones y los laboratorios siguen el
caso de una empresa ficticia que pasa de un runbook manual a un proyecto Ansible que crece módulo a módulo.
Cada laboratorio arranca desde un punto de partida reproducible: no hace falta haber hecho el anterior.

## Dirigido a

Administradores de sistemas y equipos de operaciones o DevOps que mantienen servidores Linux a mano o con
scripts y van a estandarizar esas tareas con Ansible: instalar y configurar servicios, desplegar versiones,
parchear y llevar los cambios de desarrollo a producción de forma revisada y repetible.

## Conocimientos previos

- Se da por sabido: trabajar en un terminal Linux (SSH, paquetes, servicios, editar ficheros).
- Basta con haberlo usado: Git (commit, rama, push) y GitHub.
- Se estudia en el curso: Ansible y YAML desde cero, ansible-lint, Makefile, AWX y GitHub Actions aplicados a Ansible.

El entorno es un GitHub Codespace con todo instalado y los servidores de prácticas ya levantados como
contenedores: solo hace falta una cuenta de GitHub.

## Objetivos específicos

- Explicar el modelo agentless de Ansible y ejecutar módulos y un primer playbook sobre varios nodos.
- Describir los nodos por función y entorno en inventarios estáticos y dinámicos, con sus variables.
- Escribir playbooks idempotentes que instalan y configuran un servicio.
- Adaptar la configuración a cada nodo y entorno con group_vars, host_vars, plantillas Jinja2 y facts.
- Empaquetar la automatización en roles reutilizables dentro de un proyecto ordenado.
- Controlar la ejecución con condicionales, bucles, handlers, tags y el registro de resultados.
- Desplegar versiones de una aplicación en varios nodos, por tandas y con vuelta atrás.
- Parchear, aplicar cambios controlados en producción y diagnosticar ejecuciones que fallan.
- Orquestar servicios dependientes (base de datos, aplicación, balanceador), en secuencia o en paralelo.
- Estandarizar y validar cada ejecución con Makefile, ansible-lint y modo check, y llevar los cambios por pull request.
- Reconocer qué aportan AWX, Red Hat Ansible Automation Platform y un CI/CD como control centralizado.
- Ejecutar Ansible desde un pipeline para validar, desplegar y aplicar lo que hay en la rama principal.

## Temario

<!-- gen:temario -->
- **[M01 — Fundamentos y arquitectura](labs/M01-fundamentos-arquitectura/README.md)**
  - [Qué es Ansible y casos de uso](labs/M01-fundamentos-arquitectura/00-que-es-ansible.md)
  - [Arquitectura y modelo agentless](labs/M01-fundamentos-arquitectura/00-que-es-ansible.md)
  - [Inventario, playbooks y módulos](labs/M01-fundamentos-arquitectura/02-del-runbook-al-playbook.md)
  - [Idempotencia](labs/M01-fundamentos-arquitectura/02-del-runbook-al-playbook.md)
  - [Primer playbook y ejecución sobre nodos](labs/M01-fundamentos-arquitectura/04-lab-primer-playbook.md)
- **[M02 — Inventarios](labs/M02-inventarios/README.md)**
  - [Inventario estático](labs/M02-inventarios/00-inventario-estatico.md)
  - [Grupos y jerarquías](labs/M02-inventarios/01-lab-grupos-y-jerarquias.md)
  - [Variables en inventario](labs/M02-inventarios/02-lab-variables-en-inventario.md)
  - [Introducción a inventario dinámico](labs/M02-inventarios/04-lab-inventario-dinamico.md)
  - [Definición de inventarios por entornos](labs/M02-inventarios/03-lab-inventarios-por-entornos.md)
- **[M03 — Desarrollo de playbooks](labs/M03-desarrollo-playbooks/README.md)**
  - [Estructura y sintaxis YAML](labs/M03-desarrollo-playbooks/00-anatomia-de-un-playbook.md)
  - [Módulos principales](labs/M03-desarrollo-playbooks/01-lab-modulos-principales.md)
  - [Ejecución e idempotencia](labs/M03-desarrollo-playbooks/03-lab-ejecucion-idempotente.md)
  - [Automatización de instalación y configuración de un servicio](labs/M03-desarrollo-playbooks/02-lab-instalar-servicio.md)
- **[M04 — Gestión de configuración](labs/M04-gestion-configuracion/README.md)**
  - [Variables (host_vars, group_vars)](labs/M04-gestion-configuracion/01-lab-group-vars-host-vars.md)
  - [Templates con Jinja2](labs/M04-gestion-configuracion/02-lab-plantillas-jinja2.md)
  - [Uso de facts](labs/M04-gestion-configuracion/03-lab-facts.md)
  - [Configuración dinámica por entorno](labs/M04-gestion-configuracion/04-lab-configuracion-por-entorno.md)
- **[M05 — Modularización](labs/M05-modularizacion/README.md)**
  - [Roles y estructura de proyectos](labs/M05-modularizacion/00-estructura-de-un-rol.md)
  - [Reutilización de código](labs/M05-modularizacion/02-lab-reutilizar-rol.md)
  - [Buenas prácticas](labs/M05-modularizacion/03-buenas-practicas.md)
  - [Creación de un rol reutilizable](labs/M05-modularizacion/01-lab-crear-rol.md)
- **[M06 — Control de ejecución](labs/M06-control-ejecucion/README.md)**
  - [Condicionales, bucles y handlers](labs/M06-control-ejecucion/00-flujo-de-una-ejecucion.md)
  - [Tags](labs/M06-control-ejecucion/03-lab-tags.md)
  - [Registro de resultados](labs/M06-control-ejecucion/04-lab-registro-de-resultados.md)
  - [Automatización con lógica condicional](labs/M06-control-ejecucion/01-lab-condicionales-y-bucles.md)
- **[M07 — Despliegues con Ansible](labs/M07-despliegues/README.md)**
  - [Automatización de despliegues](labs/M07-despliegues/00-anatomia-de-un-despliegue.md)
  - [Ejecución sobre múltiples nodos](labs/M07-despliegues/02-lab-multiples-nodos.md)
  - [Estrategias básicas](labs/M07-despliegues/03-lab-despliegue-escalonado.md)
  - [Despliegue completo de servicio](labs/M07-despliegues/01-lab-despliegue-completo.md)
- **[M08 — Operaciones de día 2](labs/M08-operaciones-dia-2/README.md)**
  - [Actualizaciones y parcheo](labs/M08-operaciones-dia-2/01-lab-parcheo.md)
  - [Cambios controlados](labs/M08-operaciones-dia-2/00-cambios-controlados.md)
  - [Troubleshooting](labs/M08-operaciones-dia-2/03-lab-troubleshooting.md)
  - [Simulación de cambios en entorno productivo](labs/M08-operaciones-dia-2/02-lab-cambio-en-produccion.md)
- **[M09 — Orquestación](labs/M09-orquestacion/README.md)**
  - [Coordinación entre servicios](labs/M09-orquestacion/00-coordinacion-entre-servicios.md)
  - [Dependencias](labs/M09-orquestacion/01-lab-dependencias.md)
  - [Ejecución secuencial y paralela](labs/M09-orquestacion/02-lab-secuencial-y-paralelo.md)
  - [Orquestación de varios nodos](labs/M09-orquestacion/03-lab-orquestar-nodos.md)
- **[M10 — Gobernanza y operación de Ansible](labs/M10-gobernanza/README.md)**
  - [Estandarización de ejecuciones:](labs/M10-gobernanza/00-estandarizar-y-organizar.md)
  - [uso de Makefile como punto de entrada (make deploy, make check, etc.)](labs/M10-gobernanza/01-lab-makefile.md)
  - [Organización de repositorios y entornos (dev / pre / prod)](labs/M10-gobernanza/00-estandarizar-y-organizar.md)
  - [Control de cambios con Git (PR, revisión, trazabilidad)](labs/M10-gobernanza/04-lab-cambios-con-pr.md)
  - [Validación y calidad:](labs/M10-gobernanza/02-lab-ansible-lint.md)
  - [ansible-lint](labs/M10-gobernanza/02-lab-ansible-lint.md)
  - [ejecución en modo check](labs/M10-gobernanza/03-lab-validacion-previa.md)
  - [Creación de Makefile para ejecución estandarizada](labs/M10-gobernanza/01-lab-makefile.md)
  - [Validación previa y ejecución controlada](labs/M10-gobernanza/03-lab-validacion-previa.md)
- **[M11 — Control centralizado de ejecuciones](labs/M11-control-centralizado/README.md)**
  - [Introducción a Ansible AWX](labs/M11-control-centralizado/00-awx-y-aap.md)
  - [Inventarios centralizados](labs/M11-control-centralizado/01-demo-awx.md)
  - [Ejecución desde interfaz](labs/M11-control-centralizado/01-demo-awx.md)
  - [Control de accesos y auditoría](labs/M11-control-centralizado/01-demo-awx.md)
  - [Enfoque enterprise con Red Hat Ansible Automation Platform](labs/M11-control-centralizado/00-awx-y-aap.md)
  - [Alternativa mediante CI/CD (GitHub Actions / GitLab)](labs/M11-control-centralizado/02-cicd-como-alternativa.md)
  - [Ejecución de playbooks desde AWX](labs/M11-control-centralizado/01-demo-awx.md)
  - [Visualización de jobs y logs](labs/M11-control-centralizado/01-demo-awx.md)
- **[M12 — Integración en entornos DevOps](labs/M12-integracion-devops/README.md)**
  - [Uso de Ansible en pipelines](labs/M12-integracion-devops/00-ansible-en-un-pipeline.md)
  - [Automatización de despliegues](labs/M12-integracion-devops/02-lab-despliegue-desde-pipeline.md)
  - [Flujo GitOps básico](labs/M12-integracion-devops/03-lab-flujo-gitops.md)
  - [Ejecución de Ansible desde pipeline (simulado o real)](labs/M12-integracion-devops/01-lab-pipeline-de-validacion.md)
<!-- /gen:temario -->

## Antes de empezar

1. Haz un fork de este repositorio en tu cuenta de GitHub.
2. En tu fork, pulsa **Code** → **Codespaces** → **Create codespace on main**.
3. Cuando el terminal esté listo, comprueba los nodos: `scripts/nodos.sh estado` (seis líneas `SSH ok`).

| Necesitas | Dónde |
|-----------|-------|
| Qué hay en el entorno, nodos, puertos y solución de problemas | [infra/README.md](infra/README.md) |
| Dejar el proyecto en el punto de partida de una página | `scripts/partida.sh <estado>` (lo indica cada página) |

## Empieza aquí

<!-- gen:empieza -->
→ **[M01 — Qué es Ansible](labs/M01-fundamentos-arquitectura/00-que-es-ansible.md)**
<!-- /gen:empieza -->
