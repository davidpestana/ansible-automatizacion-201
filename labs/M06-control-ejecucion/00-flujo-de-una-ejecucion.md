# El flujo de una ejecución

[← Página anterior](README.md) · [Siguiente página →](01-lab-condicionales-y-bucles.md)

El equipo de operaciones de Tienda Norte quiere tres cosas a la vez en los servidores web del portal: tener `jq` y
`tree` a mano para diagnosticar, que nginx deje de anunciar su versión exacta en cada respuesta y que las respuestas
de producción lleven una cabecera que diga que son de producción. Esta demostración recorre un único playbook,
`flujo.yml`, que lo hace con un bucle, una condición y un handler, y mira en la salida de `ansible-playbook` en qué
orden ocurre cada cosa y cuántas veces.

## Punto de partida

- Terminal del Codespace, en la raíz del repositorio:

  ```bash
  cd "$CODESPACE_VSCODE_FOLDER"
  scripts/partida.sh m06-00
  cd proyecto
  ```

- Estado: `proyecto/` con los roles `portal` y `portal_lb` del curso y un playbook nuevo, `flujo.yml`.
  La preparación aplica `web.yml` en `dev-web1` y en `prod-web1`/`prod-web2`, así que los tres tienen nginx y el
  portal publicado. Al terminar, el script muestra los `PLAY RECAP` de esas dos ejecuciones y
  `Listo: proyecto/ en el punto de partida «m06-00»`.
- Comprobación previa: `curl -sI localhost:8083` devuelve `Server: nginx/1.26.3`, con la versión.

## Recorrido

### 1 — El playbook

```yaml
# proyecto/flujo.yml
- name: Flujo de una ejecución en los web del portal
  hosts: web
  become: true
  vars:
    flujo_utilidades:
      - jq
      - tree
  tasks:
    - name: Instalar utilidades de operaciones
      ansible.builtin.apt:
        name: "{{ item }}"
        state: present
        update_cache: true
        cache_valid_time: 3600
      loop: "{{ flujo_utilidades }}"

    - name: Ocultar la versión de nginx en las respuestas
      ansible.builtin.copy:
        dest: /etc/nginx/sites-enabled/00-seguridad.conf
        content: "server_tokens off;\n"
        mode: "0644"
      notify: Recargar nginx

    - name: Marcar las respuestas de producción
      ansible.builtin.copy:
        dest: /etc/nginx/sites-enabled/00-entorno.conf
        content: "add_header X-Entorno {{ portal_entorno }} always;\n"
        mode: "0644"
      when: portal_entorno == 'prod'
      notify: Recargar nginx

    - name: Comprobar que nginx sigue respondiendo
      ansible.builtin.uri:
        url: http://localhost/

  handlers:
    - name: Recargar nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

Cuatro piezas de control en un mismo play:

| Pieza | Dónde | Qué decide |
|-------|-------|------------|
| `loop` | Instalar utilidades | La tarea se repite una vez por elemento de `flujo_utilidades`; `item` es el elemento en curso |
| `notify` | Las dos copias de ficheros | Si la tarea da `changed`, deja pendiente el handler `Recargar nginx` |
| `when` | Marcar las respuestas de producción | Solo corre en nodos con `portal_entorno == 'prod'` (viene de `inventories/prod/group_vars/all.yml`) |
| `handlers` | Al final del play | `Recargar nginx` corre al final, una vez por nodo, solo si alguien lo ha notificado |

Los dos ficheros van en `sites-enabled/` porque el `nginx.conf` del rol solo incluye esa carpeta dentro de `http { }`,
y ahí `server_tokens` y `add_header` valen para todo el servidor.

> [!NOTE]
> `ansible.builtin.apt` acepta una lista en `name:` y la instala en una sola operación, que es más rápido. El bucle
> está aquí para ver `loop` en acción con algo conocido: cada elemento aparece en su propia línea de la salida.

### 2 — Primera ejecución en producción

```bash
ansible-playbook -i inventories/prod/hosts.yml flujo.yml
```

```text
TASK [Instalar utilidades de operaciones] **************************************
changed: [prod-web1] => (item=jq)
changed: [prod-web2] => (item=jq)
changed: [prod-web1] => (item=tree)
changed: [prod-web2] => (item=tree)

TASK [Ocultar la versión de nginx en las respuestas] ***************************
changed: [prod-web2]
changed: [prod-web1]

TASK [Marcar las respuestas de producción] *************************************
changed: [prod-web2]
changed: [prod-web1]

TASK [Comprobar que nginx sigue respondiendo] **********************************
ok: [prod-web2]
ok: [prod-web1]

RUNNING HANDLER [Recargar nginx] ***********************************************
changed: [prod-web1]
changed: [prod-web2]

PLAY RECAP *********************************************************************
prod-web1                  : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Lo que cuenta la salida:

- El bucle produce una línea por nodo y por elemento: `(item=jq)` y `(item=tree)`.
- Dos tareas han notificado `Recargar nginx` en cada nodo, pero `RUNNING HANDLER` aparece **una sola vez**.
- El handler corre **después** de `Comprobar que nginx sigue respondiendo`: los handlers esperan al final del play,
  no se ejecutan en el momento en que se notifican.

### 3 — El efecto en las respuestas

```bash
curl -sI localhost:8083
```

```text
HTTP/1.1 200 OK
Server: nginx
…
X-Entorno: prod
Accept-Ranges: bytes
```

`Server` ya no lleva la versión y aparece `X-Entorno: prod`. Sin la recarga del handler, nginx seguiría con la
configuración anterior aunque los ficheros estuvieran en disco.

### 4 — Segunda ejecución: nada cambia, nada se recarga

```bash
ansible-playbook -i inventories/prod/hosts.yml flujo.yml
```

```text
TASK [Marcar las respuestas de producción] *************************************
ok: [prod-web2]
ok: [prod-web1]

TASK [Comprobar que nginx sigue respondiendo] **********************************
ok: [prod-web2]
ok: [prod-web1]

PLAY RECAP *********************************************************************
prod-web1                  : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Ninguna copia da `changed`, así que nadie notifica y el bloque `RUNNING HANDLER` ni siquiera aparece. Son
`ok=5` y no 6 porque el handler no ha corrido.

### 5 — El mismo playbook en dev

Sin `-i`, `ansible.cfg` usa el inventario de dev:

```bash
ansible-playbook flujo.yml
```

```text
TASK [Instalar utilidades de operaciones] **************************************
changed: [dev-web1] => (item=jq)
changed: [dev-web1] => (item=tree)

TASK [Ocultar la versión de nginx en las respuestas] ***************************
changed: [dev-web1]

TASK [Marcar las respuestas de producción] *************************************
skipping: [dev-web1]

TASK [Comprobar que nginx sigue respondiendo] **********************************
ok: [dev-web1]

RUNNING HANDLER [Recargar nginx] ***********************************************
changed: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=5    changed=3    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

En `dev-web1`, `portal_entorno` vale `dev`: la tarea de producción sale como `skipping` y cuenta en `skipped=1`.
El handler corre igualmente, porque la otra tarea sí lo ha notificado. `curl -sI localhost:8081` muestra
`Server: nginx` y ninguna cabecera `X-Entorno`.

## Qué queda visto

- `loop` repite una tarea por elemento y la salida lo muestra con `(item=…)`.
- `when` decide por nodo con variables del inventario; lo que no cumple sale como `skipping`.
- `notify` deja un handler pendiente solo si la tarea cambia algo; el handler corre al final, una vez por nodo,
  aunque lo notifiquen varias tareas.

Cada pieza se practica por separado, y cada laboratorio se hace sin haber seguido esta demostración:
[Lab — Lógica condicional](01-lab-condicionales-y-bucles.md) (`when` y `loop`),
[Lab — Handlers](02-lab-handlers.md), [Lab — Tags](03-lab-tags.md) y
[Lab — Registro de resultados](04-lab-registro-de-resultados.md).
