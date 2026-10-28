# Lab — ansible-lint

[← Página anterior](01-lab-makefile.md) · [Siguiente página →](03-lab-validacion-previa.md)

Un compañero de operaciones de Tienda Norte ha añadido al rol `portal` una página de mantenimiento y una
comprobación de la versión de nginx. Funciona, pero lo ha escrito con prisa: módulos sin nombre completo, una tarea
sin `name`, ficheros sin permisos explícitos… En este lab pasas `ansible-lint` por el proyecto, fijas las reglas del
equipo en `.ansible-lint` y corriges los avisos uno a uno hasta que `make lint` pasa con el perfil `production`.

### Objetivo

`proyecto/.ansible-lint` con el perfil `production` y el rol `portal` corregido: `make lint` termina en
`Profile 'production' was required, and it passed.`

### Punto de partida

- Terminal del Codespace, en la raíz del repositorio.
- Estado: proyecto completo con el `Makefile` del [Lab — Makefile](01-lab-makefile.md) y el cambio del compañero en
  `roles/portal/`, sin `.ansible-lint`. Lo deja así el paso 1. No hace falta tocar los nodos: `ansible-lint` no se
  conecta a ellos.

### En qué consiste

Lees el informe de `ansible-lint`, creas su configuración y corriges ocho avisos en dos ficheros:
`roles/portal/tasks/main.yml` y `roles/portal/defaults/main.yml`. No aplicas nada en los nodos.

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repositorio
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m10-02
cd proyecto
tail -n 18 roles/portal/tasks/main.yml
tail -n 1 roles/portal/defaults/main.yml
```

**Por qué:** te deja el proyecto con el cambio del compañero sin depender de otras páginas. Los `tail` enseñan qué
ha añadido.

**Resultado esperado:** las tres tareas nuevas al final del rol y una variable nueva:

```yaml
# proyecto/roles/portal/tasks/main.yml (final)
- name: Comprobar la versión de nginx
  command: nginx -v
  register: portal_nginx_version

- ansible.builtin.file:
    path: "{{ portal_raiz }}/mantenimiento"
    state: directory

- name: Publicar la página de mantenimiento
  ansible.builtin.copy:
    content: "<h1>El portal de pedidos de Tienda Norte está en mantenimiento. Estamos publicando una nueva versión; vuelve a intentarlo en unos minutos o escribe a pedidos@tienda-norte.example.</h1>\n"
    dest: "{{ portal_raiz }}/mantenimiento/index.html"
  when: mantenimiento_activo
```

```text
mantenimiento_activo: yes
```

> [!WARNING]
> `scripts/partida.sh` sustituye `proyecto/` entero (lo anterior queda en `proyecto.anterior/`). Si tenías trabajo
> propio en `proyecto/`, haz commit antes.

### 2 — Pasa `ansible-lint` por el proyecto

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-lint
```

**Por qué:** sin argumentos, `ansible-lint` revisa todos los YAML del proyecto (playbooks, roles, inventarios) sin
conectarse a ningún nodo. Es la revisión que haría un compañero exigente, pero automática.

**Resultado esperado:** ocho avisos, un resumen y el código de salida 2:

```text
WARNING  Listing 8 violation(s) that are fatal
var-naming[no-role-prefix]: Variables names from within roles should use portal_ as a prefix. (vars: mantenimiento_activo)
roles/portal/defaults/main.yml:8:1

yaml[truthy]: Truthy value should be one of [false, true]
roles/portal/defaults/main.yml:8

no-changed-when: Commands should not change things if nothing needs doing.
roles/portal/tasks/main.yml:50 Task/Handler: Comprobar la versión de nginx

fqcn[action-core]: Use FQCN for builtin module actions (command).
roles/portal/tasks/main.yml:51:3 Use `ansible.builtin.command` or `ansible.legacy.command` instead.

name[missing]: All tasks should be named.
roles/portal/tasks/main.yml:54 Task/Handler: file path={{ portal_raiz }}/mantenimiento state=directory

risky-file-permissions: File permissions unset or incorrect.
roles/portal/tasks/main.yml:54 Task/Handler: file path={{ portal_raiz }}/mantenimiento state=directory

risky-file-permissions: File permissions unset or incorrect.
roles/portal/tasks/main.yml:58 Task/Handler: Publicar la página de mantenimiento

yaml[line-length]: Line too long (201 > 160 characters)
roles/portal/tasks/main.yml:60

Read documentation for instructions on how to ignore specific rule violations.

# Rule Violation Summary
…
Failed: 8 failure(s), 0 warning(s) in 32 files processed of 37 encountered. Last profile that met the validation criteria was 'min'.
```

Cada aviso tiene la misma forma:

| Parte | Ejemplo | Qué dice |
|-------|---------|----------|
| Regla y subregla | `fqcn[action-core]` | Qué norma se incumple; la documentación está en `https://ansible.readthedocs.io/projects/lint/rules/fqcn/` |
| Mensaje | `Use FQCN for builtin module actions (command).` | El problema concreto |
| Fichero y línea | `roles/portal/tasks/main.yml:51:3` | Dónde está (línea 51, columna 3) |
| Tarea | `Task/Handler: Comprobar la versión de nginx` | Qué tarea, por su `name` |

La última línea dice que el proyecto solo cumple el perfil `min`, el más permisivo.

### 3 — Fija las reglas del equipo en `.ansible-lint`

**Acción:** crea `proyecto/.ansible-lint`:

```yaml
# proyecto/.ansible-lint
# Reglas de calidad del proyecto (ansible-lint). Perfil de producción.
profile: production
exclude_paths:
  - app/
```

Y vuelve a lanzar `ansible-lint`.

**Por qué:** sin configuración, cada uno ve lo que su versión de `ansible-lint` decida. Con el fichero en el
repositorio, todo el equipo (y más adelante el pipeline) aplica el mismo perfil. `app/` son las releases del
portal, HTML que no es Ansible.

**Resultado esperado:** los mismos ocho avisos; cambia la última línea, que ahora dice qué perfil se exige:

```text
Failed: 8 failure(s), 0 warning(s) in 33 files processed of 35 encountered. Profile 'production' was required, but 'min' profile passed.
```

### 4 — Compara perfiles

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-lint --profile basic
```

**Por qué:** los perfiles son escalones; cada uno añade reglas al anterior. Saber en qué escalón cae cada aviso
ayuda a decidir qué exige el equipo.

**Resultado esperado:** solo cuatro avisos (`var-naming`, `yaml[truthy]`, `name[missing]` y `yaml[line-length]`):

```text
Failed: 4 failure(s), 0 warning(s) in 32 files processed of 37 encountered. Profile 'basic' was required, but 'min' profile passed.
```

Así se reparten los ocho avisos de este proyecto:

| Perfil | Avisos | Añade, en este proyecto |
|--------|--------|--------------------------|
| `min` | 0 | Solo errores que impiden cargar el YAML |
| `basic` y `moderate` | 4 | `var-naming[no-role-prefix]`, `yaml[truthy]`, `name[missing]`, `yaml[line-length]` |
| `safety` | 6 | `risky-file-permissions` (dos) |
| `shared` | 7 | `no-changed-when` |
| `production` | 8 | `fqcn[action-core]` |

### 5 — Usa el nombre completo del módulo (`fqcn`)

**Acción:** en `roles/portal/tasks/main.yml`, en la tarea «Comprobar la versión de nginx», cambia
`command: nginx -v` por:

```yaml
# proyecto/roles/portal/tasks/main.yml
  ansible.builtin.command: nginx -v
```

Lanza `ansible-lint` otra vez.

**Por qué:** `command` a secas depende de qué colecciones estén instaladas y en qué orden se busquen. Con el
FQCN (`ansible.builtin.command`) no hay ambigüedad, y es como está escrito el resto del proyecto.

**Resultado esperado:** `Failed: 7 failure(s)`. Desaparece `fqcn[action-core]`.

### 6 — Di cuándo cambia algo una tarea `command` (`no-changed-when`)

**Acción:** debajo de `register: portal_nginx_version`, añade:

```yaml
# proyecto/roles/portal/tasks/main.yml
  changed_when: false
```

Y vuelve a lanzar `ansible-lint`.

**Por qué:** Ansible no sabe qué hace un comando, así que `command` siempre informa `changed`. `nginx -v` solo lee:
sin `changed_when: false`, cada ejecución de `site.yml` diría que ha cambiado algo en todas las web y el
`changed=0` de la segunda ejecución dejaría de significar «nada que hacer».

**Resultado esperado:** `Failed: 6 failure(s)`.

### 7 — Pon nombre y permisos a la carpeta de mantenimiento

**Acción:** sustituye la tarea sin nombre por:

```yaml
# proyecto/roles/portal/tasks/main.yml
- name: Crear la carpeta de mantenimiento
  ansible.builtin.file:
    path: "{{ portal_raiz }}/mantenimiento"
    state: directory
    mode: "0755"
```

Y lanza `ansible-lint`.

**Por qué:** sin `name`, la salida de Ansible muestra `TASK [portal : file]` y nadie sabe qué hace; las tareas del
proyecto se nombran en español con mayúscula inicial. Sin `mode`, los permisos dependen de la `umask` del nodo y
pueden cambiar entre servidores.

**Resultado esperado:** `Failed: 4 failure(s)`: se van `name[missing]` y uno de los `risky-file-permissions`.

### 8 — Parte la línea larga y fija el modo de la página

**Acción:** en la tarea «Publicar la página de mantenimiento», sustituye la línea `content:` por un bloque plegado
y añade `mode`:

```yaml
# proyecto/roles/portal/tasks/main.yml
- name: Publicar la página de mantenimiento
  ansible.builtin.copy:
    content: >
      <h1>El portal de pedidos de Tienda Norte está en mantenimiento.
      Estamos publicando una nueva versión; vuelve a intentarlo en unos minutos
      o escribe a pedidos@tienda-norte.example.</h1>
    mode: "0644"
    dest: "{{ portal_raiz }}/mantenimiento/index.html"
  when: mantenimiento_activo
```

Lanza `ansible-lint`.

**Por qué:** con `>`, YAML une las líneas con un espacio y deja un salto de línea al final: el HTML es el mismo y
el fichero se lee sin desplazarse. `mode: "0644"` es el mismo permiso que el resto de ficheros del portal.

**Resultado esperado:** `Failed: 2 failure(s)`. Solo quedan los dos avisos de `roles/portal/defaults/main.yml:8`.

### 9 — Renombra la variable con el prefijo del rol y usa `true`

**Acción:** en `roles/portal/defaults/main.yml`, cambia la última línea por:

```yaml
# proyecto/roles/portal/defaults/main.yml
portal_mantenimiento: true
```

Y en `roles/portal/tasks/main.yml` cambia `when: mantenimiento_activo` por `when: portal_mantenimiento`.

**Por qué:** las variables de un rol llevan su prefijo (`portal_`) para no chocar con las de otros roles: con tres
roles en el proyecto, un `activo` o un `version` sin prefijo acaba pisándose. `yes` es booleano en YAML 1.1 pero
texto en YAML 1.2; `true` es booleano en los dos.

**Resultado esperado:** al cambiar el nombre en los dos ficheros desaparecen los dos últimos avisos. Si cambias
solo `defaults/main.yml`, el lint pasa pero el playbook fallará con
`Error while evaluating conditional: 'mantenimiento_activo' is undefined`.

### 10 — Pasa el lint del equipo

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
make lint
make syntax
```

**Por qué:** `make lint` es lo que ejecutarán `make deploy`, tus compañeros y el pipeline. Si pasa aquí, pasa en
todas partes.

**Resultado esperado:**

```text
ansible-lint site.yml deploy.yml

Passed: 0 failure(s), 0 warning(s) in 18 files processed of 18 encountered. Profile 'production' was required, and it passed.
```

Y `make syntax` lista `playbook: site.yml` y `playbook: deploy.yml` sin errores.

## Comprueba tu entendimiento

**Silenciar no es corregir**
Con el proyecto del paso 3 (antes de corregir), `ansible-lint -x yaml[line-length]` da `Failed: 7 failure(s)`.
→ `-x` excluye una regla en esa ejecución; el problema sigue en el fichero. Lo mismo hace `skip_list:` en
`.ansible-lint`, pero para todo el equipo: úsalo solo para reglas que el equipo haya decidido no aplicar.

**Una excepción justificada**
Abre `roles/portal_lb/tasks/balancear.yml` y busca `# noqa: no-handler`.
→ Es una excepción a una sola tarea, con el motivo escrito encima: el fichero se incluye con `delegate_to` y un
handler se ejecutaría en la web, no en el balanceador. Así se deja una excepción: en la línea, con su regla y
con el porqué.

**El lint no se conecta a los nodos**
Ejecuta `make lint` con los nodos parados o sin red.
→ Pasa igual: `ansible-lint` solo lee ficheros. Lo que depende de los nodos lo comprueba `make check`.

## Reto

### 1 — Prueba `--fix` en una copia

`ansible-lint --fix` corrige algunos avisos solo. Pruébalo sobre una copia del proyecto del paso 1 y averigua qué
arregla, qué no y qué más toca.

<details>
<summary>Ver solución</summary>

```bash
# Terminal del Codespace, en la raíz del repositorio
cp -r partidas/m10-02 /tmp/lint-fix
cd /tmp/lint-fix
ansible-lint --fix
diff -r "$CODESPACE_VSCODE_FOLDER/partidas/m10-02" /tmp/lint-fix | head -40
```

Fuera de un repositorio Git puede avisar con un `UserWarning` sobre la caché; no afecta. Termina con
`Modified 25 files.` y `Failed: 5 failure(s)`. Ha corregido `fqcn` (`ansible.builtin.command`) y
`yaml[truthy]` (`true`) y ha partido la línea larga en dos, pero **también** ha añadido `---` al principio de los
25 YAML del proyecto y ha reformateado un comentario `# noqa`. No arregla `name`, `mode`, `changed_when` ni el
prefijo de la variable: eso exige decidir (qué nombre, qué permisos), y una herramienta no lo sabe. Usa `--fix`
en una rama y revisa el diff entero antes de hacer commit. Borra la copia con `rm -rf /tmp/lint-fix`.

</details>

### 2 — ¿Por qué `make lint` revisa menos ficheros?

`ansible-lint` revisa 33 ficheros y `make lint`, 18. Explica la diferencia y si es un problema.

<details>
<summary>Ver solución</summary>

`make lint` ejecuta `ansible-lint site.yml deploy.yml`: revisa esos playbooks y lo que cargan (roles, tareas,
`db.yml`, `web.yml`, `lb.yml`). Sin argumentos revisa todo el proyecto, también los inventarios y los `meta/` de
los roles. Si alguien añade un playbook nuevo que no está en `PLAYBOOKS`, `make lint` no lo revisa: al crear un
playbook, añádelo a esa variable del `Makefile`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `yaml[indentation]` o `syntax-check[specific]` después de editar | Al pegar, la tarea quedó con otra sangría | Alinea `- name:` con las demás tareas y sus claves con dos espacios más |
| Los avisos no cambian tras crear `.ansible-lint` | El fichero se llama distinto (`ansible-lint.yml`, sin punto) o está fuera de `proyecto/` | `ls -a proyecto/` debe mostrar `.ansible-lint` |
| `Error while evaluating conditional: 'mantenimiento_activo' is undefined` al ejecutar el playbook | Renombraste la variable en `defaults` pero no en el `when` | Usa `portal_mantenimiento` en los dos sitios |
| `A new release of ansible-lint is available` | Aviso informativo de la herramienta | Ignóralo: el curso fija la versión en `requirements.txt` |
| `ansible-lint` revisa `app/` y tarda más | Falta `exclude_paths` | Añade `- app/` en `exclude_paths` |
