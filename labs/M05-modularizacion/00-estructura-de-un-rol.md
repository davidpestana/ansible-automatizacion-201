# Estructura de un rol y del proyecto

[← Página anterior](README.md) · [Siguiente página →](01-lab-crear-rol.md)

El portal de Tienda Norte vive en un único `portal.yml` que mezcla tareas, variables por defecto y
plantillas. Esta demostración muestra el esqueleto que propone Ansible para un rol y dónde encaja cada pieza
del portal antes de partirlo.

## Qué se va a ver

**Qué se hace**

1. Se mira el proyecto antes de los roles.
2. Se genera el esqueleto de un rol con `ansible-galaxy role init`.
3. Se comprueba qué valor toma una variable definida en `defaults/` del rol.
4. Se repite con la variable en `vars/`.
5. Se ve cómo queda el proyecto con roles.

**Objetivos**

- Conocer la estructura estándar de un rol y el papel de cada carpeta.
- Distinguir `defaults/` de `vars/` por su prioridad frente al inventario.

**Conclusiones**

- Lo configurable va en `defaults/`, porque el inventario puede pisarlo.
- Lo que va en `vars/` gana al inventario, así que no sirve para valores que cambian por entorno.

## Punto de partida

- Terminal del Codespace, en la raíz del repositorio.
- Estado: `proyecto/` con el `portal.yml` del M04 (plantillas y `group_vars` por entorno, sin roles). Se carga con:

```bash
# Terminal del Codespace, raíz del repo
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m05
cd proyecto
```

- Los nodos no se modifican en esta demostración: solo se lee una variable con `ansible.builtin.debug`.

## Recorrido

### 1. El proyecto antes de los roles

Fuera de `app/` (las releases), el proyecto tiene esta forma:

```text
./ansible.cfg
./inventories/dev/group_vars/all.yml
./inventories/dev/hosts.yml
./inventories/pre/group_vars/all.yml
./inventories/pre/hosts.yml
./inventories/prod/group_vars/all.yml
./inventories/prod/hosts.yml
./inventories/prod/host_vars/prod-web2.yml
./portal.yml
./templates/estado.json.j2
./templates/nginx.conf.j2
./templates/portal.conf.j2
```

Los inventarios ya están ordenados por entorno. Lo que no escala es lo de abajo: un playbook con todo dentro y una
carpeta `templates/` que solo entiende quien conoce ese playbook. En `ansible.cfg` ya hay una línea preparada para
lo que viene:

```ini
# proyecto/ansible.cfg (fragmento)
[defaults]
inventory = inventories/dev/hosts.yml
roles_path = roles
```

`roles_path = roles` le dice a Ansible que busque los roles en `proyecto/roles/`.

### 2. El esqueleto que genera `ansible-galaxy role init`

`ansible-galaxy` crea la estructura estándar de un rol. Con `--init-path roles` la deja dentro de `roles/`:

```bash
# Terminal del Codespace, en proyecto/
ansible-galaxy role init --init-path roles portal
find roles/portal | sort
```

```text
- Role portal was created successfully
roles/portal
roles/portal/defaults
roles/portal/defaults/main.yml
roles/portal/files
roles/portal/handlers
roles/portal/handlers/main.yml
roles/portal/meta
roles/portal/meta/main.yml
roles/portal/README.md
roles/portal/tasks
roles/portal/tasks/main.yml
roles/portal/templates
roles/portal/tests
roles/portal/tests/inventory
roles/portal/tests/test.yml
roles/portal/vars
roles/portal/vars/main.yml
```

Cada carpeta tiene un papel fijo y Ansible carga su `main.yml` sin que nadie se lo pida:

| Carpeta | Qué hace Ansible con ella | Qué pieza de `portal.yml` iría aquí |
|---------|---------------------------|-------------------------------------|
| `tasks/` | Ejecuta `tasks/main.yml` al aplicar el rol | La lista `tasks:` del playbook |
| `handlers/` | Carga los handlers que las tareas notifican | Nada todavía (la recarga se hace con `register`/`when`) |
| `templates/` | `ansible.builtin.template` busca aquí el `src:` | `templates/*.j2` |
| `files/` | `ansible.builtin.copy` busca aquí el `src:` | Nada: la release se copia desde `app/` del proyecto |
| `defaults/` | Variables con la prioridad más baja | El bloque `vars:` del play (`portal_puerto`, `portal_raiz`…) |
| `vars/` | Variables con prioridad alta | Nada |
| `meta/` | Información del rol y sus dependencias | Autor, plataforma Debian, `dependencies: []` |
| `tests/`, `README.md` | Ansible no los usa al ejecutar | Pensados para publicar el rol en Galaxy |

El `meta/main.yml` generado trae valores de ejemplo (`author: your name`, `min_ansible_version: 2.2`) que hay que
sustituir, y los `main.yml` vacíos llevan solo una cabecera de licencia y `---`. Un rol no necesita todas las
carpetas: las que no se usan se pueden borrar.

### 3. Dónde mira el rol cada variable: `defaults`

Para ver la diferencia entre `defaults/` y `vars/` basta con que el rol muestre `portal_version`. Se cambia de
forma temporal `tasks/main.yml` del esqueleto por una sola tarea:

```yaml
# proyecto/roles/portal/tasks/main.yml (temporal, solo para la demo)
- name: Mostrar la versión que ve el rol
  ansible.builtin.debug:
    var: portal_version
```

Se pone un valor reconocible en los defaults del rol:

```yaml
# proyecto/roles/portal/defaults/main.yml (temporal)
portal_version: "0.0.0-defaults"
```

Y un playbook mínimo que aplica el rol, `precedencia.yml`:

```yaml
# proyecto/precedencia.yml
- name: Qué valor de portal_version ve el rol
  hosts: web
  gather_facts: false
  roles:
    - portal
```

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook precedencia.yml
```

```text
TASK [portal : Mostrar la versión que ve el rol] *******************************
ok: [dev-web1] => {
    "portal_version": "1.1.0"
}
```

El rol no ve `0.0.0-defaults` sino `1.1.0`, el valor de `inventories/dev/group_vars/all.yml`. Un default solo se
usa cuando nadie más da valor a la variable. El nombre de la tarea aparece como `portal : …`: Ansible antepone el
rol del que viene.

Con `-e` el valor de la línea de comandos gana a todo:

```bash
ansible-playbook precedencia.yml -e portal_version=2.0.0
```

```text
ok: [dev-web1] => {
    "portal_version": "2.0.0"
}
```

### 4. Dónde mira el rol cada variable: `vars`

Ahora el mismo valor se escribe en `vars/main.yml` del rol:

```yaml
# proyecto/roles/portal/vars/main.yml (temporal)
portal_version: "0.0.0-vars"
```

```bash
ansible-playbook precedencia.yml
```

```text
TASK [portal : Mostrar la versión que ve el rol] *******************************
ok: [dev-web1] => {
    "portal_version": "0.0.0-vars"
}
```

Esta vez el valor del rol pisa el `group_vars` de dev. Si el rol del portal guardara la versión en `vars/`, dev,
pre y prod desplegarían siempre la misma, digan lo que digan sus inventarios. Solo `-e` sigue ganando:

```bash
ansible-playbook precedencia.yml -e portal_version=2.0.0
```

```text
ok: [dev-web1] => {
    "portal_version": "2.0.0"
}
```

| Dónde está `portal_version` | Qué ve el rol en dev | Para qué sirve ese sitio |
|-----------------------------|----------------------|--------------------------|
| Solo en `defaults/main.yml` del rol | `1.1.0` (gana `group_vars`) | Lo configurable: valores razonables que cada entorno puede cambiar |
| En `vars/main.yml` del rol | `0.0.0-vars` (pierde `group_vars`) | Constantes internas del rol que nadie debería tocar |
| Cualquiera de los dos + `-e` | `2.0.0` | Cambios puntuales desde la línea de comandos |

La demo deja el proyecto con un rol de prueba; para volver al punto de partida:

```bash
rm -rf roles precedencia.yml
```

### 5. Cómo queda el proyecto con roles

Con el portal y el balanceador convertidos en roles, el proyecto se ordena así (es el estado `m06` de `partidas/`):

```text
proyecto/
├── ansible.cfg                  # inventory = inventories/dev/hosts.yml, roles_path = roles
├── app/releases/                # 1.0.0, 1.1.0, 1.2.0
├── inventories/
│   ├── dev/  hosts.yml  group_vars/all.yml
│   ├── pre/  hosts.yml  group_vars/all.yml
│   └── prod/ hosts.yml  group_vars/all.yml  host_vars/prod-web2.yml
├── roles/
│   ├── portal/      defaults/ meta/ tasks/ templates/
│   └── portal_lb/   defaults/ meta/ tasks/ templates/
├── web.yml                      # hosts: web, roles: [portal]
├── lb.yml                       # hosts: lb,  roles: [portal_lb]
└── site.yml                     # import_playbook: web.yml y lb.yml
```

Tres ideas sostienen esta forma:

- **Los inventarios dicen *dónde* y *con qué valores*; los roles dicen *cómo*.** El mismo rol sirve para los tres
  entornos.
- **Los playbooks quedan en la raíz** y son cortos: hosts, `become` y la lista de roles. `playbook_dir` apunta a la
  raíz, y desde ahí el rol encuentra `app/releases/`.
- **`site.yml` es la entrada única** que monta todo el portal; `web.yml` y `lb.yml` siguen sirviendo por separado.

## Qué queda visto

`ansible-galaxy role init` genera el esqueleto, cada carpeta del rol tiene un papel fijo, y `defaults/` es el sitio
de lo configurable porque el inventario lo pisa, mientras que `vars/` gana al inventario. La conversión real de
`portal.yml` en el rol `portal` se hace en el [Lab — Crear un rol reutilizable](01-lab-crear-rol.md), que se puede
seguir sin haber visto esta demostración.
