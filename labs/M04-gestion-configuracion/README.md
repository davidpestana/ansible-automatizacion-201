# M04 — Gestión de configuración

[← Página anterior](../M03-desarrollo-playbooks/03-lab-ejecucion-idempotente.md) · [Siguiente página →](00-de-donde-sale-cada-valor.md)

Gestionar la configuración con Ansible es **separar datos y lógica**: el playbook describe qué hay que hacer y
los valores que cambian de un entorno o de un nodo a otro viven aparte, en ficheros de variables. Así el mismo
playbook configura desarrollo, preproducción y producción. Este módulo cubre dónde puede definirse una
variable y cuál gana cuando choca (`group_vars`, `host_vars`, play, línea de comandos), cómo se generan ficheros
de configuración con plantillas Jinja2 y cómo los **facts** de cada máquina adaptan la configuración a su
hardware y a su sistema.

## Qué aprenderás

- Averiguar de dónde sale el valor de una variable en un nodo y cuál gana cuando está definida en varios sitios.
- Llevar los valores de cada entorno a `group_vars/` y las excepciones de un nodo a `host_vars/`, y comprobarlos con `ansible-inventory --host`.
- Generar ficheros de configuración con `ansible.builtin.template` y Jinja2, y revisar el cambio con `--check --diff` antes de aplicarlo.
- Leer los facts de un nodo con el módulo `setup` y usarlos en una plantilla.
- Promocionar una versión de un entorno al siguiente cambiando un solo fichero de datos, sin tocar el playbook.

## Teoría

### Datos fuera del playbook

| Pieza | Dónde vive | Qué guarda |
|-------|------------|------------|
| `group_vars/all.yml` | Junto al inventario | Lo que comparte todo un entorno: nombre del entorno, versión a desplegar |
| `group_vars/<grupo>.yml` | Junto al inventario | Lo que comparte un grupo (`webservers`, `dbservers`) |
| `host_vars/<nodo>.yml` | Junto al inventario | La excepción de un nodo: un límite de conexiones mayor en una máquina más grande |
| `vars:` del play | En el playbook | Constantes iguales en todos los entornos: puerto, rutas |
| `-e` | Línea de comandos | Un valor puntual para una sola ejecución |

Ansible carga `group_vars/` y `host_vars/` cuando están **junto al inventario** que se usa (o junto al
playbook). Con un inventario por entorno (`-i inventories/pre/hosts.yml`) se leen los de `inventories/pre/` y
ninguno más: cada entorno tiene sus datos y no se mezclan.

### Quién gana (de menos a más)

| Orden | Origen |
|-------|--------|
| 1 | `vars:` del grupo `all` en el fichero de inventario |
| 2 | `group_vars/all.yml` |
| 3 | `group_vars/<grupo>.yml` (un grupo hijo gana a `all`) |
| 4 | `host_vars/<nodo>.yml` |
| 5 | Facts del nodo |
| 6 | `vars:` del play |
| 7 | `-e` en la línea de comandos (gana siempre) |

Es un resumen de la [precedencia completa](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence),
que tiene más niveles (roles, bloques, tareas…).

> [!WARNING]
> Las `vars:` del play ganan a `group_vars` y a `host_vars`. Si un playbook fija un valor en `vars:`, ningún
> `host_vars/` lo podrá cambiar para un nodo. Un valor por defecto que el inventario pueda pisar va en los
> `defaults` de un rol, que se ven en el M05.

### Plantillas Jinja2

`ansible.builtin.template` funciona como `copy`, pero antes de copiar sustituye las expresiones Jinja2 por
las variables y los facts **de cada nodo**:

| Sintaxis | Para qué | Ejemplo |
|----------|----------|---------|
| `{{ variable }}` | Insertar un valor | `listen {{ app_puerto }};` |
| `{{ v \| upper }}` | Transformarlo con un filtro | `{{ entorno \| upper }}` → `DEV` |
| `{{ v \| default('x') }}` | Valor si no está definida | `{{ ansible_facts['processor_vcpus'] \| default(1) }}` |
| `{% for x in lista %}…{% endfor %}` | Repetir líneas | Un `server` por cada nodo de `groups['webservers']` |
| `{{ ansible_managed }}` | Aviso de fichero gestionado | `# Ansible managed` |

### Facts

Al empezar cada play, la tarea **Gathering Facts** ejecuta el módulo `setup` en cada nodo y deja lo que
descubre en `ansible_facts`: CPU, memoria, distribución, interfaces. Por ejemplo,
`ansible_facts['processor_vcpus']` dice cuántos núcleos ve el nodo, el dato que pide `worker_processes` en la
configuración de nginx.

> [!NOTE]
> Los facts no son variables del inventario: no aparecen en `ansible-inventory --host` ni existen en un
> comando ad hoc con `debug`. Solo están cuando se ha ejecutado `setup`, a mano o con `gather_facts`
> (activado por defecto en cada play).

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [De dónde sale cada valor](00-de-donde-sale-cada-valor.md) | Demostración: la misma variable en inventario, group_vars, host_vars y línea de comandos |
| 01 | [Lab — group_vars y host_vars](01-lab-group-vars-host-vars.md) | Sacas los valores del portal del playbook a ficheros de variables |
| 02 | [Lab — Plantillas Jinja2](02-lab-plantillas-jinja2.md) | Generas la configuración de nginx y el estado del portal con plantillas |
| 03 | [Lab — Facts](03-lab-facts.md) | Usas los facts de cada nodo para ajustar la configuración |
| 04 | [Lab — Configuración por entorno](04-lab-configuracion-por-entorno.md) | El mismo playbook produce la configuración de dev, pre y prod |

→ Empieza por **[00 — De dónde sale cada valor](00-de-donde-sale-cada-valor.md)**.
<!-- /gen:paginas -->
