# Lab — Plantillas Jinja2

[← Página anterior](01-lab-group-vars-host-vars.md) · [Siguiente página →](03-lab-facts.md)

Los valores del portal de Tienda Norte ya salen de `group_vars/`, pero la configuración del sitio de nginx sigue
siendo un fichero fijo (`files/portal.conf`) y el `estado.json` se escribe como una línea dentro de una tarea.
En cuanto un nodo necesita algo distinto, eso no escala. En este lab conviertes los dos en plantillas Jinja2
que se rellenan con las variables de cada nodo, y revisas el cambio con `--check --diff` antes de aplicarlo.

### Objetivo

`templates/portal.conf.j2` y `templates/estado.json.j2` desplegados con `ansible.builtin.template` en
`dev-web1`, con el nombre del nodo en `portal.conf` y un `estado.json` legible, y los filtros `upper` y
`default` probados sobre las variables del portal.

### Punto de partida

- Terminal del Codespace, en la raíz del repositorio. El paso 1 carga el estado `m04-02`: `group_vars/all.yml`
  por entorno, `host_vars/prod-web2.yml` y un `portal.yml` que usa `portal_version` y `portal_color`, pero
  todavía copia `files/portal.conf` y escribe `estado.json` con `copy`.
- `dev-web1` con nginx y la release `1.1.0` publicada por ese `portal.yml`; el resto de nodos, vacíos.
- No hace falta nada de páginas anteriores.

### En qué consiste

Añades al play tres constantes (`portal_puerto`, `portal_raiz`, `portal_db_host`), escribes las dos plantillas, cambias las
tareas de `copy` a `template`, ensayas con `--check --diff` y aplicas en dev. No tocas todavía `nginx.conf`
(eso es del [Lab — Facts](03-lab-facts.md)).

### 1 — Carga el punto de partida

**Acción:**

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m04-02 --limpio
cd proyecto
curl -s localhost:8081/estado.json
```

**Por qué:** recrea los nodos y aplica en dev el playbook de partida, para que el `--diff` del paso 6 compare
contra un nodo conocido.

**Resultado esperado:** `partida.sh` muestra `Preparando los nodos para m04-02…` y el resumen
`dev-web1 : ok=11 changed=10`. El estado actual es una sola línea:

```text
{"host": "dev-web1", "entorno": "dev", "version": "1.1.0", "color": "#2563eb", "db": ""}
```

### 2 — Añade las constantes del play

**Acción:** en `portal.yml`, debajo de `become: true`, añade un bloque `vars:`:

```yaml
# portal.yml (cabecera del play)
- name: Portal de pedidos en los servidores web
  hosts: web
  become: true
  vars:
    portal_puerto: 80
    portal_raiz: /srv/portal
    portal_db_host: ""
```

**Por qué:** el puerto interno de nginx y la carpeta del portal son iguales en dev, pre y prod. No son datos de
un entorno, son decisiones del playbook: su sitio es el play. `portal_db_host` es la base de datos a la que
apunta el portal: de momento ninguna, así que vale `""`. Lo que cambia por entorno sigue en `group_vars/`.

**Resultado esperado:** `ansible-playbook portal.yml --syntax-check` responde `playbook: portal.yml`.

### 3 — Escribe la plantilla del sitio

**Acción:** crea la carpeta `templates/` y, dentro, `portal.conf.j2`:

```jinja
# templates/portal.conf.j2
# {{ ansible_managed }}
server {
    listen {{ portal_puerto }} default_server;
    server_name {{ inventory_hostname }};
    root {{ portal_raiz }}/current;
    index index.html;
}
```

La primera línea (`# templates/portal.conf.j2`) es solo la referencia de la ruta: no la copies en el fichero.

**Por qué:** `{{ ansible_managed }}` deja un aviso de que el fichero lo gestiona Ansible y no se edita a mano
en el nodo. `inventory_hostname` es el nombre del nodo en el inventario, distinto en cada uno: cada web de prod
recibirá su propio `server_name`.

**Resultado esperado:** existe `templates/portal.conf.j2`. `ansible.builtin.template` busca las plantillas en
`templates/` junto al playbook, así que en la tarea basta con el nombre.

### 4 — Escribe la plantilla del estado

**Acción:** crea `templates/estado.json.j2`:

```jinja
# templates/estado.json.j2
{
  "host": "{{ inventory_hostname }}",
  "entorno": "{{ portal_entorno }}",
  "version": "{{ portal_version }}",
  "color": "{{ portal_color }}",
  "db": "{{ portal_db_host }}"
}
```

(Igual que antes, sin la primera línea de comentario: un JSON no admite comentarios.)

**Por qué:** es el mismo contenido que escribía la tarea `copy`, pero en un fichero que se lee y se cambia sin
tocar el playbook. Cada `{{ }}` se rellena con las variables del nodo: del inventario (`portal_entorno`,
`portal_version`, `portal_color`) y del play (`portal_db_host`).

**Resultado esperado:** existe `templates/estado.json.j2`.

### 5 — Cambia las tareas de copy a template

**Acción:** en `portal.yml`, sustituye la tarea **Configurar el sitio del portal** y la tarea **Publicar el
estado del nodo** por estas, y usa `portal_raiz` en las rutas de la release:

```yaml
# portal.yml (tareas que cambian)
    - name: Configurar el sitio del portal
      ansible.builtin.template:
        src: portal.conf.j2
        dest: /etc/nginx/sites-available/portal
        mode: "0644"
      register: portal_sitio_conf
…
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

Después borra el fichero fijo, que ya no usa nadie:

```bash
rm files/portal.conf
rmdir files
```

**Por qué:** `template` hace lo mismo que `copy`, pero renderiza el fichero en el nodo de control con las
variables de **cada nodo** antes de subirlo. El `register: portal_sitio_conf` se mantiene: si la plantilla
cambia el fichero, la última tarea recarga nginx.

**Resultado esperado:** `ansible-playbook portal.yml --syntax-check` responde `playbook: portal.yml`.

### 6 — Ensaya con --check --diff

**Acción:**

```bash
ansible-playbook portal.yml --check --diff
```

**Por qué:** `--check` no cambia nada en el nodo y `--diff` enseña, línea a línea, qué cambiaría en cada
fichero. Es lo que revisarías antes de aplicar una plantilla en prod.

**Resultado esperado:** dos diffs, uno por plantilla (la ruta del fichero temporal será otra en tu Codespace):

```text
TASK [Configurar el sitio del portal] ******************************************
--- before: /etc/nginx/sites-available/portal
+++ after: …/portal.conf.j2
@@ -1,5 +1,7 @@
+# Ansible managed
 server {
     listen 80 default_server;
+    server_name dev-web1;
     root /srv/portal/current;
     index index.html;
 }

changed: [dev-web1]
…
TASK [Publicar el estado del nodo] *********************************************
--- before: /srv/portal/releases/1.1.0/estado.json
+++ after: …/estado.json.j2
@@ -1 +1,7 @@
-{"host": "dev-web1", "entorno": "dev", "version": "1.1.0", "color": "#2563eb", "db": ""}
+{
+  "host": "dev-web1",
+  "entorno": "dev",
+  "version": "1.1.0",
+  "color": "#2563eb",
+  "db": ""
+}

changed: [dev-web1]
…
PLAY RECAP *********************************************************************
dev-web1                   : ok=11   changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

El tercer `changed` es **Recargar nginx si ha cambiado el sitio**: en modo check se da por hecha.

### 7 — Aplica y comprueba en el nodo

**Acción:**

```bash
ansible-playbook portal.yml
curl -s localhost:8081/estado.json
docker exec dev-web1 cat /etc/nginx/sites-available/portal
```

**Por qué:** ahora sí cambian los ficheros; `curl` y `docker exec` confirman lo que ha quedado en el nodo.

**Resultado esperado:** `dev-web1 : ok=11 changed=3`, y en el nodo:

```text
{
  "host": "dev-web1",
  "entorno": "dev",
  "version": "1.1.0",
  "color": "#2563eb",
  "db": ""
}
```

```text
# Ansible managed
server {
    listen 80 default_server;
    server_name dev-web1;
    root /srv/portal/current;
    index index.html;
}
```

## Comprueba tu entendimiento

**La plantilla es idempotente**
Vuelve a lanzar `ansible-playbook portal.yml`.
→ `dev-web1 : ok=10 changed=0 … skipped=1`: el fichero renderizado es igual al del nodo y la recarga se salta.

**La plantilla usa los valores de la ejecución**
`ansible-playbook portal.yml --check --diff -e portal_db_host=prod-db1`
→ En **Publicar el estado del nodo**, el diff cambia `-  "db": ""` por `+  "db": "prod-db1"`: `-e` gana a las `vars:` del play. Sin `-e`, vuelve a `""`.

**Filtros: upper y default**
`ansible dev-web1 -m ansible.builtin.debug -a "msg='{{ portal_entorno | upper }} {{ portal_db_host | default(\"sin base de datos\") }}'"`
→ `"msg": "DEV sin base de datos"`. En un comando ad hoc no existen las `vars:` del play, así que `portal_db_host` no está definida y entra el `default`; `upper` pasa `dev` a mayúsculas. Los dos filtros se escriben igual dentro de una plantilla.

**Una variable sin definir**
`ansible dev-web1 -m ansible.builtin.debug -a "msg={{ portal_db_host }}"`
→ `FAILED!` con `'portal_db_host' is undefined`: lo que pasaría en `estado.json.j2` si quitaras `portal_db_host` del play.

## Reto

### 1 — Un bucle para el balanceador

El balanceador `prod-lb1` necesitará un bloque `upstream` con un `server` por cada nodo del grupo `web` de prod.
Escribe `templates/upstream.conf.j2` con un bucle `{% for %}` sobre `groups['web']` y comprueba qué generaría en
`prod-lb1`, en `/tmp/upstream-portal.conf`, sin cambiar nada.

<details>
<summary>Ver solución</summary>

```jinja
# templates/upstream.conf.j2
# {{ ansible_managed }}
upstream portal {
{% for servidor in groups['web'] %}
    server {{ servidor }}:80;
{% endfor %}
}
```

```bash
ansible prod-lb1 -i inventories/prod/hosts.yml -m ansible.builtin.template -a "src=templates/upstream.conf.j2 dest=/tmp/upstream-portal.conf" --check --diff
```

```text
--- before
+++ after: …/upstream.conf.j2
@@ -0,0 +1,5 @@
+# Ansible managed
+upstream portal {
+    server prod-web1:80;
+    server prod-web2:80;
+}

prod-lb1 | CHANGED => {
    "changed": true
}
```

`groups['web']` es la lista de nodos del grupo en el inventario que usas: si mañana se añade `prod-web3` al
`hosts.yml` de prod, la plantilla lo incluye sin tocarla.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `Could not find or access 'portal.conf.j2'` | La plantilla no está en `templates/` junto a `portal.yml` | `ls templates/` desde `proyecto/` |
| `'portal_raiz' is undefined` | El bloque `vars:` está mal indentado o dentro de `tasks:` | `vars:` al mismo nivel que `hosts:` y `tasks:` |
| `'portal_db_host' is undefined` | Falta `portal_db_host: ""` en `vars:` del play | Añádelo, o usa `{{ portal_db_host \| default('') }}` en la plantilla |
| `curl` a `estado.json` devuelve JSON roto | La línea de comentario con la ruta se copió dentro de `estado.json.j2` | El fichero empieza por `{` |
| `--check --diff` no enseña nada en una tarea | La tarea no cambia el fichero (el contenido ya coincide) | Es lo esperado: solo hay diff si hay cambio |
