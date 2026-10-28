# Anatomía de un playbook

[← Página anterior](README.md) · [Siguiente página →](01-lab-modulos-principales.md)

Para que Ansible haga los pasos del runbook de Tienda Norte, esos pasos se escriben en un playbook: un
fichero YAML donde cada espacio cuenta. Esta demostración abre un playbook pequeño sobre los nodos web y
después lo rompe a propósito.

## Qué se va a ver

**Qué se hace**

1. Se recorre un playbook con dos plays y se señala cada pieza.
2. Se valida sin conectar con los nodos, con `--syntax-check` y `--list-tasks`.
3. Se ejecuta dos veces.
4. Se introducen los errores de YAML más habituales: un tabulador, un espacio de más, dos puntos sin espacio, un valor que empieza por `{{` y `yes`/`no` sin comillas.
5. Se ve qué fallos se escapan a `--syntax-check` y solo aparecen al ejecutar.

**Objetivos**

- Reconocer las piezas de un playbook: plays, `hosts`, `tasks`, módulos y argumentos.
- Validar un playbook antes de tocar ningún nodo.
- Relacionar cada error típico con el mensaje de ansible-core 2.20 que lo delata.

**Conclusiones**

- La mayoría de los errores de YAML se detectan sin conectar con los nodos.
- Algunos fallos solo aparecen al ejecutar, y otros, como `yes`/`no`, no dan error: cambian el valor.

## Punto de partida

- Terminal del Codespace, en `proyecto/`.
- Estado: inventarios por entorno del M02 (`inventories/{dev,pre,prod}/hosts.yml`) y ningún playbook. Se carga con:

```bash
# Terminal del Codespace, en la raíz del repo
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m03
cd proyecto
```

- `ansible.cfg` apunta por defecto a `inventories/dev/hosts.yml`: sin `-i`, el grupo `web` es `dev-web1`.
- El playbook de la demostración, `anatomia.yml`, se crea en `proyecto/` con el contenido del paso 1.

## Recorrido

### 1 — Un playbook con dos plays

```yaml
# proyecto/anatomia.yml
- name: Preparar los servidores web del portal
  hosts: web
  become: true
  tasks:
    - name: Crear la carpeta del portal
      ansible.builtin.file:
        path: /srv/portal
        state: directory
        mode: "0755"

    - name: Dejar el aviso de entrada
      ansible.builtin.copy:
        dest: /etc/motd
        content: "Servidor web del portal de pedidos ({{ portal_entorno }})\n"
        mode: "0644"

- name: Comprobar todos los nodos del entorno
  hosts: all
  tasks:
    - name: Comprobar la conexión
      ansible.builtin.ping:
```

El fichero es una **lista** (cada `-` en la columna 0 abre un play). Dentro de cada play:

| Línea | Pieza | Qué significa aquí |
|-------|-------|--------------------|
| `- name: Preparar…` | Play | Nombre que aparece en la salida como `PLAY [...]` |
| `hosts: web` | Destino | Grupo `web` del inventario activo (en dev, `dev-web1`) |
| `become: true` | Privilegios | Las tareas se ejecutan con sudo: escribir en `/etc` lo necesita |
| `tasks:` | Tareas | Lista ordenada; cada `- name:` es una tarea |
| `ansible.builtin.file:` | Módulo | Nombre completo (FQCN) del módulo que hace el trabajo |
| `path:`, `state:`, `mode:` | Argumentos | Cuatro espacios más adentro que el módulo: son suyos |

El segundo play no lleva `become`: un `ping` no necesita sudo. `mode` va entre comillas para que YAML lo lea
como el texto `"0755"` y no como un número.

### 2 — Validar sin conectar: `--syntax-check` y `--list-tasks`

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook anatomia.yml --syntax-check
ansible-playbook anatomia.yml --list-tasks
```

```text
playbook: anatomia.yml

playbook: anatomia.yml

  play #1 (web): Preparar los servidores web del portal	TAGS: []
    tasks:
      Crear la carpeta del portal	TAGS: []
      Dejar el aviso de entrada	TAGS: []

  play #2 (all): Comprobar todos los nodos del entorno	TAGS: []
    tasks:
      Comprobar la conexión	TAGS: []
```

`--syntax-check` solo imprime el nombre del fichero cuando todo está bien (código de salida 0). `--list-tasks`
enseña el playbook tal como lo ha entendido Ansible: dos plays, con su patrón de hosts entre paréntesis y sus
tareas. Si una tarea aparece en el play equivocado, aquí se ve. Con `--list-hosts` y el inventario de prod se ve
además a quién va cada play:

```bash
ansible-playbook -i inventories/prod/hosts.yml anatomia.yml --list-hosts
```

```text
playbook: anatomia.yml

  play #1 (web): Preparar los servidores web del portal	TAGS: []
    pattern: ['web']
    hosts (2):
      prod-web2
      prod-web1

  play #2 (all): Comprobar todos los nodos del entorno	TAGS: []
    pattern: ['all']
    hosts (4):
      prod-web2
      prod-web1
      prod-lb1
      prod-db1
```

### 3 — La ejecución, dos veces

```bash
ansible-playbook anatomia.yml
```

```text
PLAY [Preparar los servidores web del portal] **********************************

TASK [Gathering Facts] *********************************************************
ok: [dev-web1]

TASK [Crear la carpeta del portal] *********************************************
changed: [dev-web1]

TASK [Dejar el aviso de entrada] ***********************************************
changed: [dev-web1]

PLAY [Comprobar todos los nodos del entorno] ***********************************

TASK [Gathering Facts] *********************************************************
ok: [dev-web1]

TASK [Comprobar la conexión] ***************************************************
ok: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=5    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Cada play empieza con `Gathering Facts` (Ansible recoge datos del nodo) y cada tarea muestra su `name`. En la
segunda ejecución el resumen queda en `ok=5 changed=0`: la carpeta y el aviso ya están como se pidieron.

### 4 — Un tabulador

Desde aquí, cada error se provoca en una copia de `anatomia.yml` con un solo cambio (`roto-tab.yml`,
`roto-indent.yml`…) y se lanza `ansible-playbook <copia> --syntax-check`. Al sangrar `path:` con tabuladores en lugar de espacios:

```text
[ERROR]: YAML parsing failed: Tabs are usually invalid in YAML.
Origin: /workspaces/ansible-automatizacion-201/proyecto/roto-tab.yml:8:1

6     - name: Crear la carpeta del portal
7       ansible.builtin.file:
8   path: /srv/portal
  ^ column 1
```

ansible-core 2.20 da el motivo, el `Origin` con `fichero:línea:columna` y el fragmento con la marca `^`. La
línea 8 se ve casi en la columna 1 porque el tabulador no se muestra como ocho espacios.

### 5 — Un espacio de más

Con `state:` un espacio más a la derecha que `path:`:

```yaml
      ansible.builtin.file:
        path: /srv/portal
         state: directory
```

```text
[ERROR]: YAML parsing failed: Mapping values are not allowed in this context.
Origin: /workspaces/ansible-automatizacion-201/proyecto/roto-indent.yml:9:15

7       ansible.builtin.file:
8         path: /srv/portal
9          state: directory
                ^ column 15
```

YAML intenta leer `state` como continuación del valor de `path` y se encuentra un `:` donde no puede haberlo.

### 6 — Dos puntos sin espacio

Con `mode:"0755"` (sin espacio tras `:`):

```text
[ERROR]: YAML parsing failed: While scanning a simple key could not find expected ':'.
Origin: /workspaces/ansible-automatizacion-201/proyecto/roto-dospuntos.yml:12:5

10         mode:"0755"
11
12     - name: Dejar el aviso de entrada
       ^ column 5
```

Sin el espacio, `mode:"0755"` no es una clave con su valor, sino un texto suelto. El error se señala en la línea
12, la siguiente tarea: a veces la causa está **justo antes** de lo marcado, y el fragmento con las líneas
anteriores sirve para encontrarla.

### 7 — Un valor que empieza por `{{`

Con `content: {{ portal_entorno }}` sin comillas:

```text
[ERROR]: YAML parsing failed: This may be an issue with missing quotes around a template block.
Origin: /workspaces/ansible-automatizacion-201/proyecto/roto-llaves.yml:15:18

13       ansible.builtin.copy:
14         dest: /etc/motd
15         content: {{ portal_entorno }}
                    ^ column 18


For example:

    raw: {{ some_var }}

Should be:

    raw: "{{ some_var }}"
```

Para YAML, `{` abre un diccionario. Cuando el valor **empieza** por `{{`, va entre comillas. Si las llaves están
en mitad del texto, como en `"Servidor web … ({{ portal_entorno }})"`, no hay problema.

### 8 — `yes` y `no` no son texto

Este error no da ningún aviso. El playbook `yaml-si-no.yml` muestra cómo ve Ansible tres variables:

```yaml
# proyecto/yaml-si-no.yml
- name: Ver cómo lee YAML el valor no
  hosts: web
  gather_facts: false
  vars:
    portal_mantenimiento: no
    portal_mantenimiento_texto: "no"
    portal_pais: NO
  tasks:
    - name: Mostrar los valores tal como los ve Ansible
      ansible.builtin.debug:
        msg:
          - "portal_mantenimiento = {{ portal_mantenimiento }} ({{ portal_mantenimiento | type_debug }})"
          - "portal_mantenimiento_texto = {{ portal_mantenimiento_texto }} ({{ portal_mantenimiento_texto | type_debug }})"
          - "portal_pais = {{ portal_pais }} ({{ portal_pais | type_debug }})"
```

```text
TASK [Mostrar los valores tal como los ve Ansible] *****************************
ok: [dev-web1] => {
    "msg": [
        "portal_mantenimiento = False (bool)",
        "portal_mantenimiento_texto = no (str)",
        "portal_pais = False (bool)"
    ]
}
```

`no` y `NO` sin comillas son el booleano `False`; el código de país de Noruega acabaría siendo `False`. Lo mismo
pasa con `yes`, `on` y `off`. Para un sí/no, el curso usa `true` y `false`; para texto, comillas. Con
`ansible.builtin.copy` y `content: no`, el fichero en el nodo contiene literalmente `False`.

### 9 — Lo que `--syntax-check` no ve

Dos fallos más, ya con YAML válido. Un módulo mal escrito (`ansible.builtin.copi`) sí lo detecta:

```text
[ERROR]: couldn't resolve module/action 'ansible.builtin.copi'. This often indicates a misspelling, missing collection, or incorrect module path.
Origin: /workspaces/ansible-automatizacion-201/proyecto/roto-modulo.yml:12:7
```

Un argumento mal escrito (`destino:` en lugar de `dest:`) pasa el `--syntax-check` y falla al ejecutar, cuando el
módulo ya está en el nodo:

```text
$ ansible-playbook roto-argumento.yml --syntax-check

playbook: roto-argumento.yml
$ ansible-playbook roto-argumento.yml
…
TASK [Dejar el aviso de entrada] ***********************************************
[ERROR]: Task failed: Action failed: dest is required
Origin: /workspaces/ansible-automatizacion-201/proyecto/roto-argumento.yml:12:7
…
fatal: [dev-web1]: FAILED! => {"changed": false, "msg": "dest is required"}

PLAY RECAP *********************************************************************
dev-web1                   : ok=2    changed=0    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
```

`--syntax-check` valida el YAML y la estructura del playbook; los argumentos de cada módulo se comprueban al
ejecutarlo. Las tareas anteriores (`ok=2`) sí se aplicaron: Ansible para en el nodo que falla, no deshace.

## Qué queda visto

| Error | Mensaje de ansible-core 2.20 | Arreglo |
|-------|------------------------------|---------|
| Tabulador | `Tabs are usually invalid in YAML.` | Solo espacios |
| Indentación | `Mapping values are not allowed in this context.` | Alinear con la clave hermana |
| `clave:valor` | `could not find expected ':'` (en la línea siguiente) | Espacio tras `:` |
| Valor con `{{` al principio | `missing quotes around a template block` | Comillas |
| `no`, `yes`, `on`, `off` | Ninguno: se convierten en booleano | `true`/`false` o comillas |
| Módulo mal escrito | `couldn't resolve module/action` | FQCN correcto |
| Argumento mal escrito | Solo al ejecutar (`dest is required`) | `ansible-doc` del módulo |

Los módulos que resuelven el runbook se practican en [Lab — Módulos principales](01-lab-modulos-principales.md);
el playbook completo del portal, en [Lab — Instalar y configurar un servicio](02-lab-instalar-servicio.md). Ambos
se hacen desde su propio punto de partida, sin haber seguido esta demostración.
