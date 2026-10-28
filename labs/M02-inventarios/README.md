# M02 — Inventarios

[← Página anterior](../M01-fundamentos-arquitectura/04-lab-primer-playbook.md) · [Siguiente página →](00-inventario-estatico.md)

El inventario es la descripción de la infraestructura que gestiona Ansible: qué nodos hay, cómo se agrupan y
qué valores distinguen a cada uno. Una lista plana de nombres sirve para empezar, pero no dice qué hace cada
máquina ni a qué entorno pertenece, y cualquier ejecución acaba yendo a «todos» o a nombres escritos a mano.
Este módulo trata el inventario como modelo de la arquitectura: grupos por función y por entorno, variables
de grupo y de host, un inventario por entorno para que cada ejecución apunte a uno de forma explícita y, por
último, inventarios dinámicos que descubren los nodos a partir de una fuente externa.

## Qué aprenderás

- Leer un inventario con `ansible-inventory --graph` y `--list` y elegir nodos con patrones antes de lanzar nada.
- Agrupar nodos por función y por entorno, con grupos que contienen grupos.
- Dar valores a grupos y a nodos concretos dentro del inventario y saber cuál se aplica cuando chocan.
- Separar los entornos en inventarios propios y decidir con `-i` (o con `ansible.cfg`) contra cuál trabajas.
- Generar el inventario desde Docker con el plugin `community.docker.docker_containers`, agrupando por las
  etiquetas de los contenedores.

## Teoría

Un **inventario** responde a dos preguntas: qué nodos hay y cómo se agrupan. Lo demás (variables,
conexión) cuelga de ahí. Ansible siempre añade dos grupos implícitos: `all` (todos los nodos) y `ungrouped`
(los que no están en ningún grupo propio).

| Formato | Aspecto | Cuándo conviene |
|---------|---------|-----------------|
| INI | `[webservers]` y un nodo por línea; variables con `clave=valor` | Inventarios pequeños y planos |
| YAML | `all:` → `children:` → `webservers:` → `hosts:` | Jerarquías de grupos y variables estructuradas |
| Plugin (YAML) | `plugin: <colección>.<plugin>` y sus opciones | Inventario dinámico: los nodos salen de una nube, un hipervisor o Docker al ejecutar |

Los grupos suelen cruzarse en dos ejes, función y entorno. Un nodo está en tantos grupos como haga falta:

| Nodo | Grupo por función | Grupo por entorno |
|------|-------------------|-------------------|
| `web-dev1` | `webservers` | `dev` |
| `web-prod1`, `web-prod2` | `webservers` | `prod` |
| `lb-prod1` | `loadbalancers` | `prod` |
| `db-prod1` | `dbservers` | `prod` |

Un grupo puede contener otros grupos (`children`): `pruebas` = `dev` + `pre`. Y para elegir nodos en cada
ejecución están los **patrones**:

| Patrón | Significado | Con los nodos de la tabla |
|--------|-------------|---------------------------|
| `webservers` | Un grupo | Los tres servidores web |
| `webservers:loadbalancers` | Unión | Web y balanceador |
| `prod:&webservers` | Intersección | `web-prod1` y `web-prod2` |
| `webservers:!prod` | Diferencia | `web-dev1` |
| `*-prod*` | Comodín sobre nombres | Los cuatro nodos de prod |

Cuando una variable está definida en varios sitios del inventario, gana la más específica:

| Dónde | Precedencia |
|-------|-------------|
| `[all:vars]` (o `vars:` bajo `all`) | La más baja |
| Grupo padre (`pruebas`) | Pierde frente a sus hijos |
| Grupo hijo (`dev`) | Gana al padre |
| Variable de host (en la línea del nodo) | La más alta dentro del inventario |

> [!NOTE]
> Las variables de conexión (`ansible_host`, `ansible_port`, `ansible_user`…) son variables de inventario
> como cualquier otra, pero cambian cómo conecta Ansible. `ansible_host` solo hace falta cuando el nombre del
> inventario no basta para llegar al nodo (no resuelve por DNS ni por `ssh_config`).

> [!NOTE]
> Las variables también pueden vivir en ficheros `group_vars/` y `host_vars/` junto al inventario; esa
> organización y la precedencia completa (inventario, playbook, línea de comandos) son del M04.

Por qué un inventario por entorno y no uno con todo:

| Un inventario con todos los entornos | Un inventario por entorno |
|--------------------------------------|---------------------------|
| `ansible webservers …` toca todos los web, producción incluida | `ansible webservers …` toca solo los del entorno elegido |
| Una variable de entorno en `all` se pisa entre entornos | Cada fichero tiene su `all` con sus valores |
| El entorno se elige con patrones, a mano | El entorno se elige con `-i inventories/<entorno>/hosts.yml` |

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [Inventario estático](00-inventario-estatico.md) | Demostración: un inventario INI y su versión YAML, leídos con ansible-inventory |
| 01 | [Lab — Grupos y jerarquías](01-lab-grupos-y-jerarquias.md) | Agrupas los nodos por función y por entorno con grupos hijos |
| 02 | [Lab — Variables en inventario](02-lab-variables-en-inventario.md) | Das valores a grupos y hosts y compruebas cuál gana |
| 03 | [Lab — Inventarios por entornos](03-lab-inventarios-por-entornos.md) | Separas dev, pre y prod en inventarios propios y apuntas cada ejecución a uno |
| 04 | [Lab — Inventario dinámico](04-lab-inventario-dinamico.md) | Descubres los nodos a partir de los contenedores con el plugin de Docker |

→ Empieza por **[00 — Inventario estático](00-inventario-estatico.md)**.
<!-- /gen:paginas -->
