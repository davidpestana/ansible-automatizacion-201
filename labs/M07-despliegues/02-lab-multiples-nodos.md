# Lab — Múltiples nodos

[← Página anterior](01-lab-despliegue-completo.md) · [Siguiente página →](03-lab-despliegue-escalonado.md)

En prod de Tienda Norte no siempre se actúa sobre todo: unas veces se prueba la release en un solo web, otras
se excluye el que está en mantenimiento o se quiere ir nodo a nodo para leer la salida con calma. En este lab
eliges **sobre qué nodos** se ejecuta Ansible con patrones y `--limit`, lo compruebas antes con `--list-hosts`
y mides **cuántos a la vez** con `forks`.

### Objetivo

Seleccionar exactamente los nodos de prod que quieres en cada ejecución, desplegar la 1.1.0 solo en `prod-web1`
y explicar, con la salida delante, qué cambia entre `-f 1` y los `forks` por defecto.

### Punto de partida

- Terminal del Codespace. El paso 1 deja `proyecto/` en el estado `m07-02`.
- Estado tras el paso 1: roles `portal` y `portal_lb`, `site.yml`, `web.yml` y `lb.yml`; prod con el portal
  1.0.0 instalado en `prod-lb1`, `prod-web1` y `prod-web2`, y solo la release 1.0.0 en disco.
- No hace falta nada de páginas anteriores.

### En qué consiste

Pruebas patrones con `--list-hosts` (no ejecutan nada), recortas un playbook con `--limit`, despliegas en un solo
web y comparas la salida de una orden en paralelo y en serie. No editas ningún fichero del proyecto.

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repo
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m07-02
cd proyecto
```

**Por qué:** deja prod instalado con la 1.0.0 y sin releases de pruebas anteriores, para que las salidas
coincidan con las de esta página.

**Resultado esperado:** `Preparando los nodos para m07-02…`, un `PLAY RECAP` con `failed=0` en los tres nodos y
`Listo: proyecto/ en el punto de partida «m07-02»`.

### 2 — Lista todos los nodos de prod

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible -i inventories/prod/hosts.yml all --list-hosts
```

**Por qué:** `--list-hosts` resuelve el patrón contra el inventario y se para ahí. Es la forma segura de saber
a quién va a tocar una orden antes de lanzarla en prod.

**Resultado esperado:**

```text
  hosts (4):
    prod-web1
    prod-web2
    prod-lb1
    prod-db1
```

### 3 — Selecciona por grupo y por nombre

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible -i inventories/prod/hosts.yml web --list-hosts
ansible -i inventories/prod/hosts.yml 'prod-web*' --list-hosts
```

**Por qué:** las dos formas llegan a los mismos nodos por caminos distintos. El grupo `web` es la función (lo que
usa `web.yml`); el comodín `prod-web*` depende de cómo se llamen los servidores. Las comillas evitan que el
shell interprete el `*`.

**Resultado esperado:** las dos órdenes devuelven lo mismo:

```text
  hosts (2):
    prod-web1
    prod-web2
```

### 4 — Excluye y combina grupos

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible -i inventories/prod/hosts.yml 'web:!prod-web2' --list-hosts
ansible -i inventories/prod/hosts.yml 'web:lb' --list-hosts
ansible -i inventories/prod/hosts.yml 'all:!db' --list-hosts
```

**Por qué:** `:` une y `:!` quita. Así se escribe «todos los web menos el que está en mantenimiento» o «todo
prod salvo la base de datos». Las comillas simples son obligatorias: con dobles, bash intenta expandir `!`.

**Resultado esperado:**

```text
  hosts (1):
    prod-web1
```

```text
  hosts (3):
    prod-web1
    prod-web2
    prod-lb1
```

```text
  hosts (3):
    prod-web1
    prod-web2
    prod-lb1
```

### 5 — Prueba un patrón que no existe

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible -i inventories/prod/hosts.yml prod-web3 --list-hosts
```

**Por qué:** un nombre mal escrito no da error, solo un aviso y cero nodos. Conviene reconocerlo para no creer
que una orden «no ha hecho nada» por otro motivo.

**Resultado esperado:**

```text
[WARNING]: Could not match supplied host pattern, ignoring: prod-web3
[WARNING]: No hosts matched, nothing to do
  hosts (0):
```

### 6 — Mira a quién toca `site.yml`, entero y con `--limit`

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml site.yml --list-hosts
ansible-playbook -i inventories/prod/hosts.yml site.yml --list-hosts --limit prod-web1
```

**Por qué:** en un playbook el patrón está en cada `hosts:`. `--limit` no lo sustituye: lo recorta. Cada play se
queda con la intersección entre su patrón y el límite.

**Resultado esperado:**

```text
playbook: site.yml

  play #1 (web): Servidores web del portal	TAGS: []
    pattern: ['web']
    hosts (2):
      prod-web1
      prod-web2

  play #2 (lb): Balanceador del portal	TAGS: []
    pattern: ['lb']
    hosts (1):
      prod-lb1
```

```text
playbook: site.yml

  play #1 (web): Servidores web del portal	TAGS: []
    pattern: ['web']
    hosts (1):
      prod-web1

  play #2 (lb): Balanceador del portal	TAGS: []
    pattern: ['lb']
    hosts (0):
```

Con `--limit prod-web1`, el play del balanceador se queda sin nodos y no hace nada.

### 7 — Despliega la 1.1.0 solo en `prod-web1`

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml web.yml --tags despliegue -e portal_version=1.1.0 --limit prod-web1
```

**Por qué:** es la forma más sencilla de probar una release en un nodo antes de extenderla. `--tags despliegue`
deja solo las tareas de la release y `--limit` deja fuera a `prod-web2`.

**Resultado esperado:** solo aparece `prod-web1`:

```text
TASK [portal : Crear la carpeta de la release] *********************************
changed: [prod-web1]

TASK [portal : Copiar la release 1.1.0] ****************************************
changed: [prod-web1]

TASK [portal : Apuntar current a la release 1.1.0] *****************************
changed: [prod-web1]

TASK [portal : Publicar el estado del nodo] ************************************
changed: [prod-web1]

PLAY RECAP *********************************************************************
prod-web1                  : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 8 — Comprueba que prod ha quedado mezclado

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
curl -s localhost:8083/estado.json | grep version; curl -s localhost:8084/estado.json | grep version
for i in 1 2 3 4; do curl -s localhost:8080 | grep Versión; done
```

**Por qué:** un despliegue parcial tiene consecuencias para el cliente: el balanceador reparte entre una web
con la 1.1.0 y otra con la 1.0.0.

**Resultado esperado:**

```text
  "version": "1.1.0",
  "version": "1.0.0",
```

```text
<p>Versión <strong>1.1.0</strong>. Nuevo: seguimiento de pedidos.</p>
<p>Versión <strong>1.0.0</strong>. Consulta de pedidos.</p>
<p>Versión <strong>1.1.0</strong>. Nuevo: seguimiento de pedidos.</p>
<p>Versión <strong>1.0.0</strong>. Consulta de pedidos.</p>
```

### 9 — Mira cuántos forks usa Ansible

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-config dump | grep -i forks
```

**Por qué:** `forks` es el número de nodos con los que Ansible trabaja a la vez. `ansible.cfg` del proyecto no
lo cambia, así que vale el valor por defecto.

**Resultado esperado:**

```text
DEFAULT_FORKS(default) = 5
```

Con cuatro nodos en prod y cinco forks, todos trabajan en paralelo.

### 10 — Lanza una orden en paralelo

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible -i inventories/prod/hosts.yml all -m ansible.builtin.shell -a 'sleep 2; date +%T'
```

**Por qué:** cada nodo espera un poco y dice su hora. Si todos trabajan a la vez, terminan juntos y el orden de
la salida es el orden en que acaban, no el del inventario.

**Resultado esperado:** las cuatro horas coinciden y el orden puede salir desordenado (tus horas serán otras):

```text
prod-web1 | CHANGED | rc=0 >>
19:34:13
prod-db1 | CHANGED | rc=0 >>
19:34:13
prod-web2 | CHANGED | rc=0 >>
19:34:13
prod-lb1 | CHANGED | rc=0 >>
19:34:13
```

Lánzala dos o tres veces: el orden cambia de una ejecución a otra.

### 11 — Lanza la misma orden con `-f 1`

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible -i inventories/prod/hosts.yml all -m ansible.builtin.shell -a 'sleep 2; date +%T' -f 1
```

**Por qué:** con un solo fork, Ansible atiende un nodo y no empieza el siguiente hasta terminar.

**Resultado esperado:** el orden es siempre el del inventario y cada hora es posterior a la anterior:

```text
prod-web1 | CHANGED | rc=0 >>
19:34:18
prod-web2 | CHANGED | rc=0 >>
19:34:20
prod-lb1 | CHANGED | rc=0 >>
19:34:23
prod-db1 | CHANGED | rc=0 >>
19:34:25
```

Con `-f 2` verías dos parejas: `prod-web1` y `prod-web2` con la misma hora, y `prod-lb1` y `prod-db1` con otra posterior.

### 12 — Despliega en el resto con `-f 1` y fíjate en el orden de las tareas

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml web.yml --tags despliegue -e portal_version=1.1.0 -f 1
```

**Por qué:** completa el despliegue en `prod-web2` (en `prod-web1` ya está) y enseña cómo encaja `forks` en un
playbook: va nodo a nodo **dentro de cada tarea**, no playbook a playbook.

**Resultado esperado:**

```text
TASK [portal : Crear la carpeta de la release] *********************************
ok: [prod-web1]
changed: [prod-web2]

TASK [portal : Copiar la release 1.1.0] ****************************************
ok: [prod-web1]
changed: [prod-web2]

TASK [portal : Apuntar current a la release 1.1.0] *****************************
ok: [prod-web1]
changed: [prod-web2]

TASK [portal : Publicar el estado del nodo] ************************************
ok: [prod-web1]
changed: [prod-web2]

PLAY RECAP *********************************************************************
prod-web1                  : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Cada tarea sale siempre con `prod-web1` primero, pero los dos nodos reciben una tarea antes de que empiece la
siguiente. Ahora `for i in 1 2 3 4; do curl -s localhost:8080 | grep Versión; done` da cuatro veces la 1.1.0.

> [!WARNING]
> `-f 1` no protege de una release rota: los dos web reciben `Apuntar current…` antes de que nada verifique
> nada. Para que un nodo termine **todo** el play antes de que empiece el siguiente hace falta `serial`, que se
> trabaja en el [Lab — Despliegue escalonado](03-lab-despliegue-escalonado.md).

## Comprueba tu entendimiento

**Patrón con exclusión**
Lanza `ansible -i inventories/prod/hosts.yml 'all:!db' --list-hosts`.
→ Tres nodos: `prod-web1`, `prod-web2` y `prod-lb1`.

**`--limit` recorta, no sustituye**
Lanza `ansible-playbook -i inventories/prod/hosts.yml site.yml --list-hosts --limit prod-web1`.
→ El play `web` se queda con `prod-web1` y el play `lb` con `hosts (0)`.

**Forks en serie**
Lanza la orden del paso 11 otra vez.
→ Orden del inventario y horas crecientes, una por nodo.

## Reto

### 1 — Despliega en todos los web menos uno sin nombrar al que sí

`prod-web1` está en mantenimiento. Escribe la orden que mostraría a quién tocaría `web.yml` excluyendo a
`prod-web1` con `--limit`, sin escribir `prod-web2` en ningún sitio.

<details>
<summary>Ver solución</summary>

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml web.yml --limit 'all:!prod-web1' --list-hosts
```

```text
  play #1 (web): Servidores web del portal	TAGS: []
    pattern: ['web']
    hosts (1):
      prod-web2
```

Quitando `--list-hosts` (y añadiendo `--tags despliegue -e portal_version=…`) se ejecutaría de verdad.
Si mañana hay un `prod-web3`, el mismo límite lo incluye sin tocar la orden.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `bash: !prod-web2: event not found` | El patrón con `!` va entre comillas dobles o sin comillas | Usa comillas simples: `'web:!prod-web2'` |
| `Could not match supplied host pattern` y `hosts (0)` | Nombre mal escrito o inventario equivocado (falta `-i inventories/prod/hosts.yml`) | Revisa el nombre con `ansible-inventory -i inventories/prod/hosts.yml --graph` |
| `Specified inventory, host pattern and/or --limit leaves us with no hosts to target` | `--limit` no coincide con ningún nodo del patrón | Comprueba primero con `--list-hosts` |
| Con `-f 1` los dos web acaban con la release rota | `forks` no hace el play nodo a nodo, solo cada tarea | Usa `serial: 1` en el play |
