# Lab — Ejecución idempotente

[← Página anterior](02-lab-instalar-servicio.md) · [Siguiente página →](../M04-gestion-configuracion/README.md)

En Tienda Norte, `portal.yml` se va a lanzar muchas veces: tras cada cambio, para corregir a quien toque un nodo a
mano y, más adelante, desde un pipeline. Eso solo es seguro si el playbook es **idempotente**: si el nodo ya está
como se pide, no cambia nada. En este lab ensayas un cambio con `--check --diff`, corriges una deriva en
`dev-web1` y arreglas un playbook de comprobaciones cuyas tareas dicen `changed` en cada ejecución.

### Objetivo

Ver `changed=0` en `portal.yml` tras corregir una deriva, y dejar `comprobaciones.yml` con tres tareas que solo
cambian cuando de verdad hay algo que cambiar.

### Punto de partida

- Terminal del Codespace, en `proyecto/`.
- Estado: el proyecto con `portal.yml` y `files/portal.conf` (nginx + release 1.0.0) y `dev-web1` con el portal
  ya aplicado. El paso 1 te deja ahí.

### En qué consiste

Trabajas sobre `dev-web1`: compruebas que `portal.yml` es idempotente, provocas una deriva a mano, la ves con
`--check --diff` y la corriges. Después escribes un playbook con `ansible.builtin.command` y
`ansible.builtin.shell` que no es idempotente y lo corriges con `changed_when`, un módulo adecuado y `creates`.

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repo
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m03-03
cd proyecto
```

**Por qué:** copia el proyecto con `portal.yml` y lo aplica en dev, para que empieces con el portal en marcha.

**Resultado esperado:**

```text
Preparando los nodos para m03-03…
PLAY RECAP *********************************************************************
dev-web1                   : ok=10   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0

Listo: proyecto/ en el punto de partida «m03-03» (lo anterior está en proyecto.anterior/).
Entra en él con: cd /workspaces/ansible-automatizacion-201/proyecto
```

Si `dev-web1` no tenía el portal, el resumen dice `ok=11 changed=10`: es la instalación. Cualquiera de los dos vale.

### 2 — Ejecuta `portal.yml` otra vez

**Acción:** `ansible-playbook portal.yml`

**Por qué:** es la prueba básica de idempotencia: con el nodo ya configurado, ninguna tarea debe cambiar nada.

**Resultado esperado:**

```text
TASK [Instalar nginx] **********************************************************
ok: [dev-web1]
…
TASK [Arrancar nginx] **********************************************************
ok: [dev-web1]

TASK [Recargar nginx si ha cambiado el sitio] **********************************
skipping: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=10   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

### 3 — Toca el nodo a mano

**Acción:**

```bash
docker exec dev-web1 sed -i 's/index index.html;/index index.html index.htm;/' /etc/nginx/sites-available/portal
```

**Por qué:** simula a un operador que sigue el runbook antiguo y edita la configuración por SSH. El nodo ya no
coincide con lo que dice el proyecto: es una **deriva**.

**Resultado esperado:** el comando no imprime nada. `docker exec dev-web1 cat /etc/nginx/sites-available/portal`
muestra `index index.html index.htm;`.

### 4 — Mira qué haría Ansible con `--check --diff`

**Acción:** `ansible-playbook portal.yml --check --diff`

**Por qué:** `--check` pregunta a cada módulo qué cambiaría **sin aplicarlo**; `--diff` enseña el antes y el
después de los ficheros. Es lo que harías antes de lanzar el playbook en prod.

**Resultado esperado:**

```text
TASK [Configurar el sitio del portal] ******************************************
--- before: /etc/nginx/sites-available/portal
+++ after: /workspaces/ansible-automatizacion-201/proyecto/files/portal.conf
@@ -1,5 +1,5 @@
 server {
     listen 80 default_server;
     root /srv/portal/current;
-    index index.html index.htm;
+    index index.html;
 }

changed: [dev-web1]
…
TASK [Recargar nginx si ha cambiado el sitio] **********************************
changed: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=11   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`-` es lo que hay en el nodo y `+` lo que pondría el proyecto. En modo check, `changed` significa «cambiaría».
Comprueba que no se ha aplicado: `docker exec dev-web1 cat /etc/nginx/sites-available/portal` sigue con
`index.htm`.

> [!NOTE]
> El modo check se usa sobre nodos ya instalados. En un nodo sin nginx, tareas como `Arrancar nginx` pueden fallar
> en `--check`, porque el paquete solo se habría instalado «en simulación».

### 5 — Corrige la deriva

**Acción:** ejecuta `ansible-playbook portal.yml` dos veces.

**Por qué:** el proyecto es la fuente de verdad. La primera ejecución devuelve el fichero a su contenido y recarga
nginx; la segunda demuestra que vuelve a estar en orden.

**Resultado esperado:** primero

```text
TASK [Configurar el sitio del portal] ******************************************
changed: [dev-web1]
…
TASK [Recargar nginx si ha cambiado el sitio] **********************************
changed: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=11   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

y después `ok=10 changed=0 … skipped=1`.

### 6 — Escribe un playbook que no es idempotente

**Acción:** crea `proyecto/comprobaciones.yml`:

```yaml
# proyecto/comprobaciones.yml
- name: Comprobaciones y registro del portal
  hosts: web
  become: true
  tasks:
    - name: Comprobar la configuración de nginx
      ansible.builtin.command: nginx -t

    - name: Anunciar el portal en el aviso de entrada
      ansible.builtin.shell: echo "Portal de pedidos 1.0.0" >> /etc/motd

    - name: Empaquetar la release 1.0.0
      ansible.builtin.command: tar czf /srv/portal/releases/1.0.0.tar.gz -C /srv/portal/releases 1.0.0
```

**Por qué:** son tres pasos del runbook copiados tal cual como comandos. Es la forma más rápida de pasar un
script a Ansible, y también la que más problemas da.

**Resultado esperado:** `ansible-playbook comprobaciones.yml --syntax-check` imprime `playbook: comprobaciones.yml`.

### 7 — Ejecútalo dos veces

**Acción:**

```bash
ansible-playbook comprobaciones.yml
ansible-playbook comprobaciones.yml
ssh -F ../infra/ssh_config dev-web1 tail -n 3 /etc/motd
```

**Por qué:** si fuera idempotente, la segunda ejecución saldría `changed=0`.

**Resultado esperado:** las dos ejecuciones terminan igual, y el aviso tiene la línea repetida:

```text
TASK [Comprobar la configuración de nginx] *************************************
changed: [dev-web1]

TASK [Anunciar el portal en el aviso de entrada] *******************************
changed: [dev-web1]

TASK [Empaquetar la release 1.0.0] *********************************************
changed: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

permitted by applicable law.
Portal de pedidos 1.0.0
Portal de pedidos 1.0.0
```

Cada tarea tiene un problema distinto:

| Tarea | Qué pasa | Por qué |
|-------|----------|---------|
| `nginx -t` | `changed` aunque solo consulta | `command` no sabe si la orden cambia algo y siempre dice que sí |
| `echo … >> /etc/motd` | Una línea más en cada ejecución | La orden **añade**, no describe un estado |
| `tar czf …` | Rehace el paquete cada vez | Nada le dice que ya existe |

### 8 — Mira qué hace `--check` con estas tareas

**Acción:** `ansible-playbook comprobaciones.yml --check`

**Por qué:** un ensayo que no ensaya es un riesgo: conviene saber qué tareas quedan fuera.

**Resultado esperado:**

```text
TASK [Comprobar la configuración de nginx] *************************************
skipping: [dev-web1]

TASK [Anunciar el portal en el aviso de entrada] *******************************
skipping: [dev-web1]

TASK [Empaquetar la release 1.0.0] *********************************************
skipping: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=1    changed=0    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0
```

`command` y `shell` se saltan en modo check: Ansible no puede simular una orden arbitraria. Un `changed=0` en
check no garantiza nada si el playbook está lleno de comandos.

### 9 — Corrige las tres tareas

**Acción:** deja `comprobaciones.yml` así:

```yaml
# proyecto/comprobaciones.yml
- name: Comprobaciones y registro del portal
  hosts: web
  become: true
  tasks:
    - name: Comprobar la configuración de nginx
      ansible.builtin.command: nginx -t
      changed_when: false

    - name: Anunciar el portal en el aviso de entrada
      ansible.builtin.lineinfile:
        path: /etc/motd
        line: Portal de pedidos 1.0.0

    - name: Empaquetar la release 1.0.0
      ansible.builtin.command: tar czf /srv/portal/releases/1.0.0.tar.gz -C /srv/portal/releases 1.0.0
      args:
        creates: /srv/portal/releases/1.0.0.tar.gz
```

**Por qué:** cada arreglo responde a un caso:

- `changed_when: false` → la orden solo consulta: nunca cambia nada (si `nginx -t` falla, la tarea sigue fallando).
- `ansible.builtin.lineinfile` → el **módulo adecuado** para «esta línea tiene que estar en el fichero»: la añade
  si falta y no la repite.
- `creates` → «si este fichero ya existe, no ejecutes la orden».

**Resultado esperado:** `ansible-playbook comprobaciones.yml --syntax-check` imprime `playbook: comprobaciones.yml`.

### 10 — Comprueba que ya es idempotente

**Acción:**

```bash
ansible-playbook comprobaciones.yml
ansible-playbook comprobaciones.yml --check
```

**Por qué:** el criterio es el mismo que para `portal.yml`: sobre un nodo en orden, `changed=0`.

**Resultado esperado:**

```text
TASK [Comprobar la configuración de nginx] *************************************
ok: [dev-web1]

TASK [Anunciar el portal en el aviso de entrada] *******************************
ok: [dev-web1]

TASK [Empaquetar la release 1.0.0] *********************************************
ok: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

y en check:

```text
TASK [Comprobar la configuración de nginx] *************************************
skipping: [dev-web1]

TASK [Anunciar el portal en el aviso de entrada] *******************************
ok: [dev-web1]

TASK [Empaquetar la release 1.0.0] *********************************************
ok: [dev-web1]

PLAY RECAP *********************************************************************
dev-web1                   : ok=3    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

`lineinfile` y el `tar` con `creates` ya se evalúan en check; `nginx -t` se sigue saltando. Las dos líneas
repetidas del paso 7 siguen en `/etc/motd`: `lineinfile` garantiza que la línea esté, no limpia lo que dejó el
comando antiguo.

## Comprueba tu entendimiento

**Idempotencia del portal**
Ejecuta `ansible-playbook portal.yml`.
→ `changed=0` y la recarga en `skipping`.

**Ensayo sin efecto**
Ejecuta `docker exec dev-web1 sed -i 's/index index.html;/index index.html index.htm;/' /etc/nginx/sites-available/portal`
y después `ansible-playbook portal.yml --check --diff`.
→ El diff muestra `-    index index.html index.htm;` y `+    index index.html;`; el fichero del nodo no cambia
hasta que lanzas `ansible-playbook portal.yml` sin `--check`.

**Comandos corregidos**
Ejecuta `ansible-playbook comprobaciones.yml` dos veces.
→ `changed=0` las dos.

## Reto

### 1 — Un reinicio que siempre cambia

Un compañero propone esta tarea para «asegurarse de que nginx está en marcha»:

```yaml
    - name: Asegurar nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
```

Sin añadirla al playbook, comprueba con un ad hoc cómo se comporta en dos ejecuciones seguidas y propón la
alternativa.

<details>
<summary>Ver solución</summary>

```bash
ansible web -b -m ansible.builtin.service -a "name=nginx state=restarted"
ansible web -b -m ansible.builtin.service -a "name=nginx state=restarted"
```

```text
dev-web1 | CHANGED => {
…
    "changed": true,
    "name": "nginx",
    "state": "started"
}
dev-web1 | CHANGED => {
…
    "changed": true,
    "name": "nginx",
    "state": "started"
}
```

`restarted` reinicia **siempre**: dos `CHANGED` y un corte en el servicio en cada ejecución. Para «que esté en
marcha», `state: started`; para aplicar una configuración nueva, `state: reloaded` solo cuando cambie, como en
`portal.yml` con `register`/`when` (y en el M06, con un handler).

</details>

### 2 — Deja limpio el aviso de entrada

Quita del `/etc/motd` de `dev-web1` las líneas repetidas con una tarea idempotente y vuelve a dejar una sola.

<details>
<summary>Ver solución</summary>

Con `lineinfile`, `state: absent` borra **todas** las líneas que coinciden; después la tarea del paso 9 la añade
una vez:

```bash
ansible web -b -m ansible.builtin.lineinfile -a "path=/etc/motd line='Portal de pedidos 1.0.0' state=absent"
ansible-playbook comprobaciones.yml
ssh -F ../infra/ssh_config dev-web1 tail -n 2 /etc/motd
```

El ad hoc sale `CHANGED` con `"msg": "2 line(s) removed"`, `comprobaciones.yml` termina con `changed=1` (solo
`Anunciar el portal…`) y el aviso acaba en una única línea `Portal de pedidos 1.0.0`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| La segunda ejecución sigue con `changed` | Tareas con `command`/`shell` o `state: restarted` | Módulo específico, `creates`/`removes` o `changed_when` |
| `--check` dice `changed=0` pero al aplicar cambia algo | Tareas `command`/`shell` saltadas en check | Mira las líneas `skipping` del check |
| `--check` falla en `Arrancar nginx` | Nodo sin nginx: la instalación solo se simuló | Usa el modo check sobre nodos ya instalados |
| La línea del `motd` se repite | `shell: echo … >>` en lugar de `lineinfile` | `ansible.builtin.lineinfile` con `line:` |
| Con `changed_when: false` no te enteras de un fallo | Confusión entre `changed_when` y `failed_when` | `changed_when` solo cambia el estado «cambiado»; un `rc` distinto de 0 sigue fallando |
