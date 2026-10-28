# Qué es Ansible

[← Página anterior](README.md) · [Siguiente página →](01-lab-instalar-y-configurar.md)

Ansible es una herramienta de código abierto para la automatización de la tecnología de la información (TI)
que permite configurar servidores, desplegar aplicaciones y gestionar infraestructuras a gran escala de forma
sencilla. Esta página explica qué problema resuelve, para qué se usa y cómo llega a las máquinas sin instalar
nada en ellas: el modelo **agentless** en el que se apoya todo lo demás.

## El problema: procedimientos manuales

Muchas tareas de operaciones viven en un runbook: un documento con los pasos que alguien repite por SSH en cada
servidor. Por ejemplo, dar de alta un servidor web:

```text
# Runbook — Alta de un servidor web (extracto)
1. ssh admin@web1
2. sudo apt-get update && sudo apt-get install -y nginx
3. Copiar app.conf a /etc/nginx/sites-available/ y enlazarlo en sites-enabled/
4. Copiar la versión nueva de la aplicación a /srv/app/
5. sudo service nginx reload
6. Comprobar con curl que responde
7. Repetir en web2, web3…
```

| Problema del runbook | Consecuencia |
|----------------------|--------------|
| Se repite a mano en cada nodo | Con decenas de servidores, cada paso se hace decenas de veces y los errores crecen con el cansancio |
| Cada persona lo interpreta | Uno aplica un permiso, otro se lo salta: servidores que deberían ser iguales acaban distintos (deriva) |
| No dice qué hay ya hecho | Si un paso falla a medias, no se sabe desde dónde seguir sin revisar el servidor |
| No se revisa ni se versiona | Un cambio en el procedimiento no lo ve nadie hasta que algo deja de funcionar |
| Depende de quién tiene acceso | Solo quien tiene la clave puede ejecutarlo, y el rastro queda en su terminal |

## Qué es Ansible

Ansible (proyecto de código abierto patrocinado por Red Hat) ejecuta tareas en muchas máquinas a la vez desde
un único punto. Las tareas se describen en ficheros YAML que dicen **cómo tiene que quedar** el sistema («el
directorio `/srv/app` existe y tiene permisos `0755`»), no qué órdenes teclear. Cada tarea la resuelve un
**módulo** (`ansible.builtin.file`, `ansible.builtin.apt`, `ansible.builtin.service`…) que mira el estado
actual del nodo y solo cambia lo que no coincide.

| Término | Qué es |
|---------|--------|
| `ansible-core` | El motor: los comandos `ansible`, `ansible-playbook`, `ansible-inventory`, `ansible-doc` y los módulos `ansible.builtin.*` |
| Paquete `ansible` | `ansible-core` más una selección de colecciones de la comunidad (`community.docker`, `community.postgresql`, `ansible.posix`…) |
| Colección | Paquete de módulos y plugins con nombre propio. Por eso los módulos se escriben con su nombre completo (FQCN): `ansible.builtin.copy` |

> [!NOTE]
> Describir el estado final es lo que permite repetir. `mkdir /srv/app` falla la segunda vez porque el
> directorio ya existe; la tarea «`/srv/app` con `state: directory`» devuelve `ok` y sigue. A esta propiedad se
> la llama **idempotencia**.

## Casos de uso

| Caso de uso | Sin Ansible | Con Ansible |
|-------------|-------------|-------------|
| Consultas a muchos nodos | Entrar en cada uno y ejecutar `uname -a` o `df -h` | Un comando ad hoc contra el inventario |
| Estado base de los servidores | Los mismos pasos en cada máquina | Un playbook que se ejecuta las veces que haga falta |
| Instalar y configurar servicios | Pasos manuales por servidor y por entorno | Playbooks, plantillas y roles con variables por entorno |
| Desplegar aplicaciones | Copiar la versión nodo a nodo y coordinar el balanceador | Despliegues por tandas, con comprobación y vuelta atrás |
| Parcheo y cambios controlados | Ventanas de mantenimiento a mano | Ejecución en modo check, por grupos, con registro de lo que cambió |
| Orquestación | Un orden entre servicios que solo conoce quien lo ejecuta | Un playbook con el orden escrito |
| Ejecución centralizada | Quien tiene la clave, en su terminal | Un controlador (AWX) o un pipeline de CI/CD |

## Arquitectura

```text
                     Nodo de control
   ┌───────────────────────────────────────────────┐
   │ proyecto/                                     │
   │   ansible.cfg ........ usuario, clave, SSH    │
   │   inventario.ini ..... qué nodos              │
   │   site.yml ........... qué tareas             │
   │                                               │
   │   ansible / ansible-playbook                  │
   └───────────────────────┬───────────────────────┘
                           │  SSH (usuario remoto + clave)
                           │  ida: módulo en Python · vuelta: JSON
            ┌──────────────┼──────────────┬──────────────┐
            ▼              ▼              ▼              ▼
          web1           web2            lb1            db1
        sshd + python3 + usuario con sudo
        (ningún agente de Ansible)
```

| Componente | Dónde vive | Qué hace |
|------------|-----------|----------|
| Nodo de control | Un equipo con Linux o macOS (o un runner de CI) | Tiene Ansible instalado, lee el proyecto y abre las conexiones. Es el único sitio donde se instala Ansible |
| Nodos gestionados | Los servidores a administrar | Reciben las tareas. Solo necesitan `sshd`, Python 3 y un usuario con permisos de `sudo` |
| Inventario | Un fichero del proyecto (`inventario.ini`, `hosts.yml`) | Dice a qué nodos se puede apuntar y cómo se agrupan, con sus variables |
| `ansible.cfg` | La raíz del proyecto | Fija el inventario por defecto, el usuario remoto, la clave y las opciones de SSH |
| Módulos | Dentro de `ansible-core` y de las colecciones, en el nodo de control | Código Python que se envía al nodo, se ejecuta allí y devuelve el resultado |
| Playbooks | Ficheros `*.yml` del proyecto | La versión escrita y repetible del procedimiento |

### Qué pasa al ejecutar una tarea

1. Ansible lee `ansible.cfg` de la carpeta actual y, con él, el inventario.
2. Abre una conexión SSH con cada nodo, con el usuario y la clave configurados. Por defecto atiende a cinco
   nodos a la vez (`forks = 5`).
3. Si la tarea lleva `become: true`, ejecuta el módulo con `sudo` en el nodo.
4. Envía el módulo, en Python, por esa conexión. Con `pipelining = True` se lo pasa directamente al `python3`
   remoto; sin él, lo copia a `~/.ansible/tmp` del nodo y lo borra al terminar.
5. El módulo comprueba el estado, cambia lo que haga falta y responde con un JSON: `changed`, `failed`, mensajes.
6. Ansible pinta el resultado (`ok`, `changed`, `failed`, `unreachable`) y pasa a la siguiente tarea.

> [!NOTE]
> «Sin agente» no significa «sin requisitos»: el nodo necesita SSH y Python 3. Lo que no necesita es un servicio
> de Ansible instalado, un puerto propio ni un registro previo en un servidor central. Cuando la ejecución
> termina, en el nodo no queda nada de Ansible corriendo.

> [!TIP]
> Algunos módulos necesitan librerías de Python en el nodo: `ansible.builtin.apt`, por ejemplo, usa `python3-apt`.

## Ansible frente a otras formas de automatizar

| | Scripts por SSH (bash + bucle `for`) | Ansible | Herramientas con agente (Puppet, Chef, Salt con minion) |
|---|--------------------------------------|---------|----------------------------------------------------------|
| Qué se instala en el nodo | Nada | Nada: SSH y Python, que ya están | Un agente que corre como servicio y se registra en un servidor central |
| Cómo llega el cambio | Se empuja desde quien lanza el script | Se empuja (push) desde el nodo de control | El agente lo pide (pull) cada cierto tiempo |
| Cómo se describe | Órdenes imperativas: `mkdir`, `sed`, `apt-get` | Estado deseado en YAML, resuelto por módulos | Estado deseado en un lenguaje propio (DSL de Puppet, Ruby en Chef) o YAML (Salt) |
| Repetir la ejecución | Hay que programar cada comprobación (`[ -d … ] \|\| mkdir …`) | Los módulos comprueban y solo cambian lo necesario | Igual que Ansible: lo comprueba el agente |
| Saber qué cambió | Lo que el script imprima | `ok` / `changed` por tarea y nodo, `--diff`, `--check` | Informes del servidor central |
| Puesta en marcha | Inmediata | Inmediata: inventario y clave SSH | Servidor central, certificados y agente en cada nodo |
| Punto débil | No escala ni se mantiene: cada caso raro es más bash | Al ser push, no corrige solo la deriva: hay que lanzarlo (o programarlo en un controlador) | Más piezas que mantener; el agente es otro software que parchear en cada nodo |

> [!NOTE]
> Ansible no prohíbe los comandos: `ansible.builtin.command` y `ansible.builtin.shell` existen para lo que no
> tiene módulo. Pero con ellos Ansible no sabe si algo cambió y marca `changed` siempre. Conviene usarlos solo
> para consultar o cuando no hay otro remedio.

## Qué queda claro

- Ansible se instala en un sitio, el nodo de control, y llega a los nodos por SSH.
- Los nodos gestionados solo necesitan SSH, Python 3 y un usuario con `sudo`.
- Inventario, módulos y playbooks son las piezas del proyecto; `ansible.cfg` las une.
- Describir el estado final, y no los comandos, es lo que permite ejecutar el mismo playbook muchas veces.

## En los laboratorios

El curso sigue el caso de una empresa ficticia, Tienda Norte, que mantiene su portal de pedidos con un runbook
manual sobre seis servidores Debian en tres entornos. El nodo de control es el Codespace (`ansible-core` 2.20) y
los nodos son contenedores con SSH. En el [Lab — Instalar y configurar Ansible](01-lab-instalar-y-configurar.md)
instalas y configuras un nodo de control desde cero. La [demostración](02-del-runbook-al-playbook.md) convierte los primeros
pasos de ese runbook en un inventario y un playbook, y el
[Lab — Conexión agentless](03-lab-conexion-agentless.md) comprueba que en los nodos no queda nada de Ansible.
