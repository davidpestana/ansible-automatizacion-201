# Qué es Ansible

[← Página anterior](README.md) · [Siguiente página →](01-del-runbook-al-playbook.md)

En Tienda Norte, el portal de pedidos funciona gracias a un runbook: un documento con los pasos que alguien de
operaciones repite por SSH en cada servidor cada vez que hay que montar un nodo, publicar una versión o aplicar
parches. Funciona mientras lo haga la persona que lo escribió y con pocos servidores. Esta página explica qué es
Ansible, en qué partes de ese runbook encaja y cómo llega a los nodos del portal sin instalar nada en ellos:
el modelo **agentless** en el que se apoya todo el curso.

## El runbook del portal

Así empieza hoy el runbook para preparar un servidor web del portal:

```text
# Runbook — Alta de un nodo web del portal (extracto)
1. ssh admin@prod-web1
2. sudo mkdir -p /srv/portal
3. sudo apt-get update && sudo apt-get install -y nginx
4. Copiar portal.conf a /etc/nginx/sites-available/ y enlazarlo en sites-enabled/
5. Copiar la release 1.0.0 a /srv/portal/releases/1.0.0/ y apuntar /srv/portal/current a ella
6. sudo service nginx reload
7. curl -s localhost/estado.json  → comprobar versión y entorno
8. Repetir en prod-web2. Avisar a quien lleve el balanceador.
```

| Problema del runbook | Qué pasa en Tienda Norte |
|----------------------|--------------------------|
| Se repite a mano en cada nodo | Seis nodos en tres entornos: cada paso se hace seis veces, y en el sexto hay más prisa |
| Cada persona lo interpreta | Uno escribe `chmod 755`, otro se lo salta; `prod-web1` y `prod-web2` acaban distintos |
| No dice qué hay ya hecho | Si el paso 3 falló a medias, nadie sabe desde dónde seguir sin mirar el servidor |
| No se revisa ni se versiona | Un cambio en el paso 4 no lo ve nadie hasta que algo deja de funcionar |
| Depende de quién tiene acceso | Solo quien tiene la clave de prod puede ejecutarlo, y queda en su terminal |

## Qué es Ansible

Ansible es una herramienta de automatización de código abierto (mantenida por Red Hat) que ejecuta tareas en
muchas máquinas a la vez desde un único punto. Las tareas se describen en ficheros YAML que dicen **cómo tiene
que quedar** el sistema («`/srv/portal` existe, es un directorio y tiene permisos `0755`»), no qué órdenes
teclear. Cada tarea la resuelve un **módulo** (`ansible.builtin.file`, `ansible.builtin.apt`,
`ansible.builtin.service`…) que mira el estado actual del nodo y solo cambia lo que no coincide.

| Término | Qué es |
|---------|--------|
| `ansible-core` | El motor: los comandos `ansible`, `ansible-playbook`, `ansible-inventory`, `ansible-doc` y los módulos `ansible.builtin.*` |
| Paquete `ansible` | `ansible-core` más una selección de colecciones de la comunidad (`community.docker`, `community.postgresql`, `ansible.posix`…). En el Codespace: `ansible` 13.8.0 con `ansible-core` 2.20 |
| Colección | Paquete de módulos y plugins con nombre propio. Por eso los módulos se escriben con su nombre completo (FQCN): `ansible.builtin.copy` |

> [!NOTE]
> Describir el estado final es lo que permite repetir. `mkdir /srv/portal` falla la segunda vez porque el
> directorio ya existe; la tarea «`/srv/portal` con `state: directory`» devuelve `ok` y sigue. A esta propiedad
> se la llama **idempotencia** y se ve en la [demostración](01-del-runbook-al-playbook.md).

## Casos de uso en Tienda Norte

| Caso de uso | Hoy, con el runbook | Con Ansible | Dónde se trabaja |
|-------------|---------------------|-------------|------------------|
| Consultas rápidas a todos los nodos | Entrar en cada uno y ejecutar `uname -a` o `df -h` | Un comando ad hoc contra el inventario | [Lab — Conexión agentless](02-lab-conexion-agentless.md) |
| Dejar los nodos en un estado base | Pasos 1 y 2 en cada servidor | Un playbook que se ejecuta las veces que haga falta | [Lab — Primer playbook](03-lab-primer-playbook.md) |
| Instalar y configurar nginx y el portal | Pasos 3 a 7 | Playbooks, plantillas y roles por entorno | M03 a M05 |
| Publicar una release nueva | Paso 5 a mano, nodo a nodo, avisando al del balanceador | Despliegue por tandas, con vuelta atrás si la versión no responde | M07 |
| Parchear y cambios controlados | Ventana de mantenimiento y mucho cuidado | Ejecución en modo check, por grupos, con registro de lo que cambió | M08 y M10 |
| Orquestar base de datos, web y balanceador | Un orden que solo conoce quien lo hace | `site.yml` con el orden escrito | M09 |
| Ejecutar sin depender de un portátil | Quien tiene la clave, en su terminal | AWX o un pipeline de GitHub Actions | M11 y M12 |

## Arquitectura

```text
              Codespace = nodo de control
   ┌───────────────────────────────────────────────┐
   │ proyecto/                                     │
   │   ansible.cfg ........ usuario, clave, SSH    │
   │   inventario.ini ..... qué nodos              │
   │   primer-playbook.yml  qué tareas             │
   │                                               │
   │   ansible / ansible-playbook                  │
   └───────────────────────┬───────────────────────┘
                           │  SSH (usuario ansible + clave del curso)
                           │  ida: módulo en Python · vuelta: JSON
        ┌────────┬─────────┼─────────┬─────────┬─────────┐
        ▼        ▼         ▼         ▼         ▼         ▼
    dev-web1 pre-web1  prod-lb1  prod-web1 prod-web2  prod-db1
        sshd + python3 + usuario ansible con sudo
        (ningún agente de Ansible)
```

| Componente | Dónde vive | Qué hace |
|------------|-----------|----------|
| Nodo de control | El Codespace | Tiene Ansible instalado, lee el proyecto y abre las conexiones. Es el único sitio donde se instala Ansible |
| Nodos gestionados | Los seis contenedores Debian 13 del portal | Reciben las tareas. Solo necesitan `sshd`, Python 3 y un usuario con `sudo` (`ansible`, sin contraseña) |
| Inventario | `proyecto/inventario.ini` | Dice a qué nodos se puede apuntar y, más adelante, cómo se agrupan y con qué variables |
| `ansible.cfg` | `proyecto/ansible.cfg` | Fija el inventario por defecto, `remote_user = ansible`, la clave `~/.ssh/curso-ansible/curso_ansible` y las opciones de SSH (`-F ../infra/ssh_config`) |
| Módulos | Dentro de `ansible-core` y de las colecciones, en el nodo de control | Código Python que se envía al nodo, se ejecuta allí y devuelve el resultado |
| Playbooks | `proyecto/*.yml` | La versión escrita y repetible del runbook |

### Qué pasa al ejecutar una tarea

1. Ansible lee `ansible.cfg` de la carpeta actual y, con él, el inventario.
2. Abre una conexión SSH con cada nodo, usando el usuario `ansible` y la clave del curso. Por defecto atiende
   a cinco nodos a la vez (`forks = 5`).
3. Si la tarea lleva `become: true`, ejecuta el módulo con `sudo` en el nodo.
4. Envía el módulo, en Python, por esa conexión. Con `pipelining = True` (activado en el `ansible.cfg` del
   curso) se lo pasa directamente al `python3` remoto; sin él, lo copia a `~/.ansible/tmp` del nodo y lo borra
   al terminar.
5. El módulo comprueba el estado, cambia lo que haga falta y responde con un JSON: `changed`, `failed`, mensajes.
6. Ansible pinta el resultado (`ok`, `changed`, `failed`, `unreachable`) y pasa a la siguiente tarea.

> [!NOTE]
> «Sin agente» no significa «sin requisitos»: el nodo necesita SSH y Python 3. Lo que no necesita es un servicio
> de Ansible instalado, un puerto propio ni un registro previo en un servidor central. Cuando la ejecución
> termina, en el nodo no queda nada de Ansible corriendo. Se comprueba en el
> [Lab — Conexión agentless](02-lab-conexion-agentless.md).

> [!TIP]
> Algunos módulos necesitan librerías de Python en el nodo: `ansible.builtin.apt`, por ejemplo, usa `python3-apt`.
> Los nodos del curso ya la traen.

## Ansible frente a otras formas de automatizar

| | Scripts por SSH (bash + bucle `for`) | Ansible | Herramientas con agente (Puppet, Chef, Salt con minion) |
|---|--------------------------------------|---------|----------------------------------------------------------|
| Qué se instala en el nodo | Nada | Nada: SSH y Python, que ya están | Un agente que corre como servicio y se registra en un servidor central |
| Cómo llega el cambio | Se empuja desde quien lanza el script | Se empuja (push) desde el nodo de control | El agente lo pide (pull) cada cierto tiempo |
| Cómo se describe | Órdenes imperativas: `mkdir`, `sed`, `apt-get` | Estado deseado en YAML, resuelto por módulos | Estado deseado en un lenguaje propio (DSL de Puppet, Ruby en Chef) o YAML (Salt) |
| Repetir la ejecución | Hay que programar cada comprobación (`[ -d … ] \|\| mkdir …`) | Los módulos comprueban y solo cambian lo necesario | Igual que Ansible: lo comprueba el agente |
| Saber qué cambió | Lo que el script imprima | `ok` / `changed` por tarea y nodo, `--diff`, `--check` | Informes del servidor central |
| Puesta en marcha | Inmediata | Inmediata: inventario y clave SSH | Servidor central, certificados y agente en cada nodo |
| Punto débil | No escala ni se mantiene: cada caso raro es más bash | Al ser push, no corrige solo la deriva: hay que lanzarlo (o programarlo en AWX) | Más piezas que mantener; el agente es otro software que parchear en cada nodo |

> [!NOTE]
> Ansible no prohíbe los comandos: `ansible.builtin.command` y `ansible.builtin.shell` existen para lo que no
> tiene módulo. Pero con ellos Ansible no sabe si algo cambió y marca `changed` siempre. En el curso se usan solo
> para consultar o cuando no hay otro remedio.

## Qué queda claro

- Ansible se instala en un sitio, el nodo de control, y llega a los nodos por SSH.
- Los nodos del portal solo necesitan SSH, Python 3 y el usuario `ansible` con `sudo`.
- Inventario, módulos y playbooks son las piezas del proyecto; `ansible.cfg` las une.
- Describir el estado final, y no los comandos, es lo que permite ejecutar el mismo playbook muchas veces.

La [demostración](01-del-runbook-al-playbook.md) recorre un inventario y un playbook reales sobre los nodos del
portal, ejecutados dos veces.
