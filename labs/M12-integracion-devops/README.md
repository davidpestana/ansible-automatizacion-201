# M12 — Integración en entornos DevOps

[← Página anterior](../M11-control-centralizado/02-cicd-como-alternativa.md) · [Siguiente página →](00-ansible-en-un-pipeline.md)

Integrar Ansible en un entorno DevOps es dejar que sea **la plataforma** la que lo ejecute: un pipeline de CI/CD
valida cada cambio del proyecto, despliega versiones en los entornos con las aprobaciones que haga falta y
aplica lo que hay en la rama principal, de forma que Git sea la fuente de verdad de los servidores. Este módulo
cubre el uso de Ansible en pipelines, la automatización de despliegues desde ellos y un flujo GitOps básico, con
GitHub Actions como plataforma.

## Qué aprenderás

- Leer un workflow de GitHub Actions y encontrar en la pestaña **Actions** la salida de Ansible de cada paso.
- Hacer que cada pull request de un proyecto Ansible pase lint, syntax-check y modo check antes de poder fusionarse.
- Lanzar un despliegue con **Run workflow**, eligiendo entorno y versión, con aprobación obligatoria para producción.
- Montar un flujo GitOps básico: el cambio entra por PR, el merge a `main` lo aplica y una deriva manual se corrige volviendo al estado de Git.
- Distinguir un pipeline de prácticas, con nodos efímeros, de uno que llega a servidores reales.

## Teoría

### Del terminal al pipeline

Un pipeline no inventa nada nuevo: ejecuta los mismos comandos (o los mismos objetivos del `Makefile`) que se
lanzan a mano. La diferencia es **quién** los lanza y **cuándo**.

| Pieza | Desde un terminal | Desde un pipeline |
|-------|-------------------|-------------------|
| Nodo de control | El equipo de quien lo lanza | El **runner**: una máquina nueva para cada ejecución (alojada o *self-hosted*) |
| Herramientas | Instaladas una vez en el equipo | Se instalan en cada ejecución (`pip install -r requirements.txt`) o vienen en la imagen del runner |
| Acceso a los nodos | La clave SSH de esa persona | Una clave guardada como **secreto** del repositorio o del entorno |
| Quién ejecuta | Una persona, cuando escribe el comando | Un **evento**: un pull request, un push a `main`, un clic en **Run workflow**, una hora programada |
| Dónde se ve | El terminal | El registro del pipeline: un log por paso, guardado y enlazado al commit |

### Anatomía de un workflow de GitHub Actions

Un workflow es un fichero YAML en `.github/workflows/` de la **raíz** del repositorio.

| Clave | Para qué | Ejemplo |
|-------|----------|---------|
| `on` | Qué evento lo dispara | `pull_request`, `push` a `main`, `workflow_dispatch` (manual), `schedule` (cron) |
| `paths` | Solo se dispara si el cambio toca esas rutas | `ansible/**`: un cambio en la documentación no lanza Ansible |
| `jobs.<id>.runs-on` | Tipo de runner | `ubuntu-24.04` o la etiqueta de un runner propio |
| `steps` | Pasos en orden; si uno falla, el job se para y sale en rojo | `checkout`, Python, `pip`, `ansible-lint`, `ansible-playbook` |
| `working-directory` | Carpeta del paso | La carpeta del proyecto, donde está `ansible.cfg` |
| `environment` | Entorno de GitHub con reglas (revisores, secretos) | `prod` con **Required reviewers** |

En GitLab CI las mismas ideas se escriben en `.gitlab-ci.yml` con `stages`, `jobs`, `rules` y `environment`.

### Tres usos típicos

| Pipeline | Disparo | Qué hace |
|----------|---------|----------|
| Validación | Pull request que toca el proyecto | `ansible-lint`, `--syntax-check` y `--check --diff` contra un entorno de pruebas |
| Despliegue | Manual, con entorno y versión como parámetros | El playbook de despliegue, tras aprobación en producción |
| Aplicación continua (GitOps) | Push a `main` que toca el proyecto | El playbook principal de cada entorno: lo que hay en `main` es lo que se aplica |

### GitOps en una frase

**Lo que está en `main` es lo que hay en los servidores.** Un cambio se propone en una rama, se valida en el
pull request y, al fusionarse, el pipeline lo aplica. Si alguien toca un servidor a mano (una **deriva**), la
siguiente ejecución lo devuelve al estado de Git y lo deja a la vista con un `changed`.

> [!NOTE]
> Un despliegue lanzado con un parámetro (`-e version=1.1.0`) cambia los nodos, pero no Git: la siguiente
> aplicación desde `main` vuelve a la versión que diga el inventario. Con GitOps, la versión de cada entorno se
> cambia en su fichero de variables, por pull request; el despliegue manual queda para pruebas o urgencias que
> después se suben a Git.

> [!WARNING]
> Un workflow ejecuta lo que diga el fichero de la rama. Por eso `pull_request` desde forks ajenos no recibe
> secretos, y por eso conviene pasar las entradas de un workflow manual por variables de entorno y no pegando
> `${{ inputs.… }}` dentro del script, que abre la puerta a inyectar órdenes.

## En los laboratorios

Los laboratorios usan tres workflows sobre el proyecto del caso (`validar.yml`, `desplegar.yml` y `aplicar.yml`,
que llaman al `Makefile`). Como el runner de GitHub no puede llegar a los nodos del Codespace, cada ejecución
levanta sus propios nodos de prácticas en contenedores y los borra al terminar; con servidores reales, el runner
(normalmente *self-hosted*, dentro de la red) llegaría a ellos por SSH con una clave guardada como secreto.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [Ansible en un pipeline](00-ansible-en-un-pipeline.md) | Demostración: un workflow levanta nodos de prueba, ejecuta make check y deja los logs en Actions |
| 01 | [Lab — Pipeline de validación](01-lab-pipeline-de-validacion.md) | Creas el workflow que valida cada pull request con lint y check |
| 02 | [Lab — Despliegue desde pipeline](02-lab-despliegue-desde-pipeline.md) | Un workflow manual despliega una versión del portal a un entorno con aprobación |
| 03 | [Lab — Flujo GitOps básico](03-lab-flujo-gitops.md) | Un merge a main aplica el cambio y una deriva manual se corrige sola |

→ Empieza por **[00 — Ansible en un pipeline](00-ansible-en-un-pipeline.md)**.
<!-- /gen:paginas -->
