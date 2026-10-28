# Lab — Inventarios por entornos

[← Página anterior](02-lab-variables-en-inventario.md) · [Siguiente página →](04-lab-inventario-dinamico.md)

Con un solo inventario que mezcla dev, pre y prod, `ansible web …` toca los cuatro servidores web de Tienda
Norte, los de prod incluidos, y quien quiere probar en dev tiene que acordarse de poner el patrón bueno cada
vez. En este lab separas cada entorno en su propio inventario YAML, con los mismos nombres de grupo en los
tres, y haces que cada ejecución diga contra qué entorno va. Es la estructura que usa el proyecto del portal
a partir del M03.

### Objetivo

`proyecto/inventories/dev/hosts.yml`, `pre/hosts.yml` y `prod/hosts.yml` con los grupos `web`, `lb` y `db` y
`portal_entorno`; `ansible.cfg` apuntando a dev por defecto y `-i` para pre y prod.

### Punto de partida

- Terminal del Codespace, en la raíz del repositorio (`cd "$CODESPACE_VSCODE_FOLDER"`).
- Los seis nodos levantados: `scripts/nodos.sh estado` da seis líneas `SSH ok`.
- `proyecto/` en el punto de partida `m02-03`: `inventario.ini` con los grupos por función y por entorno y
  sus variables (`portal_entorno`, `portal_color`, `portal_aviso`), y `primer-playbook.yml`, que prepara
  `/srv/portal` y `/etc/motd` en `hosts: all`. El paso 1 te deja ahí.

### En qué consiste

Creas tres ficheros YAML en `proyecto/inventories/`, cambias una línea de `proyecto/ansible.cfg` y borras
`inventario.ini`. Lo único que se ejecuta en los nodos es un ping y `primer-playbook.yml`, que solo crea una
carpeta y el mensaje de bienvenida.

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repositorio
scripts/partida.sh m02-03
cd proyecto
```

**Por qué:** te deja el inventario único con los tres entornos, el que vas a separar.

**Resultado esperado:** `Listo: proyecto/ en el punto de partida «m02-03» …`. Comprueba el problema de
partida con `ansible web --list-hosts`: salen `dev-web1`, `pre-web1`, `prod-web1` y `prod-web2`, prod incluido.

### 2 — Crea las carpetas de los entornos

**Acción:** `mkdir -p inventories/dev inventories/pre inventories/prod`

**Por qué:** una carpeta por entorno deja sitio para que, en el M04, cada inventario tenga al lado sus
`group_vars/` y `host_vars/`.

**Resultado esperado:** `ls inventories` muestra `dev  pre  prod`.

### 3 — Escribe el inventario de prod

**Acción:** crea `proyecto/inventories/prod/hosts.yml` con este contenido:

```yaml
# proyecto/inventories/prod/hosts.yml
all:
  children:
    web:
      hosts:
        prod-web1:
        prod-web2:
    lb:
      hosts:
        prod-lb1:
    db:
      hosts:
        prod-db1:
  vars:
    portal_entorno: prod
```

Ejecuta `ansible-inventory -i inventories/prod/hosts.yml --graph`.

**Por qué:** en YAML, `children` cuelga los grupos de `all` y `hosts` los nodos de cada grupo. Ya no hace
falta un grupo `prod`: el fichero entero es prod, así que `portal_entorno` va en `vars` de `all`.

**Resultado esperado:**

```text
@all:
  |--@ungrouped:
  |--@web:
  |  |--prod-web1
  |  |--prod-web2
  |--@lb:
  |  |--prod-lb1
  |--@db:
  |  |--prod-db1
```

y `ansible-inventory -i inventories/prod/hosts.yml --host prod-web1` da:

```text
{
    "portal_entorno": "prod"
}
```

> [!NOTE]
> `portal_color` y `portal_aviso` no pasan a los inventarios nuevos, ni el `ansible_host` de `prod-db1`
> (los nombres ya resuelven por `infra/ssh_config`). El inventario se queda con lo que describe los nodos y su
> entorno; los valores del portal se ordenan en `group_vars/` en el M04.

### 4 — Escribe los inventarios de dev y pre

**Acción:** crea los dos ficheros:

```yaml
# proyecto/inventories/dev/hosts.yml
all:
  children:
    web:
      hosts:
        dev-web1:
  vars:
    portal_entorno: dev
```

```yaml
# proyecto/inventories/pre/hosts.yml
all:
  children:
    web:
      hosts:
        pre-web1:
  vars:
    portal_entorno: pre
```

**Por qué:** los tres inventarios usan los mismos nombres de grupo. Un playbook con `hosts: web` sirve para
cualquier entorno: lo que cambia es el inventario que le das.

**Resultado esperado:** `ansible -i inventories/dev/hosts.yml all --list-hosts` da:

```text
  hosts (1):
    dev-web1
```

### 5 — Lanza lo mismo contra entornos distintos

**Acción:**

```bash
ansible -i inventories/pre/hosts.yml web -m ansible.builtin.ping
ansible -i inventories/prod/hosts.yml web -m ansible.builtin.debug -a var=portal_entorno
```

**Por qué:** el mismo patrón, `web`, llega a nodos distintos según `-i`. El entorno lo eliges con el
inventario, no con el patrón.

**Resultado esperado:** el ping responde solo `pre-web1 | SUCCESS`, y el `debug`:

```text
prod-web1 | SUCCESS => {
    "portal_entorno": "prod"
}
prod-web2 | SUCCESS => {
    "portal_entorno": "prod"
}
```

### 6 — Haz de dev el inventario por defecto

**Acción:** en `proyecto/ansible.cfg`, sección `[defaults]`, cambia `inventory = inventario.ini` por:

```ini
inventory = inventories/dev/hosts.yml
```

Guarda y ejecuta `ansible-inventory --graph`.

**Por qué:** lo que se lanza sin `-i` va a dev, el entorno donde equivocarse sale barato. Para tocar pre o
prod hay que escribirlo.

**Resultado esperado:**

```text
@all:
  |--@ungrouped:
  |--@web:
  |  |--dev-web1
```

### 7 — Retira el inventario único

**Acción:** `rm inventario.ini`

**Por qué:** dos fuentes con los mismos nodos acaban diciendo cosas distintas. A partir de aquí, los nodos se
describen solo en `inventories/`.

**Resultado esperado:** `ls` muestra `ansible.cfg  app  inventories  primer-playbook.yml`.

### 8 — Ejecuta un playbook sin `-i`

**Acción:** `ansible-playbook primer-playbook.yml`

**Por qué:** el playbook dice `hosts: all`, pero `all` es ahora todo *dev*: el inventario por defecto acota
el alcance aunque el playbook apunte a todo.

**Resultado esperado:** solo aparece `dev-web1`; ningún otro nodo. Sobre un nodo donde nunca se ejecutó,
crea la carpeta y el mensaje:

```text
PLAY RECAP *********************************************************************
dev-web1                   : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Si ya lo ejecutaste en el M01, o lo repites, sale `changed=0`: no queda nada por hacer.

### 9 — Ejecuta el mismo playbook en prod, acotado

**Acción:** `ansible-playbook -i inventories/prod/hosts.yml primer-playbook.yml --limit web`

**Por qué:** `-i` elige el entorno y `--limit` reduce aún más dentro de él: solo los web de prod, sin tocar
el balanceador ni la base de datos.

**Resultado esperado:**

```text
PLAY RECAP *********************************************************************
prod-web1                  : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

(`changed=0` si esos nodos ya tenían `/srv/portal` y el mensaje).

### 10 — Compara con el punto de partida del M03

**Acción:** `diff -r ../partidas/m03 .`

**Por qué:** `partidas/m03` es el proyecto tal como empieza el siguiente módulo. Si coincide, tu `proyecto/`
ya está ahí.

**Resultado esperado:**

```text
Only in .: primer-playbook.yml
```

Ninguna otra diferencia: `ansible.cfg`, `app/` y los tres `hosts.yml` son iguales.

## Comprueba tu entendimiento

**El entorno por defecto**
Ejecuta `ansible all --list-hosts` sin `-i`.
→ `hosts (1)`: `dev-web1`, porque `ansible.cfg` apunta a `inventories/dev/hosts.yml`.

**Los web de dos entornos a la vez**
Lista los web de pre y de prod en un solo comando.
→ `ansible -i inventories/pre/hosts.yml -i inventories/prod/hosts.yml web --list-hosts` da `pre-web1`,
`prod-web1` y `prod-web2`: varios `-i` se suman.

**Qué entorno tiene cada fichero**
Sin abrir los ficheros, di qué `portal_entorno` recibe `pre-web1` y compruébalo.
→ `ansible -i inventories/pre/hosts.yml pre-web1 -m ansible.builtin.debug -a var=portal_entorno` da `"pre"`.

## Reto

### 1 — Por qué no se pasa la carpeta entera

`-i` también acepta una carpeta y carga todo lo que hay dentro. Prueba
`ansible -i inventories dev-web1 -m ansible.builtin.debug -a var=portal_entorno` y explica el resultado.

<details>
<summary>Ver solución</summary>

```text
dev-web1 | SUCCESS => {
    "portal_entorno": "prod"
}
```

`dev-web1` dice ser de prod. Con `-i inventories` se cargan los tres `hosts.yml` en un único inventario, y los
tres definen `portal_entorno` en el mismo grupo, `all`: el último que se carga (prod) pisa a los demás. Además,
`ansible -i inventories web --list-hosts` devuelve los cuatro web de todos los entornos. Por eso cada ejecución
apunta a un solo `inventories/<entorno>/hosts.yml`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `[WARNING]: Unable to parse …/inventories/pro/hosts.yml as an inventory source` y `Could not match supplied host pattern, ignoring: web` | Ruta mal escrita en `-i`: Ansible sigue sin inventario en lugar de fallar | Revisa la ruta (`inventories/prod/hosts.yml`); `ls inventories/*/hosts.yml` lista las buenas |
| Sin `-i`, los comandos siguen viendo los seis nodos | `ansible.cfg` sigue con `inventory = inventario.ini` | Cambia la línea a `inventory = inventories/dev/hosts.yml` y lanza los comandos desde `proyecto/` |
| Un nodo de dev o pre recibe `portal_entorno: prod` | Se pasó `-i inventories` (la carpeta) y se mezclaron los tres entornos | Pasa un solo fichero: `-i inventories/<entorno>/hosts.yml` |
| `ansible-inventory --graph` no muestra un grupo, o un nodo cuelga de `ungrouped` | Sangría YAML: `hosts:` o el nodo no están debajo de su grupo | Sangra con dos espacios por nivel, como en los ficheros de este lab |
