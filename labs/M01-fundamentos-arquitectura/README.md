# M01 — Fundamentos y arquitectura

[← Página anterior](../../README.md) · [Siguiente página →](00-que-es-ansible.md)

El equipo de operaciones de Tienda Norte mantiene el portal de pedidos con un runbook: una lista de pasos que
alguien repite por SSH en cada servidor, de `dev-web1` a `prod-db1`. Este módulo pone la primera piedra para
sustituirlo. Primero, qué es Ansible y cómo llega a los nodos sin instalar nada en ellos. Después, módulos
sueltos lanzados desde el Codespace. Por último, un primer playbook que deja los seis nodos del portal en el
mismo estado, se ejecute las veces que se ejecute.

## Qué aprenderás

- Explicar qué hace el nodo de control (tu Codespace) y qué necesita cada nodo gestionado: SSH, Python y un
  usuario con `sudo`, nada más.
- Describir los nodos del portal en un inventario y comprobar que Ansible llega a todos con `ansible all -m ping`.
- Lanzar módulos ad hoc (`command`, `setup`) para consultar los seis nodos de una vez, sin entrar en ellos uno a uno.
- Comprobar en un nodo que Ansible no deja ningún proceso ni paquete instalado.
- Escribir `primer-playbook.yml`, ejecutarlo, leer el `PLAY RECAP` y ver que la segunda ejecución no cambia nada.

## Teoría

### Las piezas de un proyecto Ansible

| Pieza | Qué es | En Tienda Norte |
|-------|--------|-----------------|
| Nodo de control | La máquina donde está instalado Ansible y desde la que se lanza todo | El Codespace, dentro de `proyecto/` |
| Nodos gestionados | Las máquinas que Ansible configura | `dev-web1`, `pre-web1`, `prod-lb1`, `prod-web1`, `prod-web2`, `prod-db1` |
| Inventario | Fichero con la lista de nodos (y, más adelante, sus grupos y variables) | `proyecto/inventario.ini` |
| `ansible.cfg` | Configuración del proyecto: inventario por defecto, usuario remoto, clave, opciones de SSH | `proyecto/ansible.cfg`, ya preparado |
| Módulo | Unidad de trabajo que se ejecuta en el nodo: crear un directorio, copiar un fichero, instalar un paquete | `ansible.builtin.file`, `ansible.builtin.copy`, `ansible.builtin.ping` |
| Tarea | Una llamada a un módulo con sus parámetros y un nombre legible | «Crear la carpeta del portal» |
| Play | Un conjunto de tareas que se aplican a unos hosts del inventario | «Preparar los nodos del portal», sobre `all` |
| Playbook | Fichero YAML con uno o varios plays | `proyecto/primer-playbook.yml` |

### Dos formas de lanzar Ansible

| | Comando ad hoc | Playbook |
|---|----------------|----------|
| Herramienta | `ansible <hosts> -m <módulo> -a '<argumentos>'` | `ansible-playbook <fichero>.yml` |
| Para qué | Una consulta o un arreglo puntual: ¿responden todos?, ¿qué versión de Debian tienen? | Un procedimiento completo y repetible: el runbook |
| Queda escrito | No, solo en el historial del terminal | Sí, en un fichero que se versiona y se revisa |
| Ejemplo | `ansible all -m command -a 'uname -a'` | `ansible-playbook primer-playbook.yml` |

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
> Todos los comandos `ansible` y `ansible-playbook` del curso se lanzan desde `proyecto/`, porque ahí está
> `ansible.cfg`. Desde otra carpeta Ansible no encuentra el inventario y solo ve `localhost`.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [Qué es Ansible](00-que-es-ansible.md) | Para qué sirve, casos de uso en Tienda Norte y cómo trabaja sin agente |
| 01 | [Del runbook al playbook](01-del-runbook-al-playbook.md) | Demostración: el runbook del portal frente a un inventario, un playbook y sus módulos, ejecutado dos veces |
| 02 | [Lab — Conexión agentless](02-lab-conexion-agentless.md) | Conectas por SSH con los nodos y lanzas módulos ad hoc desde el Codespace |
| 03 | [Lab — Primer playbook](03-lab-primer-playbook.md) | Escribes y ejecutas un playbook que prepara los nodos web |

→ Empieza por **[00 — Qué es Ansible](00-que-es-ansible.md)**.
<!-- /gen:paginas -->
