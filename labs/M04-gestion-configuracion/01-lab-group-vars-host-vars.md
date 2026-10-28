# Lab — group_vars y host_vars

[← Página anterior](00-de-donde-sale-cada-valor.md) · [Siguiente página →](02-lab-plantillas-jinja2.md)

El `portal.yml` de Tienda Norte publica siempre la release `1.0.0` con el color azul de dev, da igual contra
qué entorno se lance. Para que dev pruebe la `1.1.0` y pre siga en la `1.0.0` con su ámbar, hoy habría que
tener un playbook por entorno. En este lab sacas esos valores del playbook a `group_vars/` y `host_vars/`,
uno por entorno, y el mismo playbook pasa a publicar en cada nodo lo que le toca.

### Objetivo

`inventories/{dev,pre,prod}/group_vars/all.yml` con la versión, el color y el entorno de cada uno,
`inventories/prod/host_vars/prod-web2.yml` con su excepción y un `portal.yml` sin valores escritos a mano,
aplicado en dev (`1.1.0`, `#2563eb`) y en pre (`1.0.0`, `#d97706`).

### Punto de partida

- Terminal del Codespace, en la raíz del repositorio. El paso 1 deja `proyecto/` en el estado `m04`: los tres
  inventarios con `vars: portal_entorno` y el `portal.yml` del módulo anterior con los valores escritos dentro.
- Nodos recién creados, sin nginx ni portal (`--limpio`).
- No hace falta nada de páginas anteriores.

### En qué consiste

Creas los ficheros de variables de cada entorno, quitas las variables de los `hosts.yml`, compruebas con
`ansible-inventory` y `debug` qué recibe cada nodo, cambias los valores fijos de `portal.yml` por variables y
lo aplicas en pre y en dev. No tocas todavía las plantillas ni prod: eso llega en los labs siguientes.

### 1 — Carga el punto de partida

**Acción:**

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m04 --limpio
cd proyecto
```

**Por qué:** recrea los seis nodos vacíos y te deja el proyecto tal como empieza el módulo, sin depender de lo
que hicieras antes.

**Resultado esperado:** la salida acaba en `Listo: proyecto/ en el punto de partida «m04»` y, antes, seis
líneas `<nodo>  SSH ok`.

### 2 — Lanza el playbook actual contra pre

**Acción:**

```bash
ansible-playbook -i inventories/pre/hosts.yml portal.yml
curl -s localhost:8082/estado.json
```

**Por qué:** antes de cambiar nada, comprueba el problema: el playbook no sabe nada de pre más allá del
nombre del entorno.

**Resultado esperado:** el playbook termina sin fallos y el estado de pre sale con el color de dev:

```text
PLAY RECAP *********************************************************************
pre-web1                   : ok=11   changed=10   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

```text
{"host": "pre-web1", "entorno": "pre", "version": "1.0.0", "color": "#2563eb", "db": ""}
```

`#2563eb` es el azul de dev; pre debería ser `#d97706`.

### 3 — Crea los group_vars de cada entorno

**Acción:** crea tres ficheros nuevos (en VS Code o con el editor que prefieras), uno por entorno:

```yaml
# inventories/dev/group_vars/all.yml
portal_entorno: dev
portal_color: "#2563eb"
portal_version: "1.1.0"
```

```yaml
# inventories/pre/group_vars/all.yml
portal_entorno: pre
portal_color: "#d97706"
portal_version: "1.0.0"
```

```yaml
# inventories/prod/group_vars/all.yml
portal_entorno: prod
portal_color: "#15803d"
portal_version: "1.0.0"
```

**Por qué:** `group_vars/all.yml` junto a cada `hosts.yml` es lo que comparte todo el entorno. Dev prueba la
`1.1.0`; pre y prod siguen en la `1.0.0`.

> [!WARNING]
> Pon el color **entre comillas**. Sin ellas, YAML lee `#2563eb` como un comentario y la variable queda vacía.

**Resultado esperado:** `ls inventories/*/group_vars` muestra un `all.yml` en cada entorno.

### 4 — Crea la excepción de prod-web2

**Acción:** crea `inventories/prod/host_vars/prod-web2.yml`:

```yaml
# inventories/prod/host_vars/prod-web2.yml
portal_worker_connections: 2048
```

**Por qué:** `prod-web2` es la máquina con más capacidad de prod y el equipo quiere que nginx acepte en ella
más conexiones por proceso (`worker_connections`). Hoy no lo usa ninguna tarea: lo leerá la plantilla de
`nginx.conf` en el [Lab — Facts](03-lab-facts.md).
Es un dato de **un solo nodo**: va en `host_vars/` con el nombre exacto del nodo, no en el playbook ni en el
`all.yml` de prod.

**Resultado esperado:** el fichero existe en `inventories/prod/host_vars/`.

### 5 — Quita las variables de los hosts.yml

**Acción:** en los tres `inventories/<entorno>/hosts.yml`, borra las dos últimas líneas (`vars:` y
`portal_entorno: …`). El de dev queda así:

```yaml
# inventories/dev/hosts.yml
all:
  children:
    web:
      hosts:
        dev-web1:
```

**Por qué:** `portal_entorno` ya está en `group_vars/all.yml`. Si se queda también en `hosts.yml`, hay dos
sitios para el mismo dato y el siguiente que lo cambie tocará el que no gana. El inventario queda para
describir nodos y grupos; los datos, en `group_vars/` y `host_vars/`.

**Resultado esperado:** `grep -r portal_entorno inventories/*/hosts.yml` no devuelve nada.

### 6 — Comprueba qué recibe cada nodo

**Acción:**

```bash
ansible-inventory --host dev-web1
ansible-inventory -i inventories/prod/hosts.yml --host prod-web1
ansible-inventory -i inventories/prod/hosts.yml --host prod-web2
```

**Por qué:** `ansible-inventory --host` mezcla inventario, `group_vars` y `host_vars` igual que lo hará el
playbook, sin conectarse al nodo. Sin `-i` usa el inventario de `ansible.cfg`, que es el de dev.

**Resultado esperado:**

```text
{
    "portal_color": "#2563eb",
    "portal_entorno": "dev",
    "portal_version": "1.1.0"
}
```

```text
{
    "portal_color": "#15803d",
    "portal_entorno": "prod",
    "portal_version": "1.0.0"
}
```

```text
{
    "portal_color": "#15803d",
    "portal_entorno": "prod",
    "portal_version": "1.0.0",
    "portal_worker_connections": 2048
}
```

Los dos nodos web de prod comparten todo; `prod-web2` añade su `portal_worker_connections`.

### 7 — Cambia los valores fijos de portal.yml por variables

**Acción:** en `portal.yml`, sustituye cada `1.0.0` por `{{ portal_version }}` y `#2563eb` por
`{{ portal_color }}`. Las cinco últimas tareas antes de **Arrancar nginx** quedan así:

```yaml
# portal.yml (tareas de la release)
    - name: Crear la carpeta de la release
      ansible.builtin.file:
        path: "/srv/portal/releases/{{ portal_version }}"
        state: directory
        mode: "0755"

    - name: Copiar la release {{ portal_version }}
      ansible.builtin.copy:
        src: "{{ playbook_dir }}/app/releases/{{ portal_version }}/"
        dest: "/srv/portal/releases/{{ portal_version }}/"
        mode: "0644"

    - name: Apuntar current a la release {{ portal_version }}
      ansible.builtin.file:
        src: "/srv/portal/releases/{{ portal_version }}"
        dest: /srv/portal/current
        state: link

    - name: Publicar el estado del nodo
      ansible.builtin.copy:
        dest: "/srv/portal/releases/{{ portal_version }}/estado.json"
        content: |
          {"host": "{{ inventory_hostname }}", "entorno": "{{ portal_entorno }}", "version": "{{ portal_version }}", "color": "{{ portal_color }}", "db": ""}
        mode: "0644"
```

**Por qué:** el playbook se queda con la lógica (qué hacer) y el inventario con los datos (con qué valores).
Las rutas van entre comillas porque empiezan o terminan con `{{ }}`: si un valor YAML empieza por `{`, YAML lo
toma por un diccionario. `{{ playbook_dir }}` es la carpeta de `portal.yml`: la ruta de la release ya no depende
de desde dónde se busque el fichero.

**Resultado esperado:** `ansible-playbook portal.yml --syntax-check` responde `playbook: portal.yml` y
`grep -c 1.0.0 portal.yml` devuelve `0`.

### 8 — Mira los valores de cada entorno con debug

**Acción:**

```bash
ansible web -m ansible.builtin.debug -a "msg='{{ portal_entorno }} {{ portal_version }} {{ portal_color }}'"
ansible web -i inventories/pre/hosts.yml -m ansible.builtin.debug -a "msg='{{ portal_entorno }} {{ portal_version }} {{ portal_color }}'"
ansible web -i inventories/prod/hosts.yml -m ansible.builtin.debug -a "msg='{{ portal_entorno }} {{ portal_version }} {{ portal_color }}'"
```

**Por qué:** `debug` resuelve las mismas expresiones que usa el playbook, sin cambiar nada en los nodos. Es
la forma rápida de saber qué va a publicar cada uno antes de lanzar `portal.yml`.

**Resultado esperado:**

```text
dev-web1 | SUCCESS => {
    "msg": "dev 1.1.0 #2563eb"
}
pre-web1 | SUCCESS => {
    "msg": "pre 1.0.0 #d97706"
}
prod-web1 | SUCCESS => {
    "msg": "prod 1.0.0 #15803d"
}
prod-web2 | SUCCESS => {
    "msg": "prod 1.0.0 #15803d"
}
```

### 9 — Aplica en pre

**Acción:**

```bash
ansible-playbook -i inventories/pre/hosts.yml portal.yml
curl -s localhost:8082/estado.json
```

**Por qué:** pre ya tiene nginx y la `1.0.0` del paso 2; lo único que debe cambiar es el color del estado.

**Resultado esperado:** una sola tarea cambia y la recarga se salta, porque el sitio no ha cambiado:

```text
TASK [Publicar el estado del nodo] *********************************************
changed: [pre-web1]

TASK [Arrancar nginx] **********************************************************
ok: [pre-web1]

TASK [Recargar nginx si ha cambiado el sitio] **********************************
skipping: [pre-web1]

PLAY RECAP *********************************************************************
pre-web1                   : ok=10   changed=1    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

```text
{"host": "pre-web1", "entorno": "pre", "version": "1.0.0", "color": "#d97706", "db": ""}
```

### 10 — Aplica en dev

**Acción:**

```bash
ansible-playbook portal.yml
curl -s localhost:8081/estado.json
```

**Por qué:** sin `-i` el playbook va a dev, que estaba vacío. Con los mismos ficheros recibe otra versión.

**Resultado esperado:** los nombres de las tareas ya dicen la versión de dev, y el estado la confirma:

```text
TASK [Copiar la release 1.1.0] *************************************************
changed: [dev-web1]

TASK [Apuntar current a la release 1.1.0] **************************************
changed: [dev-web1]
…
PLAY RECAP *********************************************************************
dev-web1                   : ok=11   changed=10   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

```text
{"host": "dev-web1", "entorno": "dev", "version": "1.1.0", "color": "#2563eb", "db": ""}
```

En la pestaña **Puertos**, el puerto 8081 muestra la página «Versión 1.1.0. Nuevo: seguimiento de pedidos.»
con la cabecera azul, y el 8082 la `1.0.0` en ámbar.

## Comprueba tu entendimiento

**Idempotencia con variables**
Vuelve a lanzar `ansible-playbook portal.yml`.
→ `dev-web1 : ok=10 changed=0 … skipped=1`: los valores salen de los ficheros, pero el resultado es el mismo.

**El inventario entero de prod con sus variables**
`ansible-inventory -i inventories/prod/hosts.yml --graph --vars`
→ Bajo `prod-web2` aparece `{portal_worker_connections = 2048}`; los otros tres nodos solo tienen `portal_color`, `portal_entorno` y `portal_version`.

**Los datos de pre solo valen para pre**
`ansible-inventory --host pre-web1`
→ `Could not match supplied host pattern, ignoring: pre-web1` y `You must pass a single valid host to --host parameter`: sin `-i inventories/pre/hosts.yml`, pre no existe.

## Reto

### 1 — Un color de prueba solo para dev-web1

El equipo de diseño quiere ver el portal de dev en morado (`#7c3aed`) sin tocar `inventories/dev/group_vars/all.yml`.
Hazlo y compruébalo con `curl`.

<details>
<summary>Ver solución</summary>

Crea `inventories/dev/host_vars/dev-web1.yml`:

```yaml
# inventories/dev/host_vars/dev-web1.yml
portal_color: "#7c3aed"
```

`ansible-inventory --host dev-web1` muestra `"portal_color": "#7c3aed"`, `ansible-playbook portal.yml` cambia solo
**Publicar el estado del nodo** y `curl -s localhost:8081/estado.json` devuelve el nuevo color. Para quitarlo,
borra el fichero y vuelve a lanzar el playbook.

</details>

### 2 — Una versión puntual sin cambiar ficheros

Publica en pre la `1.1.0` para una prueba rápida, sin editar ningún fichero del proyecto.

<details>
<summary>Ver solución</summary>

```bash
ansible-playbook -i inventories/pre/hosts.yml portal.yml -e portal_version=1.1.0
```

`-e` gana a `group_vars`. La siguiente ejecución sin `-e` vuelve a dejar `current` en la `1.0.0`: lo que no
está en un fichero no queda registrado en ningún sitio.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `ansible-inventory --host` muestra `"portal_color": null` | `portal_color: #d97706` sin comillas: YAML lo toma como comentario | `portal_color: "#d97706"` |
| `'portal_version' is undefined` | El fichero se llama `group_var/` o `all.yaml` en otra carpeta, o no está junto al `hosts.yml` que usas | La ruta exacta es `inventories/<entorno>/group_vars/all.yml` |
| `prod-web2` no recibe `2048` | El fichero no se llama igual que el nodo (`prod_web2.yml`, `prod-web2.yaml` en `group_vars/`) | `inventories/prod/host_vars/prod-web2.yml` |
| `YAML parsing failed: This may be an issue with missing quotes around a template block.` | Un valor que empieza por `{{` sin comillas | Entrecomilla el valor: `path: "{{ … }}"` |
| Pre publica la versión de dev | Lanzaste sin `-i inventories/pre/hosts.yml` y fue a dev | Comprueba el `PLAY RECAP`: debe salir `pre-web1` |
