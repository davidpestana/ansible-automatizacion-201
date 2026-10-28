# Lab — Handlers

[← Página anterior](01-lab-condicionales-y-bucles.md) · [Siguiente página →](03-lab-tags.md)

El rol `portal` recarga nginx con una tarea al final: registra el resultado de dos plantillas y recarga si alguna ha
cambiado. Funciona, pero cada tarea nueva que toque la configuración obliga a tocar también ese `when`, y en cada
ejecución aparece un `skipping` que no aporta nada. En este lab sustituyes esa tarea por un handler, `Recargar nginx`,
y compruebas en `dev-web1` que sin cambios no se recarga y que con dos cambios se recarga una sola vez.

### Objetivo

El rol `portal` con `roles/portal/handlers/main.yml` y `notify: Recargar nginx` en sus cuatro tareas de configuración,
sin la tarea `Recargar nginx si ha cambiado su configuración`.

### Punto de partida

- Terminal del Codespace. El paso 1 carga el proyecto y el paso 2 instala el portal en `dev-web1`, vengas de donde vengas.
- Estado: `proyecto/` con los roles `portal` y `portal_lb`, `web.yml`, `lb.yml` y `site.yml`. La recarga de nginx
  todavía se hace con `register` + `when`; no hay handlers ni tags.

### En qué consiste

Trabajas solo en el rol `portal` y en `dev-web1` (el inventario por defecto). El balanceador (`portal_lb`) mantiene
su recarga con `when` a propósito; se explica en el paso 3.

### 1 — Prepara el punto de partida

**Acción:**

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m06
cd proyecto
```

**Por qué:** deja `proyecto/` tal como empieza este módulo, con la recarga aún sin handler.

**Resultado esperado:** `Listo: proyecto/ en el punto de partida «m06» (lo anterior está en proyecto.anterior/).`

### 2 — Aplica el portal en dev y repite

**Acción:**

```bash
ansible-playbook web.yml
ansible-playbook web.yml
```

**Por qué:** la primera ejecución deja `dev-web1` con el portal (si ya lo tenía, no cambia nada). La segunda muestra
cómo se comporta la recarga actual cuando no hay nada que cambiar.

**Resultado esperado:** la primera termina con `dev-web1 … ok=12 changed=11` en un nodo limpio o con `changed=0` si
ya estaba instalado. La segunda:

```text
TASK [portal : Arrancar nginx] *************************************************
ok: [dev-web1]

TASK [portal : Recargar nginx si ha cambiado su configuración] *****************
skipping: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=11   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

La recarga no ocurre, pero la tarea está ahí, saltada, en cada ejecución.

### 3 — Crea el handler

**Acción:** crea `proyecto/roles/portal/handlers/main.yml`:

```yaml
# proyecto/roles/portal/handlers/main.yml
- name: Recargar nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded
```

**Por qué:** los handlers de un rol viven en su carpeta `handlers/`, y Ansible los carga solo al usar el rol. El
nombre es el que usarán las tareas en `notify`, así que debe coincidir letra a letra.

**Resultado esperado:** el fichero existe; todavía nadie lo notifica.

> [!NOTE]
> El rol `portal_lb` no usa handler en `tasks/balancear.yml`, y el comentario del fichero explica por qué: en el
> M07, `deploy.yml` incluye esas tareas con `delegate_to` al balanceador, y un handler correría en el nodo web que
> lo notifica, no en `prod-lb1`. Ahí la tarea con `when` es la opción correcta.

### 4 — Notifica desde las tareas de configuración

**Acción:** en `proyecto/roles/portal/tasks/main.yml`:

1. En `Configurar nginx (nginx.conf)` y en `Configurar el sitio del portal`, sustituye la línea `register: …` por
   `notify: Recargar nginx`.
2. Añade `notify: Recargar nginx` también a `Activar el sitio del portal` y a `Quitar el sitio por defecto`.
3. Borra la última tarea entera, `Recargar nginx si ha cambiado su configuración`.

Las tareas de configuración quedan así:

```yaml
# proyecto/roles/portal/tasks/main.yml (extracto)
- name: Configurar nginx (nginx.conf)
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    mode: "0644"
    validate: nginx -t -c %s
  notify: Recargar nginx

- name: Configurar el sitio del portal
  ansible.builtin.template:
    src: portal.conf.j2
    dest: /etc/nginx/sites-available/portal
    mode: "0644"
  notify: Recargar nginx

- name: Activar el sitio del portal
  ansible.builtin.file:
    src: /etc/nginx/sites-available/portal
    dest: /etc/nginx/sites-enabled/portal
    state: link
  notify: Recargar nginx

- name: Quitar el sitio por defecto
  ansible.builtin.file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  notify: Recargar nginx
```

**Por qué:** cada tarea declara por sí misma que, si cambia algo, nginx debe recargarse. Activar o quitar un sitio
también cambia lo que sirve nginx, y con `register` + `when` nadie se acordó de ellas. La última tarea del fichero
pasa a ser `Arrancar nginx`.

**Resultado esperado:** `ansible-playbook web.yml --syntax-check` responde `playbook: web.yml`.

### 5 — Ejecuta sin cambios

**Acción:** `ansible-playbook web.yml`

**Por qué:** el nodo ya tiene la configuración correcta: ninguna tarea cambia, nadie notifica.

**Resultado esperado:**

```text
TASK [portal : Publicar el estado del nodo] ************************************
ok: [dev-web1]

TASK [portal : Arrancar nginx] *************************************************
ok: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Ya no hay `skipping` ni `skipped=1`: un handler que nadie notifica ni aparece.

### 6 — Provoca dos cambios a mano

**Acción:** simula que alguien ha tocado los dos ficheros de configuración de `dev-web1` por SSH:

```bash
docker exec dev-web1 bash -c "echo '# cambio a mano' >> /etc/nginx/nginx.conf; echo '# cambio a mano' >> /etc/nginx/sites-available/portal"
```

**Por qué:** es el caso real del runbook: un cambio manual que Ansible tiene que deshacer. Con dos ficheros
alterados, dos tareas notificarán el mismo handler.

**Resultado esperado:** el comando no muestra nada.

### 7 — Ejecuta con cambios

**Acción:** `ansible-playbook web.yml`

**Por qué:** es la prueba de que el handler corre cuando hay cambios y solo una vez aunque lo pidan dos tareas.

**Resultado esperado:**

```text
TASK [portal : Configurar nginx (nginx.conf)] **********************************
changed: [dev-web1]

TASK [portal : Configurar el sitio del portal] *********************************
changed: [dev-web1]
…
TASK [portal : Arrancar nginx] *************************************************
ok: [dev-web1]

RUNNING HANDLER [portal : Recargar nginx] **************************************
changed: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=12   changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Dos tareas `changed`, un único `RUNNING HANDLER`, y después de la última tarea del rol.

### 8 — Adelanta el handler con `meta: flush_handlers`

**Acción:** en `roles/portal/tasks/main.yml`, justo antes de `Desplegar la release`, añade:

```yaml
- name: Aplicar ya la configuración de nginx
  ansible.builtin.meta: flush_handlers
```

Altera solo el sitio y ejecuta:

```bash
docker exec dev-web1 bash -c "echo '# cambio a mano' >> /etc/nginx/sites-available/portal"
ansible-playbook web.yml
```

**Por qué:** a veces una tarea posterior necesita la configuración nueva ya aplicada (una comprobación contra nginx,
por ejemplo). `flush_handlers` ejecuta en ese punto los handlers pendientes, en lugar de esperar al final.

**Resultado esperado:**

```text
TASK [portal : Quitar el sitio por defecto] ************************************
ok: [dev-web1]

TASK [portal : Aplicar ya la configuración de nginx] ***************************

RUNNING HANDLER [portal : Recargar nginx] **************************************
changed: [dev-web1]

TASK [portal : Crear la carpeta de la release] *********************************
ok: [dev-web1]
…
PLAY RECAP *********************************************************************
dev-web1                   : ok=12   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

El handler aparece en mitad del rol, antes del despliegue de la release.

### 9 — Quita el `flush_handlers`

**Acción:** borra las dos líneas de `Aplicar ya la configuración de nginx` y comprueba con
`ansible-playbook web.yml` que vuelve a dar `changed=0`.

**Por qué:** en el rol `portal` nada depende de que nginx se haya recargado antes de desplegar: la release son
ficheros estáticos. Sin necesidad real, es mejor dejar que el handler corra al final una sola vez. Así el rol queda
igual que el del punto de partida de las páginas siguientes.

**Resultado esperado:** `dev-web1 … ok=11 changed=0`.

> [!NOTE]
> Si una tarea falla en un nodo después de notificar, los handlers pendientes de ese nodo **no** corren y la
> configuración nueva queda en disco sin cargar. `ansible-playbook web.yml --force-handlers` los ejecuta aunque haya
> fallos. La siguiente ejecución sin cambios tampoco los lanzaría: el fichero ya no cambia, y nadie notifica.

## Comprueba tu entendimiento

**Sin cambios no hay recarga**
`ansible-playbook web.yml` dos veces seguidas.
→ La segunda no muestra `RUNNING HANDLER` y termina con `changed=0 … skipped=0`.

**Varios avisos, una recarga**
Repite el paso 6 y `ansible-playbook web.yml`.
→ Dos tareas `changed` y un solo `RUNNING HANDLER [portal : Recargar nginx]`.

**El nombre manda**
`grep -rn "Recargar nginx" roles/portal/`.
→ Una línea `- name: Recargar nginx` en `handlers/main.yml` y cuatro `notify: Recargar nginx` en `tasks/main.yml`.

## Reto

### 1 — Cambio de configuración desde el inventario

Sube `portal_worker_connections` a `1024` en `inventories/dev/group_vars/all.yml` y aplica. ¿Cuántas tareas cambian
y cuántas veces se recarga nginx? Deja el valor como estaba al terminar.

<details>
<summary>Ver solución</summary>

Solo cambia `Configurar nginx (nginx.conf)` (la variable se usa en `nginx.conf.j2`) y el handler corre una vez:
`changed=2` en el resumen. `docker exec dev-web1 grep worker_connections /etc/nginx/nginx.conf` muestra
`worker_connections 1024;`. Al quitar la línea del `group_vars` y aplicar de nuevo, vuelve a 768 con otra recarga.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `The requested handler 'Recargar Nginx' was not found in either the main handlers list nor in the listening handlers list` | El texto de `notify` no coincide con el `name` del handler (mayúsculas, espacios) | Copia el nombre exacto: `Recargar nginx` |
| El handler no corre aunque la plantilla sale `changed` | `handlers/main.yml` está en otra carpeta (p. ej. `roles/portal/handler/`) o en la raíz del proyecto | Debe ser `proyecto/roles/portal/handlers/main.yml` |
| El handler corre en cada ejecución | Una tarea que lo notifica da `changed` siempre (por ejemplo, un `command` sin `changed_when`) | Haz idempotente esa tarea o añade `changed_when` |
| Sigue apareciendo `Recargar nginx si ha cambiado su configuración` | No has borrado la tarea antigua del final de `tasks/main.yml` | Bórrala; si no, falla con `'portal_nginx_conf' is undefined` al quitar los `register` |
| Fallo a mitad y nginx no carga la configuración nueva | Los handlers pendientes no corren en un nodo con una tarea fallida | Arregla el fallo y ejecuta con `--force-handlers`, o recarga con `ansible dev-web1 -b -m ansible.builtin.service -a "name=nginx state=reloaded"` |
