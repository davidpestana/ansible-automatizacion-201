# M03 — Desarrollo de playbooks

[← Página anterior](../M02-inventarios/04-lab-inventario-dinamico.md) · [Siguiente página →](00-anatomia-de-un-playbook.md)

En el M02 el equipo de operaciones de Tienda Norte dejó descritos sus nodos en un inventario por entorno. Falta lo
que de verdad hace el runbook: instalar nginx, colocar la configuración del sitio, publicar la release del portal y
arrancar el servicio. En este módulo escribes esos pasos como un playbook correcto e idempotente, `portal.yml`, que
instala y configura el servicio web del portal en dev, pre y prod, y que puedes lanzar las veces que haga falta
sin romper nada.

## Qué aprenderás

- Leer y escribir un playbook en YAML sin pelearte con la indentación, y detectar los errores con `--syntax-check` antes de tocar un nodo.
- Encontrar el módulo adecuado para cada paso del runbook con `ansible-doc` y usar sus argumentos.
- Automatizar el patrón paquete → configuración → servicio de nginx con el portal publicado en `/srv/portal/current`.
- Ensayar un cambio con `--check --diff`, reconocer una tarea que no es idempotente y corregirla.

## Teoría

### De un paso del runbook a una tarea

| Runbook (por SSH) | Tarea de Ansible | Estado que se pide |
|-------------------|------------------|--------------------|
| `apt-get install nginx` | `ansible.builtin.apt` | `name: nginx`, `state: present` |
| `useradd -m operador` | `ansible.builtin.user` | `name: operador`, `state: present` |
| `mkdir -p /srv/portal/releases/1.0.0` | `ansible.builtin.file` | `state: directory` |
| `ln -s … /srv/portal/current` | `ansible.builtin.file` | `state: link` |
| `scp portal.conf …` | `ansible.builtin.copy` | `src` o `content`, `dest`, `mode` |
| `service nginx start` | `ansible.builtin.service` | `state: started` |

El runbook dice **qué hacer**; la tarea dice **cómo tiene que quedar**. El módulo comprueba el estado actual y
solo actúa si no coincide: por eso la segunda ejecución sale `changed=0`.

### Las piezas de un playbook

| Pieza | Qué es | En `portal.yml` |
|-------|--------|-----------------|
| Playbook | Fichero YAML con una lista de plays | `portal.yml` |
| Play | Un grupo de hosts y lo que se les hace | `Portal de pedidos en los servidores web` |
| `hosts` | Patrón de inventario | `web` |
| `become` | Ejecutar con sudo en el nodo | `true` |
| `tasks` | Lista ordenada de tareas | Instalar nginx, configurar el sitio… |
| Tarea | `name` + un módulo con sus argumentos | `ansible.builtin.apt: {name: nginx}` |

> [!NOTE]
> YAML no admite tabuladores y la indentación **es** la estructura: dos espacios más a la derecha significan
> «esto está dentro de lo anterior». Un valor que empieza por `{{` va entre comillas, y `yes`, `no`, `on` u `off`
> sin comillas son booleanos, no texto.

### Ejecutar sin miedo

| Opción | Qué hace | Cuándo |
|--------|----------|--------|
| `--syntax-check` | Valida YAML y estructura, sin conectar | Siempre, tras editar |
| `--list-tasks` | Lista plays y tareas que se ejecutarían | Para revisar el orden |
| `--check` | Simula: los módulos dicen qué cambiarían | Antes de aplicar en un nodo instalado |
| `--diff` | Muestra el antes y el después de los ficheros | Junto a `--check` o al aplicar |

> [!WARNING]
> `ansible.builtin.command` y `ansible.builtin.shell` no saben si su orden cambia algo: siempre dicen `changed` y
> en `--check` se saltan. Usa un módulo específico siempre que exista y, si no, `creates` o `changed_when`.

> [!NOTE]
> En `portal.yml` la recarga de nginx se decide con `register` y `when`. Es la forma directa de verlo ahora; en el
> M06 se sustituye por un **handler**, que es como se hace en un proyecto real.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [Anatomía de un playbook](00-anatomia-de-un-playbook.md) | Demostración: estructura de un playbook, errores típicos de YAML y --syntax-check |
| 01 | [Lab — Módulos principales](01-lab-modulos-principales.md) | Resuelves pasos del runbook con apt, user, file, copy y service, consultando ansible-doc |
| 02 | [Lab — Instalar y configurar un servicio](02-lab-instalar-servicio.md) | Automatizas nginx y la página del portal en los nodos web |
| 03 | [Lab — Ejecución idempotente](03-lab-ejecucion-idempotente.md) | Ejecutas con --check y --diff y corriges una tarea que siempre cambia |

→ Empieza por **[00 — Anatomía de un playbook](00-anatomia-de-un-playbook.md)**.
<!-- /gen:paginas -->
