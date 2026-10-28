# Del runbook al playbook

[← Página anterior](00-que-es-ansible.md) · [Siguiente página →](02-lab-conexion-agentless.md)

El runbook del portal de Tienda Norte empieza siempre igual: entrar por SSH en cada servidor, crear la carpeta
`/srv/portal` y dejar en `/etc/motd` un aviso de que el nodo es del portal. Son dos pasos sencillos, pero se
repiten en seis nodos y nadie comprueba que hayan quedado iguales. Esta demostración muestra esos mismos pasos
convertidos en un proyecto Ansible: un **inventario** con los seis nodos, un **playbook** con tres tareas y los
**módulos** que las resuelven, ejecutado dos veces para ver qué significa que sea **idempotente**.

## Punto de partida

- Terminal del Codespace, en la raíz del repositorio.
- Estado: el proyecto en el punto `m02` (`ansible.cfg`, `inventario.ini` y `primer-playbook.yml`) y los nodos
  recién creados, sin nada aplicado:

```bash
# Terminal del Codespace, en la raíz del repositorio
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m02 --limpio
cd proyecto
```

La salida termina con las seis líneas `SSH ok` de los nodos y:

```text
Listo: proyecto/ en el punto de partida «m02» (lo anterior está en proyecto.anterior/).
```

## Recorrido

### 1. El estado de partida de un nodo

Antes de automatizar nada, `dev-web1` está como lo dejó la imagen de Debian: el `/etc/motd` de serie y sin
carpeta del portal.

```bash
# Terminal del Codespace, en proyecto/
ssh -F ../infra/ssh_config dev-web1 "cat /etc/motd; ls -ld /srv/portal"
```

```text

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
ls: cannot access '/srv/portal': No such file or directory
```

Con el runbook, el siguiente paso sería un `sudo mkdir` y un `sudo tee /etc/motd` en este nodo, y después en
los otros cinco.

### 2. El inventario: a qué nodos

El inventario es la lista de nodos sobre los que puede actuar Ansible. En este punto es un fichero INI plano,
un nombre por línea:

```ini
# proyecto/inventario.ini
dev-web1
pre-web1
prod-lb1
prod-web1
prod-web2
prod-db1
```

`ansible-inventory --graph` enseña cómo lo entiende Ansible:

```bash
# Terminal del Codespace, en proyecto/
ansible-inventory --graph
```

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

Todos los nodos caen en el grupo `all`, que existe siempre, y en `ungrouped` porque todavía no hay grupos. Los
grupos por función y entorno (`web`, `prod`…) llegan en el módulo de inventarios.

El inventario no dice cómo conectar. Eso lo pone `ansible.cfg`, en la misma carpeta:

```ini
# proyecto/ansible.cfg (extracto)
[defaults]
inventory = inventario.ini
remote_user = ansible
private_key_file = ~/.ssh/curso-ansible/curso_ansible

[ssh_connection]
ssh_args = -F ../infra/ssh_config -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
```

Con esto, cualquier `ansible` o `ansible-playbook` lanzado desde `proyecto/` usa ese inventario, entra como
`ansible` con la clave del curso y resuelve los nombres de los nodos con `infra/ssh_config`.

### 3. El playbook: qué tareas

El playbook es el runbook escrito como estado deseado:

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

    - name: Dejar constancia de quién gestiona el nodo
      ansible.builtin.copy:
        dest: /etc/motd
        content: "Nodo del portal de pedidos de Tienda Norte. Gestionado con Ansible.\n"
        mode: "0644"
```

| Línea del runbook | En el playbook | Módulo |
|-------------------|----------------|--------|
| `ssh admin@<nodo>`, uno por uno | `hosts: all`: los seis nodos del inventario, en paralelo | — |
| `sudo …` | `become: true`: las tareas se ejecutan con `sudo` en el nodo | — |
| «Comprobar que se puede entrar» | Comprobar la conexión | `ansible.builtin.ping` |
| `sudo mkdir -p /srv/portal` | Crear la carpeta del portal: que exista, sea un directorio y tenga `0755` | `ansible.builtin.file` |
| `echo "…" \| sudo tee /etc/motd` | Dejar constancia de quién gestiona el nodo: que `/etc/motd` tenga ese contenido y `0644` | `ansible.builtin.copy` |

El fichero tiene un **play** (el bloque con `name`, `hosts`, `become` y `tasks`) y tres **tareas**. Cada tarea
tiene un nombre en español, que es lo que aparece al ejecutar, y llama a un módulo por su nombre completo.

### 4. Primera ejecución

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook primer-playbook.yml
```

```text
PLAY [Preparar los nodos del portal] *******************************************

TASK [Gathering Facts] *********************************************************
ok: [prod-web2]
ok: [pre-web1]
ok: [prod-web1]
ok: [prod-lb1]
ok: [dev-web1]
ok: [prod-db1]

TASK [Comprobar la conexión] ***************************************************
ok: [pre-web1]
ok: [prod-lb1]
…

TASK [Crear la carpeta del portal] *********************************************
changed: [prod-lb1]
changed: [dev-web1]
changed: [prod-web1]
changed: [prod-web2]
changed: [pre-web1]
changed: [prod-db1]

TASK [Dejar constancia de quién gestiona el nodo] ******************************
changed: [prod-web2]
changed: [pre-web1]
…

PLAY RECAP *********************************************************************
dev-web1                   : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
pre-web1                   : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-db1                   : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web1                  : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Lo que se lee aquí:

- **Gathering Facts** es una tarea que Ansible añade al principio de cada play: recoge datos del nodo (sistema,
  versión, red…) con el módulo `ansible.builtin.setup`. Por eso hay cuatro `ok` y solo tres tareas escritas.
- El orden de los nodos cambia de una tarea a otra: Ansible atiende a varios a la vez y los pinta según terminan.
- `ping` da `ok`: comprueba, no cambia. La carpeta y el `motd` dan `changed`: no estaban y Ansible los ha creado.
- El `PLAY RECAP` resume por nodo: `ok=4` tareas correctas, de las que `changed=2` tuvieron que cambiar algo.

### 5. Segunda ejecución

El mismo comando, sin tocar nada:

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook primer-playbook.yml
```

```text
…
TASK [Crear la carpeta del portal] *********************************************
ok: [dev-web1]
ok: [prod-lb1]
…

TASK [Dejar constancia de quién gestiona el nodo] ******************************
ok: [prod-web1]
ok: [prod-web2]
…

PLAY RECAP *********************************************************************
dev-web1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
pre-web1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-db1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web1                  : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Las mismas tareas se han ejecutado en los mismos nodos, pero ahora todas dan `ok` y el resumen marca
`changed=0`. `ansible.builtin.file` vio que `/srv/portal` ya existía con `0755`; `ansible.builtin.copy` comparó el
contenido de `/etc/motd` con el pedido y era el mismo. Eso es la **idempotencia**: ejecutar una vez o diez deja
el sistema igual, y solo se cambia lo que no está como se describe. El runbook no tiene esa propiedad: un
`mkdir` sin `-p` falla la segunda vez, y un `echo >> /etc/motd` duplica la línea.

> [!NOTE]
> `changed=0` en una segunda ejecución es la prueba de que un playbook está bien escrito. Si una tarea da
> `changed` siempre, o no es idempotente o usa `command`/`shell` sin decirle a Ansible cuándo cambia algo.

### 6. El resultado en el nodo

```bash
# Terminal del Codespace, en proyecto/
ssh -F ../infra/ssh_config dev-web1 "cat /etc/motd; ls -ld /srv/portal"
```

```text
Nodo del portal de pedidos de Tienda Norte. Gestionado con Ansible.
drwxr-xr-x 2 root root 4096 Oct 26 19:27 /srv/portal
```

El nodo tiene la carpeta, del usuario `root` (las tareas corrieron con `become: true`), y el aviso en el `motd`,
que ahora es lo primero que ve quien entra por SSH. Lo mismo ha pasado en los otros cinco nodos con una sola orden.

## Qué queda visto

- Un **inventario** dice a qué nodos se apunta; `ansible.cfg` dice cómo conectar con ellos.
- Un **playbook** tiene plays, y cada play aplica unas **tareas** a unos hosts; cada tarea llama a un **módulo**.
- `ok` y `changed` dicen si una tarea tuvo que cambiar el nodo, y el `PLAY RECAP` lo cuenta por nodo.
- Una segunda ejecución con `changed=0` demuestra la **idempotencia**.

La conexión con los nodos y los comandos ad hoc se practican en el
[Lab — Conexión agentless](02-lab-conexion-agentless.md), y escribir este playbook paso a paso, en el
[Lab — Primer playbook](03-lab-primer-playbook.md). Los dos se pueden hacer sin haber seguido esta demostración.
