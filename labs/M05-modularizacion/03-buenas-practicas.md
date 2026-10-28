# Buenas prácticas

[← Página anterior](02-lab-reutilizar-rol.md) · [Siguiente página →](../M06-control-ejecucion/README.md)

El proyecto del portal de Tienda Norte ya no es de una persona: lo leen operaciones, lo revisa quien aprueba los
cambios de prod y, más adelante, lo ejecutan un Makefile, ansible-lint, AWX y un pipeline. Lo que hace que eso
funcione no es ningún módulo especial, sino unas cuantas costumbres que el proyecto sigue desde que tiene roles.
Esta página las reúne, con el ejemplo del propio portal.

## Nombres de tareas que se leen como un runbook

La salida de `ansible-playbook` es lo primero que mira quien revisa un despliegue. Si cada tarea tiene un nombre
claro, la salida *es* el runbook:

```text
TASK [portal : Copiar la release 1.1.0] ****************************************
TASK [portal : Apuntar current a la release 1.1.0] *****************************
TASK [portal : Recargar nginx si ha cambiado su configuración] *****************
```

| Práctica | En el portal | Por qué |
|----------|--------------|---------|
| Toda tarea con `name:` | Ninguna tarea anónima en `roles/portal/tasks/` | Sin nombre, la salida muestra `TASK [ansible.builtin.file]` y no se sabe qué hace |
| Verbo en infinitivo y mayúscula inicial | `Instalar nginx`, `Publicar el estado del nodo` | Se lee como los pasos del runbook que sustituye |
| Variables en el nombre cuando aportan | `Copiar la release {{ portal_version }}` | La salida dice qué versión se ha desplegado en cada nodo |
| Nombres de play que dicen el papel | `Servidores web del portal`, `Balanceador del portal` | En `site.yml` se distingue cada tramo |

## FQCN: el nombre completo del módulo

Las tareas del proyecto usan `ansible.builtin.apt`, `ansible.builtin.template`, `ansible.builtin.service`, nunca
`apt` a secas. El nombre completo (*Fully Qualified Collection Name*) dice de qué colección sale cada módulo.

| Forma | Ejemplo | Qué pasa |
|-------|---------|----------|
| Corta | `apt:` | Funciona, pero si una colección instalada define otro `apt`, no está claro cuál se usa |
| FQCN | `ansible.builtin.apt:` | Sin ambigüedad; ansible-lint lo exige (regla `fqcn`) |
| FQCN de otra colección | `community.postgresql.postgresql_db:` | Deja claro que el proyecto necesita esa colección |

Lo mismo vale para las palabras clave que son módulos: `ansible.builtin.import_tasks`,
`ansible.builtin.import_playbook`, `ansible.builtin.include_role`.

## Variables con el prefijo del rol

Todas las variables del rol web empiezan por `portal_` y las del balanceador por `portal_lb_`. No es estética:
las variables de Ansible comparten un único espacio de nombres, y una variable `version` en un rol puede pisar o
quedar pisada por otra `version` de cualquier otro rol o inventario. ansible-lint lo comprueba con la regla
`var-naming[no-role-prefix]`. Así se ve si alguien añade `version: "1.0.0"` al `defaults/main.yml` del rol `portal`:

```text
var-naming[no-role-prefix]: Variables names from within roles should use portal_ as a prefix. (vars: version)
roles/portal/defaults/main.yml:8:1
```

Por eso el rol se llama `portal` y no, por ejemplo, `web`: el proyecto ya usaba `portal_version`,
`portal_color` o `portal_entorno` desde los inventarios, y el nombre del rol tenía que coincidir con ese prefijo.
El prefijo se aplica también a las variables registradas (`portal_nginx_conf`, `portal_lb_conf`).

> [!NOTE]
> El prefijo es del **rol**, no del proyecto. `portal_lb_backends` empieza por `portal_lb_` porque vive en el rol
> `portal_lb`. Una variable `portal_version` dentro de `portal_lb` también incumpliría la regla.

## `defaults` para lo configurable

| Dónde | Qué poner | Ejemplo en el portal |
|-------|-----------|----------------------|
| `roles/<rol>/defaults/main.yml` | Todo lo que un entorno o un nodo puede querer cambiar, con un valor razonable | `portal_puerto: 80`, `portal_worker_connections: 768` |
| `inventories/<entorno>/group_vars/` | Lo que distingue a un entorno | `portal_version`, `portal_color` de cada entorno |
| `inventories/<entorno>/host_vars/` | Lo que distingue a un nodo | `portal_worker_connections: 2048` en `prod-web2` |
| `roles/<rol>/vars/main.yml` | Constantes internas que nadie debe cambiar | Nada en el portal |
| `-e` | Cambios puntuales de una ejecución | `-e portal_version=1.0.0` para probar en dev |

> [!WARNING]
> Un valor en el `vars:` de un play gana a `host_vars`. En el antiguo `portal.yml`, `portal_worker_connections: 768`
> estaba ahí y el 2048 de `prod-web2` no llegaba nunca a su nginx. Al pasarlo a `defaults` del rol, el inventario
> vuelve a mandar.

## Nada de secretos en claro

El portal todavía no tiene contraseñas, pero las tendrá: la de PostgreSQL de `prod-db1`, tokens de AWX o del
pipeline. Un secreto escrito en un `group_vars` acaba en el historial de Git para siempre.

| Opción | Cuándo |
|--------|--------|
| Ansible Vault (`ansible-vault encrypt`) | Ficheros de variables cifrados dentro del repositorio; se descifran al ejecutar con una contraseña que no está en el repo |
| Credenciales de AWX / AAP | Cuando la ejecución es centralizada: el secreto lo guarda AWX y lo inyecta en el job |
| Secretos del pipeline (GitHub Actions) | Cuando ejecuta un workflow: se pasan como variables de entorno |

En el curso Vault solo se menciona; lo importante es la regla: el repositorio nunca guarda un secreto legible, y la
clave SSH del curso (`~/.ssh/curso-ansible/`) vive fuera de `proyecto/`.

## Una estructura que escala

```text
proyecto/
├── ansible.cfg            # roles_path = roles, inventario por defecto dev
├── requirements.yml       # roles y colecciones externos (cuando hagan falta)
├── inventories/<entorno>/ # hosts.yml, group_vars/, host_vars/
├── roles/<rol>/           # un rol por responsabilidad
├── web.yml  lb.yml        # un playbook por papel, en la raíz
└── site.yml               # entrada única: import_playbook de todo
```

- **Un rol, una responsabilidad.** `portal` sirve el portal; `portal_lb` reparte. Cuando llegue PostgreSQL será otro
  rol, no más tareas en `portal`. Un rol que hace de todo no se puede reutilizar en ningún sitio.
- **Playbooks en la raíz y cortos.** Dicen hosts, privilegios y roles. `playbook_dir` es la raíz, y desde ella el
  rol encuentra `app/releases/`.
- **Inventario por entorno.** El mismo `site.yml` despliega dev, pre o prod cambiando solo `-i`.
- **Dependencias externas declaradas.** Si el proyecto usa un rol de Galaxy o una colección que no viene con
  `ansible`, se declara en `requirements.yml` y se instala con `ansible-galaxy install -r requirements.yml`, en vez
  de copiarla a mano:

```yaml
# proyecto/requirements.yml (ejemplo de formato)
collections:
  - name: community.postgresql
    version: ">=3.0.0"
roles:
  - name: geerlingguy.postgresql
```

> [!NOTE]
> El paquete `ansible` del curso ya trae `community.postgresql`, `community.docker` y `ansible.posix`, así que el
> proyecto del portal no necesita `requirements.yml` todavía. El fichero tiene sentido en cuanto alguien dependa de
> algo que no venga incluido, o para fijar versiones en el pipeline.

## Idempotencia: la segunda ejecución no cambia nada

La comprobación más barata de que un rol está bien hecho es lanzarlo dos veces. Sobre prod recién desplegado,
`site.yml` da en la segunda pasada:

```text
PLAY RECAP *********************************************************************
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web2                  : ok=11   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

| Señal | Qué indica |
|-------|------------|
| `changed=0` en la segunda pasada | Las tareas describen un estado, no una acción |
| `changed` siempre en una tarea | Suele ser `ansible.builtin.command`/`shell` sin `creates` ni `changed_when`, o una plantilla con algo que cambia en cada ejecución |
| La recarga se ejecuta sin cambios | La condición no depende de un cambio real (en el M06 se resuelve con handlers) |

Las mismas reglas las aplica ansible-lint de forma automática cuando el proyecto lo incorpora en el M10.
