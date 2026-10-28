# Lab — Parcheo

[← Página anterior](00-un-cambio-en-produccion.md) · [Siguiente página →](02-lab-cambio-en-produccion.md)

En Tienda Norte los parches se aplicaban entrando por SSH en cada servidor y lanzando `apt-get upgrade` a mano, a
veces en los dos web a la vez y sin mirar antes qué se iba a actualizar. En este lab escribes `parcheo.yml`: un
playbook que informa de lo pendiente, actualiza los servidores web de prod de uno en uno, avisa si alguno pide
reinicio y comprueba que el portal sigue respondiendo.

### Objetivo

Dejar `proyecto/parcheo.yml` aplicado en prod: `prod-web1` y `prod-web2` sin paquetes pendientes, parcheados uno
detrás de otro y con el portal respondiendo `200` en cada uno.

### Punto de partida

- Terminal del Codespace. Desde la raíz del repositorio:

  ```bash
  scripts/partida.sh m08
  cd proyecto
  ```

- Estado: prod con `site.yml` aplicado (balanceador y dos web con la release 1.0.0). No hace falta nada de páginas
  anteriores.

### En qué consiste

Creas un playbook nuevo, `parcheo.yml`, para el grupo `web` del inventario de prod. Lo simulas con `--check`, lo
corriges para que el informe funcione también en simulación, lo aplicas y compruebas que una segunda pasada ya
no tiene nada que hacer. No tocas los roles ni el balanceador.

> [!NOTE]
> Los nodos son Debian 13 recién construidos. Lo que haya pendiente depende del día en que se creó tu Codespace:
> puede que haya uno o dos paquetes, o ninguno. Las salidas de esta página muestran un caso real con `tzdata`;
> en la tuya puede aparecer otro paquete o una lista vacía, y el lab funciona igual.

### 1 — Mira qué hay pendiente con un comando ad hoc

**Acción:**

```bash
ansible -i inventories/prod/hosts.yml web -m ansible.builtin.command -a "apt list --upgradable"
```

**Por qué:** antes de parchear producción, el equipo quiere saber qué va a cambiar. Un comando ad hoc da la foto
sin escribir nada todavía.

**Resultado esperado:** una entrada por nodo con la lista de paquetes actualizables:

```text
prod-web2 | CHANGED | rc=0 >>
Listing...
tzdata/stable-updates 2026e-0+deb13u1 all [upgradable from: 2026c-0+deb13u1]
WARNING: apt does not have a stable CLI interface. Use with caution in scripts.
prod-web1 | CHANGED | rc=0 >>
Listing...
tzdata/stable-updates 2026e-0+deb13u1 all [upgradable from: 2026c-0+deb13u1]
WARNING: apt does not have a stable CLI interface. Use with caution in scripts.
```

`CHANGED` aparece porque `ansible.builtin.command` no sabe si un comando cambia algo y por defecto supone que sí. El
`WARNING` es de `apt` y no afecta.

### 2 — Escribe el playbook de parcheo

**Acción:** crea `proyecto/parcheo.yml` con este contenido:

```yaml
# proyecto/parcheo.yml
# Parcheo de los servidores web de prod, de uno en uno.
- name: Parchear los servidores web
  hosts: web
  become: true
  serial: 1
  max_fail_percentage: 0
  tasks:
    - name: Actualizar la caché de paquetes
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600

    - name: Listar los paquetes actualizables
      ansible.builtin.command: apt list --upgradable
      register: parcheo_pendientes
      changed_when: false

    - name: Mostrar los paquetes pendientes
      ansible.builtin.debug:
        msg: "{{ parcheo_pendientes.stdout_lines | select('search', '/') | list }}"

    - name: Aplicar las actualizaciones
      ansible.builtin.apt:
        upgrade: safe
      register: parcheo_resultado

    - name: Reiniciar nginx si se ha actualizado algo
      ansible.builtin.service:
        name: nginx
        state: restarted
      when: parcheo_resultado is changed

    - name: Comprobar si el sistema pide reinicio
      ansible.builtin.stat:
        path: /var/run/reboot-required
      register: parcheo_reinicio

    - name: Avisar si el nodo necesita reinicio
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} pide reinicio (/var/run/reboot-required)"
      when: parcheo_reinicio.stat.exists

    - name: Verificar que el portal responde
      ansible.builtin.uri:
        url: http://localhost/
        status_code: 200
```

**Por qué:** cada pieza resuelve un problema del parcheo manual:

| Pieza | Para qué |
|-------|----------|
| `serial: 1` + `max_fail_percentage: 0` | Un web cada vez; si uno falla, el otro no se toca y sigue atendiendo pedidos |
| `changed_when: false` | Listar paquetes no cambia nada: el informe no ensucia el `changed` del recap |
| `select('search', '/')` | Quita `Listing...` y deja solo las líneas `paquete/origen …` |
| `upgrade: safe` | Actualiza sin quitar paquetes instalados |
| `when: parcheo_resultado is changed` | nginx solo se reinicia si de verdad se ha actualizado algo |
| `/var/run/reboot-required` | Lo crea Debian cuando una actualización (núcleo, libc) necesita reiniciar |

En un servidor real, el aviso de reinicio sería una tarea `ansible.builtin.reboot`, que reinicia el nodo y espera a
que vuelva por SSH. Aquí los nodos son contenedores y no se reinician, así que el playbook solo avisa.

**Resultado esperado:** `ansible-playbook -i inventories/prod/hosts.yml parcheo.yml --syntax-check` responde
`playbook: parcheo.yml`.

### 3 — Simula el parcheo

**Acción:**

```bash
ansible-playbook -i inventories/prod/hosts.yml parcheo.yml --check
```

**Por qué:** es prod. Antes de actualizar, quieres ver qué haría el playbook en cada nodo.

**Resultado esperado:** el playbook recorre `prod-web1` y después `prod-web2` (un `PLAY` por nodo, por `serial: 1`).
Pero el informe sale vacío:

```text
TASK [Listar los paquetes actualizables] ***************************************
skipping: [prod-web1]

TASK [Mostrar los paquetes pendientes] *****************************************
ok: [prod-web1] => {
    "msg": []
}

TASK [Aplicar las actualizaciones] *********************************************
changed: [prod-web1]
…
TASK [Verificar que el portal responde] ****************************************
skipping: [prod-web1]
…
PLAY RECAP *********************************************************************
prod-web1                  : ok=6    changed=2    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0
prod-web2                  : ok=6    changed=2    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0
```

En modo check, `ansible.builtin.command` no se ejecuta (`skipping`): Ansible no sabe si un comando cambiaría algo y
prefiere no lanzarlo. Por eso la lista de pendientes queda vacía justo cuando más falta hace. `ansible.builtin.uri`
tampoco se ejecuta en check.

### 4 — Haz que el informe funcione también en simulación

**Acción:** en la tarea `Listar los paquetes actualizables`, añade `check_mode: false` debajo de `changed_when`:

```yaml
# proyecto/parcheo.yml (fragmento)
    - name: Listar los paquetes actualizables
      ansible.builtin.command: apt list --upgradable
      register: parcheo_pendientes
      changed_when: false
      check_mode: false
```

Y repite la simulación:

```bash
ansible-playbook -i inventories/prod/hosts.yml parcheo.yml --check
```

**Por qué:** `check_mode: false` le dice a Ansible que esa tarea se ejecute de verdad aunque el playbook vaya en
check. Solo se pone en tareas que leen y no cambian nada, como esta.

**Resultado esperado:** ahora el informe sale con los paquetes de cada nodo:

```text
TASK [Listar los paquetes actualizables] ***************************************
ok: [prod-web1]

TASK [Mostrar los paquetes pendientes] *****************************************
ok: [prod-web1] => {
    "msg": [
        "tzdata/stable-updates 2026e-0+deb13u1 all [upgradable from: 2026c-0+deb13u1]"
    ]
}
…
PLAY RECAP *********************************************************************
prod-web1                  : ok=7    changed=2    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
prod-web2                  : ok=7    changed=2    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
```

Si en tu Codespace no hay nada pendiente, `msg` es `[]` y `Aplicar las actualizaciones` sale `ok` en lugar de
`changed`.

### 5 — Simula que un nodo pide reinicio

**Acción:**

```bash
docker exec prod-web2 touch /var/run/reboot-required
```

**Por qué:** en los contenedores ninguna actualización deja este fichero. Lo creas a mano para ver la rama del
playbook que avisa del reinicio, la que en un servidor real se activaría tras actualizar el núcleo.

**Resultado esperado:** el comando no muestra nada. `docker exec prod-web2 ls /var/run/reboot-required` devuelve
la ruta.

### 6 — Aplica el parcheo

**Acción:**

```bash
ansible-playbook -i inventories/prod/hosts.yml parcheo.yml
```

**Por qué:** con la simulación revisada, toca parchear. `serial: 1` hace que `prod-web2` no se toque hasta que
`prod-web1` haya terminado y el portal haya respondido.

**Resultado esperado:**

```text
PLAY [Parchear los servidores web] *********************************************
…
TASK [Aplicar las actualizaciones] *********************************************
changed: [prod-web1]

TASK [Reiniciar nginx si se ha actualizado algo] *******************************
changed: [prod-web1]
…
TASK [Verificar que el portal responde] ****************************************
ok: [prod-web1]

PLAY [Parchear los servidores web] *********************************************
…
TASK [Avisar si el nodo necesita reinicio] *************************************
ok: [prod-web2] => {
    "msg": "prod-web2 pide reinicio (/var/run/reboot-required)"
}

TASK [Verificar que el portal responde] ****************************************
ok: [prod-web2]

PLAY RECAP *********************************************************************
prod-web1                  : ok=8    changed=2    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web2                  : ok=9    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`prod-web1` no pide reinicio (la tarea de aviso sale `skipping`); `prod-web2` sí, por el fichero del paso 5.

### 7 — Comprueba que no queda nada pendiente

**Acción:**

```bash
ansible-playbook -i inventories/prod/hosts.yml parcheo.yml
```

**Por qué:** una segunda pasada prueba que el parcheo está completo. El playbook se puede lanzar todas las semanas:
si no hay nada que actualizar, no toca nada.

**Resultado esperado:**

```text
TASK [Mostrar los paquetes pendientes] *****************************************
ok: [prod-web1] => {
    "msg": []
}
…
PLAY RECAP *********************************************************************
prod-web1                  : ok=7    changed=0    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
prod-web2                  : ok=8    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

`changed=0` en los dos: no se ha actualizado nada ni se ha reiniciado nginx. El aviso de `prod-web2` sigue saliendo
porque el fichero sigue ahí.

### 8 — Limpia el aviso de reinicio

**Acción:**

```bash
docker exec prod-web2 rm /var/run/reboot-required
```

**Por qué:** en un servidor real el fichero desaparece al reiniciar. Aquí lo quitas a mano para dejar el nodo
como estaba.

**Resultado esperado:** el comando no muestra nada. En la siguiente ejecución de `parcheo.yml`, `Avisar si el nodo
necesita reinicio` sale `skipping` también en `prod-web2`.

## Comprueba tu entendimiento

**Nada pendiente en prod**
`ansible -i inventories/prod/hosts.yml web -m ansible.builtin.command -a "apt list --upgradable"`
→ En cada nodo solo aparecen `Listing...` y el `WARNING` de apt, sin paquetes.

**El parcheo va de uno en uno**
`ansible-playbook -i inventories/prod/hosts.yml parcheo.yml` y fíjate en los encabezados.
→ Dos `PLAY [Parchear los servidores web]`: el primero solo con `prod-web1` y el segundo solo con `prod-web2`.

**El portal sigue respondiendo**
`curl -s -o /dev/null -w "%{http_code}\n" localhost:8080`
→ `200`.

## Reto

### 1 — Parchear fuera del balanceador

Mientras nginx se reinicia en un nodo, el balanceador puede mandarle algún pedido. Haz que `parcheo.yml` saque cada
web del balanceador antes de parchearlo y lo devuelva al terminar, reutilizando `roles/portal_lb/tasks/balancear.yml`
como hace `deploy.yml`.

<details>
<summary>Ver solución</summary>

Añade un bloque `pre_tasks` antes de `tasks` y otro `post_tasks` al final del play:

```yaml
# proyecto/parcheo.yml (fragmento)
  pre_tasks:
    - name: Sacar el nodo del balanceador
      ansible.builtin.include_role:
        name: portal_lb
        tasks_from: balancear
        apply:
          delegate_to: "{{ item }}"
      vars:
        portal_lb_fuera: ["{{ inventory_hostname }}"]
      loop: "{{ groups['lb'] | default([]) }}"

  tasks:
    # … las tareas del lab, sin cambios …

  post_tasks:
    - name: Devolver el nodo al balanceador
      ansible.builtin.include_role:
        name: portal_lb
        tasks_from: balancear
        apply:
          delegate_to: "{{ item }}"
      loop: "{{ groups['lb'] | default([]) }}"
```

Al lanzarlo, cada nodo empieza y termina con tareas delegadas en el balanceador:

```text
TASK [Sacar el nodo del balanceador] *******************************************
included: portal_lb for prod-web1 => (item=prod-lb1)

TASK [portal_lb : Actualizar los servidores del balanceador] *******************
changed: [prod-web1 -> prod-lb1]
…
TASK [Devolver el nodo al balanceador] *****************************************
included: portal_lb for prod-web1 => (item=prod-lb1)

TASK [portal_lb : Actualizar los servidores del balanceador] *******************
changed: [prod-web1 -> prod-lb1]
```

</details>

### 2 — Actualizar todo con `state: latest`

¿Qué cambiarías en `Aplicar las actualizaciones` para usar `name: "*"` con `state: latest` en lugar de
`upgrade: safe`? ¿En qué se diferencian?

<details>
<summary>Ver solución</summary>

```yaml
    - name: Aplicar las actualizaciones
      ansible.builtin.apt:
        name: "*"
        state: latest
      register: parcheo_resultado
```

Las dos actualizan lo instalado. `upgrade: safe` equivale a `apt-get upgrade` y nunca quita paquetes;
`name: "*"` con `state: latest` pide la última versión de cada paquete y puede instalar dependencias nuevas.
Para el parcheo habitual, `upgrade: safe` es la opción conservadora.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| En `--check`, `Mostrar los paquetes pendientes` sale `"msg": []` aunque haya paquetes | `ansible.builtin.command` no se ejecuta en modo check | `check_mode: false` en la tarea que lista los paquetes |
| `Listar los paquetes actualizables` sale `changed` en cada ejecución | Falta `changed_when: false` | Añádelo: la tarea solo lee |
| `Could not get lock /var/lib/dpkg/lock-frontend` | Otro `apt` está corriendo en el nodo | Espera a que termine y repite; no borres el bloqueo |
| `apt` se queda colgado o falla con `Temporary failure resolving` | Red de Docker en Codespaces | `bash scripts/red-docker-codespace.sh` desde la raíz del repositorio y repite |
| Se parchean los dos web a la vez | Falta `serial: 1` en el play | Añádelo al mismo nivel que `hosts` y `become` |
| `Verificar que el portal responde` falla tras el parcheo | nginx no ha arrancado tras el reinicio | `docker exec prod-web1 nginx -t` y revisa el error; `max_fail_percentage: 0` ya ha parado antes del segundo nodo |
