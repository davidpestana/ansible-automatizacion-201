# Lab — Troubleshooting

[← Página anterior](02-lab-cambio-en-produccion.md) · [Siguiente página →](../M09-orquestacion/README.md)

Cuando una ejecución de Ansible falla en prod, el equipo de Tienda Norte necesita saber en poco tiempo si es un
nodo caído, un error en el proyecto o un problema de permisos, y retomar sin repetirlo todo. En este lab provocas
cuatro fallos reales sobre el portal de producción, los diagnosticas con las herramientas de Ansible y de nginx y
dejas prod como estaba.

### Objetivo

Dejar prod sano después de diagnosticar y resolver cuatro fallos: un nodo parado, una variable mal escrita en una
plantilla, una tarea sin permisos y una configuración de nginx rota a mano.

### Punto de partida

- Terminal del Codespace. Desde la raíz del repositorio:

  ```bash
  scripts/partida.sh m08
  cd proyecto
  ```

- Estado: prod con `site.yml` aplicado (balanceador y dos web con la release 1.0.0). No hace falta nada de páginas
  anteriores.

### En qué consiste

Cada fallo sigue el mismo ciclo: lo provocas, lees lo que dice Ansible, buscas la causa con la herramienta
adecuada y lo arreglas. Trabajas con `web.yml` y comandos ad hoc sobre el inventario de prod.

| Fallo | Herramientas |
|-------|--------------|
| Nodo parado | `PLAY RECAP`, `ansible.builtin.ping` |
| Variable indefinida en una plantilla | `Origin:`, `ansible.builtin.debug`, `--start-at-task` |
| Sin permisos | `-vvv` |
| Configuración de nginx rota | `nginx -t`, `--check --diff` |

### 1 — Para un servidor web

**Acción:**

```bash
docker stop prod-web2
```

**Por qué:** simula un servidor caído (un corte de red, una máquina apagada). Es el fallo más común de una
ejecución en prod.

**Resultado esperado:** Docker responde `prod-web2`.

### 2 — Lanza el playbook con el nodo caído

**Acción:**

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml
```

**Por qué:** quieres ver cómo se presenta un nodo inalcanzable y qué pasa con el resto.

**Resultado esperado:** tras unos segundos de espera, `prod-web2` sale como `UNREACHABLE` y el playbook sigue con
`prod-web1`:

```text
TASK [Gathering Facts] *********************************************************
ok: [prod-web1]
[ERROR]: Task failed: Failed to connect to the host via ssh: ssh: connect to host 172.30.0.22 port 22: Connection timed out
…
fatal: [prod-web2]: UNREACHABLE! => {"changed": false, "msg": "Task failed: Failed to connect to the host via ssh: ssh: connect to host 172.30.0.22 port 22: Connection timed out", "unreachable": true}

TASK [portal : Instalar nginx] *************************************************
ok: [prod-web1]
…
PLAY RECAP *********************************************************************
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=0    changed=0    unreachable=1    failed=0    skipped=0    rescued=0    ignored=0
```

`unreachable=1` y no `failed=1`: Ansible ni siquiera ha llegado al nodo. El problema no está en el proyecto, sino
en la conexión. El portal sigue respondiendo por el balanceador: `curl -s -o /dev/null -w "%{http_code}\n"
localhost:8080` devuelve `200`, porque nginx deja de mandar pedidos al nodo que no contesta.

### 3 — Confirma el diagnóstico con un ping

**Acción:**

```bash
ansible -i inventories/prod/hosts.yml prod-web2 -m ansible.builtin.ping
```

**Por qué:** antes de tocar el proyecto, comprueba lo más básico: si Ansible llega al nodo. Es más rápido que
relanzar el playbook.

**Resultado esperado:**

```text
prod-web2 | UNREACHABLE! => {
    "changed": false,
    "msg": "Task failed: Failed to connect to the host via ssh: ssh: connect to host 172.30.0.22 port 22: Connection timed out",
    "unreachable": true
}
```

`Connection timed out` significa que nadie contesta en esa IP. Si fuera `Permission denied (publickey)`, el nodo
estaría vivo y el problema sería la clave.

### 4 — Arranca el nodo y vuelve a aplicar

**Acción:**

```bash
docker start prod-web2
ansible -i inventories/prod/hosts.yml prod-web2 -m ansible.builtin.ping
ansible-playbook -i inventories/prod/hosts.yml web.yml --limit prod-web2
```

**Por qué:** el nodo vuelve, pero los contenedores del curso no arrancan servicios solos: nginx sigue parado. El
playbook es el que deja el nodo como debe estar, y `--limit` lo aplica solo donde hace falta.

**Resultado esperado:** el ping responde `"ping": "pong"`. En el playbook solo cambia una tarea:

```text
TASK [portal : Arrancar nginx] *************************************************
changed: [prod-web2]

PLAY RECAP *********************************************************************
prod-web2                  : ok=11   changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`curl -s -o /dev/null -w "%{http_code}\n" localhost:8084` vuelve a dar `200`.

### 5 — Introduce un error en una plantilla

**Acción:** en `roles/portal/templates/portal.conf.j2`, añade una cabecera con el nombre de la variable mal escrito
(`portal_entrono` en lugar de `portal_entorno`):

```jinja
# proyecto/roles/portal/templates/portal.conf.j2
# {{ ansible_managed }}
server {
    listen {{ portal_puerto }} default_server;
    server_name {{ inventory_hostname }};
    add_header X-Entorno {{ portal_entrono }};
    root {{ portal_raiz }}/current;
    index index.html;
}
```

Y lanza el playbook en el canario:

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml --limit prod-web1
```

**Por qué:** una errata en una variable es el fallo más común del proyecto. Quieres reconocer el mensaje a la
primera.

**Resultado esperado:**

```text
TASK [portal : Configurar el sitio del portal] *********************************
[ERROR]: Task failed: 'portal_entrono' is undefined

Task failed.
Origin: …/proyecto/roles/portal/tasks/main.yml:18:3

16   tags: [config]
17
18 - name: Configurar el sitio del portal
     ^ column 3

<<< caused by >>>

'portal_entrono' is undefined
Origin: …/proyecto/roles/portal/templates/portal.conf.j2

fatal: [prod-web1]: FAILED! => {"changed": false, "msg": "Task failed: 'portal_entrono' is undefined"}

PLAY RECAP *********************************************************************
prod-web1                  : ok=3    changed=0    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
```

Aquí es `failed=1`: Ansible ha llegado al nodo, pero la tarea ha fallado. Los dos `Origin:` dan la tarea
(`main.yml`, línea 18) y el fichero donde está el error (`portal.conf.j2`). La plantilla no llega a escribirse en
el nodo: el sitio sigue como estaba.

### 6 — Comprueba qué variable existe de verdad

**Acción:**

```bash
ansible -i inventories/prod/hosts.yml prod-web1 -m ansible.builtin.debug -a var=portal_entorno
```

**Por qué:** `ansible.builtin.debug` enseña el valor que tiene una variable para un nodo concreto, con el inventario
real. Así confirmas cuál es el nombre bueno y qué valor tomará.

**Resultado esperado:**

```text
prod-web1 | SUCCESS => {
    "portal_entorno": "prod"
}
```

Con el nombre mal escrito (`-a var=portal_entrono`), el mismo comando avisa con `[WARNING]: Encountered 1 template
error.` y responde `"portal_entrono": "<< error 1 - 'portal_entrono' is undefined >>"`.

### 7 — Corrige y retoma desde la tarea que falló

**Acción:** en `portal.conf.j2`, cambia `portal_entrono` por `portal_entorno` y lanza:

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml --limit prod-web1 --start-at-task "Configurar el sitio del portal"
```

**Por qué:** `--start-at-task` empieza el playbook en la tarea indicada y se salta las anteriores, que ya estaban
bien. En un playbook largo te ahorras repetir lo que no hace falta.

**Resultado esperado:**

```text
TASK [Gathering Facts] *********************************************************
ok: [prod-web1]

TASK [portal : Configurar el sitio del portal] *********************************
changed: [prod-web1]
…
RUNNING HANDLER [portal : Recargar nginx] **************************************
changed: [prod-web1]

PLAY RECAP *********************************************************************
prod-web1                  : ok=10   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`curl -sI localhost:8083 | grep X-Entorno` responde `X-Entorno: prod`. Para dejar `prod-web2` igual, basta
`ansible-playbook -i inventories/prod/hosts.yml web.yml`.

> [!TIP]
> `--step` hace lo contrario: pregunta antes de cada tarea, `Perform task: TASK: portal : Instalar nginx
> (N)o/(y)es/(c)ontinue:`. `y` la ejecuta, `n` se la salta y `c` sigue sin preguntar más. Sirve para avanzar
> tarea a tarea por un playbook que no conoces bien:
> `ansible-playbook -i inventories/prod/hosts.yml web.yml --limit prod-web1 --step`.

### 8 — Lanza una tarea sin permisos

**Acción:**

```bash
ansible -i inventories/prod/hosts.yml prod-web1 -m ansible.builtin.copy -a 'content=prueba dest=/etc/nginx/conf.d/prueba.conf'
```

**Por qué:** los playbooks del portal llevan `become: true`. Un comando ad hoc o un play que lo olvida se ejecuta
como el usuario `ansible`, que no puede escribir en `/etc`.

**Resultado esperado:**

```text
[ERROR]: Task failed: Module failed: Destination /etc/nginx/conf.d not writable
Origin: <adhoc 'ansible.builtin.copy' task>
…
prod-web1 | FAILED! => {
    …
    "changed": false,
    "checksum": "711383a59fda05336fd2ccf70c8059d1523eb41a",
    "msg": "Destination /etc/nginx/conf.d not writable"
}
```

### 9 — Mira la ejecución por dentro con `-vvv`

**Acción:**

```bash
ansible -i inventories/prod/hosts.yml prod-web1 -m ansible.builtin.copy -a 'content=prueba dest=/etc/nginx/conf.d/prueba.conf' -vvv
```

**Por qué:** `-vvv` enseña qué configuración se ha cargado, con qué usuario se conecta Ansible y cada comando que
lanza en el nodo. Es la forma de confirmar qué está pasando cuando el mensaje de error no basta.

**Resultado esperado:** muchas líneas; las que importan aquí son estas:

```text
Using …/proyecto/ansible.cfg as config file
…
<prod-web1> ESTABLISH SSH CONNECTION FOR USER: ansible
<prod-web1> SSH: EXEC ssh -F ../infra/ssh_config -o ControlMaster=auto -o ControlPersist=60s …
…
<prod-web1> PUT …/.utg3nplv TO /home/ansible/.ansible/tmp/ansible-tmp-…/.source.conf
…
```

La conexión es como usuario `ansible` y en ninguna línea aparece `sudo`: no hay `become`. Repite el comando con
`-b` (el `become` de los comandos ad hoc) y el resultado pasa a `prod-web1 | CHANGED`. Después borra el fichero de prueba:

```bash
ansible -i inventories/prod/hosts.yml prod-web1 -b -m ansible.builtin.file -a 'path=/etc/nginx/conf.d/prueba.conf state=absent'
```

> [!NOTE]
> `-v` añade el resultado de cada tarea; `-vvv`, la conexión y los comandos; `-vvvv`, también el detalle de SSH.
> Si hace falta examinar el módulo que Ansible ha copiado al nodo, `ANSIBLE_KEEP_REMOTE_FILES=1` delante del
> comando hace que no borre los ficheros de `/home/ansible/.ansible/tmp/`. Se usa poco y solo mientras se depura.

### 10 — Rompe la configuración de nginx a mano

**Acción:**

```bash
docker exec prod-web1 sh -c "echo 'roto' >> /etc/nginx/sites-available/portal"
docker exec prod-web1 nginx -t
```

**Por qué:** simula a alguien que ha editado el nodo por SSH, como en los tiempos del runbook. `nginx -t` comprueba
la configuración sin recargarla: es lo primero que se lanza en el nodo cuando nginx no arranca o no recarga.

**Resultado esperado:**

```text
2026/10/26 23:43:02 [emerg] 3984#3984: unexpected end of file, expecting ";" or "}" in /etc/nginx/sites-enabled/portal:10
nginx: configuration file /etc/nginx/nginx.conf test failed
```

nginx sigue sirviendo con la configuración que cargó al arrancar, pero la próxima recarga o el próximo reinicio
fallarían.

### 11 — Encuentra y repara la deriva con Ansible

**Acción:**

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml --limit prod-web1 --tags config --diff
docker exec prod-web1 nginx -t
```

**Por qué:** la plantilla del rol es la fuente de verdad. `--diff` enseña qué había de más en el nodo y la
ejecución lo devuelve a su estado.

**Resultado esperado:**

```text
TASK [portal : Configurar el sitio del portal] *********************************
--- before: /etc/nginx/sites-available/portal
+++ after: …/portal.conf.j2
@@ -6,4 +6,3 @@
     root /srv/portal/current;
     index index.html;
 }
-roto

changed: [prod-web1]
…
PLAY RECAP *********************************************************************
prod-web1                  : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

## Comprueba tu entendimiento

**Prod está sano**
`ansible-playbook -i inventories/prod/hosts.yml web.yml --check --diff`
→ `failed=0` y `unreachable=0` en los dos nodos. Si `prod-web2` sale con `changed` en `Configurar el sitio del
portal`, falta aplicarle la cabecera `X-Entorno`: lanza el playbook sin `--check`.

**La configuración de nginx es válida en los dos web**
`docker exec prod-web1 nginx -t` y `docker exec prod-web2 nginx -t`
→ `syntax is ok` y `test is successful` en los dos.

**Sabes distinguir los fallos**
Para cada fallo del lab, di qué contador del `PLAY RECAP` se activó.
→ Nodo parado: `unreachable=1`. Variable indefinida: `failed=1`. Configuración rota a mano: ninguno; solo se ve
con `nginx -t` o con el diff.

## Reto

### 1 — Un `debug` dentro del playbook

En el paso 6 consultaste una variable con un comando ad hoc. Añade una tarea a `web.yml`, antes de los roles,
que muestre `portal_entorno` y `portal_worker_connections` de cada nodo, pero solo cuando se lanza con `-v` o más.

<details>
<summary>Ver solución</summary>

`ansible.builtin.debug` tiene la opción `verbosity`: la tarea solo enseña algo a partir de ese nivel de `-v`.

```yaml
# proyecto/web.yml
- name: Servidores web del portal
  hosts: web
  become: true
  pre_tasks:
    - name: Mostrar las variables del portal
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }}: entorno {{ portal_entorno }}, worker_connections {{ portal_worker_connections }}"
        verbosity: 1
  roles:
    - portal
```

Sin `-v`, la tarea sale `skipping`. Con `-v`, muestra una línea por nodo, por ejemplo
`prod-web2: entorno prod, worker_connections 2048`.

</details>

### 2 — ¿Qué hace el playbook con un nodo caído?

Con `prod-web2` parado, ¿por qué `web.yml` siguió con `prod-web1`, y qué habría pasado con `deploy.yml`?

<details>
<summary>Ver solución</summary>

`web.yml` no tiene `serial` ni `max_fail_percentage`: un nodo inalcanzable se aparta de la ejecución y el resto
sigue. `deploy.yml` tiene `serial: 1` y `max_fail_percentage: 0`, y va de uno en uno: si el nodo del lote falla o no
es alcanzable, el despliegue se para y no pasa al siguiente.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `UNREACHABLE! … Connection timed out` | El nodo está parado o no hay red | `docker ps` para ver si está; `docker start prod-web2` o `scripts/nodos.sh up` desde la raíz del repositorio |
| `UNREACHABLE! … Permission denied (publickey)` | La clave del curso no coincide con la del nodo | `scripts/nodos.sh reset` desde la raíz del repositorio y vuelve a cargar la partida |
| Tras `docker start`, el portal del nodo no responde | En los contenedores nginx no arranca solo | `ansible-playbook -i inventories/prod/hosts.yml web.yml --limit prod-web2` |
| `'…' is undefined` | Variable mal escrita o no definida para ese entorno | `ansible … -m ansible.builtin.debug -a var=<nombre>` y revisa el fichero que indica `Origin:` |
| `--start-at-task` no encuentra la tarea y no ejecuta nada | El nombre no coincide exactamente con el de la tarea | Copia el nombre tal como sale en `TASK [portal : …]`, sin el prefijo del rol |
| `Destination … not writable` | Falta `become` | `become: true` en el play, o `-b` en el comando ad hoc |
| `nginx -t` falla y Ansible no lo detectó | Alguien editó el nodo a mano después de la última ejecución | `ansible-playbook … --check --diff` muestra la deriva; aplica para corregirla |
