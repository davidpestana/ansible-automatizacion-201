# Lab — Despliegue escalonado

[← Página anterior](02-lab-multiples-nodos.md) · [Siguiente página →](../M08-operaciones-dia-2/README.md)

Con el runbook, una release mala en Tienda Norte se descubría cuando ya estaba en los dos servidores web y el
portal entero daba error. En este lab escribes `deploy.yml`, el playbook de despliegue de prod: actualiza un web
cada vez, verifica que responde y, si no, lo devuelve a la release anterior y para antes de tocar el siguiente.
Lo pruebas con la 1.1.0, que funciona, y con la 1.2.0, que viene rota.

### Objetivo

Un `proyecto/deploy.yml` con `serial: 1`, `max_fail_percentage: 0` y `block`/`rescue` que, al desplegar la 1.2.0,
deja `prod-web1` de vuelta en la 1.1.0 y `prod-web2` sin tocar, con el portal respondiendo 200 en el 8080.

### Punto de partida

- Terminal del Codespace. El paso 1 deja `proyecto/` en el estado `m07-03`.
- Estado tras el paso 1: roles `portal` (con `tasks/desplegar.yml`, las cuatro tareas que publican una release)
  y `portal_lb`, `site.yml`; prod con el portal 1.0.0 instalado y solo la release 1.0.0 en disco. No existe `deploy.yml`.
- En `app/releases/` están la 1.0.0, la 1.1.0 y la 1.2.0, que se empaquetó sin `index.html`: nginx responde 403.
- No hace falta nada de páginas anteriores.

### En qué consiste

Escribes `deploy.yml` en dos versiones: primero solo con `serial` y verificación, para ver qué pasa cuando la
release falla; después con vuelta atrás automática. No sacas los nodos del balanceador durante el despliegue:
eso exige ejecutar tareas en `prod-lb1` desde el play de los web y se trabaja en el M09.

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repo
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m07-03
cd proyecto
```

**Por qué:** deja prod en la 1.0.0 y sin releases de pruebas anteriores.

**Resultado esperado:** `Preparando los nodos para m07-03…`, un `PLAY RECAP` con `failed=0` y
`Listo: proyecto/ en el punto de partida «m07-03»`.

### 2 — Escribe un despliegue por tandas con verificación

**Acción:** crea `proyecto/deploy.yml` con este contenido:

```yaml
# proyecto/deploy.yml
# Despliegue del portal por tandas: un nodo web cada vez y verificación al terminar.
- name: Desplegar el portal {{ portal_version }}
  hosts: web
  become: true
  serial: 1
  tasks:
    - name: Desplegar la release
      ansible.builtin.import_role:
        name: portal
        tasks_from: desplegar

    - name: Verificar que el portal responde
      ansible.builtin.uri:
        url: "http://localhost/"
        status_code: 200
      register: portal_verificacion
      until: portal_verificacion.status == 200
      retries: 3
      delay: 2
```

Después comprueba la sintaxis:

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml deploy.yml --syntax-check
```

**Por qué:** `serial: 1` parte el play en tandas de un nodo: `prod-web1` hace todas las tareas y solo después
empieza `prod-web2`. `tasks_from: desplegar` reutiliza las tareas del rol sin instalar ni configurar nginx otra
vez. La verificación pide la portada desde el propio nodo y reintenta unas veces antes de dar el fallo por bueno.

**Resultado esperado:**

```text
playbook: deploy.yml
```

### 3 — Despliega la 1.1.0 por tandas

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml deploy.yml -e portal_version=1.1.0
```

**Por qué:** la versión va con `-e`: el despliegue es una acción puntual sobre lo que ya está instalado.

**Resultado esperado:** el play aparece **dos veces**, una por tanda, cada una con un solo nodo:

```text
PLAY [Desplegar el portal 1.1.0] ***********************************************

TASK [Gathering Facts] *********************************************************
ok: [prod-web1]

TASK [portal : Crear la carpeta de la release] *********************************
changed: [prod-web1]

TASK [portal : Copiar la release 1.1.0] ****************************************
changed: [prod-web1]

TASK [portal : Apuntar current a la release 1.1.0] *****************************
changed: [prod-web1]

TASK [portal : Publicar el estado del nodo] ************************************
changed: [prod-web1]

TASK [Verificar que el portal responde] ****************************************
ok: [prod-web1]

PLAY [Desplegar el portal 1.1.0] ***********************************************

TASK [Gathering Facts] *********************************************************
ok: [prod-web2]
…
TASK [Verificar que el portal responde] ****************************************
ok: [prod-web2]

PLAY RECAP *********************************************************************
prod-web1                  : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 4 — Despliega la release rota 1.2.0

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml deploy.yml -e portal_version=1.2.0
```

**Por qué:** es el caso que justifica todo esto: una release que se copia sin errores pero no sirve el portal.

**Resultado esperado:** la verificación falla en `prod-web1` tras los reintentos y el play se para; `prod-web2`
no llega a empezar:

```text
TASK [portal : Apuntar current a la release 1.2.0] *****************************
changed: [prod-web1]
…
TASK [Verificar que el portal responde] ****************************************
FAILED - RETRYING: [prod-web1]: Verificar que el portal responde (3 retries left).
FAILED - RETRYING: [prod-web1]: Verificar que el portal responde (2 retries left).
FAILED - RETRYING: [prod-web1]: Verificar que el portal responde (1 retries left).
[ERROR]: Task failed: Module failed: Status code was 403 and not [200]: HTTP Error 403: Forbidden
Origin: /workspaces/…/proyecto/deploy.yml:13:7

11         tasks_from: desplegar
12
13     - name: Verificar que el portal responde
         ^ column 7

fatal: [prod-web1]: FAILED! => {"attempts": 3, "changed": false, … "status": 403, "url": "http://localhost/"}

PLAY RECAP *********************************************************************
prod-web1                  : ok=5    changed=4    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
```

Con `serial`, si **todos** los nodos de una tanda fallan, Ansible no empieza la siguiente. Con tandas de uno,
basta un fallo.

### 5 — Mira el daño

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
curl -s -o /dev/null -w "%{http_code}\n" localhost:8083; curl -s -o /dev/null -w "%{http_code}\n" localhost:8084
for i in 1 2 3 4; do curl -s -o /dev/null -w "%{http_code}\n" localhost:8080; done
```

**Por qué:** parar a tiempo salvó a `prod-web2`, pero `prod-web1` se ha quedado con la release rota y el
balanceador le sigue mandando clientes.

**Resultado esperado:**

```text
403
200
```

```text
403
200
403
200
```

La mitad de las peticiones al portal fallan.

### 6 — Vuelve a mano a la 1.1.0

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml deploy.yml -e portal_version=1.1.0
curl -s -o /dev/null -w "%{http_code}\n" localhost:8083
```

**Por qué:** la 1.1.0 sigue en disco, así que volver es solo mover `current`. Funciona, pero depende de que
alguien vea el fallo y sepa cuál era la versión anterior.

**Resultado esperado:** en `prod-web1` cambia solo `Apuntar current a la release 1.1.0`, y `prod-web2` no cambia:

```text
PLAY RECAP *********************************************************************
prod-web1                  : ok=6    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=6    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

```text
200
```

### 7 — Añade la vuelta atrás automática y `max_fail_percentage`

**Acción:** sustituye el contenido de `proyecto/deploy.yml` por este:

```yaml
# proyecto/deploy.yml
# Despliegue del portal por tandas: un nodo web cada vez, verificación al terminar
# y vuelta a la release anterior si la verificación falla.
- name: Desplegar el portal {{ portal_version }}
  hosts: web
  become: true
  serial: 1
  max_fail_percentage: 0
  tasks:
    - name: Leer la release actual
      ansible.builtin.stat:
        path: "{{ portal_raiz }}/current"
      register: portal_actual

    - name: Desplegar y verificar
      block:
        - name: Desplegar la release
          ansible.builtin.import_role:
            name: portal
            tasks_from: desplegar

        - name: Verificar que el portal responde
          ansible.builtin.uri:
            url: "http://localhost/"
            status_code: 200
          register: portal_verificacion
          until: portal_verificacion.status == 200
          retries: 3
          delay: 2
      rescue:
        - name: Volver a la release anterior
          ansible.builtin.file:
            src: "{{ portal_actual.stat.lnk_source }}"
            dest: "{{ portal_raiz }}/current"
            state: link
          when: portal_actual.stat.islnk | default(false)

        - name: Parar el despliegue
          ansible.builtin.fail:
            msg: >-
              La release {{ portal_version }} no responde en {{ inventory_hostname }};
              se ha vuelto a {{ portal_actual.stat.lnk_source | default('ninguna') | basename }}.
```

Y comprueba la sintaxis con `ansible-playbook -i inventories/prod/hosts.yml deploy.yml --syntax-check`.

**Por qué:** cada pieza resuelve un hueco del paso 5:

| Pieza | Qué hace |
|-------|----------|
| `Leer la release actual` | Guarda adónde apunta `current` **antes** de tocar nada (`lnk_source`, p. ej. `/srv/portal/releases/1.1.0`) |
| `block` | Agrupa desplegar y verificar: si cualquiera falla, salta al `rescue` |
| `rescue` → `Volver a la release anterior` | Devuelve `current` a lo que se leyó; el `when` evita fallar en un nodo sin release previa |
| `rescue` → `Parar el despliegue` | Vuelve a marcar el nodo como fallido. Sin esta tarea, un `rescue` que termina bien da el nodo por **rescatado** y el despliegue seguiría con `prod-web2` |
| `max_fail_percentage: 0` | Cualquier fallo en una tanda para el resto del play, aunque la tanda tenga más de un nodo |

**Resultado esperado:** `playbook: deploy.yml`.

> [!NOTE]
> Con `serial: 1` el play ya se paraba solo en el paso 4, porque fallaba toda la tanda. `max_fail_percentage: 0`
> deja la regla escrita y la mantiene si mañana las tandas son más grandes, por ejemplo `serial: "50%"` con
> cuatro web: sin él, un fallo en uno de los dos nodos de la tanda no pararía el despliegue.

### 8 — Despliega otra vez la 1.2.0

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml deploy.yml -e portal_version=1.2.0
```

**Por qué:** es la misma release rota; ahora el playbook tiene que detectarla, deshacerla y parar solo.

**Resultado esperado:** falla la verificación, se ejecuta el `rescue` y el play se detiene antes de `prod-web2`:

```text
TASK [Leer la release actual] **************************************************
ok: [prod-web1]
…
TASK [portal : Apuntar current a la release 1.2.0] *****************************
changed: [prod-web1]
…
TASK [Verificar que el portal responde] ****************************************
FAILED - RETRYING: [prod-web1]: Verificar que el portal responde (3 retries left).
FAILED - RETRYING: [prod-web1]: Verificar que el portal responde (2 retries left).
FAILED - RETRYING: [prod-web1]: Verificar que el portal responde (1 retries left).
[ERROR]: Task failed: Module failed: Status code was 403 and not [200]: HTTP Error 403: Forbidden
…
fatal: [prod-web1]: FAILED! => {"attempts": 3, "changed": false, … "status": 403, "url": "http://localhost/"}

TASK [Volver a la release anterior] ********************************************
changed: [prod-web1]

TASK [Parar el despliegue] *****************************************************
[ERROR]: Task failed: Action failed: La release 1.2.0 no responde en prod-web1; se ha vuelto a 1.1.0.
…
fatal: [prod-web1]: FAILED! => {"changed": false, "msg": "La release 1.2.0 no responde en prod-web1; se ha vuelto a 1.1.0."}

NO MORE HOSTS LEFT *************************************************************

NO MORE HOSTS LEFT *************************************************************

PLAY RECAP *********************************************************************
prod-web1                  : ok=7    changed=2    unreachable=0    failed=1    skipped=0    rescued=1    ignored=0
```

`rescued=1` y `failed=1`: el nodo se rescató (vuelta atrás) y aun así cuenta como fallido, que es lo que para
el despliegue. `prod-web2` no aparece en el resumen.

### 9 — Comprueba que prod sigue sano

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
curl -s localhost:8083/estado.json | grep version; curl -s localhost:8084/estado.json | grep version
for i in 1 2 3 4; do curl -s -o /dev/null -w "%{http_code}\n" localhost:8080; done
ssh -F ../infra/ssh_config prod-web1 ls -l /srv/portal /srv/portal/releases
```

**Por qué:** la salida en rojo del playbook es la alarma; el estado real lo dice el portal.

**Resultado esperado:** los dos web en la 1.1.0, el balanceador sirviendo 200 siempre y, en `prod-web1`, la 1.2.0
copiada pero sin usar:

```text
  "version": "1.1.0",
  "version": "1.1.0",
```

```text
200
200
200
200
```

```text
/srv/portal:
total 4
lrwxrwxrwx 1 root root   26 Oct 26 19:37 current -> /srv/portal/releases/1.1.0
drwxr-xr-x 5 root root 4096 Oct 26 19:36 releases

/srv/portal/releases:
total 12
drwxr-xr-x 2 root root 4096 Oct 26 19:35 1.0.0
drwxr-xr-x 2 root root 4096 Oct 26 19:35 1.1.0
drwxr-xr-x 2 root root 4096 Oct 26 19:36 1.2.0
```

### 10 — Confirma prod en la 1.1.0

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml deploy.yml -e portal_version=1.1.0
```

**Por qué:** cierra el incidente dejando constancia de que la versión buena está aplicada en todos los web.
Si la vuelta atrás fue completa, no queda nada por cambiar.

**Resultado esperado:**

```text
PLAY RECAP *********************************************************************
prod-web1                  : ok=7    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=7    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

## Comprueba tu entendimiento

**Una tanda por nodo**
Lanza `ansible-playbook -i inventories/prod/hosts.yml deploy.yml -e portal_version=1.1.0 | grep '^PLAY'`.
→ Dos líneas `PLAY [Desplegar el portal 1.1.0]` y una `PLAY RECAP`.

**La vuelta atrás es solo el enlace**
Lanza `ssh -F ../infra/ssh_config prod-web1 readlink /srv/portal/current`.
→ `/srv/portal/releases/1.1.0`, aunque la carpeta `1.2.0` exista en el nodo.

**El despliegue roto no llegó al segundo web**
Lanza `ssh -F ../infra/ssh_config prod-web2 ls /srv/portal/releases`.
→ Solo `1.0.0` y `1.1.0`.

## Reto

### 1 — Vuelve prod a la 1.0.0 con el mismo playbook

Producto pide retirar la 1.1.0 de prod. Hazlo con `deploy.yml` y explica cuántas tareas cambian en cada web y por qué.

<details>
<summary>Ver solución</summary>

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml deploy.yml -e portal_version=1.0.0
```

```text
PLAY RECAP *********************************************************************
prod-web1                  : ok=7    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=7    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Un cambio por nodo: la release 1.0.0 y su `estado.json` ya estaban en disco, así que solo se mueve `current`.
Pasa también por la verificación y por las tandas: una vuelta atrás es un despliegue más.

</details>

### 2 — ¿Por qué no basta con `-f 1`?

Explica qué habría pasado en el paso 4 si en lugar de `serial: 1` el play no tuviera `serial` y lo lanzaras con `-f 1`.

<details>
<summary>Ver solución</summary>

`forks` reparte cada **tarea** de uno en uno, pero cada tarea pasa por todos los nodos antes de que empiece la siguiente:
los dos web habrían recibido `Apuntar current a la release 1.2.0` antes de la verificación, y el portal entero
habría respondido 403. `serial` es lo que hace que un nodo termine el play (y falle) antes de que el siguiente empiece.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| Con la 1.2.0, `prod-web2` también queda en 403 | Falta `serial: 1` o está mal indentado (dentro de `tasks`) | `serial` va al nivel de `hosts` y `become` |
| El `rescue` deja el nodo en la 1.2.0 | Se lanzó con `current` ya apuntando a la 1.2.0 (por ejemplo, tras el paso 4 sin el paso 6): la «release anterior» leída es la rota | Vuelve primero a la 1.1.0 con `-e portal_version=1.1.0` y repite |
| Tras el `rescue`, el despliegue sigue con `prod-web2` | Falta la tarea `Parar el despliegue`: el nodo queda `rescued` y no cuenta como fallido | Termina el `rescue` con `ansible.builtin.fail` |
| `Could not find or access '…/app/releases/1.3.0/'` | Versión que no existe en `app/releases/` | Usa `1.0.0`, `1.1.0` o `1.2.0` |

