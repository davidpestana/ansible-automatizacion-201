# Buenas prácticas

[← Página anterior](02-lab-reutilizar-rol.md) · [Siguiente página →](../M06-control-ejecucion/README.md)

Un proyecto Ansible compartido lo leen varias personas, lo revisa quien aprueba los cambios y acaban
ejecutándolo herramientas (un Makefile, ansible-lint, un controlador, un pipeline). Lo que hace que eso funcione
no es ningún módulo especial, sino unas cuantas costumbres que conviene seguir desde que el proyecto tiene
roles. Esta página las reúne.

## Nombres de tareas que se leen como un procedimiento

La salida de `ansible-playbook` es lo primero que mira quien revisa una ejecución. Si cada tarea tiene un nombre
claro, la salida *es* el procedimiento:

```text
TASK [webserver : Instalar nginx] **********************************************
TASK [webserver : Copiar la release 1.1.0] *************************************
TASK [webserver : Recargar nginx si ha cambiado su configuración] **************
```

| Práctica | Ejemplo | Por qué |
|----------|---------|---------|
| Toda tarea con `name:` | Ninguna tarea anónima en `tasks/` | Sin nombre, la salida muestra `TASK [ansible.builtin.file]` y no se sabe qué hace |
| Verbo en infinitivo y mayúscula inicial | `Instalar nginx`, `Publicar la configuración` | Se lee como los pasos de un procedimiento |
| Variables en el nombre cuando aportan | `Copiar la release {{ webserver_version }}` | La salida dice qué versión se ha desplegado en cada nodo |
| Nombres de play que dicen el papel | `Servidores web`, `Balanceador` | En el playbook principal se distingue cada tramo |

## FQCN: el nombre completo del módulo

Las tareas usan `ansible.builtin.apt`, `ansible.builtin.template`, `ansible.builtin.service`, nunca `apt` a secas.
El nombre completo (*Fully Qualified Collection Name*) dice de qué colección sale cada módulo.

| Forma | Ejemplo | Qué pasa |
|-------|---------|----------|
| Corta | `apt:` | Funciona, pero si una colección instalada define otro `apt`, no está claro cuál se usa |
| FQCN | `ansible.builtin.apt:` | Sin ambigüedad; ansible-lint lo exige (regla `fqcn`) |
| FQCN de otra colección | `community.postgresql.postgresql_db:` | Deja claro que el proyecto necesita esa colección |

Lo mismo vale para las palabras clave que son módulos: `ansible.builtin.import_tasks`,
`ansible.builtin.import_playbook`, `ansible.builtin.include_role`.

## Variables con el prefijo del rol

Las variables de Ansible comparten un único espacio de nombres: una variable `version` en un rol puede pisar o
quedar pisada por otra `version` de cualquier otro rol o inventario. Por eso todas las variables de un rol
empiezan por su nombre: `webserver_puerto`, `webserver_version`; las de un rol `loadbalancer`, por
`loadbalancer_`. ansible-lint lo comprueba con la regla `var-naming[no-role-prefix]`, que señala el fichero, la
línea y la variable sin prefijo.

El prefijo se aplica también a las variables registradas (`webserver_nginx_conf`). Y es del **rol**, no del
proyecto: una variable `webserver_version` dentro del rol `loadbalancer` también incumpliría la regla.

> [!TIP]
> Elegir el nombre del rol pensando en ese prefijo ahorra renombrados: si el inventario ya usa variables
> `app_*`, un rol llamado `app` encaja con ellas.

## `defaults` para lo configurable

| Dónde | Qué poner | Ejemplo |
|-------|-----------|---------|
| `roles/<rol>/defaults/main.yml` | Todo lo que un entorno o un nodo puede querer cambiar, con un valor razonable | `webserver_puerto: 80`, `webserver_worker_connections: 768` |
| `inventories/<entorno>/group_vars/` | Lo que distingue a un entorno | La versión desplegada en ese entorno |
| `inventories/<entorno>/host_vars/` | Lo que distingue a un nodo | Más conexiones en un servidor más grande |
| `roles/<rol>/vars/main.yml` | Constantes internas que nadie debe cambiar | Nombres de paquete por distribución |
| `-e` | Cambios puntuales de una ejecución | `-e webserver_version=1.0.0` para probar en dev |

> [!WARNING]
> Un valor en el `vars:` de un play gana a `host_vars`: si un playbook fija ahí un ajuste, ningún nodo podrá
> cambiarlo desde el inventario. Los valores configurables van en los `defaults` del rol, que el inventario sí pisa.

## Nada de secretos en claro

Contraseñas de base de datos, tokens de API o de un controlador: un secreto escrito en un `group_vars` acaba en
el historial de Git para siempre.

| Opción | Cuándo |
|--------|--------|
| Ansible Vault (`ansible-vault encrypt`) | Ficheros de variables cifrados dentro del repositorio; se descifran al ejecutar con una contraseña que no está en el repo |
| Credenciales de AWX / AAP | Cuando la ejecución es centralizada: el secreto lo guarda el controlador y lo inyecta en el job |
| Secretos del pipeline (GitHub Actions, GitLab CI) | Cuando ejecuta un workflow: se pasan como variables de entorno |
| Gestor de secretos (HashiCorp Vault, gestores de la nube) | Cuando la organización ya centraliza los secretos; Ansible los lee con un lookup |

La regla es una: el repositorio nunca guarda un secreto legible, y las claves SSH privadas viven fuera del proyecto.

## Una estructura que escala

```text
proyecto/
├── ansible.cfg            # roles_path = roles, inventario por defecto
├── requirements.yml       # roles y colecciones externos
├── inventories/<entorno>/ # hosts.yml, group_vars/, host_vars/
├── roles/<rol>/           # un rol por responsabilidad
├── web.yml  lb.yml        # un playbook por papel, en la raíz
└── site.yml               # entrada única: import_playbook de todo
```

- **Un rol, una responsabilidad.** Un rol para el servidor web, otro para el balanceador, otro para la base de
  datos. Un rol que hace de todo no se puede reutilizar en ningún sitio.
- **Playbooks en la raíz y cortos.** Dicen hosts, privilegios y roles; la lógica está en los roles.
- **Inventario por entorno.** El mismo `site.yml` despliega dev, pre o prod cambiando solo `-i`.
- **Dependencias externas declaradas.** Si el proyecto usa un rol de Galaxy o una colección que no viene con
  `ansible`, se declara en `requirements.yml` y se instala con `ansible-galaxy install -r requirements.yml`, en vez
  de copiarla a mano:

```yaml
# requirements.yml (ejemplo de formato)
collections:
  - name: community.postgresql
    version: ">=3.0.0"
roles:
  - name: geerlingguy.postgresql
```

> [!NOTE]
> El paquete `ansible` ya trae muchas colecciones de la comunidad (`community.postgresql`, `community.docker`,
> `ansible.posix`…). `requirements.yml` tiene sentido en cuanto el proyecto dependa de algo que no venga
> incluido, o para fijar versiones en un pipeline o en un execution environment.

## Idempotencia: la segunda ejecución no cambia nada

La comprobación más barata de que un rol está bien hecho es lanzarlo dos veces seguidas: en la segunda pasada,
el `PLAY RECAP` debe dar `changed=0` en todos los nodos.

| Señal | Qué indica |
|-------|------------|
| `changed=0` en la segunda pasada | Las tareas describen un estado, no una acción |
| `changed` siempre en una tarea | Suele ser `ansible.builtin.command`/`shell` sin `creates` ni `changed_when`, o una plantilla con algo que cambia en cada ejecución (una fecha) |
| Una recarga se ejecuta sin cambios | La condición no depende de un cambio real: se resuelve con handlers (M06) |

Muchas de estas reglas las comprueba ansible-lint de forma automática, como se ve en el M10.

## En los laboratorios

En el proyecto del caso, el rol del servidor web se llama `portal` porque el inventario ya usaba variables
`portal_*`, y el del balanceador `portal_lb`. El [Lab — Crear un rol reutilizable](01-lab-crear-rol.md) y el
[Lab — Reutilizar el rol](02-lab-reutilizar-rol.md) aplican estas prácticas.
