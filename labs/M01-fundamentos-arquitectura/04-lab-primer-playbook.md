# Lab — Primer playbook

[← Página anterior](03-lab-conexion-agentless.md) · [Siguiente página →](../M02-inventarios/README.md)

Los dos primeros pasos del runbook de Tienda Norte (crear la carpeta `/srv/portal` y dejar en `/etc/motd` el aviso
de que el nodo es del portal) se repiten a mano en cada servidor. En este lab los conviertes en
`primer-playbook.yml`, tarea a tarea. Lo ejecutas sobre los seis nodos, lees el `PLAY RECAP` y compruebas que una
segunda ejecución no cambia nada.

### Objetivo

`proyecto/primer-playbook.yml` con un play y tres tareas (comprobar la conexión, crear `/srv/portal` y escribir
`/etc/motd`) aplicado en los seis nodos, con una segunda ejecución que termina en `changed=0` para todos.

### Punto de partida

- Terminal del Codespace.
- Estado: el proyecto en el punto `m01-03`: `proyecto/` tiene `ansible.cfg`, `app/` e `inventario.ini` con los
  seis nodos, pero no tiene playbook. Los nodos, recién creados, sin carpeta del portal ni `motd` propio.
  El paso 1 te deja ahí aunque no vengas de la página anterior.
- Credenciales: usuario remoto `ansible` con la clave del curso, ya configurados en `ansible.cfg`.

### En qué consiste

Escribes el playbook en varias versiones y lo ejecutas después de cada una: primero solo un `ping`, luego la
carpeta (que falla sin permisos y arreglas con `become`), después el `motd`, y al final repites para ver la
idempotencia. Solo tocas `/srv/portal` y `/etc/motd` en los nodos: nada de nginx ni del portal todavía.

### 1 — Prepara el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repositorio
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m01-03 --limpio
cd proyecto
ls
```

**Por qué:** `--limpio` recrea los nodos sin nada aplicado, así la primera ejecución del playbook tendrá algo que
cambiar aunque ya hayas seguido la demostración. Lo que hubiera en `proyecto/` queda en `proyecto.anterior/`.

**Resultado esperado:** la salida termina con las seis líneas `SSH ok` y
`Listo: proyecto/ en el punto de partida «m01-03» (lo anterior está en proyecto.anterior/).`, y `ls` muestra:

```text
ansible.cfg
app
inventario.ini
```

### 2 — Escribe un play con una sola tarea

**Acción:** crea `proyecto/primer-playbook.yml` en VS Code con este contenido y guárdalo:

```yaml
# proyecto/primer-playbook.yml
- name: Preparar los nodos del portal
  hosts: all
  tasks:
    - name: Comprobar la conexión
      ansible.builtin.ping:
```

**Por qué:** es el esqueleto de cualquier playbook. El fichero es una lista YAML (cada `-` en la columna 0 es un
play). El play tiene un `name`, que se verá al ejecutar; `hosts`, el patrón del inventario al que se aplica
(`all`, los seis nodos), y `tasks`, la lista de tareas. Cada tarea lleva su `name` y el módulo por su nombre
completo. La sangría es de dos espacios y no admite tabuladores.

**Resultado esperado:** el fichero aparece en el explorador de VS Code, dentro de `proyecto/`.

### 3 — Comprueba la sintaxis

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook primer-playbook.yml --syntax-check
```

**Por qué:** `--syntax-check` lee el YAML y la estructura del playbook sin conectar con ningún nodo. Es la forma
rápida de descubrir una sangría rota antes de lanzar nada.

**Resultado esperado:** solo el nombre del fichero, sin errores:

```text
playbook: primer-playbook.yml
```

### 4 — Ejecuta la primera versión

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook primer-playbook.yml
```

**Por qué:** antes de añadir tareas que cambian algo, compruebas que el play llega a todos los nodos.

**Resultado esperado:**

```text
PLAY [Preparar los nodos del portal] *******************************************

TASK [Gathering Facts] *********************************************************
ok: [prod-lb1]
ok: [dev-web1]
…

TASK [Comprobar la conexión] ***************************************************
ok: [prod-web1]
ok: [prod-web2]
…

PLAY RECAP *********************************************************************
dev-web1                   : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
pre-web1                   : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-db1                   : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web1                  : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`ok=2` aunque solo has escrito una tarea: **Gathering Facts** la añade Ansible al principio de cada play para
recoger los datos del nodo. El `ping` no cambia nada, así que `changed=0`.

### 5 — Añade la carpeta del portal

**Acción:** añade esta tarea al final de `tasks`, con la misma sangría que la anterior, y guarda:

```yaml
# proyecto/primer-playbook.yml (tarea nueva, al final de tasks)
    - name: Crear la carpeta del portal
      ansible.builtin.file:
        path: /srv/portal
        state: directory
        mode: "0755"
```

Ejecuta:

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook primer-playbook.yml
```

**Por qué:** sustituye al `sudo mkdir -p /srv/portal` del runbook. No le dices «crea», sino cómo tiene que quedar:
`/srv/portal` existe, es un directorio (`state: directory`) y tiene permisos `0755`. El modo va entre comillas
para que YAML no lo lea como un número.

**Resultado esperado:** la tarea **falla** en los seis nodos:

```text
TASK [Crear la carpeta del portal] *********************************************
[ERROR]: Task failed: Module failed: There was an issue creating /srv/portal as requested: [Errno 13] Permission denied: b'/srv/portal'
Origin: /workspaces/ansible-automatizacion-201/proyecto/primer-playbook.yml:7:7

5       ansible.builtin.ping:
6
7     - name: Crear la carpeta del portal
        ^ column 7

fatal: [dev-web1]: FAILED! => {"changed": false, "msg": "There was an issue creating /srv/portal as requested: [Errno 13] Permission denied: b'/srv/portal'", "path": "/srv/portal"}
…

PLAY RECAP *********************************************************************
dev-web1                   : ok=2    changed=0    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
…
```

Ansible entra como `ansible`, y ese usuario no puede escribir en `/srv`. El error dice qué tarea falló, en qué
línea del fichero (`Origin: …:7:7`) y por qué. La ruta de `Origin` depende del nombre de tu fork, y la línea
cambia si tu fichero empieza por el comentario de la ruta.

### 6 — Ejecuta las tareas como root

**Acción:** añade `become: true` al play, debajo de `hosts: all`. El fichero queda así:

```yaml
# proyecto/primer-playbook.yml
- name: Preparar los nodos del portal
  hosts: all
  become: true
  tasks:
    - name: Comprobar la conexión
      ansible.builtin.ping:

    - name: Crear la carpeta del portal
      ansible.builtin.file:
        path: /srv/portal
        state: directory
        mode: "0755"
```

Ejecuta de nuevo:

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook primer-playbook.yml
```

**Por qué:** `become: true` es el `sudo` del runbook: Ansible sigue entrando como `ansible`, pero ejecuta los
módulos como `root`. Puesto en el play, vale para todas sus tareas.

**Resultado esperado:**

```text
TASK [Crear la carpeta del portal] *********************************************
changed: [dev-web1]
changed: [prod-lb1]
…

PLAY RECAP *********************************************************************
dev-web1                   : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
pre-web1                   : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-db1                   : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web1                  : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`changed=1`: la carpeta no existía y Ansible la ha creado en los seis nodos.

### 7 — Añade el aviso del motd

**Acción:** añade la tercera tarea al final de `tasks` y guarda:

```yaml
# proyecto/primer-playbook.yml (tarea nueva, al final de tasks)
    - name: Dejar constancia de quién gestiona el nodo
      ansible.builtin.copy:
        dest: /etc/motd
        content: "Nodo del portal de pedidos de Tienda Norte. Gestionado con Ansible.\n"
        mode: "0644"
```

Ejecuta:

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook primer-playbook.yml
```

**Por qué:** `ansible.builtin.copy` con `content` escribe el fichero con ese texto exacto. Sustituye al
`echo … | sudo tee /etc/motd` del runbook, y cualquiera que entre en el nodo sabrá que no debe cambiarlo a mano.

**Resultado esperado:**

```text
TASK [Crear la carpeta del portal] *********************************************
ok: [prod-web2]
ok: [prod-web1]
…

TASK [Dejar constancia de quién gestiona el nodo] ******************************
changed: [dev-web1]
changed: [prod-lb1]
…

PLAY RECAP *********************************************************************
dev-web1                   : ok=4    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
pre-web1                   : ok=4    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-db1                   : ok=4    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web1                  : ok=4    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=4    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

La carpeta ya da `ok` (existía de la ejecución anterior) y solo cambia el `motd`: `ok=4 changed=1`.

### 8 — Repite la ejecución

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook primer-playbook.yml
```

**Por qué:** es la prueba de que el playbook describe un estado y no una lista de órdenes. Si los nodos ya están
como se pide, no debe tocar nada.

**Resultado esperado:** todas las tareas dan `ok` y el resumen marca `changed=0` en los seis nodos:

```text
PLAY RECAP *********************************************************************
dev-web1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
pre-web1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-db1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web1                  : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

| Columna del `PLAY RECAP` | Qué cuenta |
|--------------------------|------------|
| `ok` | Tareas que terminaron bien, hayan cambiado algo o no |
| `changed` | De esas, las que tuvieron que cambiar el nodo |
| `unreachable` | Nodos a los que no se pudo conectar |
| `failed` | Tareas que fallaron (el nodo deja de ejecutar el resto del play) |
| `skipped`, `rescued`, `ignored` | Tareas saltadas por una condición, recuperadas o con error ignorado; se ven más adelante en el curso |

### 9 — Comprueba el resultado en un nodo

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ssh -F ../infra/ssh_config prod-web1 cat /etc/motd
```

**Por qué:** el `PLAY RECAP` dice lo que hizo Ansible. Mirar el nodo confirma que ha quedado como se pedía.

**Resultado esperado:**

```text
Nodo del portal de pedidos de Tienda Norte. Gestionado con Ansible.
```

## Comprueba tu entendimiento

**El playbook es idempotente**
`ansible-playbook primer-playbook.yml` otra vez.
→ `changed=0` en los seis nodos del `PLAY RECAP`.

**Solo un nodo**
`ansible-playbook primer-playbook.yml --limit dev-web1`.
→ Las mismas tareas, solo con `[dev-web1]`, y un `PLAY RECAP` de una línea: `dev-web1 : ok=4 changed=0 …`.

**La sintaxis es correcta**
`ansible-playbook primer-playbook.yml --syntax-check`.
→ `playbook: primer-playbook.yml`, sin errores.

## Reto

### 1 — Alguien cambia el motd a mano

Un compañero entra en `prod-web2` y sustituye el `motd` por otro texto. Simúlalo y averigua qué hace el playbook
la siguiente vez, en qué nodos cambia algo y qué cambia exactamente.

```bash
# Terminal del Codespace, en proyecto/
docker exec prod-web2 sh -c "echo 'Cambio a mano' > /etc/motd"
```

<details>
<summary>Ver solución</summary>

Ejecuta el playbook con `--diff`, que enseña el antes y el después de cada fichero que cambia:

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook primer-playbook.yml --diff
```

```text
TASK [Dejar constancia de quién gestiona el nodo] ******************************
ok: [prod-web1]
ok: [dev-web1]
ok: [prod-lb1]
ok: [pre-web1]
ok: [prod-db1]
--- before: /etc/motd
+++ after: /etc/motd
@@ -1 +1 @@
-Cambio a mano
+Nodo del portal de pedidos de Tienda Norte. Gestionado con Ansible.

changed: [prod-web2]

PLAY RECAP *********************************************************************
…
prod-web1                  : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=4    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Solo cambia `prod-web2`, y solo su `motd`: Ansible devuelve el nodo al estado descrito y deja los demás como
estaban. Es la forma de corregir la deriva que deja el trabajo manual.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `Permission denied: b'/srv/portal'` en «Crear la carpeta del portal» | Falta `become: true`: la tarea corre como `ansible` | Añade `become: true` al play, debajo de `hosts` |
| `YAML parsing failed: Colons in unquoted values must be followed by a non-space character` | Sangría rota: el módulo no está alineado con el `name` de su tarea | Alinea `ansible.builtin.file:` con el `name` de la tarea (dos espacios más que el `-`) y pasa `--syntax-check` |
| `couldn't resolve module/action 'ansible.builtin.cpy'` | Nombre del módulo mal escrito | Corrige el nombre (`ansible.builtin.copy`) |
| `skipping: no hosts matched` y avisos de `No inventory was parsed` | Has lanzado `ansible-playbook` fuera de `proyecto/` y no se carga `ansible.cfg` | `cd "$CODESPACE_VSCODE_FOLDER/proyecto"` y repite |
| La primera ejecución da `ok` en todo, sin `changed` | Los nodos ya tenían la carpeta y el `motd` (por ejemplo, de la demostración) | Es correcto: el playbook no tenía nada que cambiar. Para verlo desde cero, `scripts/partida.sh m01-03 --limpio` |
