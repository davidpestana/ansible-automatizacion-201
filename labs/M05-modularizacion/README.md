# M05 — Modularización

[← Página anterior](../M04-gestion-configuracion/04-lab-configuracion-por-entorno.md) · [Siguiente página →](00-estructura-de-un-rol.md)

Un playbook que lo hace todo funciona, pero es un bloque: para reutilizar parte de su lógica hay que copiarla, y
quien quiera usarlo tiene que entenderlo entero. Los **roles** son la unidad de reutilización de Ansible: una
carpeta con una estructura fija (tareas, handlers, plantillas, valores por defecto, metadatos) que cualquier
playbook puede aplicar a unos hosts con una línea. Este módulo cubre la estructura de un rol y de un proyecto
que crece, cómo se hace un rol configurable y reutilizable, y las buenas prácticas que mantienen legible un
proyecto compartido.

## Qué aprenderás

- Generar el esqueleto de un rol con `ansible-galaxy role init` y saber qué va en cada carpeta.
- Convertir un playbook en un rol sin cambiar nada en los nodos (`changed=0`).
- Hacer un rol configurable con `defaults` y cambiar su comportamiento desde el inventario o con `-e`.
- Crear un segundo rol siguiendo el mismo patrón y combinar los dos en un playbook principal.
- Ordenar el proyecto para que escale: `inventories/`, `roles/`, playbooks en la raíz y `ansible.cfg` con `roles_path`.

## Teoría

Un **rol** es una carpeta con una estructura fija que Ansible sabe leer: no hace falta decirle dónde están las
tareas, las plantillas o los valores por defecto. El playbook solo dice *a qué hosts* y *qué rol*.

| Carpeta del rol | Qué contiene | Ejemplo en un rol `webserver` |
|-----------------|--------------|-------------------------------|
| `tasks/` | Las tareas; se empieza por `main.yml` | Instalar nginx, configurarlo, publicar el sitio |
| `handlers/` | Tareas que se ejecutan cuando otra las notifica | `Recargar nginx` |
| `templates/` | Plantillas Jinja2; `src:` las busca aquí sin ruta | `nginx.conf.j2`, `sitio.conf.j2` |
| `files/` | Ficheros que se copian tal cual | Una página estática, un certificado de prueba |
| `defaults/` | Valores por defecto, la prioridad **más baja** | `webserver_puerto: 80` |
| `vars/` | Valores internos, prioridad **alta** | Nombres de paquete por distribución |
| `meta/` | Autor, plataformas y dependencias del rol | `galaxy_info` y `dependencies: []` |

Una estructura de proyecto habitual:

```text
proyecto/
├── ansible.cfg                   # roles_path = roles
├── inventories/{dev,pre,prod}/   # hosts.yml, group_vars/, host_vars/
├── roles/
│   ├── webserver/
│   └── loadbalancer/
├── web.yml                       # hosts: webservers    → rol webserver
├── lb.yml                        # hosts: loadbalancers → rol loadbalancer
└── site.yml                      # import_playbook de web.yml y lb.yml
```

> [!NOTE]
> **`defaults` frente a `vars`.** Los dos guardan variables del rol, pero en extremos opuestos de la precedencia.
> Lo que va en `defaults/main.yml` es lo que *se puede* cambiar: el `group_vars` de cada entorno lo pisa. Lo que va
> en `vars/main.yml` gana al inventario y solo lo supera `-e`. Si la versión a desplegar estuviera en `vars/`,
> todos los entornos desplegarían la misma, digan lo que digan sus `group_vars`.

> [!NOTE]
> **Prefijo de las variables.** ansible-lint (regla `var-naming[no-role-prefix]`) exige que las variables de un
> rol empiecen por el nombre del rol: `webserver_puerto`, no `puerto`. Evita choques entre roles y deja claro de
> dónde sale cada valor.

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
