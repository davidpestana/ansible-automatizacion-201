# M02 — Inventarios

[← Página anterior](../M01-fundamentos-arquitectura/03-lab-primer-playbook.md) · [Siguiente página →](00-inventario-del-portal.md)

Hasta ahora, el inventario del portal de Tienda Norte es una lista de seis nombres en `proyecto/inventario.ini`.
Para Ansible todos son iguales: no sabe que `prod-lb1` es el balanceador, que `prod-db1` lleva PostgreSQL ni
que `dev-web1` es un entorno donde se puede romper. Así que cualquier ejecución va a «todos» o a nombres
escritos a mano, y lanzar algo contra prod por error está a un `all` de distancia. Este módulo convierte esa
lista en la descripción de la arquitectura: grupos por función y por entorno, los valores que distinguen a
cada nodo y un inventario por entorno, para que cada ejecución apunte a dev, pre o prod de forma explícita.
Se cierra con un inventario dinámico que descubre los nodos a partir de los contenedores que los ejecutan.

## Qué aprenderás

- Leer un inventario con `ansible-inventory --graph` y `--list` y elegir nodos con patrones antes de lanzar nada.
- Agrupar los nodos del portal por función (`web`, `lb`, `db`) y por entorno (`dev`, `pre`, `prod`), con
  grupos que contienen grupos.
- Dar valores a grupos y a nodos concretos dentro del inventario y saber cuál se aplica cuando chocan.
- Separar dev, pre y prod en inventarios propios y decidir con `-i` (o con `ansible.cfg`) contra cuál trabajas.
- Generar el inventario desde Docker con el plugin `community.docker.docker_containers`, agrupando por las
  etiquetas de los contenedores.

## Teoría

Un **inventario** responde a dos preguntas: qué nodos hay y cómo se agrupan. Lo demás (variables,
conexión) cuelga de ahí. Ansible siempre añade dos grupos implícitos: `all` (todos los nodos) y `ungrouped`
(los que no están en ningún grupo propio).

| Formato | Aspecto | Cuándo se usa en el curso |
|---------|---------|---------------------------|
| INI | `[web]` y un nodo por línea; variables con `clave=valor` | Inventario plano de partida y labs de grupos y variables |
| YAML | `all:` → `children:` → `web:` → `hosts:` | Inventarios por entorno de `proyecto/inventories/` desde M03 |
| Plugin (YAML) | `plugin: community.docker.docker_containers` y sus opciones | Inventario dinámico: los nodos salen de Docker al ejecutar |

Los grupos del portal se cruzan en dos ejes. Un nodo está en tantos grupos como haga falta:

| Nodo | Grupo por función | Grupo por entorno |
|------|-------------------|-------------------|
| `dev-web1` | `web` | `dev` |
| `pre-web1` | `web` | `pre` |
| `prod-lb1` | `lb` | `prod` |
| `prod-web1`, `prod-web2` | `web` | `prod` |
| `prod-db1` | `db` | `prod` |

Un grupo puede contener otros grupos (`children`): `pruebas` = `dev` + `pre`. Y para elegir nodos en cada
ejecución están los **patrones**:

| Patrón | Significado | En el portal |
|--------|-------------|--------------|
| `web` | Un grupo | Los cuatro nodos web |
| `web:lb` | Unión | Web y balanceador |
| `prod:&web` | Intersección | `prod-web1` y `prod-web2` |
| `web:!prod` | Diferencia | `dev-web1` y `pre-web1` |
| `prod-*` | Comodín sobre nombres | Los cuatro nodos de prod |

Cuando una variable está definida en varios sitios del inventario, gana la más específica:

| Dónde | Precedencia |
|-------|-------------|
| `[all:vars]` (o `vars:` bajo `all`) | La más baja |
| Grupo padre (`pruebas`) | Pierde frente a sus hijos |
| Grupo hijo (`dev`) | Gana al padre |
| Variable de host (en la línea del nodo) | La más alta dentro del inventario |

> [!NOTE]
> Las variables de conexión (`ansible_host`, `ansible_port`, `ansible_user`…) son variables de inventario
> como cualquier otra, pero cambian cómo conecta Ansible. En el curso los nombres ya resuelven por
> `infra/ssh_config`, así que `ansible_host` solo hace falta cuando el nombre del inventario no basta para
> llegar al nodo, como en el inventario dinámico.

> [!NOTE]
> Este módulo deja las variables dentro del inventario. Los ficheros `group_vars/` y `host_vars/` junto al
> inventario, y la precedencia completa (inventario, playbook, línea de comandos), son del M04.

Por qué un inventario por entorno y no uno con todo:

| Un inventario con dev, pre y prod | Un inventario por entorno |
|-----------------------------------|---------------------------|
| `ansible web …` toca los cuatro web, prod incluido | `ansible web …` toca solo los web del entorno elegido |
| Una variable de entorno en `all` se pisa entre entornos | Cada fichero tiene su `all` y su `portal_entorno` |
| El entorno se elige con patrones, a mano | El entorno se elige con `-i inventories/<entorno>/hosts.yml` |

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [El inventario del portal](00-inventario-del-portal.md) | Demostración: un inventario INI y su versión YAML, leídos con ansible-inventory |
| 01 | [Lab — Grupos y jerarquías](01-lab-grupos-y-jerarquias.md) | Agrupas los nodos por función y por entorno con grupos hijos |
| 02 | [Lab — Variables en inventario](02-lab-variables-en-inventario.md) | Das valores a grupos y hosts y compruebas cuál gana |
| 03 | [Lab — Inventarios por entornos](03-lab-inventarios-por-entornos.md) | Separas dev, pre y prod en inventarios propios y apuntas cada ejecución a uno |
| 04 | [Lab — Inventario dinámico](04-lab-inventario-dinamico.md) | Descubres los nodos a partir de los contenedores con el plugin de Docker |

→ Empieza por **[00 — El inventario del portal](00-inventario-del-portal.md)**.
<!-- /gen:paginas -->
