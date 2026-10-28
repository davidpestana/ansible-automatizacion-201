# Lab — Despliegue completo

[← Página anterior](00-anatomia-de-un-despliegue.md) · [Siguiente página →](02-lab-multiples-nodos.md)

Prod de Tienda Norte son tres servidores que tienen que cuadrar: un balanceador (`prod-lb1`) delante de dos web
(`prod-web1` y `prod-web2`). En este lab partes de nodos recién creados, sin nada instalado, levantas el portal
entero con `site.yml` y luego sacas la release 1.1.0 cambiando solo la versión del inventario. Cierras
comprobando con `curl`, como haría el equipo de guardia, que el balanceador reparte y que los dos web sirven la versión nueva.

### Objetivo

Prod con el portal 1.1.0 servido por el balanceador en el puerto 8080, repartiendo entre `prod-web1` (8083) y
`prod-web2` (8084), y una segunda ejecución de `site.yml` sin cambios.

### Punto de partida

- Terminal del Codespace. El paso 1 recrea los nodos desde cero y deja `proyecto/` en el estado `m07`.
- Estado tras el paso 1: roles `portal` y `portal_lb` con handlers y tags, `site.yml` = `web.yml` + `lb.yml`,
  inventario de prod con los grupos `web`, `lb` y `db`; nodos sin nginx ni portal.
- No hace falta nada de páginas anteriores.

### En qué consiste

Aplicas `site.yml` sobre el inventario de prod, verificas la 1.0.0 desde el balanceador y desde cada web,
subes `portal_version` a `1.1.0` en `inventories/prod/group_vars/all.yml`, vuelves a aplicar y verificas otra vez.
No tocas `prod-db1` (la base de datos entra en el M09) ni escribes playbooks nuevos.

### 1 — Recrea los nodos y carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repo
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m07 --limpio
cd proyecto
```

**Por qué:** un despliegue completo se prueba de verdad sobre máquinas vacías, como un servidor recién entregado.
`--limpio` borra los seis contenedores y los crea otra vez.

**Resultado esperado:** seis líneas `<nodo>  SSH ok` y, al final, `Listo: proyecto/ en el punto de partida «m07»`.

### 2 — Mira qué nodos forman prod

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-inventory -i inventories/prod/hosts.yml --graph
```

**Por qué:** `site.yml` tiene un play para `web` y otro para `lb`; el inventario decide qué nodos son cada cosa.

**Resultado esperado:**

```text
@all:
  |--@ungrouped:
  |--@web:
  |  |--prod-web1
  |  |--prod-web2
  |--@lb:
  |  |--prod-lb1
  |--@db:
  |  |--prod-db1
```

### 3 — Comprueba que el portal aún no existe

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
curl -sS localhost:8080
```

**Por qué:** te da la referencia de «antes»: el puerto del balanceador está publicado, pero no hay nginx detrás.

**Resultado esperado:** `curl: (56) Recv failure: …` (la conexión se corta porque nadie escucha en `prod-lb1`).

### 4 — Aplica `site.yml` a prod

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml site.yml
```

**Por qué:** es el despliegue completo del servicio: instala nginx en los tres nodos, configura los web, publica
la release que dice el inventario (`1.0.0`) y configura el balanceador con los dos web como backends. El orden
lo da `site.yml`: primero los web y después el balanceador, para que no reparta hacia servidores vacíos.

**Resultado esperado:** el handler `Recargar nginx` se ejecuta en los web y el resumen queda así:

```text
RUNNING HANDLER [portal : Recargar nginx] **************************************
changed: [prod-web1]
changed: [prod-web2]

PLAY [Balanceador del portal] **************************************************
…
TASK [portal_lb : Recargar el balanceador] *************************************
changed: [prod-lb1]

PLAY RECAP *********************************************************************
prod-lb1                   : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web1                  : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 5 — Verifica cada web por separado

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
curl -s localhost:8083/estado.json
curl -s localhost:8084/estado.json
```

**Por qué:** antes de mirar el balanceador, confirma que cada backend sirve su release. Si uno falla aquí, el
problema está en ese web, no en el reparto.

**Resultado esperado:** cada nodo dice quién es y qué versión tiene:

```text
{
  "host": "prod-web1",
  "entorno": "prod",
  "version": "1.0.0",
  "color": "#15803d",
  "db": ""
}
{
  "host": "prod-web2",
  "entorno": "prod",
  "version": "1.0.0",
  "color": "#15803d",
  "db": ""
}
```

### 6 — Verifica el reparto del balanceador

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
for i in 1 2 3 4; do curl -sI localhost:8080 | grep X-Servidor; done
```

**Por qué:** `prod-lb1` añade la cabecera `X-Servidor` con el backend que ha atendido cada petición. Pedir
varias veces seguidas enseña si reparte entre los dos.

**Resultado esperado:** las respuestas alternan entre las IP de los dos web:

```text
X-Servidor: 172.30.0.22:80
X-Servidor: 172.30.0.21:80
X-Servidor: 172.30.0.22:80
X-Servidor: 172.30.0.21:80
```

`172.30.0.21` es `prod-web1` y `172.30.0.22` es `prod-web2`. En la pestaña **Puertos**, el 8080 abre el portal
en el navegador con la cabecera verde de prod.

### 7 — Sube la versión de prod a 1.1.0

**Acción:** en `proyecto/inventories/prod/group_vars/all.yml`, cambia `portal_version` y guarda:

```yaml
# proyecto/inventories/prod/group_vars/all.yml
portal_entorno: prod
portal_color: "#15803d"
portal_version: "1.1.0"
```

**Por qué:** la versión de cada entorno es un dato del inventario. Cambiarla aquí, y no con `-e` en la línea de
comandos, deja escrito qué release debe tener prod; cualquier ejecución posterior de `site.yml` la respeta.

**Resultado esperado:** `grep portal_version inventories/prod/group_vars/all.yml` devuelve `portal_version: "1.1.0"`.

### 8 — Despliega la nueva versión

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml site.yml
```

**Por qué:** el mismo playbook sirve para instalar y para actualizar. Lo que ya está bien (nginx, su
configuración, el balanceador) sale en `ok`; solo cambia lo que depende de la versión.

**Resultado esperado:** solo las cuatro tareas de la release cambian en cada web, y el balanceador no cambia:

```text
TASK [portal : Crear la carpeta de la release] *********************************
changed: [prod-web1]
changed: [prod-web2]

TASK [portal : Copiar la release 1.1.0] ****************************************
changed: [prod-web2]
changed: [prod-web1]

TASK [portal : Apuntar current a la release 1.1.0] *****************************
changed: [prod-web1]
changed: [prod-web2]

TASK [portal : Publicar el estado del nodo] ************************************
changed: [prod-web1]
changed: [prod-web2]
…
PLAY RECAP *********************************************************************
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=11   changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=11   changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

No se recarga nginx: el cambio de versión es solo el enlace `current`.

### 9 — Verifica la 1.1.0 a través del balanceador

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
for i in 1 2 3 4; do curl -s localhost:8080/estado.json | grep -E '"(host|version)"'; done
curl -s localhost:8080 | grep Versión
```

**Por qué:** es lo que ve un cliente: da igual a qué web le mande el balanceador, tiene que recibir la 1.1.0.

**Resultado esperado:**

```text
  "host": "prod-web1",
  "version": "1.1.0",
  "host": "prod-web2",
  "version": "1.1.0",
  "host": "prod-web1",
  "version": "1.1.0",
  "host": "prod-web2",
  "version": "1.1.0",
```

```text
<p>Versión <strong>1.1.0</strong>. Nuevo: seguimiento de pedidos.</p>
```

### 10 — Mira las releases en un web

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ssh -F ../infra/ssh_config prod-web1 ls -l /srv/portal /srv/portal/releases
```

**Por qué:** confirma cómo quedó el despliegue en disco: la 1.0.0 no se ha borrado, y por eso volver a ella
sería solo cambiar el enlace.

**Resultado esperado:**

```text
/srv/portal:
total 4
lrwxrwxrwx 1 root root   26 Oct 26 19:28 current -> /srv/portal/releases/1.1.0
drwxr-xr-x 4 root root 4096 Oct 26 19:28 releases

/srv/portal/releases:
total 8
drwxr-xr-x 2 root root 4096 Oct 26 19:28 1.0.0
drwxr-xr-x 2 root root 4096 Oct 26 19:28 1.1.0
```

### 11 — Comprueba que el despliegue es idempotente

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml site.yml
```

**Por qué:** si una segunda ejecución cambia algo, el despliegue no es repetible y no sabrías qué toca cada vez.

**Resultado esperado:**

```text
PLAY RECAP *********************************************************************
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

## Comprueba tu entendimiento

**El balanceador reparte**
Lanza `for i in 1 2 3 4; do curl -sI localhost:8080 | grep X-Servidor; done`.
→ Aparecen `172.30.0.21:80` y `172.30.0.22:80` alternándose.

**Los dos web tienen la misma versión**
Lanza `curl -s localhost:8083/estado.json` y `curl -s localhost:8084/estado.json`.
→ Los dos dicen `"version": "1.1.0"`, cada uno con su `host`.

**La versión de prod está en el inventario**
Lanza `ansible -i inventories/prod/hosts.yml prod-web2 -m ansible.builtin.debug -a var=portal_version`.
→ `"portal_version": "1.1.0"`, leído de `inventories/prod/group_vars/all.yml`.

## Reto

### 1 — Vuelve prod a la 1.0.0 sin tocar el inventario

Producto pide volver a la 1.0.0 mientras revisa una incidencia, pero el inventario debe seguir diciendo 1.1.0
(es la versión aprobada). Hazlo con una sola ejecución que no toque nginx ni el balanceador, y comprueba el
resultado a través del puerto 8080.

<details>
<summary>Ver solución</summary>

`-e` manda sobre `group_vars` y `--tags despliegue` deja solo las tareas de la release:

```bash
# Terminal del Codespace, en proyecto/
ansible-playbook -i inventories/prod/hosts.yml web.yml --tags despliegue -e portal_version=1.0.0
curl -s localhost:8080 | grep Versión
```

La release 1.0.0 ya está en disco, así que en cada web cambia solo `Apuntar current a la release 1.0.0`
(`changed=1`) y el portal dice `Versión <strong>1.0.0</strong>`. La próxima ejecución de `site.yml` sin `-e`
volverá a la 1.1.0 del inventario.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `ansible-playbook site.yml` actúa sobre `dev-web1` | Falta `-i inventories/prod/hosts.yml`: `ansible.cfg` usa el inventario de dev por defecto | Repite el comando con `-i inventories/prod/hosts.yml` |
| `curl: (56) Recv failure` en el 8080 tras aplicar | `site.yml` falló antes del play del balanceador o se lanzó con `--limit web` | Mira el `PLAY RECAP`: `prod-lb1` tiene que aparecer con `failed=0` |
| `curl localhost:8080` devuelve `502 Bad Gateway` | El balanceador está, pero los web no responden (nginx parado o sitio sin activar) | Comprueba `curl -sI localhost:8083` y `localhost:8084`; vuelve a aplicar `site.yml` |
| Tras cambiar a 1.1.0, `estado.json` sigue diciendo 1.0.0 | El cambio se hizo en `inventories/dev/group_vars/all.yml` o el fichero no se guardó | Edita `inventories/prod/group_vars/all.yml` y revisa con `grep portal_version` |
| `Could not find or access '…/app/releases/1.1.0/'` | Versión mal escrita (`1.1`, `v1.1.0`) en el inventario | Usa exactamente el nombre de una carpeta de `app/releases/` |
