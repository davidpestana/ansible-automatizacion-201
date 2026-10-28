# Lab — Inventario dinámico

[← Página anterior](03-lab-inventarios-por-entornos.md) · [Siguiente página →](../M03-desarrollo-playbooks/README.md)

Los nodos del portal de Tienda Norte son contenedores, y Docker ya sabe cuáles hay, su IP y, por sus
etiquetas, de qué entorno son y qué papel tienen. Mantener además un `hosts.yml` a mano es tener el mismo dato
en dos sitios. En este lab generas el inventario a partir de Docker con el plugin
`community.docker.docker_containers`: los grupos salen de las etiquetas, la IP del propio contenedor, y
Ansible sigue conectando por SSH, como con cualquier servidor.

### Objetivo

`proyecto/inventories/dinamico/docker.yml`, que devuelve los seis nodos agrupados en `dev`, `pre`, `prod`,
`web`, `lb` y `db`, y con el que `ansible 'prod:&web' -m ansible.builtin.ping` responde por SSH. Un
contenedor nuevo con las etiquetas aparece solo.

### Punto de partida

- Terminal del Codespace, en la raíz del repositorio (`cd "$CODESPACE_VSCODE_FOLDER"`).
- Los seis nodos levantados: `scripts/nodos.sh estado` da seis líneas `SSH ok`.
- `proyecto/` en el punto de partida `m03`: inventarios estáticos en `inventories/{dev,pre,prod}/hosts.yml`.
  El plugin necesita la librería `requests` de Python, que ya está en el Codespace (`requirements.txt`).
  El paso 1 te deja ahí.

### En qué consiste

Creas un fichero de configuración del plugin y lo vas completando: filtro, grupos, conexión. Lanzas un
contenedor de prueba y lo borras. Los inventarios estáticos no se tocan: el dinámico es otra fuente, que se
usa con `-i`.

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repositorio
scripts/partida.sh m03
cd proyecto
```

**Por qué:** te deja el proyecto con los inventarios por entorno, venga de donde vengas.

**Resultado esperado:** `Listo: proyecto/ en el punto de partida «m03» …`.

### 2 — Mira lo que Docker sabe de los nodos

**Acción:**

```bash
docker ps --filter label=tienda-norte.rol --format 'table {{.Names}}\t{{.Label "tienda-norte.entorno"}}\t{{.Label "tienda-norte.rol"}}'
```

**Por qué:** `infra/compose.yaml` pone a cada nodo dos etiquetas, `tienda-norte.entorno` y `tienda-norte.rol`.
Son la fuente de la que va a beber el inventario.

**Resultado esperado** (el orden puede variar):

```text
NAMES       entorno   rol
prod-web2   prod      web
prod-web1   prod      web
pre-web1    pre       web
prod-db1    prod      db
dev-web1    dev       web
prod-lb1    prod      lb
```

### 3 — Consulta el plugin instalado

**Acción:** `ansible-doc -t inventory community.docker.docker_containers`

**Por qué:** las opciones cambian entre versiones de la colección. La documentación que vale es la de la
versión que tienes, y `ansible-doc` la enseña. Busca en ella `connection_type`, `filters`, `keyed_groups` y
`compose` (con <kbd>/</kbd> dentro del paginador; <kbd>q</kbd> para salir).

**Resultado esperado:** empieza por:

```text
> INVENTORY community.docker.docker_containers (…/ansible_collections/community/docker/plugins/inventory/docker_containers.py)

  Reads inventories from the Docker API.
```

y en las notas: `The configuration file must be a YAML file whose filename ends with docker.yml or docker.yaml`.

### 4 — Crea un inventario mínimo con filtro

**Acción:** `mkdir -p inventories/dinamico` y crea `proyecto/inventories/dinamico/docker.yml`:

```yaml
# proyecto/inventories/dinamico/docker.yml
plugin: community.docker.docker_containers
strict: true
filters:
  - include: "'tienda-norte.rol' in docker_config.Labels"
  - exclude: true
```

Ejecuta `ansible-inventory -i inventories/dinamico/docker.yml --graph`.

**Por qué:** `plugin` dice qué plugin lee el fichero, y su nombre tiene que acabar en `docker.yml`. Sin
filtros entraría *cualquier* contenedor del Codespace (en el M11, por ejemplo, el de kind de AWX). Los filtros
se evalúan en orden y el primero que encaja decide: se incluye lo que tiene la etiqueta `tienda-norte.rol`, y
se excluye todo lo demás. `strict: true` hace que una expresión mal escrita sea un error y no un fallo
silencioso.

**Resultado esperado:**

```text
@all:
  |--@ungrouped:
  |  |--prod-web2
  |  |--prod-web1
  |  |--pre-web1
  |  |--prod-db1
  |  |--dev-web1
  |  |--prod-lb1
```

Los seis nodos, con el nombre del contenedor, y todos en `ungrouped`.

### 5 — Agrupa por las etiquetas

**Acción:** añade al final de `docker.yml`:

```yaml
keyed_groups:
  - key: docker_config.Labels['tienda-norte.entorno']
    separator: ""
  - key: docker_config.Labels['tienda-norte.rol']
    separator: ""
```

Ejecuta `ansible-inventory -i inventories/dinamico/docker.yml --graph`.

**Por qué:** `keyed_groups` crea un grupo por cada valor distinto de la clave: uno por entorno y otro por
rol. Sin `prefix` y con `separator: ""`, el grupo se llama igual que el valor (`prod`, `web`), los mismos
nombres que en los inventarios estáticos.

**Resultado esperado:**

```text
@all:
  |--@ungrouped:
  |--@prod:
  |  |--prod-web2
  |  |--prod-web1
  |  |--prod-db1
  |  |--prod-lb1
  |--@web:
  |  |--prod-web2
  |  |--prod-web1
  |  |--pre-web1
  |  |--dev-web1
  |--@pre:
  |  |--pre-web1
  |--@db:
  |  |--prod-db1
  |--@dev:
  |  |--dev-web1
  |--@lb:
  |  |--prod-lb1
```

### 6 — Mira cómo conectaría

**Acción:** `ansible-inventory -i inventories/dinamico/docker.yml --host prod-web1`

**Por qué:** antes de lanzar nada, comprueba con qué variables de conexión llega cada nodo.

**Resultado esperado:**

```text
{
    "ansible_connection": "community.docker.docker_api",
    "ansible_docker_api_version": "auto",
    "ansible_docker_docker_host": "unix:///var/run/docker.sock",
    "ansible_docker_timeout": 60,
    "ansible_docker_tls": false,
    "ansible_docker_use_ssh_client": false,
    "ansible_docker_validate_certs": false,
    "ansible_host": "prod-web1",
    "docker_name": "prod-web1",
    "docker_short_id": "…"
}
```

Por defecto el plugin entra en los contenedores por la API de Docker, como un `docker exec`. Funcionaría,
pero no es como se gestionan los servidores del portal ni como se gestionará uno real: el curso conecta
por SSH, con el usuario `ansible` y su clave.

### 7 — Pide conexión por SSH con la IP del contenedor

**Acción:** debajo de `strict: true`, añade:

```yaml
connection_type: ssh
compose:
  ansible_host: docker_networksettings.Networks['tienda-norte_portal'].IPAddress
```

Guarda y ejecuta:

```bash
ansible-inventory -i inventories/dinamico/docker.yml --host prod-web1
ansible -i inventories/dinamico/docker.yml prod-web1 -m ansible.builtin.ping
```

**Por qué:** `compose` crea variables con expresiones sobre los datos del contenedor. La IP está en la red
`tienda-norte_portal` (la red `portal` del proyecto Compose `tienda-norte`).

**Resultado esperado:** el ping **falla**:

```text
{
    "ansible_host": "172.30.0.21",
    "ansible_ssh_host": "",
    "ansible_ssh_port": 0,
    "docker_name": "prod-web1",
    "docker_short_id": "…"
}
```

```text
prod-web1 | UNREACHABLE! => {
    "changed": false,
    "msg": "Task failed: Failed to connect to the host via ssh: command-line line 0: Bad port '0'.",
    "unreachable": true
}
```

Con `connection_type: ssh`, el plugin rellena `ansible_ssh_host` y `ansible_ssh_port` con el puerto 22
*publicado* en el Codespace. Los nodos no publican el 22 (se llega a ellos por su red), así que quedan vacío
y 0. `ansible_ssh_host` es el nombre antiguo de `ansible_host` y, si los dos existen, la conexión SSH usa
`ansible_ssh_host`: tu IP se ignora.

### 8 — Sustituye las variables del plugin

**Acción:** cambia el bloque `compose` por:

```yaml
compose:
  ansible_ssh_host: docker_networksettings.Networks['tienda-norte_portal'].IPAddress
  ansible_ssh_port: "22"
```

**Por qué:** pones la IP y el puerto en las mismas variables que rellena el plugin, así que las tuyas las
sustituyen. Cada valor de `compose` es una expresión Jinja2 en texto: `"22"` entre comillas; un `22` sin
comillas es un número y, con `strict: true`, da `Expressions must be <class 'str'>`.

**Resultado esperado:** `ansible-inventory -i inventories/dinamico/docker.yml --host prod-web1` da:

```text
{
    "ansible_ssh_host": "172.30.0.21",
    "ansible_ssh_port": 22,
    "docker_name": "prod-web1",
    "docker_short_id": "…"
}
```

El fichero completo queda así:

```yaml
# proyecto/inventories/dinamico/docker.yml
plugin: community.docker.docker_containers
strict: true
connection_type: ssh
compose:
  ansible_ssh_host: docker_networksettings.Networks['tienda-norte_portal'].IPAddress
  ansible_ssh_port: "22"
filters:
  - include: "'tienda-norte.rol' in docker_config.Labels"
  - exclude: true
keyed_groups:
  - key: docker_config.Labels['tienda-norte.entorno']
    separator: ""
  - key: docker_config.Labels['tienda-norte.rol']
    separator: ""
```

### 9 — Usa los grupos generados

**Acción:**

```bash
ansible -i inventories/dinamico/docker.yml 'prod:&web' -m ansible.builtin.ping
ansible -i inventories/dinamico/docker.yml pre -m ansible.builtin.command -a hostname
```

**Por qué:** los patrones funcionan igual que con el inventario estático, porque los grupos se llaman igual.
El `hostname` confirma que el comando se ejecuta dentro del nodo, por SSH.

**Resultado esperado:** `prod-web1 | SUCCESS` y `prod-web2 | SUCCESS` con `"ping": "pong"`, y:

```text
pre-web1 | CHANGED | rc=0 >>
pre-web1
```

### 10 — Añade un nodo sin tocar el inventario

**Acción:** lanza un tercer servidor web de prod con la misma imagen y las mismas etiquetas:

```bash
docker run -d --name prod-web3 --hostname prod-web3 --network tienda-norte_portal \
  --label tienda-norte.entorno=prod --label tienda-norte.rol=web \
  -v ~/.ssh/curso-ansible:/run/claves:ro tienda-norte/nodo:1
```

Después:

```bash
ansible-inventory -i inventories/dinamico/docker.yml --graph web
ansible -i inventories/dinamico/docker.yml 'prod:&web' -m ansible.builtin.ping
```

**Por qué:** es lo que justifica un inventario dinámico. El inventario se calcula en cada ejecución, así que
el contenedor nuevo entra en `web` y en `prod` por sus etiquetas, sin editar ningún fichero. El volumen le da
la clave pública del curso para que acepte el SSH de `ansible`.

**Resultado esperado:** `docker run` imprime el identificador del contenedor, y:

```text
@web:
  |--prod-web3
  |--prod-web2
  |--prod-web1
  |--pre-web1
  |--dev-web1
```

El ping responde `SUCCESS` en `prod-web1`, `prod-web2` y `prod-web3`.

### 11 — Retira el nodo de prueba

**Acción:**

```bash
docker rm -f prod-web3
ansible -i inventories/dinamico/docker.yml 'prod:&web' --list-hosts
```

**Por qué:** deja el entorno como estaba y confirma que, al desaparecer el contenedor, desaparece del inventario.

**Resultado esperado:**

```text
  hosts (2):
    prod-web2
    prod-web1
```

## Comprueba tu entendimiento

**De dónde sale cada grupo**
Ejecuta `ansible-inventory -i inventories/dinamico/docker.yml --graph db` y explica por qué contiene `prod-db1`.
→ `@db` con `prod-db1`: el contenedor tiene la etiqueta `tienda-norte.rol=db` y `keyed_groups` crea un grupo
por cada valor.

**Estático frente a dinámico**
Compara `ansible -i inventories/prod/hosts.yml web --list-hosts` con `ansible -i inventories/dinamico/docker.yml 'prod:&web' --list-hosts`.
→ Los dos dan `prod-web1` y `prod-web2`: el mismo conjunto, uno escrito a mano y otro calculado desde Docker.

**Por qué no entra cualquier contenedor**
Di qué pasaría con un contenedor sin la etiqueta `tienda-norte.rol`.
→ No encaja con el `include` y lo recoge el último filtro, `exclude: true`: no aparece en el inventario.

## Reto

### 1 — El frontal de prod como grupo

Tienda Norte llama «frontal» a lo que recibe tráfico de clientes en prod: el balanceador y los servidores web.
Haz que el inventario dinámico cree el grupo `frontal` con esos tres nodos. Busca en `ansible-doc` la opción
que crea grupos a partir de una condición.

<details>
<summary>Ver solución</summary>

La opción es `groups`: cada clave es un grupo y su valor, una condición Jinja2. Añade al final de `docker.yml`:

```yaml
groups:
  frontal: >-
    docker_config.Labels['tienda-norte.entorno'] == 'prod'
    and docker_config.Labels['tienda-norte.rol'] in ['web', 'lb']
```

```bash
ansible-inventory -i inventories/dinamico/docker.yml --graph frontal
```

```text
@frontal:
  |--prod-web2
  |--prod-web1
  |--prod-lb1
```

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `inventory source '…/contenedores.yml' could not be verified by inventory plugin 'community.docker.docker_containers'` y después `Invalid host pattern 'plugin:'` | El fichero no acaba en `docker.yml`: el plugin lo rechaza y Ansible lo intenta leer como YAML e INI | Llámalo `docker.yml` (o `algo.docker.yml`) |
| `UNREACHABLE! … Bad port '0'` | `connection_type: ssh` sin `ansible_ssh_port`/`ansible_ssh_host` en `compose`: el plugin busca un puerto 22 publicado que no existe | Pon en `compose` `ansible_ssh_host` con la IP y `ansible_ssh_port: "22"` |
| `Could not set ansible_ssh_port … Expressions must be <class 'str'>` | En `compose`, `22` sin comillas: los valores tienen que ser expresiones en texto | Escribe `ansible_ssh_port: "22"` |
| Aparecen contenedores que no son del portal | Falta el filtro o el `exclude: true` final: lo que no encaja con ningún filtro se incluye | Deja `- exclude: true` como último filtro |
| `--graph` muestra `web`, `lb` y `db` pero faltan `dev`, `pre` y `prod` | Errata en la etiqueta de una clave de `keyed_groups` (`tienda-norte.entrono`) con `strict: false`: la expresión falla en silencio | Usa `strict: true` para ver el error y copia el nombre de la etiqueta de `infra/compose.yaml` |
