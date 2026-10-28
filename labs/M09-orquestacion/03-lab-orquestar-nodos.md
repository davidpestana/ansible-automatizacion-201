# Lab — Orquestar varios nodos

[← Página anterior](02-lab-secuencial-y-paralelo.md) · [Siguiente página →](../M10-gobernanza/README.md)

Tienda Norte publica la versión 1.1.0 del portal en prod, y los pedidos no pueden pararse mientras tanto. En el
runbook manual, alguien comentaba una línea del balanceador, actualizaba una web, la probaba, la volvía a activar y
repetía con la otra. En este lab haces lo mismo con `deploy.yml`: cada web sale del balanceador `prod-lb1` con
`delegate_to`, se actualiza, se verifica y vuelve, mientras un bucle de `curl` comprueba que el portal sigue
respondiendo.

### Objetivo

Las dos web de prod en la release 1.1.0 tras una actualización rodante, sin ninguna petición fallida en el puerto
8080, y habiendo visto la marca `down` de cada web en la configuración de `prod-lb1` durante su turno.

### Punto de partida

- Tres terminales del Codespace (botón **+** del panel de terminal, o **Terminal → New Terminal**). El primero en
  `proyecto/`; los otros dos pueden estar en cualquier carpeta.
- Estado: prod con el portal 1.0.0 en `prod-web1` y `prod-web2` detrás de `prod-lb1`. El paso 1 te deja así.
- `proyecto/deploy.yml` ya existe; en este lab lo lees y lo ejecutas, no lo cambias.

### En qué consiste

Lees cómo `deploy.yml` saca y devuelve cada web del balanceador, dejas dos terminales vigilando el portal y la
configuración del balanceador, lanzas el despliegue de 1.1.0 en el primero y compruebas el resultado.

### 1 — Prepara el punto de partida

**Acción** (terminal 1):

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m09
cd proyecto
curl -s localhost:8083/estado.json | grep version
curl -s localhost:8084/estado.json | grep version
```

**Por qué:** el script vuelve a aplicar `site.yml` en prod, que deja las dos web en la versión de
`inventories/prod/group_vars/all.yml` (1.0.0), aunque antes hubieras desplegado otra.

**Resultado esperado:** `Listo: proyecto/ en el punto de partida «m09»` y las dos web en 1.0.0:

```text
  "version": "1.0.0",
  "version": "1.0.0",
```

### 2 — Lee cómo sale una web del balanceador

**Acción:** abre `proyecto/deploy.yml` y fíjate en la tarea que saca el nodo:

```yaml
# proyecto/deploy.yml (fragmento)
- name: Desplegar el portal {{ portal_version }}
  hosts: web
  become: true
  serial: 1
  max_fail_percentage: 0
  tasks:
    …
    - name: Sacar el nodo del balanceador
      ansible.builtin.include_role:
        name: portal_lb
        tasks_from: balancear
        apply:
          delegate_to: "{{ item }}"
      vars:
        portal_lb_fuera: ["{{ inventory_hostname }}"]
      loop: "{{ groups['lb'] | default([]) }}"
```

Después abre `proyecto/roles/portal_lb/tasks/balancear.yml` y la plantilla `roles/portal_lb/templates/balanceador.conf.j2`.

**Por qué:** el play corre sobre una web cada vez (`serial: 1`), pero el cambio hay que hacerlo en el balanceador.
`include_role` con `apply: delegate_to` ejecuta las tareas de `balancear.yml` en cada nodo de `groups['lb']`, con las
variables de la web: `portal_lb_fuera` vale la web en curso y la plantilla escribe `down` junto a ella. La tarea
`Devolver el nodo al balanceador`, en el `always`, repite lo mismo sin `portal_lb_fuera`, así que la web vuelve aunque
el despliegue falle.

**Resultado esperado:** en `balancear.yml` ves la recarga escrita como tarea con `when: portal_lb_conf is changed`, y
este comentario:

```yaml
# Sin handler a propósito: deploy.yml incluye este fichero con delegate_to al balanceador,
# y un handler se ejecutaría en el nodo web que lo notifica, no en el balanceador.
```

> [!NOTE]
> Un handler pertenece al nodo que lo notifica. Si `balancear.yml` notificara `Recargar nginx`, el handler correría en
> la web (con su propio nginx) y el balanceador seguiría con la configuración vieja cargada. Por eso la recarga es una
> tarea normal, delegada como las demás.

### 3 — Deja el portal vigilado

**Acción** (terminal 2):

```bash
while true; do curl -s localhost:8080/estado.json | tr -d ' \n'; echo; sleep 0.5; done
```

**Por qué:** es lo que vería un cliente: una petición al balanceador cada poco. Si alguna fallara, saldría una página
de error de nginx en vez del JSON.

**Resultado esperado:** líneas que alternan entre las dos web, todas en 1.0.0:

```text
{"host":"prod-web2","entorno":"prod","version":"1.0.0","color":"#15803d","db":"prod-db1"}
{"host":"prod-web1","entorno":"prod","version":"1.0.0","color":"#15803d","db":"prod-db1"}
{"host":"prod-web2","entorno":"prod","version":"1.0.0","color":"#15803d","db":"prod-db1"}
```

### 4 — Deja el balanceador vigilado

**Acción** (terminal 3):

```bash
while true; do docker exec prod-lb1 grep "server prod-" /etc/nginx/sites-available/default | tr -s " " | paste -sd" "; sleep 0.5; done
```

**Por qué:** muestra en una línea los dos `server` del `upstream` de `prod-lb1`, la configuración que cambia
`deploy.yml` por delegación.

**Resultado esperado:**

```text
 server prod-web1:80;  server prod-web2:80;
 server prod-web1:80;  server prod-web2:80;
```

### 5 — Lanza la actualización rodante

**Acción** (terminal 1): `ansible-playbook -i inventories/prod/hosts.yml deploy.yml -e portal_version=1.1.0`

**Por qué:** `-e portal_version=1.1.0` manda sobre el valor de `group_vars` solo en esta ejecución. El play hace
`prod-web1` entero (sacar, desplegar, verificar, devolver) y después `prod-web2`.

**Resultado esperado:** dos veces el mismo play, uno por web; las tareas del balanceador aparecen como
`prod-webN -> prod-lb1`:

```text
PLAY [Desplegar el portal 1.1.0] ***********************************************
TASK [Gathering Facts] *********************************************************
ok: [prod-web1]
TASK [Leer la release actual] **************************************************
ok: [prod-web1]
TASK [Sacar el nodo del balanceador] *******************************************
included: portal_lb for prod-web1 => (item=prod-lb1)
TASK [portal_lb : Actualizar los servidores del balanceador] *******************
changed: [prod-web1 -> prod-lb1]
TASK [portal_lb : Recargar el balanceador] *************************************
changed: [prod-web1 -> prod-lb1]
TASK [portal : Crear la carpeta de la release] *********************************
changed: [prod-web1]
…
TASK [Verificar que el portal responde] ****************************************
ok: [prod-web1]
TASK [Devolver el nodo al balanceador] *****************************************
included: portal_lb for prod-web1 => (item=prod-lb1)
TASK [portal_lb : Actualizar los servidores del balanceador] *******************
changed: [prod-web1 -> prod-lb1]
TASK [portal_lb : Recargar el balanceador] *************************************
changed: [prod-web1 -> prod-lb1]
PLAY [Desplegar el portal 1.1.0] ***********************************************
TASK [Gathering Facts] *********************************************************
ok: [prod-web2]
…
PLAY RECAP *********************************************************************
prod-web1                  : ok=13   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=13   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`prod-lb1` no sale en el `PLAY RECAP`: no está en el play. Sus cambios se cuentan en la web que los delegó.

### 6 — Lee lo que ha visto el balanceador

**Acción:** mira el terminal 3 y párralo con <kbd>Ctrl</kbd>+<kbd>C</kbd>.

**Por qué:** es la orquestación vista desde `prod-lb1`: una web marcada `down` cada vez, nunca las dos.

**Resultado esperado** (líneas repetidas resumidas, con cuántas veces salió cada una):

```text
 12 ×  server prod-web1:80;  server prod-web2:80;
  6 ×  server prod-web1:80 down;  server prod-web2:80;
  6 ×  server prod-web1:80;  server prod-web2:80;
  8 ×  server prod-web1:80;  server prod-web2:80 down;
  7 ×  server prod-web1:80;  server prod-web2:80;
```

### 7 — Lee lo que han visto los clientes

**Acción:** mira el terminal 2 y párralo con <kbd>Ctrl</kbd>+<kbd>C</kbd>.

**Por qué:** la prueba de que la orquestación funciona es que ninguna petición ha fallado y que la versión ha cambiado
web a web.

**Resultado esperado** (resumido): mientras `prod-web1` está fuera, solo contesta `prod-web2`; después conviven las dos
versiones; mientras `prod-web2` está fuera, solo contesta `prod-web1`, ya en 1.1.0; al final, las dos en 1.1.0. Ninguna
línea de error:

```text
{"host":"prod-web1","entorno":"prod","version":"1.0.0",…}
{"host":"prod-web2","entorno":"prod","version":"1.0.0",…}
{"host":"prod-web2","entorno":"prod","version":"1.0.0",…}     ← 8 seguidas: prod-web1 fuera
…
{"host":"prod-web1","entorno":"prod","version":"1.1.0",…}
{"host":"prod-web2","entorno":"prod","version":"1.0.0",…}     ← conviven 1.1.0 y 1.0.0
…
{"host":"prod-web1","entorno":"prod","version":"1.1.0",…}     ← 11 seguidas: prod-web2 fuera
{"host":"prod-web2","entorno":"prod","version":"1.1.0",…}
{"host":"prod-web1","entorno":"prod","version":"1.1.0",…}
```

> [!TIP]
> Durante unos instantes conviven dos versiones detrás del mismo balanceador. Con un sitio estático no importa; con
> una aplicación que cambia el esquema de la base de datos habría que planificar ese momento (compatibilidad entre
> versiones), y por eso el orden db → web → lb de `site.yml` no basta en todos los despliegues.

### 8 — Comprueba el estado final

**Acción** (terminal 1):

```bash
curl -s localhost:8083/estado.json | grep version
curl -s localhost:8084/estado.json | grep version
docker exec prod-lb1 grep "server prod-" /etc/nginx/sites-available/default
```

**Por qué:** confirma que las dos web acabaron en 1.1.0 y que ninguna se quedó marcada `down`.

**Resultado esperado:**

```text
  "version": "1.1.0",
  "version": "1.1.0",
    server prod-web1:80;
    server prod-web2:80;
```

## Comprueba tu entendimiento

**Dónde se ejecutó cada tarea**
Busca en la salida del paso 5 las líneas con `->`.
→ Solo las dos tareas de `portal_lb` (`Actualizar los servidores del balanceador` y `Recargar el balanceador`), con
`prod-webN -> prod-lb1`. El resto se ejecuta en la propia web.

**Una web cada vez**
Vuelve a lanzar `deploy.yml` con `-e portal_version=1.0.0` con el terminal 3 vigilando.
→ Nunca aparecen las dos web con `down` en la misma línea: `serial: 1` impide que el segundo nodo empiece antes de
que el primero vuelva.

**El balanceador siempre vuelve a su sitio**
Al terminar cualquier despliegue, ejecuta el `docker exec prod-lb1 grep …` del paso 8.
→ Las dos líneas `server` sin `down`.

## Reto

### 1 — Mantenimiento de una web sin desplegar

Hay que revisar el disco de `prod-web2` y el equipo quiere sacarla del balanceador un rato, sin desplegar nada.
Consíguelo con `lb.yml` y una variable extra, comprueba con `curl -sI localhost:8080` que solo responde `prod-web1`, y
después devuélvela.

<details>
<summary>Ver solución</summary>

`portal_lb_fuera` es una variable del rol `portal_lb`; pasándola con `-e` (como lista, en JSON) la plantilla marca esa
web como `down`:

```bash
ansible-playbook -i inventories/prod/hosts.yml lb.yml -e '{"portal_lb_fuera": ["prod-web2"]}'
docker exec prod-lb1 grep "server prod-" /etc/nginx/sites-available/default
for i in 1 2 3 4; do curl -sI localhost:8080 | grep X-Servidor; done
```

```text
PLAY RECAP *********************************************************************
prod-lb1                   : ok=5    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

    server prod-web1:80;
    server prod-web2:80 down;
X-Servidor: 172.30.0.21:80
X-Servidor: 172.30.0.21:80
X-Servidor: 172.30.0.21:80
X-Servidor: 172.30.0.21:80
```

Para devolverla basta con aplicar `lb.yml` sin la variable: `ansible-playbook -i inventories/prod/hosts.yml lb.yml`
(`changed=2` otra vez y las dos líneas `server` sin `down`).

</details>

### 2 — Dos balanceadores

Si prod tuviera `prod-lb1` y `prod-lb2` en el grupo `lb`, ¿qué tendrías que cambiar en `deploy.yml` para que cada web
salga de los dos?

<details>
<summary>Ver solución</summary>

Nada. La tarea recorre `loop: "{{ groups['lb'] | default([]) }}"` y delega en cada `item`, así que se ejecutaría una
vez por balanceador. Bastaría con añadir el nodo al grupo `lb` del inventario de prod.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| El bucle del terminal 2 muestra `502 Bad Gateway` | Las dos web estaban fuera a la vez (se quitó `serial: 1`) o una web no tenía nginx arrancado | Restaura `serial: 1` en `deploy.yml` y aplica `site.yml` para dejar las web bien |
| Una web se queda con `down` tras el despliegue | Se interrumpió `ansible-playbook` (<kbd>Ctrl</kbd>+<kbd>C</kbd>) antes del `always` | Aplica `ansible-playbook -i inventories/prod/hosts.yml lb.yml` |
| La configuración cambia pero el balanceador sigue enviando tráfico a la web | La recarga se convirtió en handler y corrió en la web | Deja la recarga como tarea en `balancear.yml`, como en la partida |
| `docker exec prod-lb1 …` responde `No such container` | El terminal no es el del Codespace o los nodos no están levantados | `scripts/nodos.sh up` desde la raíz del repositorio |
| El despliegue se para en `prod-web1` con `Parar el despliegue` | La release pedida no responde (por ejemplo, 1.2.0 sin `index.html`) | Es el rollback de `deploy.yml`: despliega una versión correcta |
