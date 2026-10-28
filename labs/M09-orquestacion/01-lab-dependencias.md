# Lab — Dependencias

[← Página anterior](00-orden-del-portal.md) · [Siguiente página →](02-lab-secuencial-y-paralelo.md)

En prod, las web del portal de Tienda Norte dicen trabajar contra `prod-db1`, pero el proyecto nunca instala la base
de datos: `db.yml` existe y `site.yml` no lo llama. En este lab haces explícita esa dependencia: las web esperan a que
PostgreSQL acepte conexiones antes de configurarse, y `site.yml` levanta la base de datos antes que las web.

### Objetivo

Un `site.yml` que en prod configura `prod-db1`, después las dos web (que comprueban con `ansible.builtin.wait_for`
que PostgreSQL escucha en el 5432) y por último el balanceador, con `"db": "prod-db1"` en el `estado.json` de cada web.

### Punto de partida

- Terminal del Codespace. `scripts/partida.sh` se lanza desde la raíz del repositorio; lo demás, desde `proyecto/`.
- Estado: nodos recién creados, con las web y el balanceador de prod instalados y `prod-db1` vacío. El paso 1 te deja
  ahí, vengas de donde vengas.
- `proyecto/` trae el rol `portal_db`, `db.yml` y `portal_db_host: prod-db1` en `inventories/prod/group_vars/all.yml`.

### En qué consiste

Tocas dos ficheros: `web.yml` (una tarea de espera antes del rol) y `site.yml` (un play más al principio). No cambias
ningún rol. Primero ves fallar la espera sin base de datos, luego la incorporas y compruebas el resultado.

### 1 — Prepara el punto de partida

**Acción:**

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m09 --limpio
cd proyecto
```

**Por qué:** `--limpio` recrea los nodos, así `prod-db1` está seguro vacío aunque hayas instalado PostgreSQL en otra
página. El script aplica después el `site.yml` de partida (web y balanceador).

**Resultado esperado:** el script termina con este resumen y el mensaje `Listo: proyecto/ en el punto de partida «m09»`:

```text
PLAY RECAP *********************************************************************
prod-lb1                   : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web1                  : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`prod-db1` no aparece: ningún play lo toca.

### 2 — Mira a qué base de datos apunta la web

**Acción:** `curl -s localhost:8083/estado.json`

**Por qué:** la variable `portal_db_host` ya está en el inventario de prod y la plantilla `estado.json.j2` la publica.
El portal declara una dependencia que nadie ha satisfecho.

**Resultado esperado:**

```text
{
  "host": "prod-web1",
  "entorno": "prod",
  "version": "1.0.0",
  "color": "#15803d",
  "db": "prod-db1"
}
```

### 3 — Comprueba desde la web si PostgreSQL responde

**Acción:**

```bash
ansible -i inventories/prod/hosts.yml prod-web1 -m ansible.builtin.wait_for -a "host=prod-db1 port=5432 timeout=5"
```

**Por qué:** `ansible.builtin.wait_for` se ejecuta **en el nodo web** y abre una conexión a `prod-db1:5432`. Es la
misma prueba que haría la aplicación al arrancar: si falla aquí, fallaría el portal.

**Resultado esperado:** falla tras la espera indicada en `timeout`:

```text
[ERROR]: Task failed: Module failed: Timeout when waiting for prod-db1:5432
…
prod-web1 | FAILED! => {
    …
    "changed": false,
    "elapsed": 5,
    "msg": "Timeout when waiting for prod-db1:5432"
}
```

### 4 — Haz que las web esperen a la base de datos

**Acción:** abre `proyecto/web.yml` y añade un bloque `pre_tasks` antes de `roles`. El fichero queda así:

```yaml
# proyecto/web.yml
- name: Servidores web del portal
  hosts: web
  become: true
  pre_tasks:
    - name: Esperar a PostgreSQL en {{ portal_db_host }}
      ansible.builtin.wait_for:
        host: "{{ portal_db_host }}"
        port: 5432
        timeout: 15
      when: portal_db_host | length > 0
  roles:
    - portal
```

**Por qué:** `pre_tasks` se ejecuta antes que los roles del play, así ninguna web se configura sin su base de datos.
El `when` evita la espera en dev y pre, donde `portal_db_host` está vacío (valor por defecto del rol `portal`).

**Resultado esperado:** el fichero guardado, con `pre_tasks` al mismo nivel que `roles`.

### 5 — Ejecuta `site.yml` todavía sin la base de datos

**Acción:** `ansible-playbook -i inventories/prod/hosts.yml site.yml`

**Por qué:** antes de arreglar el orden, comprueba que la dependencia ahora se nota: el playbook se para en vez de
configurar las web contra una base de datos que no existe.

**Resultado esperado:**

```text
PLAY [Servidores web del portal] ***********************************************

TASK [Gathering Facts] *********************************************************
ok: [prod-web2]
ok: [prod-web1]

TASK [Esperar a PostgreSQL en prod-db1] ****************************************
[ERROR]: Task failed: Module failed: Timeout when waiting for prod-db1:5432
Origin: …/proyecto/web.yml:5:7

3   become: true
4   pre_tasks:
5     - name: Esperar a PostgreSQL en {{ portal_db_host }}
        ^ column 7

fatal: [prod-web2]: FAILED! => {"changed": false, "elapsed": 15, "msg": "Timeout when waiting for prod-db1:5432"}
fatal: [prod-web1]: FAILED! => {"changed": false, "elapsed": 15, "msg": "Timeout when waiting for prod-db1:5432"}

PLAY RECAP *********************************************************************
prod-web1                  : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Fíjate en que `prod-lb1` ni siquiera aparece en el resumen: cuando fallan todos los nodos de un play, Ansible detiene
el playbook y no pasa al play del balanceador.

### 6 — Pon la base de datos al principio de `site.yml`

**Acción:** abre `proyecto/site.yml` y añade el play de la base de datos como primera entrada:

```yaml
# proyecto/site.yml
- name: Base de datos
  ansible.builtin.import_playbook: db.yml
- name: Web
  ansible.builtin.import_playbook: web.yml
- name: Balanceador
  ansible.builtin.import_playbook: lb.yml
```

Comprueba el orden sin ejecutar nada:

```bash
ansible-playbook -i inventories/prod/hosts.yml site.yml --list-tasks
```

**Por qué:** los plays se ejecutan en el orden del fichero. Poner `db.yml` primero es lo que garantiza que, cuando
llegue la espera de las web, PostgreSQL ya esté instalado y arrancado.

**Resultado esperado:** tres plays, en este orden, y la espera como primera tarea de las web:

```text
playbook: site.yml

  play #1 (db): Base de datos del portal	TAGS: []
    tasks:
      portal_db : Instalar PostgreSQL	TAGS: [paquetes]
      …
      portal_db : Crear la base de datos de pedidos	TAGS: []

  play #2 (web): Servidores web del portal	TAGS: []
    tasks:
      Esperar a PostgreSQL en {{ portal_db_host }}	TAGS: []
      portal : Instalar nginx	TAGS: [paquetes]
      …

  play #3 (lb): Balanceador del portal	TAGS: []
    tasks:
      portal_lb : Instalar nginx	TAGS: [paquetes]
      …
```

### 7 — Aplica el portal completo en orden

**Acción:** `ansible-playbook -i inventories/prod/hosts.yml site.yml`

**Por qué:** es la ejecución coordinada: base de datos, web que comprueban la base de datos y balanceador.

**Resultado esperado:** el play de la base de datos instala y configura PostgreSQL (con el handler
`Reiniciar PostgreSQL`), las web pasan la espera y el balanceador no cambia:

```text
PLAY [Base de datos del portal] ************************************************
…
RUNNING HANDLER [portal_db : Reiniciar PostgreSQL] *****************************
changed: [prod-db1]
…
PLAY [Servidores web del portal] ***********************************************
…
TASK [Esperar a PostgreSQL en prod-db1] ****************************************
ok: [prod-web2]
ok: [prod-web1]
…
PLAY RECAP *********************************************************************
prod-db1                   : ok=9    changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=12   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=12   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

> [!NOTE]
> Durante el play de la base de datos verás avisos `[WARNING]: Module remote_tmp … did not exist and was created with
> a mode of 0700`. Salen la primera vez que Ansible usa `become` hacia `root` o `postgres` en ese nodo y no afectan al
> resultado.

### 8 — Comprueba el portal a través del balanceador

**Acción:**

```bash
curl -s localhost:8080/estado.json
ansible -i inventories/prod/hosts.yml prod-web1 -m ansible.builtin.wait_for -a "host=prod-db1 port=5432 timeout=5"
```

**Por qué:** el `estado.json` confirma qué base de datos usa la web que contesta, y el `wait_for` confirma que esa base
de datos ahora sí escucha.

**Resultado esperado:**

```text
{
  "host": "prod-web1",
  "entorno": "prod",
  "version": "1.0.0",
  "color": "#15803d",
  "db": "prod-db1"
}
prod-web1 | SUCCESS => {
    …
    "elapsed": 0,
    "port": 5432,
    "state": "started"
}
```

El `host` puede ser `prod-web1` o `prod-web2`: el balanceador reparte.

### 9 — Repite la ejecución

**Acción:** `ansible-playbook -i inventories/prod/hosts.yml site.yml | sed -n '/PLAY RECAP/,$p'`

**Por qué:** el orden y la espera no rompen la idempotencia: una segunda pasada no debe cambiar nada.

**Resultado esperado:**

```text
PLAY RECAP *********************************************************************
prod-db1                   : ok=8    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=12   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=12   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`prod-db1` pasa de `ok=9` a `ok=8` porque esta vez no hay cambios de configuración y el handler no se ejecuta.

## Comprueba tu entendimiento

**La espera solo actúa donde hay base de datos**
Ejecuta `ansible-playbook web.yml` (sin `-i`: usa el inventario de dev de `ansible.cfg`).
→ La tarea `Esperar a PostgreSQL en` sale `skipping: [dev-web1]` (en dev `portal_db_host` está vacío) y el resto del
rol se aplica en `dev-web1`.

**El orden lo decide `site.yml`**
Ejecuta `ansible-playbook -i inventories/prod/hosts.yml site.yml --list-tasks | grep play`.
→ `play #1 (db)`, `play #2 (web)`, `play #3 (lb)`.

**La base de datos responde desde la otra web**
Lanza el `wait_for` del paso 8 contra `prod-web2`.
→ `prod-web2 | SUCCESS` con `"state": "started"`.

## Reto

### 1 — ¿Y si la dependencia va en el rol?

Alguien del equipo propone borrar el play de la base de datos de `site.yml` y declarar `portal_db` como dependencia
del rol `portal` en `roles/portal/meta/main.yml` (`dependencies: [{role: portal_db}]`). Pruébalo con
`ansible-playbook -i inventories/prod/hosts.yml web.yml --list-tasks` y explica qué haría esa ejecución en prod.
Deja `meta/main.yml` como estaba al terminar.

<details>
<summary>Ver solución</summary>

```yaml
# proyecto/roles/portal/meta/main.yml (solo el final)
dependencies:
  - role: portal_db
```

```text
  play #1 (web): Servidores web del portal	TAGS: []
    tasks:
      Esperar a PostgreSQL en {{ portal_db_host }}	TAGS: []
      portal_db : Instalar PostgreSQL	TAGS: [paquetes]
      portal_db : Localizar la configuración de PostgreSQL	TAGS: []
      …
      portal_db : Crear la base de datos de pedidos	TAGS: []
      portal : Instalar nginx	TAGS: [paquetes]
      …
```

Las tareas de `portal_db` aparecen **dentro del play de las web**: instalarían PostgreSQL en `prod-web1` y `prod-web2`,
no en `prod-db1`. Además, la espera de `pre_tasks` sigue apuntando a `prod-db1`, que seguiría vacío, así que fallaría
igual. `meta/main.yml dependencies` sirve para roles que van en el mismo nodo; entre nodos distintos, el orden lo
marcan los plays. Vuelve a dejar `dependencies: []`.

</details>

### 2 — Espera más fina

`wait_for` solo comprueba que el puerto está abierto. Busca en la documentación de `ansible.builtin.wait_for` qué
parámetro harías servir para fallar antes si PostgreSQL tarda, y qué parámetro limita cada intento de conexión.

<details>
<summary>Ver solución</summary>

`timeout` es la espera total (en el lab, 15); `connect_timeout` limita cada intento de conexión y `sleep` el intervalo
entre intentos. Para una comprobación de verdad de PostgreSQL (no solo del puerto) haría falta un cliente o el módulo
`community.postgresql.postgresql_ping`, que se ejecuta con las credenciales de la base de datos.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `Timeout when waiting for prod-db1:5432` aunque `db.yml` ya está en `site.yml` | `db.yml` está **después** de `web.yml` | Mueve `import_playbook: db.yml` a la primera línea de `site.yml` |
| La espera sale `skipping` y el play corre en `dev-web1` | Lanzaste sin `-i inventories/prod/hosts.yml` y se usó el inventario de dev | Ejecuta con el inventario de prod |
| Error al cargar `web.yml` que señala la línea de `pre_tasks` | `pre_tasks` sangrado dentro de `roles` o con distinta sangría que `hosts` | `pre_tasks` y `roles` al mismo nivel que `hosts` y `become` |
| El playbook acaba sin ejecutar el play del balanceador | Fallaron todas las web, y Ansible para el playbook entero | Arregla la causa del fallo de las web y repite |
| `[WARNING]: Module remote_tmp … was created with a mode of 0700` | Primera vez que se usa `become` hacia ese usuario en el nodo | Es informativo; no afecta |
