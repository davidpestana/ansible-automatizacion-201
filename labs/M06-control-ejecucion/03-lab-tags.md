# Lab — Tags

[← Página anterior](02-lab-handlers.md) · [Siguiente página →](04-lab-registro-de-resultados.md)

Cuando operaciones de Tienda Norte solo quiere corregir la configuración de nginx, lanzar el rol entero significa
revisar paquetes con `apt`, copiar la release y comprobar el enlace `current`: más lento y más cosas que pueden salir
mal. En este lab etiquetas las tareas de los roles con `paquetes`, `config` y `despliegue`, y aprendes a ejecutar o
saltar cada parte, además de dos tags especiales: uno que entra siempre y otro que solo entra si se pide.

### Objetivo

Los roles `portal` y `portal_lb` con tags `paquetes`, `config` y `despliegue`, y `web.yml` con una tarea `always` y
otra `never`, comprobado con `--list-tags`, `--tags` y `--skip-tags` en `dev-web1`.

### Punto de partida

- Terminal del Codespace. El paso 1 carga el proyecto y aplica el portal en `dev-web1`.
- Estado: `proyecto/` con los roles `portal` (ya con el handler `Recargar nginx` y sus `notify`) y `portal_lb`,
  sin ningún tag.

### En qué consiste

Añades tags a las tareas de los dos roles y dos tareas nuevas en `web.yml`. No cambias lo que hace ninguna tarea:
solo decides en qué ejecuciones entra cada una. Todo se prueba en dev.

### 1 — Prepara el punto de partida

**Acción:**

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m06-03
cd proyecto
ansible-playbook web.yml
```

**Por qué:** `m06-03` es el proyecto con handlers y sin tags. Aplicar `web.yml` garantiza que `dev-web1` tiene el
portal, vengas de donde vengas.

**Resultado esperado:** `Listo: proyecto/ en el punto de partida «m06-03» …` y un `PLAY RECAP` sin fallos
(`changed=11` en un nodo limpio, `changed=0` si ya tenía el portal).

### 2 — Etiqueta el rol `portal`

**Acción:** en `proyecto/roles/portal/tasks/main.yml`, añade una línea `tags:` al final de cada tarea, al mismo
nivel que `notify`:

| Tarea | Línea que añades |
|-------|------------------|
| `Instalar nginx` | `tags: [paquetes]` |
| `Configurar nginx (nginx.conf)` | `tags: [config]` |
| `Configurar el sitio del portal` | `tags: [config]` |
| `Activar el sitio del portal` | `tags: [config]` |
| `Quitar el sitio por defecto` | `tags: [config]` |
| `Desplegar la release` | `tags: [despliegue]` |
| `Arrancar nginx` | (ninguna) |

Por ejemplo:

```yaml
# proyecto/roles/portal/tasks/main.yml (extracto)
- name: Configurar el sitio del portal
  ansible.builtin.template:
    src: portal.conf.j2
    dest: /etc/nginx/sites-available/portal
    mode: "0644"
  notify: Recargar nginx
  tags: [config]

- name: Desplegar la release
  ansible.builtin.import_tasks: desplegar.yml
  tags: [despliegue]
```

**Por qué:** son las tres cosas que operaciones hace por separado: instalar software, cambiar configuración y
publicar una release. `import_tasks` es estático, así que el tag `despliegue` pasa a las cuatro tareas de
`desplegar.yml` sin tocar ese fichero.

**Resultado esperado:** `ansible-playbook web.yml --syntax-check` responde `playbook: web.yml`.

### 3 — Etiqueta el rol `portal_lb`

**Acción:** en `proyecto/roles/portal_lb/tasks/main.yml`, añade `tags: [paquetes]` a `Instalar nginx` y
`tags: [config]` a `Configurar el balanceador` (el `import_tasks` de `balancear.yml`).

**Por qué:** los mismos nombres en los dos roles permiten lanzar `site.yml --tags config` y que afecte a web y
balanceador por igual.

**Resultado esperado:** `ansible-playbook site.yml --syntax-check` responde `playbook: site.yml`.

### 4 — Añade una tarea `always` y otra `never` en `web.yml`

**Acción:** sustituye `proyecto/web.yml` por:

```yaml
# proyecto/web.yml
- name: Servidores web del portal
  hosts: web
  become: true
  pre_tasks:
    - name: Mostrar qué se va a aplicar
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }}: entorno {{ portal_entorno }}, release {{ portal_version }}"
      tags: [always]
  roles:
    - portal
  post_tasks:
    - name: Volcar la configuración completa de nginx
      ansible.builtin.command: nginx -T
      changed_when: false
      tags: [never, diagnostico]
```

**Por qué:** el resumen de qué se va a aplicar interesa en cualquier ejecución, se filtre lo que se filtre: `always`.
El volcado de `nginx -T` es largo y solo sirve para diagnosticar: `never` lo deja fuera salvo que se pida su otro
tag, `diagnostico`.

**Resultado esperado:** `ansible-playbook web.yml --syntax-check` responde `playbook: web.yml`.

### 5 — Lista los tags

**Acción:** `ansible-playbook site.yml --list-tags`

**Por qué:** antes de filtrar, conviene ver qué tags existen en cada play. No se ejecuta nada.

**Resultado esperado:**

```text
[WARNING]: Could not match supplied host pattern, ignoring: lb

playbook: site.yml

  play #1 (web): Servidores web del portal	TAGS: []
      TASK TAGS: [always, config, despliegue, diagnostico, never, paquetes]

  play #2 (lb): Balanceador del portal	TAGS: []
      TASK TAGS: [config, paquetes]
```

El aviso sale porque el inventario de dev no tiene grupo `lb`; con `-i inventories/prod/hosts.yml` desaparece.

### 6 — Aplica solo la configuración

**Acción:** altera el sitio a mano y aplica solo `config`:

```bash
docker exec dev-web1 bash -c "echo '# cambio a mano' >> /etc/nginx/sites-available/portal"
ansible-playbook web.yml --tags config
```

**Por qué:** es el caso de uso típico: corregir un cambio manual en la configuración sin pasar por `apt` ni por la
release.

**Resultado esperado:**

```text
TASK [Mostrar qué se va a aplicar] *********************************************
ok: [dev-web1] => {
    "msg": "dev-web1: entorno dev, release 1.1.0"
}

TASK [portal : Configurar nginx (nginx.conf)] **********************************
ok: [dev-web1]

TASK [portal : Configurar el sitio del portal] *********************************
changed: [dev-web1]

TASK [portal : Activar el sitio del portal] ************************************
ok: [dev-web1]

TASK [portal : Quitar el sitio por defecto] ************************************
ok: [dev-web1]

RUNNING HANDLER [portal : Recargar nginx] **************************************
changed: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=7    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Solo corren las cuatro tareas `config`, la tarea `always` y el handler notificado. `Instalar nginx`, las de la
release y `Arrancar nginx` (sin tag) no aparecen.

### 7 — Salta los paquetes

**Acción:** `ansible-playbook web.yml --skip-tags paquetes`

**Por qué:** en un parche de configuración o un despliegue no hace falta que `apt` revise la caché. `--skip-tags`
ejecuta todo lo demás, también lo que no tiene tag.

**Resultado esperado:** las tareas que aparecen son:

```text
TASK [Gathering Facts] *********************************************************
TASK [Mostrar qué se va a aplicar] *********************************************
TASK [portal : Configurar nginx (nginx.conf)] **********************************
TASK [portal : Configurar el sitio del portal] *********************************
TASK [portal : Activar el sitio del portal] ************************************
TASK [portal : Quitar el sitio por defecto] ************************************
TASK [portal : Crear la carpeta de la release] *********************************
TASK [portal : Copiar la release 1.1.0] ****************************************
TASK [portal : Apuntar current a la release 1.1.0] *****************************
TASK [portal : Publicar el estado del nodo] ************************************
TASK [portal : Arrancar nginx] *************************************************
PLAY RECAP *********************************************************************
dev-web1                   : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Falta `Instalar nginx`; `Arrancar nginx` sí está, porque no tiene tag y nadie la ha saltado.

### 8 — Despliega solo una release

**Acción:** `ansible-playbook web.yml --tags despliegue -e portal_version=1.0.0`

**Por qué:** cambiar de release no debería tocar la configuración. `-e` fuerza la versión solo en esta ejecución
(gana a `group_vars`), sin editar el inventario.

**Resultado esperado:**

```text
TASK [Mostrar qué se va a aplicar] *********************************************
ok: [dev-web1] => {
    "msg": "dev-web1: entorno dev, release 1.0.0"
}

TASK [portal : Crear la carpeta de la release] *********************************
changed: [dev-web1]

TASK [portal : Copiar la release 1.0.0] ****************************************
changed: [dev-web1]

TASK [portal : Apuntar current a la release 1.0.0] *****************************
changed: [dev-web1]

TASK [portal : Publicar el estado del nodo] ************************************
changed: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`curl -s localhost:8081/estado.json` muestra `"version": "1.0.0"`.

### 9 — Pide la tarea `never`

**Acción:** `ansible-playbook web.yml --tags diagnostico -v`

**Por qué:** `never` solo entra si se pide por su otro tag. `-v` muestra la salida del comando.

**Resultado esperado:** tres tareas (`Gathering Facts`, `Mostrar qué se va a aplicar` y
`Volcar la configuración completa de nginx`) y `ok=3 changed=0`. La línea del volcado empieza por
`ok: [dev-web1] => {"changed": false, "cmd": ["nginx", "-T"], …` y contiene
`# configuration file /etc/nginx/nginx.conf:`.

### 10 — Vuelve a la release de dev

**Acción:**

```bash
ansible-playbook web.yml
curl -s localhost:8081/estado.json
```

**Por qué:** sin filtros se aplica todo, y `portal_version` vuelve a ser la de `group_vars` (1.1.0). La tarea
`never` no aparece.

**Resultado esperado:** `dev-web1 … ok=12 changed=1` (el enlace `current` vuelve a la 1.1.0) y:

```text
{
  "host": "dev-web1",
  "entorno": "dev",
  "version": "1.1.0",
  "color": "#2563eb",
  "db": ""
}
```

## Comprueba tu entendimiento

**Qué entra con cada filtro**
`ansible-playbook web.yml --tags config --list-tasks`.
→ Lista `Mostrar qué se va a aplicar` y las cuatro tareas de configuración del rol, con sus tags entre corchetes.

**`always` también se puede saltar**
`ansible-playbook web.yml --tags config --skip-tags always`.
→ La tarea `Mostrar qué se va a aplicar` desaparece de la salida.

**`never` no entra por defecto**
`ansible-playbook web.yml` sin opciones.
→ No aparece `Volcar la configuración completa de nginx`.

## Reto

### 1 — Configuración en todo prod

Aplica solo la configuración en web y balanceador de prod con un único comando. ¿Qué tareas corren en `prod-lb1`?

<details>
<summary>Ver solución</summary>

`ansible-playbook -i inventories/prod/hosts.yml site.yml --tags config`. Con prod ya instalado, en `prod-lb1` corren
`Gathering Facts`, `Actualizar los servidores del balanceador` y `Recargar el balanceador` (las dos de `balancear.yml`
heredan `config` del `import_tasks`); la recarga sale `skipping` si la plantilla no cambia:

```text
prod-lb1                   : ok=2    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=6    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=6    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Con prod limpio falla en los web con `Destination directory /etc/nginx does not exist`: sin el tag `paquetes`, nginx
no se instala. Como fallan todos los web, la ejecución se para y el play del balanceador ni empieza. Un filtro por
tags presupone que lo que se salta ya está hecho.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `--tags config` no ejecuta ninguna tarea del rol | Escribiste el tag con otra forma (`configuracion`, `Config`) | `ansible-playbook web.yml --list-tags` y usa el nombre exacto |
| `--tags despliegue` no ejecuta las tareas de `desplegar.yml` | Usaste `include_tasks` en lugar de `import_tasks`: con `include` el tag solo se aplica al propio include | Mantén `ansible.builtin.import_tasks`, o usa `apply: {tags: [despliegue]}` con `include_tasks` |
| `--tags config` falla con `Destination directory /etc/nginx does not exist` | Nodo limpio: las tareas `config` necesitan nginx instalado, y `paquetes` no entra | Primera vez sin filtros; los tags son para nodos ya instalados |
| La tarea de diagnóstico corre siempre | Le pusiste solo `tags: [diagnostico]`, sin `never` | `tags: [never, diagnostico]` |
