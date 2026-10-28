# Lab — Grupos y jerarquías

[← Página anterior](00-inventario-estatico.md) · [Siguiente página →](02-lab-variables-en-inventario.md)

El inventario del portal de Tienda Norte es una lista de seis nombres. Para hacer ping solo a los servidores
web de prod, hoy hay que escribir `prod-web1,prod-web2` a mano, y el día que llegue `prod-web3` habrá que
acordarse de añadirlo en cada comando. En este lab agrupas los nodos por lo que hacen (web, balanceador,
base de datos) y por el entorno en que viven (dev, pre, prod), y juntas dev y pre en un grupo de grupos.

### Objetivo

`proyecto/inventario.ini` con los grupos `web`, `lb`, `db`, `dev`, `pre`, `prod` y el grupo padre `pruebas`,
y comandos que actúan sobre `web`, `pruebas` o `prod:&web` sin nombrar ningún nodo.

### Punto de partida

- Terminal del Codespace, en la raíz del repositorio (`cd "$CODESPACE_VSCODE_FOLDER"`).
- Los seis nodos levantados: `scripts/nodos.sh estado` da seis líneas `SSH ok` (si no, `scripts/nodos.sh up`).
- `proyecto/` en el punto de partida `m02`: `ansible.cfg` apunta a `inventario.ini`, que tiene los seis
  nodos sin grupos. El paso 1 te deja ahí aunque no vengas de la página anterior.

### En qué consiste

Editas solo `proyecto/inventario.ini` (con el editor de VS Code) y compruebas cada cambio con
`ansible-inventory --graph` y con patrones. No tocas los nodos: lo único que se ejecuta en ellos es un
`ansible.builtin.ping`. Las variables de grupo son del [Lab — Variables en inventario](02-lab-variables-en-inventario.md).

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repositorio
scripts/partida.sh m02
cd proyecto
```

**Por qué:** deja `proyecto/` con el inventario plano de seis nodos, el mismo para todos, y guarda lo que
tuvieras en `proyecto.anterior/`.

**Resultado esperado:**

```text
Listo: proyecto/ en el punto de partida «m02» (lo anterior está en proyecto.anterior/).
Entra en él con: cd /workspaces/…/proyecto
```

### 2 — Mira el árbol de partida

**Acción:** `ansible-inventory --graph`

**Por qué:** es la referencia para ver qué cambia con cada grupo que añadas.

**Resultado esperado:** los seis nodos cuelgan de `@ungrouped`, dentro de `@all`. No hay ningún grupo propio.

### 3 — Agrupa por función

**Acción:** abre `proyecto/inventario.ini` en VS Code y sustituye su contenido por este:

```ini
# proyecto/inventario.ini
[web]
dev-web1
pre-web1
prod-web1
prod-web2

[lb]
prod-lb1

[db]
prod-db1
```

Guarda y ejecuta `ansible-inventory --graph`.

**Por qué:** web, balanceador y base de datos reciben cosas distintas: nginx y el portal, la configuración del
balanceador, PostgreSQL. Cada playbook del curso apunta a uno de estos grupos.

**Resultado esperado:**

```text
@all:
  |--@ungrouped:
  |--@web:
  |  |--dev-web1
  |  |--pre-web1
  |  |--prod-web1
  |  |--prod-web2
  |--@lb:
  |  |--prod-lb1
  |--@db:
  |  |--prod-db1
```

`@ungrouped` se queda vacío: todos los nodos tienen ya un grupo.

### 4 — Lanza un módulo contra un grupo

**Acción:** `ansible web -m ansible.builtin.ping`

**Por qué:** el patrón `web` es el nombre del grupo. Cuando llegue un cuarto servidor web, se añade una línea
en `[web]` y el comando no cambia.

**Resultado esperado:** cuatro respuestas `SUCCESS` con `"ping": "pong"`, de `dev-web1`, `pre-web1`,
`prod-web1` y `prod-web2` (el orden puede variar). Ni `prod-lb1` ni `prod-db1` aparecen:

```text
prod-web1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
…
```

### 5 — Agrupa por entorno

**Acción:** añade al final de `proyecto/inventario.ini`:

```ini
[dev]
dev-web1

[pre]
pre-web1

[prod]
prod-lb1
prod-web1
prod-web2
prod-db1
```

Guarda y ejecuta `ansible-inventory --graph`.

**Por qué:** la función dice *qué* se instala; el entorno dice *dónde* se puede romper. Un nodo puede estar en
varios grupos a la vez: `prod-web1` es web y es prod.

**Resultado esperado:** además de `@web`, `@lb` y `@db`, aparecen:

```text
  |--@dev:
  |  |--dev-web1
  |--@pre:
  |  |--pre-web1
  |--@prod:
  |  |--prod-lb1
  |  |--prod-web1
  |  |--prod-web2
  |  |--prod-db1
```

`prod-web1` sale dos veces en el árbol, una bajo `@web` y otra bajo `@prod`. Sigue siendo un solo nodo.

### 6 — Cruza los dos ejes con patrones

**Acción:** ejecuta, uno a uno:

```bash
ansible 'prod:&web' --list-hosts
ansible 'web:!prod' --list-hosts
ansible 'lb:db' --list-hosts
```

**Por qué:** `:&` es la intersección (web *y* prod), `:!` la diferencia (web *menos* prod) y `:` la unión.
Con dos ejes de grupos ya no hace falta un grupo para cada combinación. Las comillas simples impiden que la
shell se quede con `&` o `!`.

**Resultado esperado:**

```text
  hosts (2):
    prod-web1
    prod-web2
```

```text
  hosts (2):
    dev-web1
    pre-web1
```

```text
  hosts (2):
    prod-lb1
    prod-db1
```

### 7 — Crea un grupo de grupos

**Acción:** añade al final de `proyecto/inventario.ini`:

```ini
[pruebas:children]
dev
pre
```

Guarda y ejecuta `ansible-inventory --graph`.

**Por qué:** dev y pre son los entornos donde el equipo prueba antes de prod. Con `:children`, `pruebas`
contiene *grupos*, no nodos: si mañana hay un entorno `qa`, basta con añadirlo aquí.

**Resultado esperado:** `@dev` y `@pre` dejan de colgar de `@all` y pasan a estar dentro de `@pruebas`:

```text
  |--@prod:
  |  |--prod-lb1
  |  |--prod-web1
  |  |--prod-web2
  |  |--prod-db1
  |--@pruebas:
  |  |--@dev:
  |  |  |--dev-web1
  |  |--@pre:
  |  |  |--pre-web1
```

### 8 — Usa el grupo padre

**Acción:**

```bash
ansible-inventory --graph pruebas
ansible pruebas -m ansible.builtin.ping
```

**Por qué:** `--graph` con un grupo dibuja solo esa rama. El ping confirma que el grupo padre llega a los
nodos de sus hijos.

**Resultado esperado:**

```text
@pruebas:
  |--@dev:
  |  |--dev-web1
  |--@pre:
  |  |--pre-web1
```

y dos `SUCCESS`, de `dev-web1` y `pre-web1`.

El fichero completo queda así:

```ini
# proyecto/inventario.ini
[web]
dev-web1
pre-web1
prod-web1
prod-web2

[lb]
prod-lb1

[db]
prod-db1

[dev]
dev-web1

[pre]
pre-web1

[prod]
prod-lb1
prod-web1
prod-web2
prod-db1

[pruebas:children]
dev
pre
```

## Comprueba tu entendimiento

**Nodos de prod que no son base de datos**
Escribe el patrón y compruébalo con `--list-hosts`.
→ `ansible 'prod:!db' --list-hosts` da `hosts (3)`: `prod-lb1`, `prod-web1`, `prod-web2`.

**Todos los web menos uno**
Lista los servidores web salvo `prod-web2`, que va a entrar en mantenimiento.
→ `ansible 'web:!prod-web2' --list-hosts` da `dev-web1`, `pre-web1` y `prod-web1`.

**Dónde está cada nodo**
Mira `ansible-inventory --graph` y di en cuántos grupos está `pre-web1`.
→ En `web` y en `pre`, y a través de `pre` también en `pruebas` (y en `all`).

## Reto

### 1 — El frontal del portal

Tienda Norte llama «frontal» a todo lo que recibe tráfico de los clientes: los servidores web y el
balanceador. Crea el grupo `frontal` sin repetir ningún nodo y lista con un solo patrón el frontal de prod.

<details>
<summary>Ver solución</summary>

Un grupo con `:children` que contiene `web` y `lb`, al final de `proyecto/inventario.ini`:

```ini
[frontal:children]
web
lb
```

`ansible-inventory --graph frontal` dibuja `@web` y `@lb` dentro de `@frontal`, y la intersección con prod:

```bash
ansible 'frontal:&prod' --list-hosts
```

```text
  hosts (3):
    prod-web1
    prod-web2
    prod-lb1
```

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `[WARNING]: Found both group and host with same name: dev` y después `Could not resolve hostname dev` | Falta `:children` en `[pruebas]`: Ansible toma `dev` y `pre` como nombres de nodo | Escribe la cabecera como `[pruebas:children]` |
| `bash: web: command not found` al lanzar `ansible prod:&web …` | Sin comillas, la shell interpreta `&` y manda `ansible prod:` a segundo plano | Pon el patrón entre comillas simples: `'prod:&web'` |
| `Could not match supplied host pattern, ignoring: Web` | Los nombres de grupo distinguen mayúsculas | Usa el nombre tal cual está en el inventario: `web` |
| Un nodo nuevo aparece en el árbol pero da `UNREACHABLE` | Errata en el nombre (`prod-wed1`): Ansible crea el nodo tal cual lo escribes | Corrige el nombre; `ansible-inventory --graph` sirve para cazarlo antes de ejecutar |
