# Lab — Instalar y configurar Ansible

[← Página anterior](00-que-es-ansible.md) · [Siguiente página →](02-del-runbook-al-playbook.md)

Antes de automatizar el runbook del portal, el equipo de operaciones de Tienda Norte quiere saber qué es
exactamente lo que va a instalar en sus máquinas de administración y qué hace Ansible cada vez que toca un
servidor. En el Codespace Ansible ya viene instalado; en este lab lo instalas tú desde cero, en un directorio
aparte, lo configuras con tu propio `ansible.cfg` y sigues una ejecución por dentro: qué viaja por SSH, qué se
ejecuta en el nodo y qué queda después.

### Objetivo

Un Ansible instalado por ti en `~/ansible-desde-cero/.venv`, con su `ansible.cfg` y su inventario, que hace
`ping` a `dev-web1` y `pre-web1`; haber visto en `dev-web1` el módulo que Ansible le envía; y una colección
instalada en el propio directorio y localizada por Ansible.

### Punto de partida

- Terminal del Codespace. Los nodos se levantan solos al arrancar el Codespace.
- Estado: no depende de `proyecto/` ni de ninguna página anterior. Trabajas en `~/ansible-desde-cero`, fuera
  del repositorio, y lo borras al final.
- Credenciales: el usuario remoto de los nodos es `ansible` y la clave, `~/.ssh/curso-ansible/curso_ansible`.
  La genera el Codespace al arrancar.

### En qué consiste

Miras qué necesita cada lado (nodo de control y nodo gestionado), instalas `ansible-core` con una versión
fijada, le das una configuración mínima, compruebas de dónde sale cada ajuste y lanzas un `ping` con el máximo
detalle para ver sus fases. Después conservas en el nodo el fichero que Ansible le envía, lo abres, y terminas
instalando una colección. En los nodos solo haces consultas: no cambias nada.

### 1 — Mira qué Ansible usa el Codespace

**Acción:**

```bash
# Terminal del Codespace
which ansible
ansible --version | head -1
pip show ansible | head -2
```

**Por qué:** Ansible es un programa de Python que se instala solo en el **nodo de control**, la máquina desde
la que se lanza. El Codespace lo instala al crearse con `pip install -r requirements.txt`, en un entorno
virtual propio. Saber cuál se está usando evita sorpresas cuando hay más de una instalación.

**Resultado esperado:**

```text
/home/vscode/.venv/bin/ansible
ansible [core 2.20.10]
Name: ansible
Version: 13.8.0
```

Hay dos números: `ansible` 13.8.0 es el paquete completo (el motor más un lote de colecciones) y `core 2.20.10`
es la versión del motor, `ansible-core`, que lleva dentro.

### 2 — Mira qué necesita un nodo gestionado

**Acción:**

```bash
# Terminal del Codespace
ssh -F "$CODESPACE_VSCODE_FOLDER/infra/ssh_config" dev-web1 \
  'hostname; python3 --version; sudo -n true && echo "sudo sin contraseña"; dpkg -l | grep -c ansible'
```

**Por qué:** en los **nodos gestionados** Ansible no instala nada. Le basta con tres cosas: entrar por SSH,
encontrar un Python con el que ejecutar sus módulos y, para tareas de administración, un usuario que pueda
usar `sudo`. `infra/ssh_config` traduce `dev-web1` a su IP y fija el usuario `ansible` y la clave del curso.

**Resultado esperado:**

```text
dev-web1
Python 3.13.5
sudo sin contraseña
0
```

El `0` final: no hay ningún paquete de Ansible en el nodo.

### 3 — Crea un entorno virtual aparte

**Acción:**

```bash
# Terminal del Codespace
mkdir -p ~/ansible-desde-cero && cd ~/ansible-desde-cero
python3 -m venv .venv
source .venv/bin/activate
which python pip
```

**Por qué:** instalar Ansible con `pip` dentro de un entorno virtual (*venv*) lo aísla del Python del sistema
y de otras instalaciones: puedes tener una versión por proyecto y borrarla sin dejar rastro. Es la forma
recomendada cuando se necesita una versión concreta; `apt install ansible` instala la que trae la
distribución.

**Resultado esperado:** el prompt empieza por `(.venv)` y:

```text
/home/vscode/ansible-desde-cero/.venv/bin/python
/home/vscode/ansible-desde-cero/.venv/bin/pip
```

### 4 — Instala ansible-core con la versión fijada

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
pip install -q "ansible-core==2.20.10"
which ansible
pip list
```

**Por qué:** fijar la versión (`==`) hace que la instalación sea repetible: hoy, en otra máquina o en un
pipeline sale lo mismo. Instalas solo `ansible-core`, el motor, para ver qué trae por sí mismo.

**Resultado esperado:** `pip` puede mostrar un aviso `[notice]` de que hay una versión nueva de pip; no afecta.
`ansible` ahora es el del venv, y `pip list` muestra el motor y sus pocas dependencias:

```text
/home/vscode/ansible-desde-cero/.venv/bin/ansible
Package      Version
------------ -------
ansible-core 2.20.10
cffi         2.1.1
cryptography 50.0.2
Jinja2       3.1.6
MarkupSafe   3.0.4
packaging    26.3
pip          25.0.1
pycparser    3.12
PyYAML       6.0.3
resolvelib   1.2.1
```

Jinja2 es el motor de plantillas y PyYAML lee los playbooks; las verás trabajar en los módulos siguientes.

### 5 — Lee `ansible --version`

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
ansible --version
```

**Por qué:** es el primer comando ante cualquier duda: dice qué Ansible se ejecuta, con qué Python, qué
configuración ha cargado y dónde busca módulos y colecciones.

**Resultado esperado:**

```text
ansible [core 2.20.10]
  config file = None
  configured module search path = ['/home/vscode/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /home/vscode/ansible-desde-cero/.venv/lib/python3.12/site-packages/ansible
  ansible collection location = /home/vscode/.ansible/collections:/usr/share/ansible/collections
  executable location = /home/vscode/ansible-desde-cero/.venv/bin/ansible
  python version = 3.12.16 (main, …) [GCC 13.3.0] (/home/vscode/ansible-desde-cero/.venv/bin/python3.12)
  jinja version = 3.1.6
  pyyaml version = 6.0.3 (with libyaml v0.2.5)
```

| Línea | Qué te dice |
|-------|-------------|
| `config file` | El `ansible.cfg` cargado. `None`: ninguno, todo va con valores por defecto |
| `configured module search path` | Carpetas extra donde busca módulos propios |
| `ansible python module location` | Dónde está instalado el motor: aquí, dentro del venv |
| `ansible collection location` | Dónde busca colecciones instaladas con `ansible-galaxy` |
| `executable location` | Qué ejecutable `ansible` se ha lanzado |
| `python version` | El Python del **nodo de control** (el de los nodos es otro: 3.13 en `dev-web1`) |

### 6 — Compara lo que trae cada instalación

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
ansible-doc -l | wc -l
ansible-doc -l | head -3
ansible-galaxy collection list
/home/vscode/.venv/bin/ansible-galaxy collection list 2>/dev/null | grep -c '^[a-z]'
```

**Por qué:** los módulos se agrupan en **colecciones** (`ansible.builtin`, `community.docker`,
`amazon.aws`…). `ansible-core` solo trae `ansible.builtin`; el paquete `ansible` del Codespace añade decenas
de colecciones. La última línea consulta la instalación del Codespace sin salir del venv.

**Resultado esperado:**

```text
71
ansible.builtin.add_host               Add a host (and alternatively a grou...
ansible.builtin.apt                    Manages apt-packages
ansible.builtin.apt_key                Add or remove an apt key
[ERROR]: - None of the provided paths were usable. Please specify a valid path with --collections-path
95
```

71 módulos, todos `ansible.builtin`, y ninguna colección instalada (de ahí el error). El paquete del Codespace
tiene 95 colecciones. Con `ansible-core` y solo las colecciones que se necesitan, la instalación es pequeña
y se sabe qué hay; con `ansible` se tiene casi todo a mano a cambio de mucho más tamaño.

### 7 — Comprueba la configuración sin `ansible.cfg`

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
ls ~/.ansible.cfg /etc/ansible/ansible.cfg
ansible-config dump --only-changed
```

**Por qué:** Ansible busca su configuración en este orden y se queda con **el primer** fichero que encuentra
(no los mezcla):

1. La variable de entorno `ANSIBLE_CONFIG`.
2. `ansible.cfg` en el directorio actual.
3. `~/.ansible.cfg` en tu carpeta personal.
4. `/etc/ansible/ansible.cfg`.

`ansible-config dump --only-changed` lista solo los ajustes que difieren del valor por defecto, y de dónde
sale cada uno.

**Resultado esperado:** no existe ninguno de los dos ficheros globales y no hay nada cambiado:

```text
ls: cannot access '/home/vscode/.ansible.cfg': No such file or directory
ls: cannot access '/etc/ansible/ansible.cfg': No such file or directory
CONFIG_FILE() = None

GALAXY_SERVERS:
```

### 8 — Crea el inventario y el `ansible.cfg`

**Acción:** crea los dos ficheros desde el terminal:

```bash
# Terminal del Codespace, en ~/ansible-desde-cero
cat > inventario.ini <<'EOF'
[web]
dev-web1 ansible_host=172.30.0.11
pre-web1 ansible_host=172.30.0.12
EOF

cat > ansible.cfg <<'EOF'
[defaults]
inventory = inventario.ini
remote_user = ansible
private_key_file = ~/.ssh/curso-ansible/curso_ansible
host_key_checking = False
EOF

ansible-inventory --graph
```

**Por qué:** el inventario dice **a qué** máquinas conectar; `ansible_host` le da a cada nombre su IP. El
`ansible.cfg` dice **cómo**: qué inventario usar si no se pasa `-i`, con qué usuario y qué clave.
`host_key_checking = False` evita la pregunta de huella SSH con estos nodos de laboratorio, que se recrean
con huellas nuevas; en servidores reales se deja activado.

**Resultado esperado:**

```text
@all:
  |--@ungrouped:
  |--@web:
  |  |--dev-web1
  |  |--pre-web1
```

### 9 — Mira qué ha cambiado y de dónde sale

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
ansible --version | grep "config file"
ansible-config dump --only-changed
```

**Por qué:** confirmas que Ansible ha encontrado tu fichero (punto 2 del orden de búsqueda) y ves cada ajuste
con su nombre interno y su origen entre paréntesis.

**Resultado esperado:**

```text
  config file = /home/vscode/ansible-desde-cero/ansible.cfg
CONFIG_FILE() = /home/vscode/ansible-desde-cero/ansible.cfg
DEFAULT_HOST_LIST(/home/vscode/ansible-desde-cero/ansible.cfg) = ['/home/vscode/ansible-desde-cero/inventario.ini']
DEFAULT_PRIVATE_KEY_FILE(/home/vscode/ansible-desde-cero/ansible.cfg) = /home/vscode/.ssh/curso-ansible/curso_ansible
DEFAULT_REMOTE_USER(/home/vscode/ansible-desde-cero/ansible.cfg) = ansible
HOST_KEY_CHECKING(/home/vscode/ansible-desde-cero/ansible.cfg) = False

GALAXY_SERVERS:
```

### 10 — Sobrescribe un ajuste con una variable de entorno

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
ANSIBLE_REMOTE_USER=root ansible-config dump --only-changed | grep REMOTE_USER
ansible-config list | grep -A10 "^DEFAULT_REMOTE_USER:"
```

**Por qué:** casi todos los ajustes tienen también una variable `ANSIBLE_*`, que gana al `ansible.cfg`. Es
útil para cambiar algo en una sola ejecución (en un pipeline, por ejemplo) sin tocar el fichero.
`ansible-config list` documenta cada ajuste: su clave en el fichero, su variable de entorno y para qué sirve.

**Resultado esperado:** el origen ya no es el fichero, sino la variable:

```text
DEFAULT_REMOTE_USER(env: ANSIBLE_REMOTE_USER) = root
DEFAULT_REMOTE_USER:
  description:
  - Sets the login user for the target machines
  - When blank it uses the connection plugin's default, normally the user currently
    executing Ansible.
  env:
  - name: ANSIBLE_REMOTE_USER
  ini:
  - key: remote_user
    section: defaults
  name: Login/Remote User
```

### 11 — Comprueba que `ANSIBLE_CONFIG` gana a todo

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
printf '[defaults]\nremote_user = otro\n' > /tmp/otro.cfg
ANSIBLE_CONFIG=/tmp/otro.cfg ansible --version | grep "config file"
rm /tmp/otro.cfg
```

**Por qué:** es el primer punto del orden de búsqueda: con `ANSIBLE_CONFIG` definida, el `ansible.cfg` del
directorio ni se lee. Si alguna vez Ansible «no hace caso» a tu `ansible.cfg`, mira si esa variable está
definida (`env | grep ANSIBLE`).

**Resultado esperado:**

```text
  config file = /tmp/otro.cfg
```

### 12 — Provoca el aviso del directorio con escritura para todos

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
chmod o+w .
ansible --version | grep "config file"
chmod o-w .
ansible --version | grep "config file"
```

**Por qué:** un `ansible.cfg` puede ejecutar código (plugins, rutas, scripts de inventario). Si cualquier
usuario de la máquina puede escribir en el directorio, Ansible no se fía de él y lo ignora. Es un fallo
habitual en carpetas compartidas o montadas con permisos amplios.

**Resultado esperado:** con el permiso abierto, Ansible avisa y se queda sin configuración; al cerrarlo, la
recupera:

```text
[WARNING]: Ansible is being run in a world writable directory (/home/vscode/ansible-desde-cero), ignoring it as an ansible.cfg source. For more information see https://docs.ansible.com/ansible/devel/reference_appendices/config.html#cfg-in-world-writable-dir
  config file = None
  config file = /home/vscode/ansible-desde-cero/ansible.cfg
```

### 13 — Haz un ping a los dos nodos

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
ansible all -m ansible.builtin.ping
```

**Por qué:** el módulo `ping` no es un ping de red: entra por SSH, ejecuta un pequeño programa Python en el
nodo y devuelve `pong`. Si responde, la cadena completa funciona: inventario, usuario, clave y Python remoto.

**Resultado esperado:** los dos nodos responden, con un aviso por nodo:

```text
[WARNING]: Host 'pre-web1' is using the discovered Python interpreter at '/usr/bin/python3.13', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.20/reference_appendices/interpreter_discovery.html for more information.
[WARNING]: Host 'dev-web1' is using the discovered Python interpreter at '/usr/bin/python3.13', …
pre-web1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
dev-web1 | SUCCESS => {
    …
}
```

Antes de ejecutar nada, Ansible ha buscado qué Python hay en cada nodo (*interpreter discovery*) y avisa de
que ha elegido uno. Para dejar constancia de que esa elección es la buscada y quitar el aviso, añade una línea
a la sección `[defaults]`:

```bash
# Terminal del Codespace, en ~/ansible-desde-cero
echo "interpreter_python = auto_silent" >> ansible.cfg
ansible all -m ansible.builtin.ping
```

Ahora salen los dos `SUCCESS` sin avisos.

### 14 — Sigue una ejecución por dentro

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
ansible dev-web1 -m ansible.builtin.ping -vvv > /tmp/ping-vvv.txt
grep -n "Using module file\|PUT \|python3.13 /home\|rm -f -r" /tmp/ping-vvv.txt | cut -c1-200
```

**Por qué:** `-vvv` muestra cada comando que Ansible lanza. Así se ve que «agentless» no es magia: es SSH
y Python.

**Resultado esperado** (las rutas temporales cambian en cada ejecución):

```text
28:Using module file /home/vscode/ansible-desde-cero/.venv/lib/python3.12/site-packages/ansible/modules/ping.py
29:<172.30.0.11> PUT /home/vscode/.ansible/tmp/ansible-local-49921qo_ynt52/tmpdusrlfar TO /home/ansible/.ansible/tmp/ansible-tmp-1793171386.9523668-49957-61697444435872/AnsiballZ_ping.py
…
```

Abre `/tmp/ping-vvv.txt` en VS Code (`code /tmp/ping-vvv.txt`) y sigue las fases en orden:

| Fase | Qué aparece en el log |
|------|-----------------------|
| 1. Directorio de usuario | `echo ~ansible` → `/home/ansible` |
| 2. Directorio temporal | `mkdir … /home/ansible/.ansible/tmp/ansible-tmp-…` |
| 3. Buscar Python | `command -v python3.14; command -v python3.13; …` → `/usr/bin/python3.13` |
| 4. Subir el módulo | `Using module file …/ansible/modules/ping.py` y `sftp> put … AnsiballZ_ping.py` |
| 5. Ejecutarlo | `/usr/bin/python3.13 …/AnsiballZ_ping.py` → `{"ping": "pong", …}` |
| 6. Limpiar | `rm -f -r /home/ansible/.ansible/tmp/ansible-tmp-…/` |

El módulo vive en el **nodo de control** (`ansible/modules/ping.py`). Ansible lo empaqueta con lo que
necesita en un solo fichero, **AnsiballZ**, lo sube al nodo, lo ejecuta con el Python remoto, recoge el JSON
que imprime y borra el temporal. Cada fase es una conexión SSH distinta (reaprovechada con `ControlMaster`).

### 15 — Conserva el módulo en el nodo y ábrelo

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
ANSIBLE_KEEP_REMOTE_FILES=1 ansible dev-web1 -m ansible.builtin.ping
ssh -F "$CODESPACE_VSCODE_FOLDER/infra/ssh_config" dev-web1 'ls -l ~/.ansible/tmp/*/'
```

Ahora entra en el nodo, desempaqueta el fichero y ejecútalo a mano:

```bash
# Terminal del Codespace
ssh -F "$CODESPACE_VSCODE_FOLDER/infra/ssh_config" dev-web1
```

```bash
# Nodo dev-web1
cd ~/.ansible/tmp/ansible-tmp-*/
python3 AnsiballZ_ping.py explode
find debug_dir -maxdepth 3 | head
python3 AnsiballZ_ping.py
rm -rf ~/.ansible/tmp/ansible-tmp-*
exit
```

**Por qué:** `ANSIBLE_KEEP_REMOTE_FILES=1` se salta la fase 6 y deja el fichero en el nodo. Es la forma de
depurar un módulo que falla: lo puedes abrir, desempaquetar y relanzar fuera de Ansible.

**Resultado esperado:** en el nodo queda un único fichero ejecutable de unos 160 KB:

```text
-rwx------ 1 ansible ansible 167124 Oct 28 07:10 AnsiballZ_ping.py
```

`explode` lo desempaqueta en `debug_dir/`: dentro están los argumentos de la tarea y las librerías comunes de
Ansible (`module_utils`) que el módulo necesita:

```text
Module expanded into:
/home/ansible/.ansible/tmp/ansible-tmp-1793171407.4816566-51371-206911865324270/debug_dir
debug_dir
debug_dir/args
debug_dir/ansible
debug_dir/ansible/__init__.py
debug_dir/ansible/module_utils
debug_dir/ansible/module_utils/__init__.py
…
```

Y al ejecutarlo devuelve lo mismo que Ansible recibió por SSH:

```text
{"ping": "pong", "invocation": {"module_args": {"data": "pong"}}}
```

El `rm -rf` deja el nodo como estaba.

### 16 — Activa el pipelining y cuenta las conexiones

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
ansible dev-web1 -m ansible.builtin.ping -vvv | grep -c "SSH: EXEC"
ANSIBLE_PIPELINING=True ansible dev-web1 -m ansible.builtin.ping -vvv | grep -c "SSH: EXEC"
ANSIBLE_PIPELINING=True ansible dev-web1 -m ansible.builtin.ping -vvv | grep -c "PUT "
```

**Por qué:** con *pipelining*, Ansible no sube el fichero: abre una sola conexión, lanza el Python remoto y le
pasa el módulo por la entrada estándar. Menos conexiones por tarea, ejecuciones más rápidas. El `ansible.cfg`
de `proyecto/` lo tiene activado (`pipelining = True`).

**Resultado esperado:**

```text
7
2
0
```

Siete comandos SSH por tarea sin pipelining, dos con él, y ninguna subida de fichero.

### 17 — Instala una colección en el directorio

**Acción:** primero comprueba que el módulo `ansible.posix.acl` no existe en tu instalación:

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
ansible-doc ansible.posix.acl
```

Después declara la colección, dile a Ansible dónde guardarla e instálala:

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
cat > requirements.yml <<'EOF'
collections:
  - name: ansible.posix
    version: 2.2.0
EOF
echo "collections_path = ./collections" >> ansible.cfg
ansible-galaxy collection install -r requirements.yml
ansible-galaxy collection list
ansible-doc ansible.posix.acl | head -3
```

**Por qué:** un proyecto declara en `requirements.yml` las colecciones que usa, con su versión, igual que
`requirements.txt` fija los paquetes de Python. `collections_path` hace que se instalen dentro del proyecto y
no en `~/.ansible/collections`, así cada proyecto lleva las suyas.

**Resultado esperado:** antes de instalar, `ansible-doc` no encuentra el módulo:

```text
[WARNING]: Error loading plugin 'ansible.posix.acl': No module named 'ansible_collections.ansible.posix'
[WARNING]: ansible.posix.acl was not found
```

La instalación la descarga de Ansible Galaxy y la deja en `collections/`:

```text
Starting galaxy collection install process
Process install dependency map
Starting collection install process
Downloading https://galaxy.ansible.com/api/v3/plugin/ansible/content/published/collections/artifacts/ansible-posix-2.2.0.tar.gz to …
Installing 'ansible.posix:2.2.0' to '/home/vscode/ansible-desde-cero/collections/ansible_collections/ansible/posix'
ansible.posix:2.2.0 was installed successfully

# /home/vscode/ansible-desde-cero/collections/ansible_collections
Collection    Version
------------- -------
ansible.posix 2.2.0
> MODULE ansible.posix.acl (/home/vscode/ansible-desde-cero/collections/ansible_collections/ansible/posix/plugins/modules/acl.py)

  Set and retrieve file ACL information.
```

### 18 — Usa el módulo de la colección

**Acción:**

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
ansible dev-web1 -m ansible.posix.acl -a "path=/srv state=query"
```

**Por qué:** `state=query` solo consulta los permisos ACL de `/srv`, sin cambiar nada. Sirve para ver dónde
se ejecuta de verdad un módulo.

**Resultado esperado:** falla, y el motivo es la lección:

```text
[ERROR]: Task failed: Module failed: Failed to find required executable "getfacl" in paths: /usr/local/bin:/usr/bin:/bin:/usr/games:/sbin:/usr/sbin:/usr/local/sbin
…
dev-web1 | FAILED! => {
    …
    "changed": false,
    "msg": "Failed to find required executable \"getfacl\" in paths: /usr/local/bin:/usr/bin:/bin:/usr/games:/sbin:/usr/sbin:/usr/local/sbin"
}
```

Ansible ha encontrado la colección en el nodo de control y ha enviado el módulo, pero el módulo se ejecuta en
`dev-web1` y allí falta la herramienta `getfacl` (paquete `acl`). Las colecciones se instalan en el nodo de
control; lo que un módulo necesite para trabajar tiene que estar en el nodo gestionado. Instalar ese paquete
en los nodos sería, precisamente, una tarea de Ansible.

### 19 — Limpia

**Acción:**

```bash
# Terminal del Codespace
deactivate
cd ~
rm -rf ~/ansible-desde-cero /tmp/ping-vvv.txt
which ansible
```

**Por qué:** todo lo instalado vivía en el directorio del venv; al borrarlo no queda nada. El Codespace
vuelve a usar su propia instalación, que es la que usan el resto de labs.

**Resultado esperado:**

```text
/home/vscode/.venv/bin/ansible
```

## Comprueba tu entendimiento

<details>
<summary>¿Qué hay que instalar en un servidor nuevo para que Ansible lo pueda gestionar?</summary>

Nada de Ansible. Basta con que acepte SSH con el usuario y la clave que use Ansible, que tenga Python y, si
las tareas lo necesitan, que ese usuario pueda usar `sudo`. Todo lo demás viaja en cada ejecución.

</details>

<details>
<summary>Tienes un `ansible.cfg` en tu proyecto y otro en `~/.ansible.cfg`. ¿Cuál se aplica?</summary>

El del proyecto, si lanzas Ansible desde su directorio: es el segundo en el orden de búsqueda y el de tu
carpeta personal es el tercero. Solo se usa uno; los ajustes no se combinan. `ANSIBLE_CONFIG` ganaría a los
dos, y una variable `ANSIBLE_*` concreta gana al fichero en ese ajuste.

</details>

<details>
<summary>¿Dónde está el código de un módulo y dónde se ejecuta?</summary>

Está en el nodo de control, dentro de `ansible-core` o de una colección. Se ejecuta en el nodo gestionado,
con su Python, después de llegarle empaquetado como AnsiballZ (como fichero o, con pipelining, por la
entrada estándar).

</details>

## Reto

### 1 — El `ansible.cfg` completo

Genera en `~/ansible-desde-cero` un `ansible.cfg.completo` con todos los ajustes posibles comentados y busca
el valor por defecto de `forks` (cuántos nodos atiende Ansible a la vez).

<details>
<summary>Ver solución</summary>

```bash
# Terminal del Codespace, en ~/ansible-desde-cero con el venv activo
ansible-config init --disabled > ansible.cfg.completo
wc -l ansible.cfg.completo
grep -n "^;forks\|^;pipelining" ansible.cfg.completo
```

```text
697 ansible.cfg.completo
122:;forks=5
496:;pipelining=False
```

Casi 700 líneas, todas comentadas con `;`: es la plantilla de la que copiar lo que se necesite, no un fichero
para usar tal cual. `forks` vale 5 y el pipelining viene desactivado.

</details>

### 2 — Dos versiones a la vez

Sin borrar `ansible-desde-cero`, ¿cómo lanzarías un comando con el Ansible del Codespace y el siguiente con
el tuyo?

<details>
<summary>Ver solución</summary>

Con la ruta completa del ejecutable, sin activar ni desactivar nada: `/home/vscode/.venv/bin/ansible --version`
y `~/ansible-desde-cero/.venv/bin/ansible --version`. Activar un venv solo pone su carpeta `bin/` la primera
en el `PATH`; `which ansible` dice cuál gana en cada momento.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `ansible: command not found` tras abrir un terminal nuevo | El venv no está activo en ese terminal | `source ~/ansible-desde-cero/.venv/bin/activate` |
| `config file = None` estando en `~/ansible-desde-cero` | El directorio tiene permiso de escritura para todos (sale el aviso *world writable*) o `ANSIBLE_CONFIG` apunta a otro sitio | `chmod o-w ~/ansible-desde-cero`; `env \| grep ANSIBLE_CONFIG` |
| `UNREACHABLE! … Permission denied (publickey)` | Falta `remote_user` o `private_key_file` en `ansible.cfg`, y Ansible entra como `vscode` sin la clave del curso | Revisa con `ansible-config dump --only-changed` que salen `DEFAULT_REMOTE_USER` y `DEFAULT_PRIVATE_KEY_FILE` |
| `UNREACHABLE! … Connection timed out` | Los nodos no están levantados o la IP de `ansible_host` está mal | `docker ps` para ver los nodos; las IP están en `infra/ssh_config` |
| `[ERROR]: - None of the provided paths were usable` con `ansible-galaxy collection list` | No hay ninguna colección instalada en las rutas de búsqueda | Normal con solo `ansible-core`; instala las que necesites con `requirements.yml` |
| `ansible.posix.acl was not found` después de instalar la colección | La colección se instaló en otra ruta (sin `collections_path`) o se lanzó fuera del directorio | Comprueba `ansible-galaxy collection list` y que estás en `~/ansible-desde-cero` |
| `Failed to find required executable "getfacl"` | El módulo necesita una herramienta que no está en el nodo gestionado | Instálala en el nodo (paquete `acl`) con una tarea de Ansible antes de usar el módulo |
