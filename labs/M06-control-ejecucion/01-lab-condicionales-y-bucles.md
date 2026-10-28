# Lab — Lógica condicional

[← Página anterior](00-flujo-de-una-ejecucion.md) · [Siguiente página →](02-lab-handlers.md)

En el runbook de Tienda Norte había una página de «alta de operaciones» llena de excepciones: las cuentas de Ana y
Luis en todos los nodos, la del becario solo en dev, `jq` y `tree` en todas las máquinas Debian, la herramienta de
pruebas de carga solo en los servidores web y un aviso de «producción» al entrar por SSH en los nodos de prod. En este
lab conviertes esa página en un playbook nuevo, `operaciones.yml`, que toma cada decisión con `when` y recorre las
listas con `loop`.

### Objetivo

Un playbook `proyecto/operaciones.yml` que, lanzado contra dev o contra prod, crea los usuarios, instala los paquetes
y pone el aviso que corresponde a cada nodo, y que en la segunda ejecución da `changed=0`.

### Punto de partida

- Terminal del Codespace. Los nodos se recrean limpios en el paso 1 para que la salida coincida con la de la página.
- Estado: `proyecto/` con los roles `portal` y `portal_lb`, los inventorios `dev`, `pre` y `prod` y la variable
  `portal_entorno` en el `group_vars/all.yml` de cada inventario.
- No hace falta el portal instalado: este playbook no toca nginx.

### En qué consiste

Escribes `operaciones.yml` como playbook aparte, no dentro del rol `portal`: va contra **todos** los nodos (también
`prod-lb1` y `prod-db1`), y el alta de usuarios no es parte del portal. Lo construyes en dos tandas: primero los
usuarios (bucle con condición por elemento) y después paquetes y aviso (condiciones por fact, por grupo y por entorno).

### 1 — Prepara el punto de partida

**Acción:**

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m06 --limpio
cd proyecto
```

**Por qué:** `--limpio` recrea los seis nodos sin usuarios ni paquetes añadidos, así cada `changed` que veas lo ha
provocado tu playbook.

**Resultado esperado:** seis líneas `<nodo>  SSH ok` y al final
`Listo: proyecto/ en el punto de partida «m06» (lo anterior está en proyecto.anterior/).`

### 2 — Escribe los usuarios de operaciones

**Acción:** crea `proyecto/operaciones.yml` con este contenido:

```yaml
# proyecto/operaciones.yml
- name: Operaciones en todos los nodos del portal
  hosts: all
  become: true
  vars:
    operaciones_usuarios:
      - {nombre: ana, comentario: "Ana Ruiz (operaciones)", entornos: [dev, pre, prod]}
      - {nombre: luis, comentario: "Luis Gil (operaciones)", entornos: [dev, pre, prod]}
      - {nombre: becario, comentario: "Becario de operaciones", entornos: [dev]}
  tasks:
    - name: Crear el grupo operaciones
      ansible.builtin.group:
        name: operaciones
        state: present

    - name: Crear los usuarios de operaciones
      ansible.builtin.user:
        name: "{{ item.nombre }}"
        comment: "{{ item.comentario }}"
        groups: operaciones
        append: true
        shell: /bin/bash
      loop: "{{ operaciones_usuarios }}"
      when: portal_entorno in item.entornos
```

**Por qué:** cada usuario es un diccionario con sus datos y la lista de entornos donde debe existir. El `when` se
evalúa **por elemento**: `item` es el usuario en curso y `portal_entorno` llega del inventario del nodo. Así la
excepción del becario vive en los datos, no en una tarea aparte.

**Resultado esperado:** `ansible-playbook operaciones.yml --syntax-check` responde `playbook: operaciones.yml`.

### 3 — Ejecútalo en dev

**Acción:** `ansible-playbook operaciones.yml`

**Por qué:** sin `-i`, `ansible.cfg` usa `inventories/dev/hosts.yml`: un único nodo, `dev-web1`, con
`portal_entorno: dev`. Ahí deben salir los tres usuarios.

**Resultado esperado:**

```text
TASK [Crear el grupo operaciones] **********************************************
changed: [dev-web1]

TASK [Crear los usuarios de operaciones] ***************************************
changed: [dev-web1] => (item={'nombre': 'ana', 'comentario': 'Ana Ruiz (operaciones)', 'entornos': ['dev', 'pre', 'prod']})
changed: [dev-web1] => (item={'nombre': 'luis', 'comentario': 'Luis Gil (operaciones)', 'entornos': ['dev', 'pre', 'prod']})
changed: [dev-web1] => (item={'nombre': 'becario', 'comentario': 'Becario de operaciones', 'entornos': ['dev']})

PLAY RECAP *********************************************************************
dev-web1                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`changed=2` cuenta tareas, no elementos: el grupo y la tarea de usuarios. Cada elemento del bucle sale entero, con
todo el diccionario.

### 4 — Acorta la salida del bucle

**Acción:** en la tarea `Crear los usuarios de operaciones`, añade `loop_control` justo debajo de `loop`:

```yaml
      loop: "{{ operaciones_usuarios }}"
      loop_control:
        label: "{{ item.nombre }}"
      when: portal_entorno in item.entornos
```

**Por qué:** con cuatro nodos y listas más largas, imprimir cada diccionario hace la salida ilegible. `label` decide
qué se muestra de cada elemento; no cambia lo que hace la tarea.

**Resultado esperado:** el fichero sigue pasando `--syntax-check`.

### 5 — Ejecútalo en prod

**Acción:** `ansible-playbook -i inventories/prod/hosts.yml operaciones.yml`

**Por qué:** en prod hay cuatro nodos de tres grupos distintos y `portal_entorno: prod`. El becario no debe existir
en ninguno.

**Resultado esperado:**

```text
TASK [Crear los usuarios de operaciones] ***************************************
changed: [prod-web2] => (item=ana)
changed: [prod-web1] => (item=ana)
…
changed: [prod-web1] => (item=luis)
skipping: [prod-web1] => (item=becario)
…
skipping: [prod-lb1] => (item=becario)

PLAY RECAP *********************************************************************
prod-db1                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web1                  : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Cada elemento sale con su nombre. `becario` sale como `skipping` en los cuatro nodos, pero `skipped` sigue a 0 en el
resumen: la tarea se ejecutó para los otros dos elementos, así que cuenta como `changed`.

### 6 — Añade paquetes y aviso con tres condiciones distintas

**Acción:** en `vars:`, debajo de `operaciones_usuarios`, añade la lista de paquetes:

```yaml
    operaciones_paquetes:
      - jq
      - tree
```

Y al final del fichero, tras la tarea de usuarios, estas tres tareas:

```yaml
    - name: Instalar las herramientas de operaciones
      ansible.builtin.apt:
        name: "{{ item }}"
        state: present
        update_cache: true
        cache_valid_time: 3600
      loop: "{{ operaciones_paquetes }}"
      when: ansible_facts['distribution'] == 'Debian'

    - name: Instalar las pruebas de carga en los servidores web
      ansible.builtin.apt:
        name: apache2-utils
        state: present
      when: inventory_hostname in groups['web']

    - name: Avisar al entrar por SSH de que es producción
      ansible.builtin.copy:
        dest: /etc/motd
        content: "PRODUCCIÓN de Tienda Norte ({{ inventory_hostname }}). Cambios solo con Ansible.\n"
        mode: "0644"
      when: portal_entorno == 'prod'
```

**Por qué:** cada tarea decide con una fuente distinta:

| Tarea | Condición | De dónde sale |
|-------|-----------|---------------|
| Herramientas | `ansible_facts['distribution'] == 'Debian'` | Facts que recoge `Gathering Facts`: `apt` solo donde hay `apt` |
| Pruebas de carga | `inventory_hostname in groups['web']` | Grupos del inventario: `ab` solo hace falta en los web |
| Aviso | `portal_entorno == 'prod'` | `group_vars/all.yml` del inventario |

**Resultado esperado:** `--syntax-check` sigue respondiendo `playbook: operaciones.yml`.

### 7 — Ejecuta el playbook completo en prod

**Acción:** `ansible-playbook -i inventories/prod/hosts.yml operaciones.yml`

**Por qué:** es la ejecución que demuestra las tres condiciones a la vez sobre nodos con papeles distintos.

**Resultado esperado:**

```text
TASK [Instalar las herramientas de operaciones] ********************************
changed: [prod-web1] => (item=jq)
…
changed: [prod-db1] => (item=tree)

TASK [Instalar las pruebas de carga en los servidores web] *********************
skipping: [prod-lb1]
skipping: [prod-db1]
changed: [prod-web2]
changed: [prod-web1]

TASK [Avisar al entrar por SSH de que es producción] ***************************
changed: [prod-db1]
changed: [prod-lb1]
changed: [prod-web2]
changed: [prod-web1]

PLAY RECAP *********************************************************************
prod-db1                   : ok=5    changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-lb1                   : ok=5    changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=6    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=6    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`prod-lb1` y `prod-db1` se saltan las pruebas de carga (`skipped=1`) porque no están en `groups['web']`. El grupo y
los usuarios ya existían del paso 5, así que salen como `ok`.

### 8 — Comprueba la idempotencia y el contraste con dev

**Acción:**

```bash
ansible-playbook -i inventories/prod/hosts.yml operaciones.yml
ansible-playbook operaciones.yml
```

**Por qué:** un playbook con condiciones y bucles tiene que seguir siendo repetible, y el mismo fichero debe hacer
otra cosa en dev sin tocarlo.

**Resultado esperado:** la primera da `changed=0` en los cuatro nodos de prod. La segunda, en dev:

```text
TASK [Crear los usuarios de operaciones] ***************************************
ok: [dev-web1] => (item=ana)
ok: [dev-web1] => (item=luis)
ok: [dev-web1] => (item=becario)

TASK [Instalar las herramientas de operaciones] ********************************
changed: [dev-web1] => (item=jq)
changed: [dev-web1] => (item=tree)

TASK [Instalar las pruebas de carga en los servidores web] *********************
changed: [dev-web1]

TASK [Avisar al entrar por SSH de que es producción] ***************************
skipping: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=5    changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

En dev, `becario` sí existe y el aviso de producción se salta.

## Comprueba tu entendimiento

**El becario solo existe en dev**
`ansible -i inventories/prod/hosts.yml all -m ansible.builtin.command -a "id becario"` y después
`ansible all -m ansible.builtin.command -a "id becario"`.
→ En prod, los cuatro nodos responden `FAILED | rc=1` con `id: ‘becario’: no such user`. En dev,
`dev-web1 | CHANGED | rc=0` con `uid=1003(becario) … groups=1004(becario),1001(operaciones)`.

**El aviso solo está en prod**
`docker exec prod-db1 cat /etc/motd` y `docker exec dev-web1 cat /etc/motd`.
→ En `prod-db1`: `PRODUCCIÓN de Tienda Norte (prod-db1). Cambios solo con Ansible.` En `dev-web1`, el texto de
Debian de siempre (`The programs included with the Debian GNU/Linux system…`).

**El `when` de un bucle es por elemento**
Mira la tarea de usuarios en la salida del paso 5.
→ En el mismo nodo hay líneas `changed` (ana, luis) y `skipping` (becario).

## Reto

### 1 — Una cuenta solo para pre y prod

Operaciones contrata a Marta para guardias: necesita cuenta en pre y en prod, pero no en dev. Consíguelo sin añadir
ninguna tarea nueva y compruébalo en pre.

<details>
<summary>Ver solución</summary>

Añade un elemento a `operaciones_usuarios`:

```yaml
      - {nombre: marta, comentario: "Marta Sanz (guardias)", entornos: [pre, prod]}
```

`ansible-playbook -i inventories/pre/hosts.yml operaciones.yml` muestra `changed: [pre-web1] => (item=marta)` y
`skipping: [pre-web1] => (item=becario)`. En dev, `marta` sale como `skipping`.

</details>

### 2 — El aviso, sin depender de la variable

Cambia la condición del aviso para que no dependa de `portal_entorno`, sino de que el nodo esté en el inventario de
prod por su nombre. ¿Qué inconveniente tiene?

<details>
<summary>Ver solución</summary>

`when: inventory_hostname.startswith('prod-')` funciona con los nombres de Tienda Norte, pero ata la decisión a una
convención de nombres: un nodo nuevo que no siga el prefijo se quedaría sin aviso. `portal_entorno` está en el
`group_vars` del inventario y vale para cualquier nodo que se añada a él.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `Syntax error in expression. Template delimiters are not supported in expressions`, con `Origin:` apuntando a la línea del `when` | Has escrito `when: "{{ portal_entorno }} == 'prod'"` | `when` ya es una expresión: `when: portal_entorno == 'prod'`, sin llaves |
| `'item' is undefined` | El `when` que usa `item` está en una tarea sin `loop`, o el `loop` tiene otra sangría | Pon `loop`, `loop_control` y `when` al mismo nivel que `ansible.builtin.user` |
| `'dict object' has no attribute 'nombre'` | Un elemento de la lista no tiene esa clave (p. ej. escrito `name:`) | Revisa que todos los usuarios usen `nombre`, `comentario` y `entornos` |
| `'portal_entorno' is undefined` | Lanzas el playbook con un inventario sin `group_vars/all.yml` o fuera de `proyecto/` | `cd proyecto` y usa `-i inventories/<entorno>/hosts.yml` |
| Las pruebas de carga se instalan también en `prod-lb1` | La condición usa `groups['all']` o falta el `when` en esa tarea | `when: inventory_hostname in groups['web']` (equivale a `'web' in group_names`) |
