# Coordinación entre servicios

[← Página anterior](README.md) · [Siguiente página →](01-lab-dependencias.md)

En prod, el portal de pedidos de Tienda Norte son cuatro nodos que dependen unos de otros: las web `prod-web1` y
`prod-web2` apuntan a la base de datos `prod-db1`, y el balanceador `prod-lb1` reparte entre las dos web. Esta
demostración recorre qué pasa cuando cada pieza llega en su sitio y cuando no, y cómo un playbook de varios plays
coordina los tres servicios: el orden de los plays, `hostvars` de otro grupo, `run_once` y `delegate_to`.

## Punto de partida

Desde la raíz del repositorio, en el terminal del Codespace:

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m09-00 --limpio
cd proyecto
```

- Estado de los nodos: recién creados; el script aplica `site.yml` en prod, que en este punto solo tiene las web y
  el balanceador. `prod-db1` está vacío: sin PostgreSQL.
- `proyecto/` trae el rol `portal_db` y `db.yml` (todavía fuera de `site.yml`) y un playbook de lectura,
  `orden.yml`, que se usa al final.
- Todos los comandos se lanzan desde `proyecto/`.

## Recorrido

### 1. Lo que hay: web y balanceador, sin base de datos

El `site.yml` de partida encadena dos plays:

```yaml
# proyecto/site.yml
- name: Web
  ansible.builtin.import_playbook: web.yml
- name: Balanceador
  ansible.builtin.import_playbook: lb.yml
```

La base de datos tiene su propio playbook, `db.yml` (un play sobre el grupo `db` con el rol `portal_db`), pero nadie
lo llama. Aun así, cada web ya publica a qué base de datos apunta, porque `portal_db_host: prod-db1` está en
`inventories/prod/group_vars/all.yml`:

```bash
curl -s localhost:8083/estado.json
```

```text
{
  "host": "prod-web1",
  "entorno": "prod",
  "version": "1.0.0",
  "color": "#15803d",
  "db": "prod-db1"
}
```

El dato es una promesa. La comprobación real es preguntar desde la web si algo escucha en el puerto de PostgreSQL de
`prod-db1`. El módulo `ansible.builtin.wait_for` se ejecuta en `prod-web1` y abre una conexión al 5432:

```bash
ansible -i inventories/prod/hosts.yml prod-web1 -m ansible.builtin.wait_for -a "host=prod-db1 port=5432 timeout=5"
```

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

La web está configurada contra una base de datos que no existe. Nada en el proyecto lo impide: ningún play la
instala antes.

### 2. El orden invertido: un balanceador sin web

El otro extremo de la cadena es el balanceador. Para ver qué sirve `prod-lb1` cuando las web no están, se para
nginx en las dos web:

```bash
ansible -i inventories/prod/hosts.yml web -b -m ansible.builtin.service -a "name=nginx state=stopped"
curl -sI localhost:8080
```

```text
prod-web2 | CHANGED => {
    "state": "stopped"
prod-web1 | CHANGED => {
    "state": "stopped"
…
HTTP/1.1 502 Bad Gateway
Server: nginx
…
X-Servidor: 172.30.0.21:80, 172.30.0.22:80
```

Es lo que vería un cliente si el play del balanceador corriera antes que el de las web en unos nodos nuevos: el
balanceador funciona, pero no tiene a quién pasar las peticiones. La cabecera `X-Servidor` muestra que probó las dos
web. Al arrancar de nuevo nginx, el primer `curl` todavía devuelve `502`:

```bash
ansible -i inventories/prod/hosts.yml web -b -m ansible.builtin.service -a "name=nginx state=started"
curl -sI localhost:8080
```

```text
HTTP/1.1 502 Bad Gateway
…
X-Servidor: portal
```

nginx ha marcado las dos web como caídas y no las vuelve a probar hasta que pasa su `fail_timeout`;
`X-Servidor: portal` indica que no quedaba ningún servidor vivo en el `upstream`. Poco después:

```text
HTTP/1.1 200 OK
…
X-Servidor: 172.30.0.22:80
```

El orden no solo importa para instalar: un servicio que llega antes que aquel del que depende da errores, y a veces
los sigue dando un rato después de que el otro ya esté bien.

### 3. Base de datos, web y balanceador, en ese orden

El `site.yml` coordinado añade la base de datos como primer play:

```yaml
# proyecto/site.yml
- name: Base de datos
  ansible.builtin.import_playbook: db.yml
- name: Web
  ansible.builtin.import_playbook: web.yml
- name: Balanceador
  ansible.builtin.import_playbook: lb.yml
```

Con ese cambio, la ejecución en prod recorre los tres plays uno detrás de otro. Ansible no empieza un play hasta que
todos los nodos del anterior han terminado:

```bash
ansible-playbook -i inventories/prod/hosts.yml site.yml
```

```text
PLAY [Base de datos del portal] ************************************************
TASK [Gathering Facts] *********************************************************
ok: [prod-db1]
TASK [portal_db : Instalar PostgreSQL] *****************************************
changed: [prod-db1]
…
TASK [portal_db : Crear la base de datos de pedidos] ***************************
changed: [prod-db1]

PLAY [Servidores web del portal] ***********************************************
…
TASK [portal : Arrancar nginx] *************************************************
ok: [prod-web1]
ok: [prod-web2]

PLAY [Balanceador del portal] **************************************************
…
PLAY RECAP *********************************************************************
prod-db1                   : ok=9    changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Solo cambia `prod-db1`: las web y el balanceador ya estaban configurados. El mismo `wait_for` del paso 1 contesta
ahora al instante:

```text
prod-web1 | SUCCESS => {
    …
    "elapsed": 0,
    "port": 5432,
    "state": "started"
}
```

### 4. Un play lee lo que descubrió otro

Los plays de un mismo `ansible-playbook` comparten memoria: lo que un play registra en un nodo queda en
`hostvars` para los siguientes. `orden.yml` lo aprovecha para que las web lean un dato de la base de datos y para
lanzar comprobaciones desde el balanceador:

```yaml
# proyecto/orden.yml
# Cómo se coordinan los nodos del portal: lo que descubre un play lo leen los siguientes.
- name: Datos de la base de datos
  hosts: db
  gather_facts: false
  tasks:
    - name: Leer la versión de PostgreSQL
      ansible.builtin.command: psql --version
      register: orden_postgresql
      changed_when: false

- name: Las web miran a la base de datos y al balanceador
  hosts: web
  gather_facts: false
  tasks:
    - name: Anunciar la comprobación una sola vez
      ansible.builtin.debug:
        msg: "Comprobando {{ ansible_play_hosts | length }} web contra {{ groups['db'][0] }}"
      run_once: true

    - name: Leer lo que descubrió el play de la base de datos
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} usará {{ groups['db'][0] }}: {{ hostvars[groups['db'][0]]['orden_postgresql']['stdout'] }}"

    - name: Pedir el estado de cada web desde el balanceador
      ansible.builtin.command: curl -s -o /dev/null -w "%{http_code}" http://{{ inventory_hostname }}/estado.json
      delegate_to: "{{ groups['lb'][0] }}"
      register: orden_http
      changed_when: false

    - name: Mostrar lo que ve el balanceador
      ansible.builtin.debug:
        msg: "{{ groups['lb'][0] }} pide {{ inventory_hostname }}/estado.json: HTTP {{ orden_http.stdout }}"
```

- `groups['db'][0]` es el primer nodo del grupo `db` del inventario: `prod-db1`. Nadie escribe el nombre a mano.
- `hostvars[groups['db'][0]]['orden_postgresql']` es el resultado que registró el primer play en `prod-db1`.
- `run_once: true` hace la tarea en el primer nodo del play y no la repite en el segundo.
- `delegate_to` ejecuta el `curl` en `prod-lb1`, pero con las variables de cada web: `inventory_hostname` sigue
  siendo `prod-web1` o `prod-web2`.

```bash
ansible-playbook -i inventories/prod/hosts.yml orden.yml
```

```text
PLAY [Datos de la base de datos] ***********************************************

TASK [Leer la versión de PostgreSQL] *******************************************
ok: [prod-db1]

PLAY [Las web miran a la base de datos y al balanceador] ***********************

TASK [Anunciar la comprobación una sola vez] ***********************************
ok: [prod-web1] => {
    "msg": "Comprobando 2 web contra prod-db1"
}

TASK [Leer lo que descubrió el play de la base de datos] ***********************
ok: [prod-web1] => {
    "msg": "prod-web1 usará prod-db1: psql (PostgreSQL) 17.11 (Debian 17.11-0+deb13u1)"
}
ok: [prod-web2] => {
    "msg": "prod-web2 usará prod-db1: psql (PostgreSQL) 17.11 (Debian 17.11-0+deb13u1)"
}

TASK [Pedir el estado de cada web desde el balanceador] ************************
ok: [prod-web1 -> prod-lb1]
ok: [prod-web2 -> prod-lb1]

TASK [Mostrar lo que ve el balanceador] ****************************************
ok: [prod-web1] => {
    "msg": "prod-lb1 pide prod-web1/estado.json: HTTP 200"
}
ok: [prod-web2] => {
    "msg": "prod-lb1 pide prod-web2/estado.json: HTTP 200"
}

PLAY RECAP *********************************************************************
prod-db1                   : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web1                  : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

El aviso de `run_once` aparece una vez, solo para `prod-web1`, y por eso esa web suma `ok=4` frente al `ok=3` de
`prod-web2`. La notación `prod-web1 -> prod-lb1` es la marca de `delegate_to`: la tarea es de la web, pero se ha
ejecutado en el balanceador. Es la misma pieza que usa `deploy.yml` para sacar cada web del balanceador.

## Qué queda visto

- Ansible ejecuta los plays en el orden de `site.yml`; ese orden es lo que coordina db → web → lb.
- Un servicio que llega antes que el suyo falla: la web apunta a un PostgreSQL que no escucha y el balanceador
  devuelve `502` sin web detrás.
- `hostvars` y `groups` permiten a un play leer datos de otro grupo; `run_once` y `delegate_to` controlan en cuántos
  nodos y en cuál se ejecuta una tarea.

La dependencia con la base de datos se hace explícita con `wait_for` en el
[Lab — Dependencias](01-lab-dependencias.md); `delegate_to` se usa a fondo en el
[Lab — Orquestar varios nodos](03-lab-orquestar-nodos.md). Los dos se pueden hacer sin haber seguido esta
demostración.
