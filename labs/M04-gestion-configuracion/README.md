# M04 — Gestión de configuración

[← Página anterior](../M03-desarrollo-playbooks/03-lab-ejecucion-idempotente.md) · [Siguiente página →](00-de-donde-sale-cada-valor.md)

El `portal.yml` del módulo anterior instala nginx y publica el portal, pero lleva los datos escritos dentro:
la release `1.0.0` aparece seis veces y el `estado.json` dice `"color": "#2563eb"` (el azul de dev) en
cualquier nodo. Si se lanza contra pre o prod, el portal sale con la versión y el color que no tocan.
Este módulo **separa datos y lógica**: los valores de cada entorno y de cada nodo pasan a ficheros de
variables, la configuración de nginx y el estado del portal se generan con plantillas y los facts de cada
máquina ajustan lo que depende de su hardware. Al terminar, **el mismo playbook** configura dev, pre y prod.

## Qué aprenderás

- Averiguar de dónde sale el valor de una variable en un nodo y cuál gana cuando está definida en varios sitios.
- Llevar los valores de cada entorno a `group_vars/` y las excepciones de un nodo a `host_vars/`, y comprobarlos con `ansible-inventory --host`.
- Generar `portal.conf`, `estado.json` y `nginx.conf` con `ansible.builtin.template` y Jinja2, y revisar el cambio con `--check --diff` antes de aplicarlo.
- Leer los facts de un nodo con el módulo `setup` y usarlos en una plantilla.
- Promocionar una versión de dev a pre cambiando un solo fichero de datos, sin tocar el playbook.

## Teoría

### Datos fuera del playbook

| Pieza | Dónde vive en `proyecto/` | Qué guarda en Tienda Norte |
|-------|---------------------------|----------------------------|
| `group_vars/all.yml` | `inventories/<entorno>/group_vars/` | Lo que comparte todo un entorno: `portal_entorno`, `portal_color`, `portal_version` |
| `group_vars/<grupo>.yml` | `inventories/<entorno>/group_vars/` | Lo que comparte un grupo (`web`, `lb`, `db`) |
| `host_vars/<nodo>.yml` | `inventories/<entorno>/host_vars/` | La excepción de un nodo: `prod-web2` admite 2048 conexiones por worker |
| `vars:` del play | `portal.yml` | Constantes del playbook, iguales en todos los entornos: `portal_puerto`, `portal_raiz`, `portal_worker_connections: 768`, `portal_db_host` |
| `-e` | Línea de comandos | Un valor puntual para una sola ejecución |

Ansible carga `group_vars/` y `host_vars/` cuando están **junto al inventario** que se usa (o junto al
playbook). Con `-i inventories/pre/hosts.yml` se leen los de `inventories/pre/` y ninguno más: cada entorno
tiene sus datos y no se mezclan.

### Quién gana (de menos a más)

| Orden | Origen |
|-------|--------|
| 1 | `vars:` del grupo `all` en `hosts.yml` |
| 2 | `group_vars/all.yml` |
| 3 | `group_vars/web.yml` (un grupo hijo gana a `all`) |
| 4 | `host_vars/<nodo>.yml` |
| 5 | Facts del nodo |
| 6 | `vars:` del play |
| 7 | `-e` en la línea de comandos (gana siempre) |

> [!WARNING]
> Las `vars:` del play ganan a `group_vars` y a `host_vars`. Como `portal.yml` define
> `portal_worker_connections: 768` en su bloque `vars:`, el `host_vars/prod-web2.yml` con `2048` no llega al
> nodo: lo verás con salida real en el [Lab — Facts](03-lab-facts.md). Un valor por defecto que el inventario
> pueda pisar va en los `defaults` de un rol, que se ven en el M05.

### Plantillas Jinja2

`ansible.builtin.template` funciona como `copy`, pero antes de copiar sustituye las expresiones Jinja2 por
las variables y los facts **de cada nodo**:

| Sintaxis | Para qué | Ejemplo en el portal |
|----------|----------|----------------------|
| `{{ variable }}` | Insertar un valor | `root {{ portal_raiz }}/current;` |
| `{{ v \| upper }}` | Transformarlo con un filtro | `{{ portal_entorno \| upper }}` → `DEV` |
| `{{ v \| default('x') }}` | Valor si no está definida | `{{ ansible_facts['processor_vcpus'] \| default(1) }}` |
| `{% for x in lista %}…{% endfor %}` | Repetir líneas | Un `server` por cada nodo de `groups['web']` |
| `{{ ansible_managed }}` | Aviso de fichero gestionado | `# Ansible managed` |

### Facts

Al empezar cada play, la tarea **Gathering Facts** ejecuta el módulo `setup` en cada nodo y deja lo que
descubre en `ansible_facts`: CPU, memoria, distribución, interfaces. `ansible_facts['processor_vcpus']`
dice cuántos núcleos ve el nodo, justo lo que pide `worker_processes` en `nginx.conf`.

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
