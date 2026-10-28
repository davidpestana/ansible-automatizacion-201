# M05 — Modularización

[← Página anterior](../M04-gestion-configuracion/04-lab-configuracion-por-entorno.md) · [Siguiente página →](00-estructura-de-un-rol.md)

En el M04 el portal de Tienda Norte quedó en un único `portal.yml` con plantillas y variables por entorno. Funciona,
pero es un bloque: para montar el balanceador habría que copiar media lógica, y cualquiera que quiera desplegar el
portal tiene que entender el playbook entero. Este módulo trata los **roles y la estructura de proyectos**: el
playbook se convierte en el rol `portal`, el balanceador en el rol `portal_lb`, y `site.yml` monta los dos. Es la
forma de **reutilizar código** que se mantiene igual en dev, pre y prod, y la base de las **buenas prácticas** que
el resto del curso da por hechas.

## Qué aprenderás

- Generar el esqueleto de un rol con `ansible-galaxy role init` y saber qué va en cada carpeta.
- Convertir `portal.yml` en el rol `portal` sin cambiar nada en los nodos (`changed=0`).
- Hacer un rol configurable con `defaults` y cambiar su comportamiento desde el inventario o con `-e`.
- Crear un segundo rol (`portal_lb`) siguiendo el mismo patrón y orquestar los dos con `site.yml`.
- Ordenar el proyecto para que escale: `inventories/`, `roles/`, playbooks en la raíz y `ansible.cfg` con `roles_path`.

## Teoría

Un **rol** es una carpeta con una estructura fija que Ansible sabe leer: no hace falta decirle dónde están las
tareas, las plantillas o los valores por defecto. El playbook solo dice *a qué hosts* y *qué rol*.

| Carpeta del rol | Qué contiene | En el rol `portal` |
|-----------------|--------------|--------------------|
| `tasks/` | Las tareas; se empieza por `main.yml` | Instalar nginx, configurarlo, desplegar la release |
| `handlers/` | Tareas que se ejecutan cuando otra las notifica | Se usa en el M06 (`Recargar nginx`) |
| `templates/` | Plantillas Jinja2; `src:` las busca aquí sin ruta | `nginx.conf.j2`, `portal.conf.j2`, `estado.json.j2` |
| `files/` | Ficheros que se copian tal cual | No hace falta: la release vive en `app/` del proyecto |
| `defaults/` | Valores por defecto, la prioridad **más baja** | `portal_puerto: 80`, `portal_raiz: /srv/portal`… |
| `vars/` | Valores internos, prioridad **alta** | No se usa |
| `meta/` | Autor, plataformas y dependencias del rol | `galaxy_info` y `dependencies: []` |

Así queda el proyecto al final del módulo:

```text
proyecto/
├── ansible.cfg            # roles_path = roles
├── app/releases/…         # las versiones del portal
├── inventories/{dev,pre,prod}/   # hosts.yml, group_vars/, host_vars/
├── roles/
│   ├── portal/            # servidor web
│   └── portal_lb/         # balanceador
├── web.yml                # hosts: web → rol portal
├── lb.yml                 # hosts: lb  → rol portal_lb
└── site.yml               # import_playbook de web.yml y lb.yml
```

> [!NOTE]
> **`defaults` frente a `vars`.** Los dos guardan variables del rol, pero en extremos opuestos de la precedencia.
> Lo que va en `defaults/main.yml` es lo que *se puede* cambiar: el `group_vars` de cada entorno lo pisa. Lo que va
> en `vars/main.yml` gana al inventario y solo lo supera `-e`. Si `portal_version` estuviera en `vars/`, dev, pre
> y prod desplegarían la misma versión digan lo que digan sus `group_vars`.

> [!NOTE]
> **Por qué `portal` y `portal_*`.** ansible-lint (regla `var-naming[no-role-prefix]`) exige que las variables de un
> rol empiecen por el nombre del rol. Como todo el proyecto ya usa `portal_version`, `portal_color`, etc., el rol
> web se llama `portal`, y el del balanceador `portal_lb` con variables `portal_lb_*`.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [Estructura de un rol y del proyecto](00-estructura-de-un-rol.md) | Demostración: ansible-galaxy role init, carpetas del rol y del proyecto |
| 01 | [Lab — Crear un rol reutilizable](01-lab-crear-rol.md) | Conviertes el playbook del portal en el rol portal |
| 02 | [Lab — Reutilizar el rol](02-lab-reutilizar-rol.md) | Usas el rol con otros parámetros y creas el rol del balanceador |
| 03 | [Buenas prácticas](03-buenas-practicas.md) | Nombres, variables con prefijo, FQCN, secretos y estructura que escala |

→ Empieza por **[00 — Estructura de un rol y del proyecto](00-estructura-de-un-rol.md)**.
<!-- /gen:paginas -->
