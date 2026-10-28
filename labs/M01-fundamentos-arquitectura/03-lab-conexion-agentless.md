# Lab — Conexión agentless

[← Página anterior](02-del-runbook-al-playbook.md) · [Siguiente página →](04-lab-primer-playbook.md)

El primer paso del runbook de Tienda Norte es «entrar por SSH en el servidor». Antes de automatizar nada, el
equipo de operaciones quiere comprobar que desde el Codespace se llega a los seis nodos del portal con el usuario
y la clave del curso, y consultarlos todos de una vez en lugar de uno a uno. En este lab escribes el inventario,
lanzas tus primeros comandos ad hoc y compruebas en un nodo que Ansible no ha dejado nada instalado ni corriendo.

### Objetivo

`proyecto/inventario.ini` con los seis nodos del portal, `ansible all -m ansible.builtin.ping` respondiendo
`pong` en todos y la comprobación, en `dev-web1`, de que no queda ningún proceso de Ansible tras la ejecución.

### Punto de partida

- Terminal del Codespace. Los nodos se levantan solos al arrancar el Codespace.
- Estado: el proyecto en el punto `m01`: `proyecto/` tiene `ansible.cfg` y `app/`, pero **no** tiene inventario.
  El paso 1 te deja ahí aunque no vengas de la página anterior.
- Credenciales: el usuario remoto es `ansible` y la clave, `~/.ssh/curso-ansible/curso_ansible`. Las dos están
  ya en `ansible.cfg`; no las tienes que escribir.

### En qué consiste

Creas el inventario, entras en un nodo por SSH como lo haría Ansible, y lanzas los módulos `ping`, `command` y
`setup` contra los nodos. Terminas mirando dentro de `dev-web1` qué procesos hay. No cambias nada en los nodos:
todo lo de este lab son consultas.

### 1 — Prepara el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repositorio
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m01
cd proyecto
ls
```

**Por qué:** deja `proyecto/` exactamente como lo necesita este lab, sin inventario, sea cual sea el estado
en que lo dejaras antes. Lo que hubiera queda guardado en `proyecto.anterior/`.

**Resultado esperado:** `partida.sh` termina con las seis líneas `SSH ok` y
`Listo: proyecto/ en el punto de partida «m01» (lo anterior está en proyecto.anterior/).`, y `ls` muestra:

```text
ansible.cfg
app
```

### 2 — Lanza Ansible sin inventario

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible all -m ansible.builtin.ping
```

**Por qué:** `ansible.cfg` dice `inventory = inventario.ini`, pero el fichero aún no existe. Ver cómo responde
Ansible sin inventario te ayuda a reconocer este caso cuando te pase por estar en otra carpeta o tener mal
el nombre del fichero.

**Resultado esperado:** ningún nodo responde y Ansible avisa de que solo conoce `localhost`:

```text
[WARNING]: Unable to parse /workspaces/ansible-automatizacion-201/proyecto/inventario.ini as an inventory source
[WARNING]: No inventory was parsed, only implicit localhost is available
[WARNING]: provided hosts list is empty, only localhost is available. Note that the implicit localhost does not match 'all'
```

La ruta de la primera línea depende del nombre de tu fork.

### 3 — Crea el inventario

**Acción:** crea el fichero `proyecto/inventario.ini` en VS Code con este contenido y guárdalo:

```ini
# proyecto/inventario.ini
dev-web1
pre-web1
prod-lb1
prod-web1
prod-web2
prod-db1
```

Después, compruébalo:

```bash
# Terminal del Codespace, en proyecto/
ansible-inventory --graph
```

**Por qué:** el inventario es la lista de nodos a los que Ansible puede apuntar. Un nombre por línea basta: la
IP de cada uno la resuelve `infra/ssh_config`, que `ansible.cfg` pasa a SSH. La línea que empieza por `#` es un
comentario.

**Resultado esperado:**

```text
@all:
  |--@ungrouped:
  |  |--dev-web1
  |  |--pre-web1
  |  |--prod-lb1
  |  |--prod-web1
  |  |--prod-web2
  |  |--prod-db1
```

Los seis nodos están en `all`, el grupo que incluye siempre a todos, y en `ungrouped`, porque no has definido grupos.

### 4 — Entra en un nodo por SSH, como lo hará Ansible

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ssh -F ../infra/ssh_config dev-web1
```

Ya dentro del nodo:

```bash
# Nodo dev-web1
whoami
hostname
python3 --version
sudo -n true && echo "sudo ok"
exit
```

**Por qué:** Ansible no tiene un canal propio: usa SSH igual que tú. Si este `ssh` funciona, Ansible también
llegará. Y lo que compruebas es justo lo que necesita un nodo gestionado: el usuario `ansible`, Python 3 y
`sudo` sin contraseña.

**Resultado esperado:** entras sin que te pida contraseña, y los comandos responden:

```text
ansible
dev-web1
Python 3.13.5
sudo ok
```

`exit` te devuelve al terminal del Codespace.

### 5 — Haz un ping a todos los nodos

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible all -m ansible.builtin.ping
```

**Por qué:** es la comprobación de siempre antes de lanzar nada: abre SSH con cada nodo, ejecuta un módulo
Python mínimo y espera respuesta. No es un ping de red (ICMP): si responde, la conexión, el usuario y Python
funcionan.

**Resultado esperado:** seis bloques `SUCCESS` con `"ping": "pong"`, en el orden en que terminan:

```text
pre-web1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
prod-web1 | SUCCESS => {
…
prod-db1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
```

`discovered_interpreter_python` es el Python que Ansible ha encontrado en el nodo y usará para los módulos.
`"changed": false`: `ping` no cambia nada.

### 6 — Ejecuta un comando en todos los nodos

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible all -m ansible.builtin.command -a 'uname -a'
```

**Por qué:** es el «entra en cada servidor y mira…» del runbook resuelto en una orden. `-m` elige el módulo y
`-a` le pasa los argumentos; `command` ejecuta el comando en el nodo y devuelve su salida.

**Resultado esperado:** una línea `CHANGED | rc=0` por nodo con la salida de `uname -a`:

```text
pre-web1 | CHANGED | rc=0 >>
Linux pre-web1 … x86_64 GNU/Linux
prod-web1 | CHANGED | rc=0 >>
Linux prod-web1 … x86_64 GNU/Linux
…
prod-db1 | CHANGED | rc=0 >>
Linux prod-db1 … x86_64 GNU/Linux
```

`rc=0` es el código de salida del comando. Sale `CHANGED` aunque `uname` no cambie nada: Ansible no sabe qué
hace un comando arbitrario y lo marca como cambio por si acaso. La versión del núcleo es la del host del
Codespace, porque los nodos son contenedores y lo comparten.

> [!TIP]
> `ansible.builtin.command` no pasa por una shell: tuberías (`|`), redirecciones (`>`) y variables como `$HOME`
> no funcionan. Para eso está `ansible.builtin.shell`.

### 7 — Consulta los facts de un nodo

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible dev-web1 -m ansible.builtin.setup -a 'filter=ansible_distribution*'
```

**Por qué:** `setup` es el módulo que recoge los **facts**: todo lo que Ansible sabe de un nodo (sistema,
versión, memoria, red…). Sin filtro devuelve cientos de líneas; `filter` se queda con las claves que encajan
con el patrón. Aquí apuntas a un solo nodo poniendo su nombre en lugar de `all`.

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

`dev-web1` es Debian 13 (`trixie`). Estos datos son los que más adelante usan los playbooks para decidir qué
hacer en cada nodo.

### 8 — Mira los procesos del nodo justo después

**Acción:** lanza un ping a `dev-web1` y, a continuación, lista sus procesos desde el propio contenedor:

```bash
# Terminal del Codespace, en proyecto/
ansible dev-web1 -m ansible.builtin.ping
docker exec dev-web1 ps -e -o pid,user,args
```

**Por qué:** buscas el «agente» de Ansible en el nodo. `docker exec` mira dentro del contenedor sin abrir otra
sesión SSH, para que lo que veas sea solo lo que ha dejado Ansible.

**Resultado esperado:** solo `sshd` y una sesión SSH del usuario `ansible`:

```text
    PID USER     COMMAND
      1 root     /sbin/docker-init -- /usr/local/bin/arranque.sh
      7 root     sshd: /usr/sbin/sshd -D -e [listener] 0 of 10-100 startups
     37 root     sshd-session: ansible [priv]
     44 ansible  sshd-session: ansible@notty
    291 root     ps -e -o pid,user,args
```

Los números de `PID` serán otros. La sesión `ansible@notty` es la conexión SSH que Ansible deja abierta un rato
para reutilizarla en la siguiente tarea (`ControlPersist=60s` en `ansible.cfg`). No hay ningún proceso
`ansible` ni `python3`: el módulo se ejecutó y terminó.

### 9 — Comprueba que no queda nada

**Acción:** espera algo más de un minuto sin lanzar Ansible y repite:

```bash
# Terminal del Codespace, en proyecto/
docker exec dev-web1 ps -e -o pid,user,args
docker exec dev-web1 sh -c 'find / -xdev -name "AnsiballZ*" 2>/dev/null'
docker exec dev-web1 sh -c 'dpkg -l | grep -i ansible'
```

**Por qué:** es la prueba del modelo agentless. Cerrada la conexión, en el nodo no debe quedar nada de Ansible:
ni procesos, ni módulos copiados (Ansible los empaqueta en ficheros `AnsiballZ_<módulo>.py`), ni paquetes instalados.

**Resultado esperado:**

```text
    PID USER     COMMAND
      1 root     /sbin/docker-init -- /usr/local/bin/arranque.sh
      6 root     sshd: /usr/sbin/sshd -D -e [listener] 0 of 10-100 startups
     83 root     ps -e -o pid,user,args
```

- La sesión SSH ha desaparecido: solo queda `sshd` escuchando, como antes de usar Ansible.
- `find` no encuentra ningún `AnsiballZ*`. Con `pipelining = True` el módulo llega por la propia conexión SSH y
  no se escribe en disco; sin pipelining, Ansible lo copiaría a `~/.ansible/tmp` del nodo y lo borraría al terminar.
- `dpkg -l | grep -i ansible` no imprime nada: no hay ningún paquete de Ansible instalado en el nodo.

## Comprueba tu entendimiento

**Todos los nodos responden**
`ansible all -m ansible.builtin.ping` desde `proyecto/`.
→ Seis `SUCCESS` con `"ping": "pong"`.

**El inventario es el que esperas**
`ansible all --list-hosts`.
→ `hosts (6):` y los seis nombres, de `dev-web1` a `prod-db1`.

**Un solo nodo**
`ansible prod-db1 -m ansible.builtin.command -a 'hostname'`.
→ Un único bloque `prod-db1 | CHANGED | rc=0 >>` con `prod-db1`.

**Nada de Ansible en el nodo**
Pasado algo más de un minuto desde la última orden, `docker exec prod-web1 ps -e -o pid,user,args`.
→ Solo `docker-init`, `sshd` y el propio `ps`.

## Reto

### 1 — Quién ejecuta los módulos

Los playbooks del curso usan `become: true` para trabajar como `root`. Averigua con dos comandos ad hoc contra
`prod-db1` con qué usuario se ejecuta un módulo por defecto y con cuál cuando añades la opción `-b`
(`--become`).

<details>
<summary>Ver solución</summary>

```bash
# Terminal del Codespace, en proyecto/
ansible prod-db1 -m ansible.builtin.command -a whoami
ansible prod-db1 -b -m ansible.builtin.command -a whoami
```

```text
prod-db1 | CHANGED | rc=0 >>
ansible
prod-db1 | CHANGED | rc=0 >>
root
```

Ansible entra siempre como `remote_user` (`ansible`). Con `-b` ejecuta el módulo con `sudo`, y por eso es
`root`. Funciona sin pedir contraseña porque el usuario `ansible` de los nodos tiene `sudo` sin contraseña.

</details>

### 2 — Ver lo que Ansible ejecuta por SSH

Lanza el ping a `dev-web1` en modo muy detallado (`-vvv`) y busca la línea en la que Ansible ejecuta Python en
el nodo.

<details>
<summary>Ver solución</summary>

```bash
# Terminal del Codespace, en proyecto/
ansible dev-web1 -m ansible.builtin.ping -vvv | grep 'python3.13 &&'
```

La línea termina así:

```text
… dev-web1 '/bin/sh -c '"'"'/usr/bin/python3.13 && sleep 0'"'"''
```

Es un `ssh` normal que lanza `/usr/bin/python3.13` en el nodo; el módulo le llega por la entrada estándar de esa
misma conexión (pipelining). Más arriba, en la misma salida, se ve el `ssh -F ../infra/ssh_config …` completo,
con el usuario y la clave que salen de `ansible.cfg`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `No inventory was parsed, only implicit localhost is available` y ningún nodo responde | Estás fuera de `proyecto/` (Ansible no encuentra `ansible.cfg`) o falta `inventario.ini` | `cd "$CODESPACE_VSCODE_FOLDER/proyecto"` y comprueba con `ls` que está `inventario.ini` |
| `[WARNING]: Ansible is being run in a world writable directory (…/proyecto), ignoring it as an ansible.cfg source` | `proyecto/` tiene permiso de escritura para todos y Ansible no se fía de su `ansible.cfg` | Desde la raíz del repositorio, `chmod -R o-w proyecto` (`scripts/partida.sh` ya lo deja así) |
| `ssh: Could not resolve hostname dev-web1` al entrar a mano | Has lanzado `ssh dev-web1` sin `-F ../infra/ssh_config`, que es quien sabe la IP de cada nodo | `ssh -F ../infra/ssh_config dev-web1`, desde `proyecto/` |
| `UNREACHABLE! … Could not resolve hostname prod-web3` | Nombre mal escrito en el inventario: no existe en `infra/ssh_config` | Corrige la línea en `inventario.ini` y repite `ansible-inventory --graph` |
| `UNREACHABLE! … Connection timed out` en todos los nodos | Los nodos no están levantados (Codespace recién reanudado) | Desde la raíz del repositorio, `scripts/nodos.sh up` |
| `Permission denied (publickey)` | La clave del curso no coincide con la de los nodos | Desde la raíz del repositorio, `scripts/nodos.sh reset` |
| `FAILED! … rc=1` con `error: garbage option` al usar `command -a 'ps aux \| grep sshd'` | `command` no pasa por una shell: la tubería llega a `ps` como argumento | Usa `ansible.builtin.shell` cuando necesites tuberías o redirecciones |
