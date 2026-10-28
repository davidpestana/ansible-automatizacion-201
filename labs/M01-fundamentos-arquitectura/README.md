# M01 — Fundamentos y arquitectura

[← Página anterior](../../README.md) · [Siguiente página →](00-que-es-ansible.md)

Ansible es una herramienta de código abierto para la automatización de TI: configura servidores, despliega
aplicaciones y gestiona infraestructuras describiendo en ficheros de texto el estado al que deben llegar las
máquinas. Este módulo presenta sus piezas y su arquitectura: un nodo de control que se conecta por SSH a los
nodos gestionados sin instalar ningún agente en ellos, un inventario que dice cuáles son, módulos que hacen el
trabajo y playbooks que encadenan ese trabajo de forma repetible e idempotente.

## Qué aprenderás

- Explicar qué hace el nodo de control y qué necesita cada nodo gestionado: SSH, Python y un usuario con
  `sudo`, nada más.
- Instalar Ansible en un entorno virtual con una versión fijada, configurarlo con `ansible.cfg` y saber de
  dónde sale cada ajuste (`ansible-config dump --only-changed`).
- Seguir una ejecución por dentro con `-vvv`: el módulo empaquetado (AnsiballZ) que viaja al nodo, se ejecuta
  con su Python y se borra.
- Describir varios nodos en un inventario y comprobar que Ansible llega a todos con `ansible all -m ping`.
- Lanzar módulos ad hoc (`command`, `setup`) para consultar muchos nodos de una vez, sin entrar en ellos uno a uno.
- Comprobar en un nodo gestionado que Ansible no deja ningún proceso ni paquete instalado.
- Escribir y ejecutar un primer playbook, leer el `PLAY RECAP` y ver que la segunda ejecución no cambia nada.

## Teoría

### Las piezas de un proyecto Ansible

| Pieza | Qué es | Ejemplo |
|-------|--------|---------|
| Nodo de control | La máquina donde está instalado Ansible y desde la que se lanza todo | Un portátil, un servidor de administración o un runner de CI |
| Nodos gestionados | Las máquinas que Ansible configura | Servidores web, de base de datos, balanceadores |
| Inventario | Fichero con la lista de nodos (y, más adelante, sus grupos y variables) | `inventario.ini` |
| `ansible.cfg` | Configuración del proyecto: inventario por defecto, usuario remoto, clave, opciones de SSH | `ansible.cfg` en la raíz del proyecto |
| Módulo | Unidad de trabajo que se ejecuta en el nodo: crear un directorio, copiar un fichero, instalar un paquete | `ansible.builtin.file`, `ansible.builtin.copy`, `ansible.builtin.ping` |
| Tarea | Una llamada a un módulo con sus parámetros y un nombre legible | «Crear el directorio de la aplicación» |
| Play | Un conjunto de tareas que se aplican a unos hosts del inventario | «Preparar los servidores web», sobre `webservers` |
| Playbook | Fichero YAML con uno o varios plays | `site.yml` |

### Dos formas de lanzar Ansible

| | Comando ad hoc | Playbook |
|---|----------------|----------|
| Herramienta | `ansible <hosts> -m <módulo> -a '<argumentos>'` | `ansible-playbook <fichero>.yml` |
| Para qué | Una consulta o un arreglo puntual: ¿responden todos?, ¿qué versión del sistema tienen? | Un procedimiento completo y repetible |
| Queda escrito | No, solo en el historial del terminal | Sí, en un fichero que se versiona y se revisa |
| Ejemplo | `ansible all -m command -a 'uname -a'` | `ansible-playbook site.yml` |

### Cómo leer el resultado

Cada tarea devuelve un estado por nodo, y el `PLAY RECAP` final los cuenta:

| Estado | Significado |
|--------|-------------|
| `ok` | La tarea se ejecutó y el nodo ya estaba como se pedía: no hizo falta tocar nada |
| `changed` | La tarea tuvo que cambiar algo en el nodo para dejarlo como se pedía |
| `failed` | La tarea falló en ese nodo (permisos, fichero que no existe, módulo mal escrito…) |
| `unreachable` | Ansible no pudo ni conectar por SSH con el nodo |

> [!NOTE]
> `ok` no significa «no se ejecutó»: la tarea se ejecutó, comprobó el estado y no tuvo nada que cambiar. Por eso
> un playbook bien escrito da `changed` la primera vez y `changed=0` la segunda. Eso es la **idempotencia**.

> [!NOTE]
> Ansible busca `ansible.cfg` en el directorio actual. Por eso los comandos se lanzan desde la raíz del
> proyecto: desde otra carpeta no encuentra el inventario y solo ve `localhost`. En los laboratorios del curso,
> esa raíz es `proyecto/`.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [Qué es Ansible](00-que-es-ansible.md) | Para qué sirve, casos de uso y cómo trabaja sin agente |
| 01 | [Lab — Instalar y configurar Ansible](01-lab-instalar-y-configurar.md) | Instalas Ansible desde cero en un entorno virtual, lo configuras con ansible.cfg, ves qué hace en el nodo en cada ejecución e instalas una colección |
| 02 | [Del runbook al playbook](02-del-runbook-al-playbook.md) | Demostración: el runbook del portal frente a un inventario, un playbook y sus módulos, ejecutado dos veces |
| 03 | [Lab — Conexión agentless](03-lab-conexion-agentless.md) | Conectas por SSH con los nodos y lanzas módulos ad hoc desde el Codespace |
| 04 | [Lab — Primer playbook](04-lab-primer-playbook.md) | Escribes y ejecutas un playbook que prepara los nodos web |

→ Empieza por **[00 — Qué es Ansible](00-que-es-ansible.md)**.
<!-- /gen:paginas -->
