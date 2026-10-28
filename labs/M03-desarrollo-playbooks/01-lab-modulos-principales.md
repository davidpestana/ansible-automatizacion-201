# Lab — Módulos principales

[← Página anterior](00-anatomia-de-un-playbook.md) · [Siguiente página →](02-lab-instalar-servicio.md)

El runbook de Tienda Norte tiene pasos sueltos que cada operador hace a su manera en el nodo de dev: instalar
`cron` para las tareas de limpieza, dar de alta al usuario `operador`, preparar su carpeta `/opt/tienda-norte` con
un fichero de instrucciones y dejar `cron` arrancado. En este lab resuelves cada paso con el módulo que toca,
buscándolo y leyendo sus argumentos con `ansible-doc`, primero como comando ad hoc y después juntos en un
playbook de prácticas.

### Objetivo

Dejar `dev-web1` con `cron` instalado y en marcha, el usuario `operador` y `/opt/tienda-norte/LEEME.txt`, y un
`practicas.yml` que reproduce esos pasos con `changed=0` en la segunda ejecución.

### Punto de partida

- Terminal del Codespace, en `proyecto/`.
- Estado: inventarios por entorno (`inventories/{dev,pre,prod}/hosts.yml`), sin playbooks. `ansible.cfg` usa dev
  por defecto, así que el grupo `web` es `dev-web1`. El paso 1 te deja ahí.

### En qué consiste

Consultas `ansible-doc` para cinco módulos (`apt`, `user`, `file`, `copy`, `service`), lanzas cada paso con
`ansible web -b -m <módulo> -a "<argumentos>"` y lo pasas a `practicas.yml`. Solo tocas `dev-web1`; nginx y el
portal son el [Lab — Instalar y configurar un servicio](02-lab-instalar-servicio.md).

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repo
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m03
cd proyecto
ansible web -m ansible.builtin.ping
```

**Por qué:** `partida.sh` deja `proyecto/` con los inventarios del M02. El `ping` confirma que Ansible llega a
`dev-web1` antes de cambiar nada.

**Resultado esperado:**

```text
dev-web1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
```

### 2 — Busca los módulos con `ansible-doc -l`

**Acción:**

```bash
ansible-doc -l ansible.builtin | grep -E '^ansible\.builtin\.(apt|user|file|copy|service) '
```

**Por qué:** `ansible-doc -l` lista los módulos instalados con su descripción en una línea (limitado a la
colección `ansible.builtin`, que viene con ansible-core). Con `grep` encuentras el que necesitas sin salir del
terminal: `ansible-doc -l ansible.builtin | grep -i group` te diría qué módulo gestiona grupos.

**Resultado esperado:**

```text
ansible.builtin.apt                    Manages apt-packages
ansible.builtin.copy                   Copy files to remote locations
ansible.builtin.file                   Manage files and file properties
ansible.builtin.service                Manage services
ansible.builtin.user                   Manage user accounts
```

> [!TIP]
> Si aparece un `[WARNING]: Collection at '…/_protomatter' does not have a MANIFEST.json file`, es un aviso
> interno de ansible-core al listar colecciones: no afecta a la búsqueda.

### 3 — Lee la documentación de `apt`

**Acción:** `ansible-doc ansible.builtin.apt` (sales con <kbd>q</kbd>). Busca dentro con <kbd>/</kbd> las opciones
`name`, `state`, `update_cache`, `cache_valid_time` e `install_recommends`, y baja hasta `EXAMPLES`.

**Por qué:** cada módulo trae sus opciones, sus valores posibles y ejemplos copiables. Es la referencia que vas a
usar en todo el curso, también sin conexión.

**Resultado esperado:** la ficha empieza por `> MODULE ansible.builtin.apt` y, entre las opciones, aparece:

```text
   state   Indicates the desired package state. `latest' ensures that
           the latest version is installed. `build-dep' ensures the
           package build dependencies are installed. `fixed' attempt
           to correct a system with broken dependencies in place.
        choices: [absent, build-dep, latest, present, fixed]
        default: present
        type: str
…
EXAMPLES:
- name: Install apache httpd (state=present is optional)
  ansible.builtin.apt:
    name: apache2
    state: present
…
- name: Only run "update_cache=yes" if the last one is more than 3600 seconds ago
  ansible.builtin.apt:
    update_cache: yes
    cache_valid_time: 3600
```

> [!TIP]
> `ansible-doc -s ansible.builtin.user` da un esqueleto de tarea con todas las opciones comentadas, listo para
> copiar al playbook.

### 4 — Instala `cron` sin paquetes recomendados

**Acción:**

```bash
ansible web -b -m ansible.builtin.apt -a "name=cron state=present install_recommends=false update_cache=true cache_valid_time=3600"
```

Lánzalo una segunda vez, igual.

**Por qué:** es el `apt-get update && apt-get install --no-install-recommends cron` del runbook. `-b` (become)
lo ejecuta con sudo. `cache_valid_time=3600` evita actualizar la lista de paquetes si se hizo hace menos de
una hora; `install_recommends=false` evita que entre un servidor de correo que el portal no necesita.

**Resultado esperado:** la primera vez, `CHANGED` con la salida de apt; la segunda, `SUCCESS` y `"changed": false`:

```text
dev-web1 | CHANGED => {
…
        "The following NEW packages will be installed:",
        "  cron cron-daemon-common",
…
        "invoke-rc.d: policy-rc.d denied execution of start.",
…
dev-web1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "cache_update_time": 1793043066,
    "cache_updated": false,
    "changed": false
}
```

La línea `policy-rc.d denied execution of start` dice que el paquete se instaló **sin arrancar** el servicio: en
los nodos del curso (contenedores) los paquetes no arrancan solos. Lo arrancas en el paso 8.

### 5 — Da de alta al usuario `operador`

**Acción:**

```bash
ansible web -b -m ansible.builtin.user -a "name=operador comment='Operaciones Tienda Norte' shell=/bin/bash groups=crontab append=true"
ansible web -m ansible.builtin.command -a "id operador"
```

**Por qué:** sustituye a `useradd -m -s /bin/bash -G crontab operador`. Con `append=true` el usuario se añade al
grupo `crontab` sin perder otros grupos que tuviera.

**Resultado esperado:**

```text
dev-web1 | CHANGED => {
…
    "comment": "Operaciones Tienda Norte",
    "create_home": true,
    "group": 1001,
    "groups": "crontab",
    "home": "/home/operador",
    "name": "operador",
    "shell": "/bin/bash",
    "state": "present",
…
}
dev-web1 | CHANGED | rc=0 >>
uid=1001(operador) gid=1001(operador) groups=1001(operador),996(crontab)
```

El `id` sale `CHANGED` aunque no cambia nada: `ansible.builtin.command` no sabe qué hace la orden que lanza. Se
trata en el [Lab — Ejecución idempotente](03-lab-ejecucion-idempotente.md).

### 6 — Crea la carpeta de operaciones

**Acción:**

```bash
ansible web -b -m ansible.builtin.file -a "path=/opt/tienda-norte state=directory owner=operador group=operador mode=0750"
```

**Por qué:** equivale a `mkdir -p` + `chown` + `chmod` en una sola tarea. `state=directory` describe lo que
quieres; si ya existe con esos permisos, no se toca.

**Resultado esperado:**

```text
dev-web1 | CHANGED => {
…
    "group": "operador",
    "mode": "0750",
    "owner": "operador",
    "path": "/opt/tienda-norte",
    "size": 4096,
    "state": "directory",
    "uid": 1001
}
```

### 7 — Deja el `LEEME.txt`

**Acción:**

```bash
ansible web -b -m ansible.builtin.copy -a "dest=/opt/tienda-norte/LEEME.txt content='Carpeta de operaciones del portal de pedidos\n' owner=operador group=operador mode=0640"
ansible web -b -m ansible.builtin.command -a "ls -l /opt/tienda-norte"
```

**Por qué:** `copy` con `content` escribe un fichero pequeño sin tener que crearlo antes en el Codespace; con `src`
copiaría un fichero del proyecto, como harás con la configuración de nginx.

**Resultado esperado:**

```text
dev-web1 | CHANGED => {
    …
    "dest": "/opt/tienda-norte/LEEME.txt",
    "gid": 1001,
    "group": "operador",
    "mode": "0640",
    "owner": "operador",
    "size": 45,
    …
}
dev-web1 | CHANGED | rc=0 >>
total 4
-rw-r----- 1 operador operador 45 Oct 26 19:31 LEEME.txt
```

### 8 — Arranca `cron`

**Acción:**

```bash
ansible web -b -m ansible.builtin.service -a "name=cron state=started"
ansible web -m ansible.builtin.command -a "ps -C cron -o pid,user,cmd"
```

**Por qué:** el paquete quedó instalado pero parado (paso 4). `state=started` lo arranca solo si no está en
marcha; `ansible-doc ansible.builtin.service` te muestra los otros estados: `stopped`, `restarted` y `reloaded`.

**Resultado esperado:**

```text
dev-web1 | CHANGED => {
…
    "changed": true,
    "name": "cron",
    "state": "started"
}
dev-web1 | CHANGED | rc=0 >>
    PID USER     CMD
    263 root     /usr/sbin/cron
```

Si repites el `service`, sale `SUCCESS` con `"changed": false`.

### 9 — Junta los pasos en `practicas.yml`

**Acción:** crea `proyecto/practicas.yml`:

```yaml
# proyecto/practicas.yml
- name: Pasos sueltos del runbook en dev
  hosts: web
  become: true
  tasks:
    - name: Instalar cron
      ansible.builtin.apt:
        name: cron
        state: present
        install_recommends: false
        update_cache: true
        cache_valid_time: 3600

    - name: Crear el usuario de operaciones
      ansible.builtin.user:
        name: operador
        comment: Operaciones Tienda Norte
        shell: /bin/bash
        groups: crontab
        append: true

    - name: Crear la carpeta de operaciones
      ansible.builtin.file:
        path: /opt/tienda-norte
        state: directory
        owner: operador
        group: operador
        mode: "0750"

    - name: Dejar el LEEME de la carpeta
      ansible.builtin.copy:
        dest: /opt/tienda-norte/LEEME.txt
        content: "Carpeta de operaciones del portal de pedidos\n"
        owner: operador
        group: operador
        mode: "0640"

    - name: Arrancar cron
      ansible.builtin.service:
        name: cron
        state: started
```

**Por qué:** cada `-a "clave=valor …"` del ad hoc se convierte en argumentos YAML bajo el módulo. Un comando ad
hoc se olvida; el playbook queda en el proyecto y se puede repetir y revisar.

**Resultado esperado:** `ansible-playbook practicas.yml --syntax-check` imprime `playbook: practicas.yml`.

### 10 — Ejecútalo sobre el nodo ya preparado

**Acción:** `ansible-playbook practicas.yml`

**Por qué:** `dev-web1` ya tiene todo lo que pide el playbook por los pasos 4 a 8. Si las tareas equivalen a los
ad hoc, no debe cambiar nada.

**Resultado esperado:**

```text
PLAY [Pasos sueltos del runbook en dev] ****************************************

TASK [Gathering Facts] *********************************************************
ok: [dev-web1]

TASK [Instalar cron] ***********************************************************
ok: [dev-web1]

TASK [Crear el usuario de operaciones] *****************************************
ok: [dev-web1]

TASK [Crear la carpeta de operaciones] *****************************************
ok: [dev-web1]

TASK [Dejar el LEEME de la carpeta] ********************************************
ok: [dev-web1]

TASK [Arrancar cron] ***********************************************************
ok: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=6    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 11 — Borra el `LEEME.txt` a mano y vuelve a ejecutar

**Acción:**

```bash
docker exec dev-web1 rm /opt/tienda-norte/LEEME.txt
ansible-playbook practicas.yml
```

**Por qué:** simula a alguien que «limpia» el nodo por su cuenta. El playbook describe el estado deseado y lo
restaura sin que tengas que saber qué se tocó.

**Resultado esperado:** solo cambia la tarea del fichero:

```text
TASK [Dejar el LEEME de la carpeta] ********************************************
changed: [dev-web1]
…
PLAY RECAP *********************************************************************
dev-web1                   : ok=6    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

## Comprueba tu entendimiento

**El módulo correcto para cada paso**
Ejecuta `ansible-doc -l ansible.builtin | grep -i group`.
→ Aparecen `ansible.builtin.group` (`Add or remove groups`) y `ansible.builtin.group_by`; el primero es el que
crea grupos en el nodo.

**Estado deseado**
Ejecuta `ansible-playbook practicas.yml` otra vez.
→ `changed=0`: nada ha cambiado desde la ejecución anterior.

**El ad hoc y la tarea son lo mismo**
Ejecuta `ansible web -b -m ansible.builtin.service -a "name=cron state=started"`.
→ `SUCCESS` con `"changed": false`, como la tarea `Arrancar cron`.

## Reto

### 1 — Lleva los pasos a pre

Aplica `practicas.yml` al nodo de pre sin editar el playbook.

<details>
<summary>Ver solución</summary>

Cambia de inventario con `-i`:

```bash
ansible-playbook -i inventories/pre/hosts.yml practicas.yml
```

```text
PLAY RECAP *********************************************************************
pre-web1                   : ok=6    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Las cinco tareas cambian porque `pre-web1` no tenía nada; una segunda ejecución sale `changed=0`.

</details>

### 2 — Un grupo para el equipo del portal

Encuentra con `ansible-doc` el módulo que gestiona grupos y crea en `dev-web1` el grupo `portal`, primero ad hoc.

<details>
<summary>Ver solución</summary>

```bash
ansible-doc -l ansible.builtin | grep -i group
ansible web -b -m ansible.builtin.group -a "name=portal state=present"
```

```text
dev-web1 | CHANGED => {
…
    "changed": true,
    "gid": 1002,
    "name": "portal",
    "state": "present",
    "system": false
}
```

En `practicas.yml` sería una tarea con `ansible.builtin.group:` y `name: portal`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `Permission denied` o `Failed to lock apt for exclusive operation` | Falta `-b` (o `become: true`) | Añade `-b` al ad hoc o `become: true` al play |
| `couldn't resolve module/action 'ansible.builtin.servise'` | Nombre del módulo mal escrito | `ansible-doc -l ansible.builtin \| grep` para dar con el nombre exacto |
| `Unsupported parameters` en una tarea | Argumento que el módulo no tiene | Comprueba el nombre en `ansible-doc <módulo>` |
| `cron` instalado pero no hay proceso | En los nodos del curso los paquetes no arrancan el servicio | `ansible.builtin.service` con `state=started` |
| El ad hoc sale `CHANGED` siempre con `command` | `command` no sabe si cambia algo | Normal en consultas; en el [Lab — Ejecución idempotente](03-lab-ejecucion-idempotente.md) se corrige |
| `mode=0750` en YAML deja permisos raros | Sin comillas, YAML lo lee como número | En el playbook, `mode: "0750"` entre comillas |
