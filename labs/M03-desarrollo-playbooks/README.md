# M03 — Desarrollo de playbooks

[← Página anterior](../M02-inventarios/04-lab-inventario-dinamico.md) · [Siguiente página →](00-anatomia-de-un-playbook.md)

Un playbook es la forma escrita y repetible de un procedimiento: un fichero YAML con uno o varios plays que
dicen a qué nodos se aplica qué lista de tareas. Este módulo cubre la estructura y la sintaxis YAML de un
playbook, los módulos más usados para gestionar paquetes, ficheros, usuarios y servicios, y la forma de
ejecutarlo sin miedo: validación de sintaxis, simulación con `--check --diff` e idempotencia. El caso típico
es el patrón **paquete → configuración → servicio**, que resuelve la instalación de casi cualquier servicio.

## Qué aprenderás

- Leer y escribir un playbook en YAML sin pelearte con la indentación, y detectar los errores con `--syntax-check` antes de tocar un nodo.
- Encontrar el módulo adecuado para cada paso de un procedimiento con `ansible-doc` y usar sus argumentos.
- Automatizar el patrón paquete → configuración → servicio de un servidor web.
- Ensayar un cambio con `--check --diff`, reconocer una tarea que no es idempotente y corregirla.

## Teoría

### De un comando a una tarea

| Comando manual (por SSH) | Tarea de Ansible | Estado que se pide |
|--------------------------|------------------|--------------------|
| `apt-get install nginx` | `ansible.builtin.apt` | `name: nginx`, `state: present` |
| `useradd -m operador` | `ansible.builtin.user` | `name: operador`, `state: present` |
| `mkdir -p /srv/app/releases/1.0.0` | `ansible.builtin.file` | `state: directory` |
| `ln -s … /srv/app/current` | `ansible.builtin.file` | `state: link` |
| `scp app.conf …` | `ansible.builtin.copy` | `src` o `content`, `dest`, `mode` |
| `service nginx start` | `ansible.builtin.service` | `state: started` |

El comando dice **qué hacer**; la tarea dice **cómo tiene que quedar**. El módulo comprueba el estado actual y
solo actúa si no coincide: por eso la segunda ejecución sale `changed=0`.

### Las piezas de un playbook

```yaml
- name: Servidor web            # play
  hosts: webservers             # patrón de inventario
  become: true                  # sudo en el nodo
  tasks:
    - name: Instalar nginx      # tarea = name + módulo
      ansible.builtin.apt:
        name: nginx
        state: present

    - name: Arrancar nginx
      ansible.builtin.service:
        name: nginx
        state: started
```

| Pieza | Qué es |
|-------|--------|
| Playbook | Fichero YAML con una lista de plays |
| Play | Un grupo de hosts y lo que se les hace |
| `hosts` | Patrón de inventario: grupo, nodo o combinación |
| `become` | Ejecutar con privilegios (sudo) en el nodo |
| `tasks` | Lista ordenada de tareas |
| Tarea | `name` + un módulo con sus argumentos |

> [!NOTE]
> YAML no admite tabuladores y la indentación **es** la estructura: dos espacios más a la derecha significan
> «esto está dentro de lo anterior». Un valor que empieza por `{{` va entre comillas, y `yes`, `no`, `on` u `off`
> sin comillas son booleanos, no texto.

### Ejecutar sin miedo

| Opción | Qué hace | Cuándo |
|--------|----------|--------|
| `--syntax-check` | Valida YAML y estructura, sin conectar | Siempre, tras editar |
| `--list-tasks` | Lista plays y tareas que se ejecutarían | Para revisar el orden |
| `--check` | Simula: los módulos dicen qué cambiarían | Antes de aplicar en un nodo ya configurado |
| `--diff` | Muestra el antes y el después de los ficheros | Junto a `--check` o al aplicar |

> [!WARNING]
> `ansible.builtin.command` y `ansible.builtin.shell` no saben si su orden cambia algo: siempre dicen `changed` y
> en `--check` se saltan. Usa un módulo específico siempre que exista y, si no, `creates` o `changed_when`.

> [!NOTE]
> Recargar un servicio solo cuando cambia su configuración se puede resolver con `register` y `when`, pero la
> forma idiomática es un **handler**, que se ve en el M06.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [Anatomía de un playbook](00-anatomia-de-un-playbook.md) | Demostración: estructura de un playbook, errores típicos de YAML y --syntax-check |
| 01 | [Lab — Módulos principales](01-lab-modulos-principales.md) | Resuelves pasos del runbook con apt, user, file, copy y service, consultando ansible-doc |
| 02 | [Lab — Instalar y configurar un servicio](02-lab-instalar-servicio.md) | Automatizas nginx y la página del portal en los nodos web |
| 03 | [Lab — Ejecución idempotente](03-lab-ejecucion-idempotente.md) | Ejecutas con --check y --diff y corriges una tarea que siempre cambia |

→ Empieza por **[00 — Anatomía de un playbook](00-anatomia-de-un-playbook.md)**.
<!-- /gen:paginas -->
