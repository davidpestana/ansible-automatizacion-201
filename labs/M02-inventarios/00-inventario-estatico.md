# Inventario estático

[← Página anterior](README.md) · [Siguiente página →](01-lab-grupos-y-jerarquias.md)

Antes de lanzar nada contra los nodos del portal de Tienda Norte, Ansible necesita saber cuáles son. Esta
demostración recorre el **inventario** de partida del proyecto.

## Qué se va a ver

**Qué se hace**

1. Se lee el inventario en INI.
2. Se mira su árbol de grupos con `ansible-inventory --graph`.
3. Se consulta como datos con `ansible-inventory --list`.
4. Se reescribe en YAML y se comprueba que dice lo mismo.
5. Se prueban **patrones** para elegir nodos, sin tocarlos, con `--list-hosts`.
6. Se usa un patrón en una ejecución real.

**Objetivos**

- Entender qué es un inventario estático y cómo lo elige Ansible (`ansible.cfg` o `-i`).
- Comprobar qué entiende Ansible del fichero, incluidos los grupos implícitos `all` y `ungrouped`.
- Elegir sobre qué nodos actúa cada ejecución.

**Conclusiones**

- INI y YAML son dos formatos del mismo inventario: Ansible los interpreta igual.
- Antes de tocar ningún nodo se puede saber exactamente a cuáles afecta un patrón.

## Punto de partida

- Terminal del Codespace, en la raíz del repositorio (`cd "$CODESPACE_VSCODE_FOLDER"`).
- Estado: los seis nodos levantados (`scripts/nodos.sh estado` da seis líneas `SSH ok`) y `proyecto/` en el
  punto de partida `m02`:

```bash
scripts/partida.sh m02
cd proyecto
```

```text
Listo: proyecto/ en el punto de partida «m02» (lo anterior está en proyecto.anterior/).
Entra en él con: cd /workspaces/…/proyecto
```

A partir de aquí, todos los comandos se lanzan desde `proyecto/`, donde está `ansible.cfg`.

## Recorrido

### 1 — El inventario en INI

El inventario de partida es `proyecto/inventario.ini`: un nombre de nodo por línea, sin nada más.

```bash
cat inventario.ini
```

```text
dev-web1
pre-web1
prod-lb1
prod-web1
prod-web2
prod-db1
```

Nadie pasa `-i` en los comandos: `ansible.cfg` ya dice cuál es el inventario por defecto, con la línea
`inventory = inventario.ini` de la sección `[defaults]`. Los nombres no llevan IP porque SSH los resuelve con
`infra/ssh_config` (`Host prod-web1` → `HostName 172.30.0.21`), que `ansible.cfg` le pasa con `ssh_args`.

### 2 — El árbol del inventario

`ansible-inventory --graph` dibuja cómo ve Ansible ese fichero:

```bash
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

Aparecen dos grupos que nadie ha escrito: `all`, que contiene todos los nodos, y `ungrouped`, donde caen los
que no pertenecen a ningún grupo propio. Aquí son los seis: el inventario aún no sabe qué es web, qué es
balanceador ni qué es prod.

### 3 — El inventario como datos

`--list` da lo mismo en JSON, que es el formato en el que Ansible trabaja internamente y el que devuelve
cualquier inventario dinámico:

```bash
ansible-inventory --list
```

```text
{
    "_meta": {
        "hostvars": {},
        "profile": "inventory_legacy"
    },
    "all": {
        "children": [
            "ungrouped"
        ]
    },
    "ungrouped": {
        "hosts": [
            "dev-web1",
            "pre-web1",
            "prod-lb1",
            "prod-web1",
            "prod-web2",
            "prod-db1"
        ]
    }
}
```

`_meta.hostvars` está vacío: ningún nodo tiene variables todavía. Ahí aparecerán en cuanto el inventario
las tenga.

### 4 — El mismo inventario en YAML

El fichero `proyecto/inventario.yml` dice exactamente lo mismo, en YAML:

```yaml
# proyecto/inventario.yml
all:
  hosts:
    dev-web1:
    pre-web1:
    prod-lb1:
    prod-web1:
    prod-web2:
    prod-db1:
```

Cada nodo es una clave bajo `all.hosts`, sin valor (más adelante, ese valor serán sus variables). Con `-i`
se le indica a Ansible que use este fichero en lugar del de `ansible.cfg`:

```bash
ansible-inventory -i inventario.yml --graph
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

El árbol es idéntico. Ansible detecta el formato por el contenido, no por la extensión. Los dos formatos
escriben un grupo así:

| INI | YAML |
|-----|------|
| `[web]` y debajo un nodo por línea | `all:` → `children:` → `web:` → `hosts:` → un nodo por clave |

El INI es más corto para listas planas; el YAML aguanta mejor grupos anidados y variables con estructura, y es
el que usa el proyecto desde los inventarios por entorno.

### 5 — Patrones: elegir sobre qué nodos se actúa

Cada comando `ansible` recibe un **patrón** de nodos. `--list-hosts` enseña a quién afectaría sin
conectar con nadie:

```bash
ansible all --list-hosts
```

```text
  hosts (6):
    dev-web1
    pre-web1
    prod-lb1
    prod-web1
    prod-web2
    prod-db1
```

Un comodín sobre los nombres selecciona los cuatro nodos de prod:

```bash
ansible 'prod-*' --list-hosts
```

```text
  hosts (4):
    prod-lb1
    prod-web1
    prod-web2
    prod-db1
```

`!` excluye. Así quedan todos salvo la base de datos:

```bash
ansible 'all:!prod-db1' --list-hosts
```

```text
  hosts (5):
    dev-web1
    pre-web1
    prod-lb1
    prod-web1
    prod-web2
```

Las comillas simples evitan que la shell interprete `*` o `!` antes de que lleguen a Ansible.

### 6 — Un patrón en una ejecución real

Con una lista separada por comas, el ping llega solo a los dos nodos que no son de prod:

```bash
ansible 'dev-web1,pre-web1' -m ansible.builtin.ping
```

```text
dev-web1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
pre-web1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
```

Y un nombre que no está en el inventario no da error, solo un aviso y ninguna ejecución:

```bash
ansible prod-web3 -m ansible.builtin.ping
```

```text
[WARNING]: Could not match supplied host pattern, ignoring: prod-web3
[WARNING]: No hosts matched, nothing to do
```

Ansible solo actúa sobre lo que está en el inventario, aunque el nodo exista en la red.

## Qué queda visto

- Un inventario estático es un fichero (INI o YAML) con los nodos; `ansible.cfg` fija cuál se usa por defecto y
  `-i` lo cambia en cada comando.
- `ansible-inventory --graph` y `--list` enseñan qué entiende Ansible del fichero, con los grupos implícitos
  `all` y `ungrouped`.
- Los patrones (`all`, comodines, listas, `!`) eligen los nodos, y `--list-hosts` lo comprueba sin tocarlos.

Con nombres sueltos, «los web de prod» se escribe a mano. El [Lab — Grupos y jerarquías](01-lab-grupos-y-jerarquias.md)
agrupa los nodos por función y por entorno; se puede hacer sin haber seguido esta demostración.
