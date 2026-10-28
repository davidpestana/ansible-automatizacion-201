# Lab — Crear un rol reutilizable

[← Página anterior](00-estructura-de-un-rol.md) · [Siguiente página →](02-lab-reutilizar-rol.md)

Operaciones de Tienda Norte quiere que el despliegue del portal se pueda reutilizar: en el balanceador, en otros
entornos y en los despliegues por fases que vendrán. Con todo dentro de `portal.yml` eso obliga a copiar y pegar.
En este lab conviertes ese playbook en el rol `portal` y compruebas lo más importante de una refactorización:
que los nodos no notan nada.

### Objetivo

El rol `roles/portal` (tareas, plantillas, defaults y meta) y un `web.yml` que lo aplica, con `changed=0` sobre
`dev-web1`, que ya tenía el portal desplegado con `portal.yml`.

### Punto de partida

- Terminal del Codespace. Nodos levantados (`scripts/nodos.sh estado` da seis líneas `SSH ok`).
- Estado: `proyecto/` con `portal.yml`, `templates/*.j2` y `group_vars` por entorno, sin roles. El paso 1 lo carga.
- Nodos: da igual cómo estén; el paso 2 deja `dev-web1` con el portal desplegado por `portal.yml`.

### En qué consiste

Trabajas en el entorno dev (el inventario por defecto de `ansible.cfg`). Generas el esqueleto con
`ansible-galaxy`, mueves las plantillas, repartes el playbook entre `defaults/`, `tasks/main.yml`,
`tasks/desplegar.yml` y `meta/`, y escribes `web.yml`. No cambias ninguna tarea: solo de sitio. El balanceador
se convierte en rol en el [Lab — Reutilizar el rol](02-lab-reutilizar-rol.md).

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, raíz del repo
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m05
cd proyecto
```

**Por qué:** te deja `proyecto/` exactamente como lo dejó el M04, aunque no vengas de ahí.

**Resultado esperado:** el script termina con `Listo: proyecto/ en el punto de partida «m05» (lo anterior está en
proyecto.anterior/).` y `ls` muestra `ansible.cfg  app  inventories  portal.yml  templates`.

### 2 — Despliega el portal en dev con el playbook actual

**Acción:**

```bash
ansible-playbook portal.yml
```

**Por qué:** es la foto de referencia. Si después de convertirlo en rol el resultado es `changed=0`, el rol hace
exactamente lo mismo que el playbook.

**Resultado esperado:** si `dev-web1` estaba vacío, la primera vez lo instala todo:

```text
PLAY RECAP *********************************************************************
dev-web1                   : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Si ya tenía el portal, o al lanzarlo otra vez, nada cambia:

```text
PLAY RECAP *********************************************************************
dev-web1                   : ok=11   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

### 3 — Genera el esqueleto del rol

**Acción:**

```bash
ansible-galaxy role init --init-path roles portal
```

**Por qué:** crea `roles/portal/` con la estructura que Ansible reconoce. `roles/` es la carpeta que indica
`roles_path = roles` en `ansible.cfg`. El rol se llama `portal` porque sus variables ya se llaman `portal_*`, y
ansible-lint exige que las variables de un rol lleven su nombre como prefijo.

**Resultado esperado:**

```text
- Role portal was created successfully
```

### 4 — Quita lo que el rol no usa

**Acción:**

```bash
rm -rf roles/portal/{files,handlers,tests,vars,README.md}
```

**Por qué:** el portal no copia ficheros sueltos (la release viene de `app/`), aún no tiene handlers y no tiene
constantes internas. Carpetas vacías solo confunden a quien abra el rol.

**Resultado esperado:** `ls roles/portal` muestra `defaults  meta  tasks  templates`.

### 5 — Mueve las plantillas al rol

**Acción:**

```bash
mv templates/*.j2 roles/portal/templates/ && rmdir templates
```

**Por qué:** dentro de un rol, `ansible.builtin.template` busca el `src:` en `templates/` del propio rol. Las
tareas siguen diciendo `src: nginx.conf.j2`, sin ruta.

**Resultado esperado:**

```bash
find roles/portal | sort
```

```text
roles/portal
roles/portal/defaults
roles/portal/defaults/main.yml
roles/portal/meta
roles/portal/meta/main.yml
roles/portal/tasks
roles/portal/tasks/main.yml
roles/portal/templates
roles/portal/templates/estado.json.j2
roles/portal/templates/nginx.conf.j2
roles/portal/templates/portal.conf.j2
```

### 6 — Escribe los valores por defecto

**Acción:** sustituye todo el contenido de `roles/portal/defaults/main.yml` por:

```yaml
# proyecto/roles/portal/defaults/main.yml
portal_entorno: dev
portal_version: "1.0.0"
portal_color: "#2563eb"
portal_puerto: 80
portal_raiz: /srv/portal
portal_worker_connections: 768
portal_db_host: ""
```

**Por qué:** son las variables que usa el rol, con un valor razonable para cada una. Las cuatro últimas venían del
bloque `vars:` del play; las tres primeras las daba solo el inventario, y ahora el rol funciona aunque un
inventario no las defina. Al estar en `defaults`, los `group_vars` y `host_vars` de cada entorno las pisan.

**Resultado esperado:** el fichero tiene siete líneas, todas empiezan por `portal_`.

### 7 — Separa el despliegue de la release

**Acción:** crea `roles/portal/tasks/desplegar.yml` con las cuatro tareas de la release de `portal.yml`:

```yaml
# proyecto/roles/portal/tasks/desplegar.yml
- name: Crear la carpeta de la release
  ansible.builtin.file:
    path: "{{ portal_raiz }}/releases/{{ portal_version }}"
    state: directory
    mode: "0755"

- name: Copiar la release {{ portal_version }}
  ansible.builtin.copy:
    src: "{{ playbook_dir }}/app/releases/{{ portal_version }}/"
    dest: "{{ portal_raiz }}/releases/{{ portal_version }}/"
    mode: "0644"

- name: Apuntar current a la release {{ portal_version }}
  ansible.builtin.file:
    src: "{{ portal_raiz }}/releases/{{ portal_version }}"
    dest: "{{ portal_raiz }}/current"
    state: link

- name: Publicar el estado del nodo
  ansible.builtin.template:
    src: estado.json.j2
    dest: "{{ portal_raiz }}/releases/{{ portal_version }}/estado.json"
    mode: "0644"
```

**Por qué:** instalar nginx y desplegar una versión son dos cosas que cambian a ritmos distintos. Tenerlas en
ficheros separados permite reutilizar solo el despliegue más adelante. La copia sigue leyendo de
`{{ playbook_dir }}/app/`: las releases son del proyecto, no del rol, y los playbooks están en la raíz.

**Resultado esperado:** `ls roles/portal/tasks` muestra `desplegar.yml  main.yml`.

### 8 — Escribe las tareas principales

**Acción:** sustituye todo el contenido de `roles/portal/tasks/main.yml` por:

```yaml
# proyecto/roles/portal/tasks/main.yml
- name: Instalar nginx
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: true
    cache_valid_time: 3600

- name: Configurar nginx (nginx.conf)
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    mode: "0644"
    validate: nginx -t -c %s
  register: portal_nginx_conf

- name: Configurar el sitio del portal
  ansible.builtin.template:
    src: portal.conf.j2
    dest: /etc/nginx/sites-available/portal
    mode: "0644"
  register: portal_sitio_conf

- name: Activar el sitio del portal
  ansible.builtin.file:
    src: /etc/nginx/sites-available/portal
    dest: /etc/nginx/sites-enabled/portal
    state: link

- name: Quitar el sitio por defecto
  ansible.builtin.file:
    path: /etc/nginx/sites-enabled/default
    state: absent

- name: Desplegar la release
  ansible.builtin.import_tasks: desplegar.yml

- name: Arrancar nginx
  ansible.builtin.service:
    name: nginx
    state: started

- name: Recargar nginx si ha cambiado su configuración
  ansible.builtin.service:
    name: nginx
    state: reloaded
  when: portal_nginx_conf is changed or portal_sitio_conf is changed
```

**Por qué:** es la lista `tasks:` de `portal.yml` tal cual, sin `hosts`, `become` ni `vars`: eso es cosa del
playbook que aplica el rol. `ansible.builtin.import_tasks` inserta `desplegar.yml` en su sitio al leer el rol, así
que el orden de ejecución es el mismo que antes. Las variables registradas también llevan el prefijo `portal_`.

**Resultado esperado:** el fichero empieza por `- name: Instalar nginx`, sin ninguna línea `hosts:`.

### 9 — Describe el rol en `meta`

**Acción:** sustituye todo el contenido de `roles/portal/meta/main.yml` por:

```yaml
# proyecto/roles/portal/meta/main.yml
galaxy_info:
  author: Operaciones Tienda Norte
  description: Servidor web del portal de pedidos (nginx + release estática)
  license: MIT
  min_ansible_version: "2.18"
  platforms:
    - name: Debian
      versions: [trixie]
dependencies: []
```

**Por qué:** quien encuentre el rol sabe de quién es, para qué sirve y en qué sistema está probado (Debian 13,
*trixie*). `dependencies: []` dice que no necesita otro rol antes.

**Resultado esperado:** ningún valor de ejemplo del esqueleto (`your name`, `2.2`) queda en el fichero.

### 10 — Escribe el playbook que aplica el rol

**Acción:** crea `web.yml` en la raíz de `proyecto/`:

```yaml
# proyecto/web.yml
- name: Servidores web del portal
  hosts: web
  become: true
  roles:
    - portal
```

**Por qué:** el playbook se queda en lo que decide quien lo ejecuta: a qué grupo y con qué privilegios. El *cómo*
está en el rol.

**Resultado esperado:** `web.yml` tiene cinco líneas.

### 11 — Comprueba qué tareas ejecutará

**Acción:**

```bash
ansible-playbook web.yml --list-tasks
```

**Por qué:** antes de tocar el nodo, confirmas que Ansible encuentra el rol y que la lista es la de siempre.

**Resultado esperado:** las once tareas, con el prefijo `portal :`. `Desplegar la release` no aparece: el
`import_tasks` ya se ha sustituido por las cuatro tareas de `desplegar.yml`.

```text
playbook: web.yml

  play #1 (web): Servidores web del portal	TAGS: []
    tasks:
      portal : Instalar nginx	TAGS: []
      portal : Configurar nginx (nginx.conf)	TAGS: []
      portal : Configurar el sitio del portal	TAGS: []
      portal : Activar el sitio del portal	TAGS: []
      portal : Quitar el sitio por defecto	TAGS: []
      portal : Crear la carpeta de la release	TAGS: []
      portal : Copiar la release {{ portal_version }}	TAGS: []
      portal : Apuntar current a la release {{ portal_version }}	TAGS: []
      portal : Publicar el estado del nodo	TAGS: []
      portal : Arrancar nginx	TAGS: []
      portal : Recargar nginx si ha cambiado su configuración	TAGS: []
```

### 12 — Aplica el rol sobre dev

**Acción:**

```bash
ansible-playbook web.yml
```

**Por qué:** es la prueba de la refactorización. `dev-web1` ya está como lo dejó `portal.yml`; si el rol hace lo
mismo, no hay nada que cambiar.

**Resultado esperado:** todo `ok`, la recarga saltada y `changed=0`:

```text
TASK [portal : Copiar la release 1.1.0] ****************************************
ok: [dev-web1]
…
TASK [portal : Recargar nginx si ha cambiado su configuración] *****************
skipping: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=11   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

### 13 — Retira el playbook antiguo y comprueba el portal

**Acción:**

```bash
rm portal.yml
curl -s localhost:8081/estado.json
```

**Por qué:** `web.yml` y el rol sustituyen a `portal.yml`; dejar los dos invita a cambiar uno y olvidar el otro.

**Resultado esperado:** el portal de dev sigue sirviendo su estado:

```text
{
  "host": "dev-web1",
  "entorno": "dev",
  "version": "1.1.0",
  "color": "#2563eb",
  "db": ""
}
```

## Comprueba tu entendimiento

**El rol es idempotente**
Lanza otra vez `ansible-playbook web.yml`.
→ `dev-web1 : ok=11 changed=0 … skipped=1`.

**Las tareas vienen del rol**
Mira la salida del paso 12.
→ Cada tarea aparece como `TASK [portal : …]`.

**El inventario manda sobre los defaults**
El rol tiene `portal_version: "1.0.0"` en `defaults`, pero dev despliega otra cosa.
→ La tarea se llama `Copiar la release 1.1.0`: gana `inventories/dev/group_vars/all.yml`.

## Reto

### 1 — `prod-web2` y sus 2048 conexiones

`inventories/prod/host_vars/prod-web2.yml` define `portal_worker_connections: 2048`. Con `portal.yml`, ese valor no
llegaba nunca a `prod-web2`. ¿Por qué, y qué cambia con el rol? Compruébalo sin desplegar nada en prod.

<details>
<summary>Ver solución</summary>

En `portal.yml`, `portal_worker_connections: 768` estaba en el `vars:` del play, y las variables de play tienen más
prioridad que las de `host_vars`: el 768 tapaba al 2048. En el rol, el 768 está en `defaults`, la prioridad más
baja, así que ahora `host_vars` gana:

```bash
ansible -i inventories/prod/hosts.yml prod-web2 -m ansible.builtin.debug -a var=portal_worker_connections
```

```text
prod-web2 | SUCCESS => {
    "portal_worker_connections": 2048
}
```

Por eso, la primera vez que apliques el rol sobre un prod desplegado con `portal.yml`, `prod-web2` mostrará
`changed` en `Configurar nginx (nginx.conf)` y recargará nginx: es el valor que su `host_vars` pedía desde el
principio.

</details>

### 2 — ¿`defaults` o `vars`?

Un compañero propone mover `portal_version` a `roles/portal/vars/main.yml` «para que esté más protegida». ¿Qué
pasaría en dev, pre y prod?

<details>
<summary>Ver solución</summary>

`vars/` del rol gana a `group_vars`: los tres entornos desplegarían la misma versión, la del rol, y los
`group_vars` (dev 1.1.0, pre y prod 1.0.0) dejarían de tener efecto. Solo `-e` podría cambiarla. Lo que cada
entorno debe poder elegir va en `defaults/`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `[ERROR]: the role 'portal_web' was not found in …/proyecto/roles:…` con `Origin: …web.yml:5:7` | El nombre en `roles:` no coincide con la carpeta de `roles/` | Usa el nombre exacto de la carpeta: `- portal` |
| `Could not find or access 'nginx.conf.j2'` y una lista de rutas `Searched in:` | La plantilla no se ha movido a `roles/portal/templates/` | Repite el paso 5 y comprueba con `find roles/portal` |
| `[ERROR]: conflicting action statements: hosts, tasks` en `roles/portal/tasks/main.yml:1:3` | Has copiado el play entero (con `hosts:` y `tasks:`) en el fichero de tareas | `tasks/main.yml` solo lleva la lista de tareas, sin cabecera de play |
| `skipping: no hosts matched` y `No inventory was parsed` | Has lanzado `ansible-playbook` desde fuera de `proyecto/`, sin su `ansible.cfg` | `cd proyecto` y repite |
| `changed` en tareas de la release tras convertirlo en rol | El nodo tenía otra versión desplegada (por ejemplo, con `-e`) | Es correcto: el rol lo devuelve a la versión del inventario; una segunda ejecución da `changed=0` |
