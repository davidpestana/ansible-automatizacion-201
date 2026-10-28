# Lab — Facts

[← Página anterior](02-lab-plantillas-jinja2.md) · [Siguiente página →](04-lab-configuracion-por-entorno.md)

El `nginx.conf` de los nodos web de Tienda Norte es el que trae el paquete de Debian, igual en todos: nadie
decide cuántos procesos arranca nginx ni cuántas conexiones admite cada uno. Lo primero depende de los núcleos
de cada máquina, y Ansible ya lo sabe: lo descubre en cada ejecución como un *fact*. En este lab lees los facts
de los nodos, generas `nginx.conf` con una plantilla que usa los núcleos de cada uno y un número de conexiones
por proceso, y compruebas en dev y en prod qué valor recibe cada nodo y por qué.

### Objetivo

`templates/nginx.conf.j2` desplegado en `dev-web1`, `prod-web1` y `prod-web2`, con `worker_processes` igual
a los núcleos de cada nodo y `worker_connections` sacado de `portal_worker_connections`, y una explicación,
con salida real, de por qué `prod-web2` no recibe el `2048` de su `host_vars`.

### Punto de partida

- Terminal del Codespace, en la raíz del repositorio. El paso 1 carga el estado `m04-03`: `group_vars/all.yml`
  por entorno, `host_vars/prod-web2.yml` con `portal_worker_connections: 2048` y un `portal.yml` que ya usa
  plantillas para `portal.conf` y `estado.json`.
- `dev-web1` con el portal publicado por ese `portal.yml`; el resto de nodos, vacíos.
- No hace falta nada de páginas anteriores.

### En qué consiste

Consultas facts con el módulo `setup`, compruebas que solo existen cuando se recogen, escribes
`templates/nginx.conf.j2`, añades una tarea `template` con validación, ensayas con `--check --diff` y aplicas en
dev y en los web de prod. No tocas el balanceador ni la base de datos.

### 1 — Carga el punto de partida

**Acción:**

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m04-03 --limpio
cd proyecto
```

**Por qué:** deja dev con el portal ya publicado y prod vacío, para que el `--diff` de `nginx.conf` compare con el
fichero que trae Debian.

**Resultado esperado:** `Preparando los nodos para m04-03…`, el resumen `dev-web1 : ok=11 changed=10` y
`Listo: proyecto/ en el punto de partida «m04-03»`.

### 2 — Lee los facts del procesador

**Acción:**

```bash
ansible web -m ansible.builtin.setup -a 'filter=ansible_processor*'
```

**Por qué:** `setup` es el módulo que ejecuta la tarea **Gathering Facts** al empezar cada play. Con `filter`
te quedas solo con lo que interesa: los facts de CPU.

**Resultado esperado:** algo así (los números y el modelo son los de la máquina donde corre tu Codespace; los
contenedores ven sus núcleos):

```text
dev-web1 | SUCCESS => {
    "ansible_facts": {
        "ansible_processor": [
            "0",
            "GenuineIntel",
            "11th Gen Intel(R) Core(TM) i7-11370H @ 3.30GHz",
            …
        ],
        "ansible_processor_cores": 4,
        "ansible_processor_count": 1,
        "ansible_processor_nproc": 8,
        "ansible_processor_threads_per_core": 2,
        "ansible_processor_vcpus": 8,
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false
}
```

`ansible_processor_vcpus` es el número de CPU que puede usar nginx. Fíjate en el tuyo: aparecerá en el paso 6.

### 3 — Mira otros facts del nodo

**Acción:**

```bash
ansible web -m ansible.builtin.setup -a 'filter=ansible_distribution*'
```

**Por qué:** los facts no son solo hardware: también la distribución, la memoria (`ansible_memtotal_mb`) o las
interfaces (`ansible_default_ipv4`). Todo lo que un runbook comprobaría a mano antes de decidir algo.

**Resultado esperado:**

```text
dev-web1 | SUCCESS => {
    "ansible_facts": {
        "ansible_distribution": "Debian",
        "ansible_distribution_file_parsed": true,
        "ansible_distribution_file_path": "/etc/os-release",
        "ansible_distribution_file_variety": "Debian",
        "ansible_distribution_major_version": "13",
        "ansible_distribution_minor_version": "7",
        "ansible_distribution_release": "trixie",
        "ansible_distribution_version": "13.7",
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false
}
```

### 4 — Comprueba que los facts no están si no se recogen

**Acción:**

```bash
ansible web -m ansible.builtin.debug -a "var=ansible_facts['processor_vcpus']"
```

**Por qué:** un comando ad hoc no ejecuta `setup` antes. Dentro de un playbook, el dato está porque
`gather_facts` viene activado por defecto; si un play lo desactiva, `ansible_facts` está vacío.

**Resultado esperado:**

```text
[WARNING]: Encountered 1 template error.
error 1 - object of type 'dict' has no attribute 'processor_vcpus'
…
dev-web1 | SUCCESS => {
    "ansible_facts['processor_vcpus']": "<< error 1 - object of type 'dict' has no attribute 'processor_vcpus' >>"
}
```

Dentro de las plantillas se escribe `ansible_facts['processor_vcpus']`; los facts también existen con el
prefijo `ansible_` (`ansible_processor_vcpus`), que es como los muestra `setup`.

### 5 — Mira la configuración actual de nginx

**Acción:**

```bash
docker exec dev-web1 nginx -T 2>/dev/null | grep -E 'worker_(processes|connections)'
```

**Por qué:** `nginx -T` vuelca la configuración que nginx tiene cargada. Así ves de qué partes antes de cambiarla.

**Resultado esperado:**

```text
worker_processes auto;
	worker_connections 768;
```

Es el `nginx.conf` del paquete de Debian, igual en todos los nodos.

### 6 — Escribe la plantilla de nginx.conf

**Acción:** crea `templates/nginx.conf.j2`:

```jinja
# templates/nginx.conf.j2
# {{ ansible_managed }}
user www-data;
worker_processes {{ ansible_facts['processor_vcpus'] | default(1) }};
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections {{ portal_worker_connections }};
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    include /etc/nginx/sites-enabled/*;
}
```

**Por qué:** `worker_processes` sale del fact de cada nodo y `worker_connections` de la variable
`portal_worker_connections`. `default(1)` evita que la plantilla falle si alguien
lanza el play sin facts, aunque entonces arranca un solo proceso.

**Resultado esperado:** existe `templates/nginx.conf.j2`.

### 7 — Añade el valor por defecto, la tarea y la recarga

**Acción:** en el bloque `vars:` de `portal.yml`, añade el número de conexiones por defecto:

```yaml
# portal.yml (cabecera del play)
  vars:
    portal_puerto: 80
    portal_raiz: /srv/portal
    portal_worker_connections: 768
    portal_db_host: ""
```

Justo después de **Instalar nginx**, añade:

```yaml
# portal.yml (tarea nueva, tras Instalar nginx)
    - name: Configurar nginx (nginx.conf)
      ansible.builtin.template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        mode: "0644"
        validate: nginx -t -c %s
      register: portal_nginx_conf
```

Y cambia la última tarea para que recargue si cambia cualquiera de los dos ficheros:

```yaml
# portal.yml (última tarea)
    - name: Recargar nginx si ha cambiado su configuración
      ansible.builtin.service:
        name: nginx
        state: reloaded
      when: portal_nginx_conf is changed or portal_sitio_conf is changed
```

**Por qué:** `768` es lo que trae nginx en Debian y vale para todos los nodos que no digan otra cosa.
`validate` ejecuta `nginx -t` sobre el fichero nuevo **antes** de ponerlo en su sitio; si la
plantilla genera algo que nginx no acepta, la tarea falla y el `nginx.conf` que funcionaba se queda. Sin el
`or`, un cambio solo en `nginx.conf` no se aplicaría hasta el siguiente cambio del sitio.

**Resultado esperado:** `ansible-playbook portal.yml --syntax-check` responde `playbook: portal.yml`.

### 8 — Ensaya en dev

**Acción:**

```bash
ansible-playbook portal.yml --check --diff
```

**Por qué:** el diff enseña exactamente qué partes del fichero de Debian desaparecen y con qué número se queda
`worker_processes` antes de tocar el nodo.

**Resultado esperado** (recortado; el número de `worker_processes` es el `processor_vcpus` del paso 2):

```text
TASK [Configurar nginx (nginx.conf)] *******************************************
--- before: /etc/nginx/nginx.conf
+++ after: …/nginx.conf.j2
@@ -1,84 +1,18 @@
+# Ansible managed
 user www-data;
-worker_processes auto;
-worker_cpu_affinity auto;
+worker_processes 8;
 pid /run/nginx.pid;
-error_log /var/log/nginx/error.log;
 include /etc/nginx/modules-enabled/*.conf;
 
 events {
-	worker_connections 768;
-	# multi_accept on;
+    worker_connections 768;
 }
…
changed: [dev-web1]
…
PLAY RECAP *********************************************************************
dev-web1                   : ok=12   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 9 — Aplica en dev y compruébalo con nginx -T

**Acción:**

```bash
ansible-playbook portal.yml
docker exec dev-web1 nginx -T 2>/dev/null | grep -E 'worker_(processes|connections)'
```

**Por qué:** `nginx -T` confirma que nginx ha recargado con el fichero nuevo, no solo que el fichero está en disco.

**Resultado esperado:** `dev-web1 : ok=12 changed=2` y:

```text
worker_processes 8;
    worker_connections 768;
```

### 10 — Aplica en los web de prod

**Acción:**

```bash
ansible-playbook -i inventories/prod/hosts.yml portal.yml
docker exec prod-web1 nginx -T 2>/dev/null | grep worker_connections
docker exec prod-web2 nginx -T 2>/dev/null | grep worker_connections
```

**Por qué:** `prod-web2` tiene `portal_worker_connections: 2048` en su `host_vars`. Es el momento de ver si
llega al nodo.

**Resultado esperado:**

```text
PLAY RECAP *********************************************************************
prod-web1                  : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

```text
    worker_connections 768;
```

```text
    worker_connections 768;
```

Los dos nodos salen con `768`. El inventario sí tiene el `2048` de `prod-web2`:

```bash
ansible-inventory -i inventories/prod/hosts.yml --host prod-web2
```

```text
{
    "portal_color": "#15803d",
    "portal_entorno": "prod",
    "portal_version": "1.0.0",
    "portal_worker_connections": 2048
}
```

### 11 — Entiende por qué gana el 768

**Acción:** ensaya en `prod-web2` pasando el valor por línea de comandos:

```bash
ansible-playbook -i inventories/prod/hosts.yml portal.yml --limit prod-web2 --check --diff -e portal_worker_connections=2048
```

**Por qué:** las `vars:` del play tienen más precedencia que `host_vars/` del inventario: el `768` del paso 7
tapa el `2048` de `prod-web2`. Solo `-e` está por encima del play.

**Resultado esperado:**

```text
TASK [Configurar nginx (nginx.conf)] *******************************************
--- before: /etc/nginx/nginx.conf
+++ after: …/nginx.conf.j2
@@ -5,7 +5,7 @@
 include /etc/nginx/modules-enabled/*.conf;
 
 events {
-    worker_connections 768;
+    worker_connections 2048;
 }
 
 http {

changed: [prod-web2]
```

Con `-e` sí llegaría, pero un valor que hay que recordar escribir en cada ejecución no es una configuración.
El arreglo de verdad es dejar el `768` como un valor **por defecto** con menos precedencia que el inventario:
es lo que hacen los `defaults` de un rol, y lo verás al convertir este playbook en el rol del portal en el
[M05 — Modularización](../M05-modularizacion/README.md). Por ahora el proyecto se queda así.

## Comprueba tu entendimiento

**De dónde sale cada número**
`ansible-inventory -i inventories/prod/hosts.yml --host prod-web2`
→ Aparece `"portal_worker_connections": 2048`, pero no `processor_vcpus` ni el `768` del play: `ansible-inventory` solo ve el inventario; los facts y las `vars:` del play existen en la ejecución.

**Idempotencia**
Vuelve a lanzar `ansible-playbook portal.yml`.
→ `changed=0`: el fact no cambia entre ejecuciones y el fichero renderizado coincide con el del nodo.

## Reto

### 1 — Sin facts

Añade `gather_facts: false` al play, debajo de `become: true`, y ensaya en dev con `--check --diff`. ¿Qué
pasaría con `worker_processes`? Después quita la línea.

<details>
<summary>Ver solución</summary>

```text
TASK [Configurar nginx (nginx.conf)] *******************************************
--- before: /etc/nginx/nginx.conf
+++ after: …/nginx.conf.j2
@@ -1,6 +1,6 @@
 # Ansible managed
 user www-data;
-worker_processes 8;
+worker_processes 1;
```

Sin **Gathering Facts**, `ansible_facts['processor_vcpus']` no existe y entra el `default(1)`: la plantilla no
falla, pero nginx se quedaría con un proceso. `gather_facts: false` acelera los plays que no usan facts; este
sí los usa.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `worker_processes 1;` en un nodo con varios núcleos | El play tiene `gather_facts: false` | Quítalo, o ejecuta `ansible.builtin.setup` antes |
| `object of type 'dict' has no attribute 'processor_vcpus'` | Consulta ad hoc con `debug`, sin `setup` antes | Es lo esperado: los facts se recogen en el play |
| `prod-web2` sale con `768` aunque su `host_vars` dice `2048` | `portal_worker_connections` está en `vars:` del play, que gana a `host_vars` | Es lo esperado en este punto; se resuelve con los `defaults` de un rol (M05). Para una prueba, `-e` |
| La tarea de `nginx.conf` falla con `failed to validate` | La plantilla genera un `nginx.conf` que `nginx -t` no acepta (falta un `;` o una llave) | Corrige la plantilla; el fichero del nodo no se ha tocado |
| `nginx -T` sigue mostrando lo antiguo | La recarga solo mira `portal_sitio_conf` | `when: portal_nginx_conf is changed or portal_sitio_conf is changed` |
