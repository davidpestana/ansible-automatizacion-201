# Lab — Validación previa

[← Página anterior](02-lab-ansible-lint.md) · [Siguiente página →](04-lab-cambios-con-pr.md)

En el equipo de operaciones de Tienda Norte la norma es clara: en prod no se aplica nada que no haya pasado antes
por el lint, la comprobación de sintaxis y una simulación contra los nodos reales. En este lab llevas un cambio de
configuración de `prod-web2` por esa cadena, lees en el `--diff` exactamente qué va a cambiar, lo aplicas solo
cuando todo pasa y ves dónde se queda corto el modo check.

### Objetivo

`prod-web2` con `worker_connections 4096` aplicado tras `make lint` → `make syntax` → `make check` sin errores, y
un `make deploy` parado en el lint por una tarea defectuosa.

### Punto de partida

- Terminal del Codespace, en la raíz del repositorio.
- Estado: proyecto completo con `Makefile` y `.ansible-lint` (perfil `production`, pasa limpio) y prod con el portal
  1.0.0 aplicado. Lo deja así el paso 1.

| Objetivo de `make` | Qué ejecuta | Se conecta a los nodos |
|--------------------|-------------|------------------------|
| `make lint` | `ansible-lint site.yml deploy.yml` | No |
| `make syntax` | `ansible-playbook … --syntax-check` de cada playbook | No |
| `make check` | `ansible-playbook -i inventories/$(ENTORNO)/hosts.yml site.yml --check --diff` | Sí, sin cambiar nada |
| `make site` | `validar` + `confirmar` + `site.yml` | Sí, aplica |
| `make deploy` | `validar` + `check` + `confirmar` + `deploy.yml` | Sí, aplica |

### En qué consiste

Cambias una variable de `host_vars`, la validas y la aplicas en prod con `make`. Después compruebas dos límites: el
modo check no puede predecir tareas que dependen de otras, y `make deploy` no arranca si el lint falla. No tocas
roles salvo para el caso del lint, que deshaces al final.

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repositorio
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m11
cd proyecto
ls -a
```

**Por qué:** el estado `m11` es el proyecto tal como queda al terminar este módulo: con `Makefile` y `.ansible-lint`.
`partida.sh` vuelve a aplicar `site.yml` en prod, así que prod queda con la 1.0.0 aunque antes desplegaras otra.

**Resultado esperado:** el `PLAY RECAP` de prod sin `failed` y, en el listado, `Makefile` y `.ansible-lint` junto a
`site.yml`, `deploy.yml`, `inventories` y `roles`.

> [!WARNING]
> `scripts/partida.sh` sustituye `proyecto/` entero (lo anterior queda en `proyecto.anterior/`). Si tenías trabajo
> propio en `proyecto/`, haz commit antes.

### 2 — Haz el cambio

**Acción:** en `proyecto/inventories/prod/host_vars/prod-web2.yml`, cambia `2048` por `4096`:

```yaml
# proyecto/inventories/prod/host_vars/prod-web2.yml
portal_worker_connections: 4096
```

**Por qué:** `prod-web2` recibe más tráfico en campaña y el equipo quiere subirle las conexiones de nginx. Es un
cambio pequeño, solo en un nodo de prod: justo el tipo de cambio que se aplica «a mano un momento» y acaba mal.

**Resultado esperado:** el fichero guardado con una sola línea, `portal_worker_connections: 4096`.

### 3 — Lint y sintaxis

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
make lint
make syntax ENTORNO=prod
```

**Por qué:** son las comprobaciones baratas: no se conectan a nada y descartan errores de YAML, de estilo y de
estructura antes de mirar los nodos.

**Resultado esperado:**

```text
ansible-lint site.yml deploy.yml

Passed: 0 failure(s), 0 warning(s) in 18 files processed of 18 encountered. Profile 'production' was required, and it passed.
```

```text
playbook: site.yml

playbook: deploy.yml
```

### 4 — Simula el cambio en prod con `--diff`

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
make check ENTORNO=prod
```

**Por qué:** `--check` recorre todas las tareas contra los nodos reales y dice cuáles cambiarían, sin cambiar
nada. `--diff` añade el **qué**: las líneas exactas de cada fichero. Es lo que se revisa antes de aplicar y lo que
se pega en el pull request.

**Resultado esperado:** solo `prod-web2` tiene cambios, en `nginx.conf` y en la recarga de nginx (recortado):

```text
TASK [portal : Configurar nginx (nginx.conf)] **********************************
ok: [prod-web1]
--- before: /etc/nginx/nginx.conf
+++ after: /home/…/nginx.conf.j2
@@ -5,7 +5,7 @@
 include /etc/nginx/modules-enabled/*.conf;
 
 events {
-    worker_connections 2048;
+    worker_connections 4096;
 }
 
 http {

changed: [prod-web2]
…
RUNNING HANDLER [portal : Recargar nginx] **************************************
changed: [prod-web2]
…
PLAY RECAP *********************************************************************
prod-db1                   : ok=8    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=12   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`changed=2` en `prod-web2`: el fichero y el handler. Nada más en prod se toca. Comprueba que de verdad no ha
cambiado nada: `docker exec prod-web2 grep worker_connections /etc/nginx/nginx.conf` sigue diciendo `2048`.

### 5 — Aplica solo ahora

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
make site ENTORNO=prod
make site ENTORNO=prod CONFIRMAR=si
docker exec prod-web2 grep worker_connections /etc/nginx/nginx.conf
```

**Por qué:** la simulación ha dicho lo que esperabas, así que toca aplicar. La primera orden te recuerda que prod
pide confirmación; la segunda aplica.

**Resultado esperado:** la primera se para sin tocar nada:

```text
prod pide CONFIRMAR=si
make: *** [Makefile:36: confirmar] Error 2
```

La segunda pasa lint y sintaxis y aplica, con el mismo resumen que predijo el check:

```text
PLAY RECAP *********************************************************************
prod-db1                   : ok=8    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=12   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Y en el nodo:

```text
    worker_connections 4096;
```

### 6 — Vuelve a simular

**Acción:** `make check ENTORNO=prod`

**Por qué:** después de aplicar, la simulación tiene que salir limpia. Si no, algo en prod no coincide con el
proyecto (alguien ha tocado a mano, o una tarea no es idempotente).

**Resultado esperado:**

```text
PLAY RECAP *********************************************************************
prod-db1                   : ok=8    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 7 — Mira un límite del modo check

**Acción:** en `proyecto/inventories/prod/group_vars/all.yml`, cambia `portal_version: "1.0.0"` por
`portal_version: "1.1.0"` y simula:

```bash
# Terminal del Codespace, en proyecto/
make check ENTORNO=prod
```

**Por qué:** cambiar de versión encadena tareas: crear la carpeta de la release, copiar los ficheros y apuntar
`current` a esa carpeta. En modo check la carpeta **no se crea**, así que la tarea del enlace no encuentra su
destino.

**Resultado esperado:** si la 1.1.0 nunca se ha publicado en las web de prod, las dos primeras tareas salen
`changed` con su diff y la del enlace falla (recortado):

```text
TASK [portal : Crear la carpeta de la release] *********************************
--- before
+++ after
@@ -1,4 +1,4 @@
 {
     "path": "/srv/portal/releases/1.1.0",
-    "state": "absent"
+    "state": "directory"
 }

changed: [prod-web1]
…
TASK [portal : Apuntar current a la release 1.1.0] *****************************
[ERROR]: Task failed: Module failed: src file does not exist, use 'force=yes' if you really want to create the link: /srv/portal/releases/1.1.0
Origin: /workspaces/…/proyecto/roles/portal/tasks/desplegar.yml:13:3
…
PLAY RECAP *********************************************************************
prod-db1                   : ok=8    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web1                  : ok=8    changed=2    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=8    changed=2    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0

make: *** [Makefile:24: check] Error 2
```

Si ya desplegaste la 1.1.0 en algún momento, la carpeta existe y el check pasa: solo cambia el enlace. Deja la
línea otra vez en `portal_version: "1.0.0"`.

| Lo que el modo check no puede saber | Qué pasa | Qué hacer |
|-------------------------------------|----------|-----------|
| Tareas que dependen de lo que crea una tarea anterior | Fallan o dan un resultado falso, como el enlace de arriba | Leer el fallo: no es un error del cambio. Las versiones se publican con `make deploy`, que verifica de verdad |
| `ansible.builtin.command` y `ansible.builtin.shell` | Se saltan (`skipping`): no se sabe qué harían | Si solo leen, `check_mode: false` y `changed_when: false` |
| Servicios que aún no están instalados | La tarea de `service` falla porque el paquete no existe | El check se usa sobre nodos ya instalados |

### 8 — Comprueba que `make deploy` no arranca si el lint falla

**Acción:** añade al final de `proyecto/roles/portal/tasks/main.yml` esta tarea (es incorrecta a propósito):

```yaml
# proyecto/roles/portal/tasks/main.yml (añadir al final)

- name: Limpiar releases antiguas
  ansible.builtin.shell: ls -d {{ portal_raiz }}/releases/* | head -n -2 | xargs rm -rf
```

Y lanza un despliegue confirmado:

```bash
# Terminal del Codespace, en proyecto/
make deploy ENTORNO=prod VERSION=1.1.0 CONFIRMAR=si
curl -s localhost:8080/estado.json
```

**Por qué:** es el caso que la cadena tiene que parar: aunque el despliegue esté confirmado, una tarea sin
`changed_when` y con una tubería sin `pipefail` no debe llegar a prod.

**Resultado esperado:** `make` se para en el primer requisito, antes de conectarse a ningún nodo:

```text
ansible-lint site.yml deploy.yml
WARNING  Listing 2 violation(s) that are fatal
no-changed-when: Commands should not change things if nothing needs doing.
roles/portal/tasks/main.yml:50 Task/Handler: Limpiar releases antiguas

risky-shell-pipe: Shells that use pipes should set the pipefail option.
roles/portal/tasks/main.yml:50 Task/Handler: Limpiar releases antiguas
…
Failed: 2 failure(s), 0 warning(s) in 18 files processed of 18 encountered. Profile 'production' was required, but 'moderate' profile passed. Rating: 2/5 star
make: *** [Makefile:18: lint] Error 2
```

Y prod sigue igual: `"version": "1.0.0"`. Borra la tarea añadida y comprueba que `make lint` vuelve a pasar.

## Comprueba tu entendimiento

**El orden de la cadena**
Ejecuta `make -n deploy ENTORNO=prod VERSION=1.1.0`.
→ Salen en orden `ansible-lint`, el bucle de `--syntax-check`, el `--check --diff`, el `if` de `confirmar` y por
último `deploy.yml`. Si uno falla, los siguientes no se ejecutan.

**Check no es aplicar**
Tras el paso 4 (antes del 5), `docker exec prod-web2 grep worker_connections /etc/nginx/nginx.conf`.
→ `worker_connections 2048;`: el modo check informa `changed` pero no escribe nada.

**Qué nodos toca un cambio**
Busca en la salida del paso 4 los `changed`.
→ Solo `prod-web2`. Si un cambio de `host_vars` de un nodo saliera `changed` en otros, algo en el proyecto no es
lo que crees.

## Reto

### 1 — Una lectura que funcione en modo check

Crea `proyecto/release-publicada.yml` con un play sobre `web` que lea el enlace `current` con
`ansible.builtin.command: readlink /srv/portal/current` y muestre el resultado con `ansible.builtin.debug`.
Ejecútalo con `ansible-playbook -i inventories/prod/hosts.yml release-publicada.yml --check` y consigue que en modo
check también muestre la release.

<details>
<summary>Ver solución</summary>

```yaml
# proyecto/release-publicada.yml
- name: Release publicada en cada web
  hosts: web
  tasks:
    - name: Leer el enlace current
      ansible.builtin.command: readlink {{ portal_raiz | default('/srv/portal') }}/current
      register: portal_current
      changed_when: false
      check_mode: false

    - name: Mostrar la release publicada
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} sirve {{ portal_current.stdout | default('(sin leer)') }}"
```

Sin `check_mode: false`, en modo check la lectura sale `skipping` y el mensaje queda `prod-web1 sirve ` (vacío).
Con `check_mode: false` la tarea se ejecuta también en check, porque solo lee, y el mensaje es
`prod-web1 sirve /srv/portal/releases/1.0.0`. `changed_when: false` hace que no cuente como cambio. El playbook pasa
`ansible-lint` con el perfil `production`.

</details>

### 2 — Corrige la tarea de limpieza en vez de borrarla

Reescribe la tarea del paso 8 para que pase el lint del proyecto.

<details>
<summary>Ver solución</summary>

`risky-shell-pipe` pide `set -o pipefail` (con `executable: /bin/bash`) y `no-changed-when` pide decir cuándo
cambia. Una forma es contar lo borrado:

```yaml
# proyecto/roles/portal/tasks/main.yml
- name: Limpiar releases antiguas
  ansible.builtin.shell: |
    set -o pipefail
    ls -d {{ portal_raiz }}/releases/* | head -n -2 | xargs -r rm -rvf | wc -l
  args:
    executable: /bin/bash
  register: portal_limpieza
  changed_when: portal_limpieza.stdout | int > 0
```

Compruébalo con `make lint`. Ojo: con `head -n -2` se conservan las dos releases más recientes por orden
alfabético, que no siempre es el orden de versión; en el proyecto real, mejor un `ansible.builtin.find` con
`ansible.builtin.file`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `make check` falla en `Apuntar current a la release …` con `src file does not exist` | Limitación del modo check: la carpeta de la release no existe todavía | No es un fallo del cambio. Publica versiones con `make deploy ENTORNO=… VERSION=…` |
| `make check ENTORNO=dev` falla en tareas de nginx | Los nodos de ese entorno no tienen el portal instalado | Aplica una vez `make site ENTORNO=dev`; el check se usa sobre nodos instalados |
| `make site ENTORNO=prod` responde `prod pide CONFIRMAR=si` | Guarda de prod | Añade `CONFIRMAR=si` tras revisar el check |
| `make deploy` se para en `lint` con `Error 2` | Hay avisos de `ansible-lint` en el proyecto | Corrígelos (o borra la tarea del paso 8) y repite |
| El check sale `changed` en un nodo que no has tocado | Alguien cambió ese nodo a mano o una tarea no es idempotente | Mira el `--diff` de esa tarea: dice qué hay en el nodo y qué quiere el proyecto |
