# M12 — Integración en entornos DevOps

[← Página anterior](../M11-control-centralizado/02-cicd-como-alternativa.md) · [Siguiente página →](00-ansible-en-un-pipeline.md)

En Tienda Norte ya nadie lanza `ansible-playbook` a mano: todo pasa por el `Makefile`, `ansible-lint` revisa cada
cambio y los cambios llegan por pull request. Falta el último eslabón: que sea **la plataforma** la que ejecute.
En este módulo, GitHub Actions valida cada pull request del proyecto del portal, despliega una versión a un
entorno con aprobación y aplica lo que hay en `main`, de forma que Git sea la fuente de verdad de los servidores.

## Qué aprenderás

- Leer un workflow de GitHub Actions y encontrar en la pestaña **Actions** la salida de Ansible de cada paso.
- Hacer que cada pull request que toca `proyecto/` pase lint, syntax-check, `site.yml` y modo check en pre antes de poder fusionarse.
- Lanzar un despliegue del portal con **Run workflow**, eligiendo entorno y versión, con aprobación obligatoria para prod.
- Montar un flujo GitOps básico: el cambio entra por PR, el merge a `main` lo aplica y una deriva manual se corrige volviendo al estado de Git.
- Distinguir lo que en este curso es simulado (los nodos viven dentro del runner) de lo que harías con servidores reales.

## Teoría

### Del Makefile al pipeline

El pipeline no inventa nada nuevo: ejecuta los mismos objetivos del `Makefile` que usas en el Codespace. La
diferencia es **quién** los lanza y **cuándo**.

| Pieza | En el Codespace | En GitHub Actions |
|-------|-----------------|-------------------|
| Nodo de control | El Codespace | El **runner**: una máquina `ubuntu-24.04` nueva para cada ejecución |
| Herramientas | `requirements.txt` instalado en el devcontainer | `actions/setup-python` + `pip install -r requirements.txt` en cada ejecución |
| Nodos gestionados | Los seis contenedores de `infra/compose.yaml` | Los mismos seis contenedores, levantados dentro del runner con `bash scripts/nodos.sh up` |
| Quién ejecuta | Tú, cuando escribes `make …` | Un **evento**: un pull request, un push a `main`, un clic en **Run workflow**, una hora programada |
| Dónde se ve | Tu terminal | La pestaña **Actions** del repositorio: un log por paso, guardado y enlazado al commit |

### Anatomía de un workflow

Un workflow es un fichero YAML en `.github/workflows/` de la **raíz** del repositorio (no dentro de `proyecto/`).

| Clave | Para qué | En este módulo |
|-------|----------|----------------|
| `on` | Qué evento lo dispara | `pull_request`, `push` a `main`, `workflow_dispatch` (manual), `schedule` (cron) |
| `paths` | Solo se dispara si el cambio toca esas rutas | `proyecto/**`: un cambio en `labs/` no lanza Ansible |
| `jobs.<id>.runs-on` | Tipo de runner | `ubuntu-24.04` (trae Docker, que levanta los nodos) |
| `steps` | Pasos en orden; si uno falla, el job se para y sale en rojo | `checkout`, Python, `pip`, nodos, `make …` |
| `working-directory` | Carpeta del paso | `proyecto`, porque ahí está `ansible.cfg` |
| `environment` | Entorno de GitHub con reglas (revisores, secretos) | `prod` con **Required reviewers** |

### Los tres pipelines del portal

| Workflow | Disparo | Qué hace | Página |
|----------|---------|----------|--------|
| `validar.yml` | Pull request y push a `main` que tocan `proyecto/` | `make validar`, `make site ENTORNO=pre`, `make check ENTORNO=pre` | [01 — Pipeline de validación](01-lab-pipeline-de-validacion.md) |
| `desplegar.yml` | Manual, con entorno y versión | `make deploy … CONFIRMAR=si` tras aprobación en prod | [02 — Despliegue desde pipeline](02-lab-despliegue-desde-pipeline.md) |
| `aplicar.yml` | Push a `main` que toca `proyecto/` | `make site` de cada entorno: lo que hay en `main` es lo que se aplica | [03 — Flujo GitOps básico](03-lab-flujo-gitops.md) |

> [!IMPORTANT]
> **Qué es simulado aquí.** Los nodos del portal son contenedores. El runner de GitHub no puede llegar a los de tu
> Codespace, así que cada ejecución levanta **sus propios** seis nodos, vacíos, y los borra al terminar. Por eso
> los workflows aplican `make site` antes de `make check` o `make deploy`: el modo check se usa sobre nodos ya
> instalados. Con servidores reales, el runner (normalmente uno *self-hosted* dentro de la red de la empresa)
> llegaría a ellos por SSH con una clave guardada como secreto, y ese paso previo sobraría.

### GitOps en una frase

**Lo que está en `main` es lo que hay en los servidores.** Un cambio se propone en una rama, se valida en el
pull request y, al fusionarse, el pipeline lo aplica. Si alguien toca un servidor a mano (una **deriva**), la
siguiente ejecución de `make site` lo devuelve al estado de Git y lo deja a la vista con un `changed`.

> [!NOTE]
> `make deploy ENTORNO=prod VERSION=1.1.0` cambia la versión en los nodos, pero no en Git: en
> `inventories/prod/group_vars/all.yml` sigue `portal_version: "1.0.0"`, y el siguiente `make site` vuelve a la
> 1.0.0. Con GitOps, la versión de prod se cambia en ese fichero, por pull request. El despliegue manual queda
> para lo que Git no describe: probar una versión en dev o pre, o una urgencia que después se sube a Git.

> [!WARNING]
> Un workflow ejecuta lo que diga el fichero de la rama. Por eso `pull_request` desde forks ajenos no recibe
> secretos, y por eso los workflows de este módulo pasan las entradas a `make` por variables de entorno
> (`ENTORNO`, `VERSION`) y no pegando `${{ inputs.… }}` dentro del script.

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
