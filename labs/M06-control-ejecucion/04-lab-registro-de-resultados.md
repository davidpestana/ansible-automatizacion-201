# Lab — Registro de resultados

[← Página anterior](03-lab-tags.md) · [Siguiente página →](../M07-despliegues/README.md)

El último paso del runbook de Tienda Norte era «comprueba que el nodo sirve la versión que toca»: entrar por SSH,
lanzar `nginx -v`, pedir `estado.json` y mirar el número a ojo. En este lab lo conviertes en un playbook,
`comprobar.yml`, que guarda la salida de cada comprobación con `register`, la usa para decidir la siguiente tarea y
falla él solo cuando la versión publicada no es la esperada.

### Objetivo

Un playbook `proyecto/comprobar.yml` que en `dev-web1` informa de la versión de nginx y de la release publicada sin
marcar nada como `changed`, falla si la release no coincide con `portal_version` y, en un nodo sin nginx, avisa en
lugar de fallar.

### Punto de partida

- Terminal del Codespace. El paso 1 recrea los nodos limpios e instala el portal solo en `dev-web1`, así `pre-web1`
  queda sin nginx para el paso 7.
- Estado: `proyecto/` tal como termina este módulo: roles `portal` (con el handler `Recargar nginx` y los tags
  `paquetes`, `config`, `despliegue`) y `portal_lb`. Es el punto de partida `m07`.

### En qué consiste

Escribes un playbook de solo lectura: no cambia nada en los nodos. Lo construyes en dos tandas: primero registras y
miras qué devuelve un comando; después añades la petición HTTP, la condición de fallo y las decisiones con `when`.

### 1 — Prepara el punto de partida

**Acción:**

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m07 --limpio
cd proyecto
ansible-playbook web.yml
```

**Por qué:** `--limpio` deja los seis nodos sin nada instalado; `web.yml` (inventario de dev) instala el portal solo
en `dev-web1`.

**Resultado esperado:** `dev-web1 … ok=12 changed=11 … failed=0`, y `curl -s localhost:8081/estado.json` devuelve el
JSON con `"version": "1.1.0"`.

### 2 — Registra la salida de `nginx -v`

**Acción:** crea `proyecto/comprobar.yml`:

```yaml
# proyecto/comprobar.yml
- name: Comprobar el portal en los servidores web
  hosts: web
  become: true
  tasks:
    - name: Consultar la versión de nginx
      ansible.builtin.command: nginx -v
      register: comprobar_nginx

    - name: Mostrar lo que ha devuelto
      ansible.builtin.debug:
        var: comprobar_nginx
```

**Por qué:** `register` guarda todo lo que devuelve el módulo en una variable del nodo. Antes de usarla hay que ver
qué campos trae. El prefijo `comprobar_` sigue la convención del curso para variables registradas.

**Resultado esperado:** `ansible-playbook comprobar.yml --syntax-check` responde `playbook: comprobar.yml`.

### 3 — Ejecútalo y lee la variable

**Acción:** `ansible-playbook comprobar.yml`

**Por qué:** el `debug` muestra la estructura completa del resultado.

**Resultado esperado:**

```text
TASK [Consultar la versión de nginx] *******************************************
changed: [dev-web1]

TASK [Mostrar lo que ha devuelto] **********************************************
ok: [dev-web1] => {
    "comprobar_nginx": {
        "changed": true,
        "cmd": [
            "nginx",
            "-v"
        ],
        …
        "rc": 0,
        …
        "stderr": "nginx version: nginx/1.26.3",
        "stderr_lines": [
            "nginx version: nginx/1.26.3"
        ],
        "stdout": "",
        "stdout_lines": []
    }
}

PLAY RECAP *********************************************************************
dev-web1                   : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Dos detalles: `nginx -v` escribe en `stderr`, no en `stdout`; y la tarea sale `changed` aunque no ha cambiado nada,
porque `ansible.builtin.command` no sabe qué hace el comando y siempre informa de cambio.

### 4 — Escribe la versión completa

**Acción:** sustituye `proyecto/comprobar.yml` por:

```yaml
# proyecto/comprobar.yml
- name: Comprobar el portal en los servidores web
  hosts: web
  become: true
  tasks:
    - name: Consultar la versión de nginx
      ansible.builtin.command: nginx -v
      register: comprobar_nginx
      changed_when: false
      failed_when: false

    - name: Avisar si nginx no está instalado
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} no tiene nginx: aplica web.yml antes de comprobar el portal"
      when: comprobar_nginx.rc != 0

    - name: Pedir el estado del portal
      ansible.builtin.uri:
        url: http://localhost/estado.json
        return_content: true
      register: comprobar_estado
      when: comprobar_nginx.rc == 0
      failed_when: comprobar_estado.json.version != portal_version

    - name: Mostrar la release publicada
      ansible.builtin.debug:
        msg: "{{ comprobar_nginx.stderr }} sirve la release {{ comprobar_estado.json.version }} ({{ comprobar_estado.json.entorno }})"
      when: comprobar_nginx.rc == 0
```

**Por qué:** cada línea nueva cambia cómo se interpreta un resultado:

| Línea | Qué hace |
|-------|----------|
| `changed_when: false` | Una consulta nunca es un cambio: el resumen dirá `changed=0` |
| `failed_when: false` | Si nginx no existe, el comando no para la ejecución; el resultado queda en `comprobar_nginx.rc` |
| `when: comprobar_nginx.rc …` | Las tareas siguientes deciden con lo que devolvió la primera |
| `failed_when: comprobar_estado.json.version != portal_version` | La petición HTTP responde 200, pero la tarea falla si la release no es la del inventario |

`ansible.builtin.uri` con `return_content: true` convierte la respuesta JSON en `comprobar_estado.json`, así que
`version` y `entorno` se leen como campos.

**Resultado esperado:** `--syntax-check` responde `playbook: comprobar.yml`.

### 5 — Comprueba dev

**Acción:** `ansible-playbook comprobar.yml`

**Por qué:** es el caso normal: nginx instalado y release correcta.

**Resultado esperado:**

```text
TASK [Consultar la versión de nginx] *******************************************
ok: [dev-web1]

TASK [Avisar si nginx no está instalado] ***************************************
skipping: [dev-web1]

TASK [Pedir el estado del portal] **********************************************
ok: [dev-web1]

TASK [Mostrar la release publicada] ********************************************
ok: [dev-web1] => {
    "msg": "nginx version: nginx/1.26.3 sirve la release 1.1.0 (dev)"
}

PLAY RECAP *********************************************************************
dev-web1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

`changed=0`: el playbook se puede lanzar cuantas veces haga falta sin ensuciar el resumen.

### 6 — Haz que falle a propósito

**Acción:** `ansible-playbook comprobar.yml -e portal_version=1.0.0`

**Por qué:** simula que el inventario espera la 1.0.0 y el nodo sirve otra cosa, el caso que la comprobación debe
cazar.

**Resultado esperado:**

```text
TASK [Pedir el estado del portal] **********************************************
[ERROR]: Task failed: Action failed: OK (101 bytes)
Origin: /workspaces/…/proyecto/comprobar.yml:17:7

15       when: comprobar_nginx.rc != 0
16
17     - name: Pedir el estado del portal
         ^ column 7

fatal: [dev-web1]: FAILED! => {… "failed_when_result": true, "json": {"color": "#2563eb", "db": "", "entorno": "dev", "host": "dev-web1", "version": "1.1.0"}, … "status": 200, "url": "http://localhost/estado.json"}

PLAY RECAP *********************************************************************
dev-web1                   : ok=2    changed=0    unreachable=0    failed=1    skipped=1    rescued=0    ignored=0
```

La respuesta HTTP fue buena (`status: 200`, `OK (101 bytes)`), pero `failed_when_result: true` dice que la tarea ha
fallado por tu condición. La última tarea ya no corre.

### 7 — Comprueba un nodo sin nginx

**Acción:** `ansible-playbook -i inventories/pre/hosts.yml comprobar.yml`

**Por qué:** `pre-web1` está limpio desde el paso 1. Sin `failed_when: false`, el playbook se pararía en la primera
tarea; con él, la decisión pasa a las siguientes.

**Resultado esperado:**

```text
TASK [Consultar la versión de nginx] *******************************************
ok: [pre-web1]

TASK [Avisar si nginx no está instalado] ***************************************
ok: [pre-web1] => {
    "msg": "pre-web1 no tiene nginx: aplica web.yml antes de comprobar el portal"
}

TASK [Pedir el estado del portal] **********************************************
skipping: [pre-web1]

TASK [Mostrar la release publicada] ********************************************
skipping: [pre-web1]

PLAY RECAP *********************************************************************
pre-web1                   : ok=3    changed=0    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
```

El mismo playbook ha seguido caminos distintos según el resultado registrado.

## Comprueba tu entendimiento

**Qué pasa sin `failed_when: false`**
`ansible -i inventories/pre/hosts.yml web -m ansible.builtin.command -a "nginx -v"`.
→ `pre-web1 | FAILED | rc=2 >>` y `Error executing command.`: es el fallo que `failed_when: false` convierte en un
dato (`rc` distinto de 0).

**Una consulta no es un cambio**
`ansible-playbook comprobar.yml` dos veces.
→ Las dos terminan con `changed=0`.

**La condición de fallo es tuya**
`ansible-playbook comprobar.yml -e portal_version=1.1.0`.
→ Pasa sin fallos: la versión publicada y la esperada coinciden.

## Reto

### 1 — Comprobar también el contenido

Añade una tarea que pida `http://localhost/` y falle si la página no contiene `Tienda Norte`. Pruébala en dev.

<details>
<summary>Ver solución</summary>

```yaml
    - name: Comprobar la portada
      ansible.builtin.uri:
        url: http://localhost/
        return_content: true
      register: comprobar_portada
      when: comprobar_nginx.rc == 0
      failed_when: "'Tienda Norte' not in comprobar_portada.content"
```

`ansible-playbook comprobar.yml` sigue terminando con `failed=0`. Con una palabra que no esté en la portada
(cambia `'Tienda Norte'` por `'Tienda Sur'`), la tarea falla con `failed_when_result: true`.

</details>

### 2 — Todo prod de un vistazo

Lanza la comprobación sobre prod después de instalar el portal allí. ¿Qué versión debe salir en cada nodo y por qué?

<details>
<summary>Ver solución</summary>

`ansible-playbook -i inventories/prod/hosts.yml web.yml` y después
`ansible-playbook -i inventories/prod/hosts.yml comprobar.yml`. Los dos web dicen
`sirve la release 1.0.0 (prod)`, porque `inventories/prod/group_vars/all.yml` fija `portal_version: "1.0.0"`.
`prod-lb1` y `prod-db1` no aparecen: el play es `hosts: web`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `has no attribute 'json'` en `Mostrar la release publicada` | La petición se saltó (o no devolvió JSON) y la tarea siguiente no tiene el mismo `when` | Repite en `Mostrar la release publicada` el `when: comprobar_nginx.rc == 0` de la petición |
| La primera tarea falla en `pre-web1` con `rc=2` | Falta `failed_when: false` en `Consultar la versión de nginx` | Añádelo: el fallo pasa a ser un dato en `comprobar_nginx.rc` |
| `comprobar_nginx.stdout` sale vacío | `nginx -v` escribe en la salida de error | Usa `comprobar_nginx.stderr` |
| La comprobación sale como `changed` en cada ejecución | `ansible.builtin.command` sin `changed_when` | `changed_when: false` en las tareas que solo consultan |
| `Pedir el estado del portal` falla con `Status code was -1 … Connection refused` y `failed_when_result: "… has no attribute 'json'"` | nginx parado en el nodo: no hay respuesta, ni `json` que comparar | `ansible-playbook web.yml` (la tarea `Arrancar nginx` lo levanta) |
