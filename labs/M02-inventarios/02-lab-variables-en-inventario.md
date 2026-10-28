# Lab — Variables en inventario

[← Página anterior](01-lab-grupos-y-jerarquias.md) · [Siguiente página →](03-lab-inventarios-por-entornos.md)

Los nodos del portal de Tienda Norte ya están agrupados, pero el inventario aún no dice nada de ellos: un
playbook no puede saber que `dev-web1` es dev ni qué color de cabecera lleva el portal en cada entorno
(azul en dev, ámbar en pre, verde en prod). En este lab das esos valores a los grupos y a un nodo concreto
dentro del propio inventario y compruebas qué valor recibe cada nodo cuando un mismo dato está en varios sitios.

### Objetivo

`proyecto/inventario.ini` con `portal_entorno` y `portal_color` por entorno, un aviso general con
excepciones para pruebas y para `prod-web2`, y `ansible_host` en `prod-db1`, comprobado nodo a nodo con
`ansible-inventory --host` y `ansible.builtin.debug`.

### Punto de partida

- Terminal del Codespace, en la raíz del repositorio (`cd "$CODESPACE_VSCODE_FOLDER"`).
- Los seis nodos levantados: `scripts/nodos.sh estado` da seis líneas `SSH ok`.
- `proyecto/` en el punto de partida `m02-02`: `inventario.ini` con los grupos `web`, `lb`, `db`, `dev`,
  `pre`, `prod` y `pruebas` (= `dev` + `pre`), sin variables. El paso 1 te deja ahí.

### En qué consiste

Añades secciones `[grupo:vars]` y variables en la línea de un nodo en `proyecto/inventario.ini`, y lees el
resultado sin ejecutar ningún playbook. Las variables viven solo dentro del inventario: los ficheros
`group_vars/` y `host_vars/` son del M04.

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repositorio
scripts/partida.sh m02-02
cd proyecto
```

**Por qué:** te deja el inventario agrupado por función y por entorno, sin variables, venga de donde vengas.

**Resultado esperado:** `Listo: proyecto/ en el punto de partida «m02-02» …`. Abre `proyecto/inventario.ini`
en VS Code: verás los grupos y, al final, `[pruebas:children]` con `dev` y `pre`.

### 2 — Comprueba que no hay variables

**Acción:** `ansible-inventory --host prod-web1`

**Por qué:** `--host` enseña todas las variables de inventario que recibe un nodo, ya resueltas. Es la
forma más rápida de saber qué valor le llega.

**Resultado esperado:**

```text
{}
```

### 3 — Da a cada entorno su nombre y su color

**Acción:** añade al final de `proyecto/inventario.ini` y guarda:

```ini
[dev:vars]
portal_entorno=dev
portal_color=#2563eb

[pre:vars]
portal_entorno=pre
portal_color=#d97706

[prod:vars]
portal_entorno=prod
portal_color=#15803d
```

**Por qué:** el entorno y el color son propiedades del entorno, no de cada nodo. Escritos una vez en el
grupo, los recibe cada nodo que esté en él, y el prefijo `portal_` deja claro de qué parte del proyecto son.

**Resultado esperado:** `ansible-inventory --host prod-web1` ya devuelve:

```text
{
    "portal_color": "#15803d",
    "portal_entorno": "prod"
}
```

### 4 — Lee la variable desde los nodos

**Acción:** `ansible all -m ansible.builtin.debug -a var=portal_entorno`

**Por qué:** `ansible.builtin.debug` no se conecta al nodo: imprime la variable tal como la ve Ansible en
la ejecución, que es lo que usará un playbook.

**Resultado esperado:** cada nodo con su entorno (el orden puede variar):

```text
dev-web1 | SUCCESS => {
    "portal_entorno": "dev"
}
prod-web2 | SUCCESS => {
    "portal_entorno": "prod"
}
prod-lb1 | SUCCESS => {
    "portal_entorno": "prod"
}
prod-db1 | SUCCESS => {
    "portal_entorno": "prod"
}
prod-web1 | SUCCESS => {
    "portal_entorno": "prod"
}
pre-web1 | SUCCESS => {
    "portal_entorno": "pre"
}
```

### 5 — Define un valor general y una excepción para pruebas

**Acción:** añade al final de `proyecto/inventario.ini` y guarda:

```ini
[all:vars]
portal_aviso=Portal de pedidos de Tienda Norte

[pruebas:vars]
portal_aviso=Entorno de pruebas: los pedidos no son reales
```

Ejecuta `ansible all -m ansible.builtin.debug -a var=portal_aviso`.

**Por qué:** el aviso es el mismo en todo el portal salvo en dev y pre, donde hay que dejar claro que los
pedidos no son reales. `all` es el padre de todos los grupos y `pruebas` es más específico, así que gana
para sus nodos. Fíjate en que el valor lleva espacios y no necesita comillas en una sección `:vars`.

**Resultado esperado:**

```text
pre-web1 | SUCCESS => {
    "portal_aviso": "Entorno de pruebas: los pedidos no son reales"
}
prod-db1 | SUCCESS => {
    "portal_aviso": "Portal de pedidos de Tienda Norte"
}
dev-web1 | SUCCESS => {
    "portal_aviso": "Entorno de pruebas: los pedidos no son reales"
}
…
```

Los nodos de prod reciben el aviso general; `dev-web1` y `pre-web1`, el de `pruebas`.

### 6 — Da a un nodo su propio valor

**Acción:** en la sección `[prod]` de `proyecto/inventario.ini`, cambia la línea `prod-web2` por:

```ini
prod-web2 portal_aviso="Nodo canario: recibe antes las versiones nuevas"
```

Guarda y ejecuta `ansible prod -m ansible.builtin.debug -a var=portal_aviso`.

**Por qué:** `prod-web2` es el nodo que recibe primero cada versión nueva del portal. Una variable de host
es lo más específico que hay en un inventario y gana a cualquier grupo. En la línea de un nodo, los valores
con espacios van entre comillas.

**Resultado esperado:**

```text
prod-web2 | SUCCESS => {
    "portal_aviso": "Nodo canario: recibe antes las versiones nuevas"
}
prod-web1 | SUCCESS => {
    "portal_aviso": "Portal de pedidos de Tienda Norte"
}
prod-lb1 | SUCCESS => {
    "portal_aviso": "Portal de pedidos de Tienda Norte"
}
prod-db1 | SUCCESS => {
    "portal_aviso": "Portal de pedidos de Tienda Norte"
}
```

### 7 — Mira todo lo que recibe ese nodo

**Acción:** `ansible-inventory --host prod-web2`

**Por qué:** junta en un solo sitio lo que viene de `prod` y lo que viene del propio nodo.

**Resultado esperado:**

```text
{
    "portal_aviso": "Nodo canario: recibe antes las versiones nuevas",
    "portal_color": "#15803d",
    "portal_entorno": "prod"
}
```

`prod-web2` no ha perdido el color ni el entorno del grupo: la variable de host solo sustituye la que
coincide.

### 8 — Usa una variable de conexión

**Acción:** en la sección `[prod]`, cambia la línea `prod-db1` por:

```ini
prod-db1 ansible_host=172.30.0.30
```

Guarda y ejecuta:

```bash
ansible-inventory --host prod-db1
ansible prod-db1 -m ansible.builtin.ping
```

**Por qué:** las variables que empiezan por `ansible_` cambian cómo conecta Ansible. Aquí no hace falta,
porque `infra/ssh_config` ya traduce `prod-db1` a su IP, pero es lo que se hace cuando el nombre del
inventario no resuelve en la red: el nombre sigue siendo `prod-db1` en el inventario y en las salidas, y
SSH se conecta a la IP.

**Resultado esperado:**

```text
{
    "ansible_host": "172.30.0.30",
    "portal_aviso": "Portal de pedidos de Tienda Norte",
    "portal_color": "#15803d",
    "portal_entorno": "prod"
}
```

y `prod-db1 | SUCCESS` con `"ping": "pong"`.

### 9 — Comprueba a qué dirección se conecta

**Acción:** `ansible prod-db1 -m ansible.builtin.ping -vvv | grep 'SSH: EXEC'`

**Por qué:** con `-vvv` Ansible enseña el comando `ssh` que lanza. Es la prueba de que usa `ansible_host`
y no el nombre.

**Resultado esperado:** una o dos líneas que empiezan por la IP:

```text
<172.30.0.30> SSH: EXEC ssh -F ../infra/ssh_config -o ControlMaster=auto -o ControlPersist=60s …
```

### 10 — Ve el árbol con sus variables

**Acción:** `ansible-inventory --graph --vars pruebas`

**Por qué:** `--vars` dibuja cada variable en el grupo o nodo donde está definida y también la que hereda
cada nodo. Se lee de un vistazo de dónde sale cada valor.

**Resultado esperado:**

```text
@pruebas:
  |--@dev:
  |  |--dev-web1
  |  |  |--{portal_aviso = Entorno de pruebas: los pedidos no son reales}
  |  |  |--{portal_color = #2563eb}
  |  |  |--{portal_entorno = dev}
  |  |--{portal_color = #2563eb}
  |  |--{portal_entorno = dev}
  |--@pre:
  |  |--pre-web1
  |  |  |--{portal_aviso = Entorno de pruebas: los pedidos no son reales}
  |  |  |--{portal_color = #d97706}
  |  |  |--{portal_entorno = pre}
  |  |--{portal_color = #d97706}
  |  |--{portal_entorno = pre}
  |--{portal_aviso = Entorno de pruebas: los pedidos no son reales}
```

## Comprueba tu entendimiento

**Color de un nodo de pre**
Di qué color recibe `pre-web1` sin ejecutar nada y compruébalo.
→ `ansible pre-web1 -m ansible.builtin.debug -a var=portal_color` da `"portal_color": "#d97706"`, de `[pre:vars]`.

**El aviso de la base de datos**
`prod-db1` no tiene `portal_aviso` en su línea ni en `[prod:vars]`. ¿Qué recibe?
→ `ansible-inventory --host prod-db1` muestra `"portal_aviso": "Portal de pedidos de Tienda Norte"`, de `[all:vars]`.

**Dónde gana el nodo**
Explica por qué `prod-web2` tiene un aviso distinto que `prod-web1` estando los dos en `prod`.
→ La variable en la línea de `prod-web2` es de host, y la de host gana a la de cualquier grupo.

## Reto

### 1 — Un aviso solo para preproducción

En pre se cargan datos copiados de prod y el equipo quiere un aviso propio para `pre-web1`, sin cambiar el
de `dev-web1` ni tocar la línea de ningún nodo. Hazlo y comprueba los dos nodos de `pruebas`.

<details>
<summary>Ver solución</summary>

Una sección `[pre:vars]` ya existe: añade la variable en ella (o en otra sección `[pre:vars]` al final, que
Ansible junta con la primera):

```ini
[pre:vars]
portal_aviso=Preproducción: datos copiados de prod la última semana
```

`pre` es hijo de `pruebas`, así que su valor gana al del padre:

```bash
ansible pruebas -m ansible.builtin.debug -a var=portal_aviso
```

```text
dev-web1 | SUCCESS => {
    "portal_aviso": "Entorno de pruebas: los pedidos no son reales"
}
pre-web1 | SUCCESS => {
    "portal_aviso": "Preproducción: datos copiados de prod la última semana"
}
```

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `ansible-inventory --host prod-web1` da `"portal_color": ""` tras escribir `prod-web1 portal_color=#7c3aed` | En la línea de un nodo, `#` empieza un comentario y el valor se queda vacío | Entre comillas: `prod-web1 portal_color="#7c3aed"`. En las secciones `:vars`, `#2563eb` funciona sin comillas |
| `prod-db1 \| UNREACHABLE! … connect to host 172.30.0.99 port 22: No route to host` (o `Connection timed out`) | `ansible_host` con una IP equivocada: Ansible ya no usa el nombre | Corrige la IP (la tabla de nodos está en `infra/README.md`) o quita `ansible_host` |
| `Failed to parse inventory: Section [prd:vars] not valid for undefined group 'prd'` y después `No inventory was parsed` | Errata en la cabecera de una sección `:vars`: el grupo no existe y Ansible descarta el fichero entero | Corrige el nombre del grupo (`[prod:vars]`); `ansible-inventory --graph` debe volver a mostrar los seis nodos |
| `"portal_avisos": "<< error 1 - 'portal_avisos' is undefined >>"` | El nodo no recibe esa variable: nombre mal escrito o el nodo no está en el grupo que la define | `ansible-inventory --host <nodo>` enseña las variables que recibe de verdad |
