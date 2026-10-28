# Lab — Configuración por entorno

[← Página anterior](03-lab-facts.md) · [Siguiente página →](../M05-modularizacion/README.md)

Tienda Norte quiere dejar de tener «el playbook de dev» y «el de prod». Con los datos en `group_vars/` y la
configuración en plantillas, un único `portal.yml` debería dejar cada entorno con su versión, su color y su
nombre, y una promoción de dev a pre debería ser un cambio en un fichero de datos. En este lab lo compruebas
de punta a punta: aplicas el mismo playbook a dev, pre y prod, verificas cada portal con `curl` y llevas la
`1.1.0` a pre sin tocar el playbook.

### Objetivo

Los cuatro nodos web publicando su propia configuración con el mismo `portal.yml` (dev `1.1.0` en azul, pre y
prod `1.0.0` en ámbar y verde) y, después, pre promocionada a la `1.1.0` con un cambio en
`inventories/pre/group_vars/all.yml`, sin afectar a prod.

### Punto de partida

- Terminal del Codespace, en la raíz del repositorio. El paso 1 carga el estado `m05`: `group_vars/all.yml` por
  entorno, `host_vars/prod-web2.yml`, las plantillas `nginx.conf.j2`, `portal.conf.j2` y `estado.json.j2`, y
  `portal.yml` con plantillas y variables. Es el proyecto tal como queda al terminar los labs anteriores de este
  módulo.
- Nodos recién creados, sin nginx ni portal (`--limpio`).
- No hace falta nada de páginas anteriores.

### En qué consiste

Comparas los datos de cada entorno, aplicas `portal.yml` a los tres inventarios, compruebas los cuatro portales
con `curl` y promocionas una versión a pre, ensayando antes con `--check --diff`. No tocas el balanceador ni la
base de datos: son de módulos posteriores.

### 1 — Carga el punto de partida

**Acción:**

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m05 --limpio
cd proyecto
```

**Por qué:** deja el proyecto con todo lo de este módulo y los nodos vacíos: así la primera ejecución de cada
entorno se ve completa.

**Resultado esperado:** seis líneas `<nodo>  SSH ok` y `Listo: proyecto/ en el punto de partida «m05»`.

### 2 — Compara los datos de dos entornos

**Acción:**

```bash
diff inventories/pre/group_vars/all.yml inventories/prod/group_vars/all.yml
```

**Por qué:** toda la diferencia entre pre y prod está en estos ficheros; `portal.yml` y las plantillas son los
mismos. Es lo que se revisa antes de aplicar en un entorno.

**Resultado esperado:**

```text
1,2c1,2
< portal_entorno: pre
< portal_color: "#d97706"
---
> portal_entorno: prod
> portal_color: "#15803d"
```

La versión no sale: las dos están en la `1.0.0`.

### 3 — Aplica el mismo playbook a los tres entornos

**Acción:**

```bash
ansible-playbook -i inventories/dev/hosts.yml portal.yml
ansible-playbook -i inventories/pre/hosts.yml portal.yml
ansible-playbook -i inventories/prod/hosts.yml portal.yml
```

**Por qué:** solo cambia el `-i`. El inventario elegido decide qué nodos se tocan **y** qué `group_vars/` y
`host_vars/` se cargan.

**Resultado esperado:** tres resúmenes sin fallos, cada uno con los nodos de su entorno:

```text
PLAY RECAP *********************************************************************
dev-web1                   : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

```text
PLAY RECAP *********************************************************************
pre-web1                   : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

```text
PLAY RECAP *********************************************************************
prod-web1                  : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 4 — Comprueba cada portal

**Acción:**

```bash
curl -s localhost:8081/estado.json
curl -s localhost:8082/estado.json
curl -s localhost:8083/estado.json
curl -s localhost:8084/estado.json
```

**Por qué:** `estado.json` es lo que el propio portal lee para pintar su cabecera: comprobarlo con `curl` es
comprobar lo que verá un usuario.

**Resultado esperado:**

```text
{
  "host": "dev-web1",
  "entorno": "dev",
  "version": "1.1.0",
  "color": "#2563eb",
  "db": ""
}
{
  "host": "pre-web1",
  "entorno": "pre",
  "version": "1.0.0",
  "color": "#d97706",
  "db": ""
}
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

En la pestaña **Puertos**, abre 8081, 8082 y 8083: la cabecera sale azul, ámbar y verde, y el texto dice
«Entorno … · servidor … · versión …» con los datos de cada nodo.

### 5 — Promociona la 1.1.0 a pre

**Acción:** en `inventories/pre/group_vars/all.yml`, cambia la versión:

```yaml
# inventories/pre/group_vars/all.yml
portal_entorno: pre
portal_color: "#d97706"
portal_version: "1.1.0"
```

**Por qué:** dev ya ha validado la `1.1.0`; pasarla a pre es un cambio de **datos** de pre. Ni el playbook ni las
plantillas ni los otros entornos se tocan, y el cambio se revisa como un diff de una línea.

**Resultado esperado:** `diff inventories/dev/group_vars/all.yml inventories/pre/group_vars/all.yml` ya solo
muestra el entorno y el color.

### 6 — Ensaya la promoción con --check --diff

**Acción:**

```bash
ansible-playbook -i inventories/pre/hosts.yml portal.yml --check --diff
```

**Por qué:** antes de cambiar pre quieres ver qué haría. Aquí, además, aparece un límite del modo check que
conviene conocer.

**Resultado esperado:** el ensayo enseña la carpeta nueva y los ficheros de la `1.1.0`, y después **falla**:

```text
TASK [Crear la carpeta de la release] ******************************************
--- before
+++ after
@@ -1,4 +1,4 @@
 {
     "path": "/srv/portal/releases/1.1.0",
-    "state": "absent"
+    "state": "directory"
 }

changed: [pre-web1]

TASK [Copiar la release 1.1.0] *************************************************
…
+<p>Versión <strong>1.1.0</strong>. Nuevo: seguimiento de pedidos.</p>
…
changed: [pre-web1]

TASK [Apuntar current a la release 1.1.0] **************************************
[ERROR]: Task failed: Module failed: src file does not exist, use 'force=yes' if you really want to create the link: /srv/portal/releases/1.1.0
…
PLAY RECAP *********************************************************************
pre-web1                   : ok=8    changed=2    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
```

En modo check la carpeta `1.1.0` no se crea de verdad, así que la tarea siguiente no encuentra el destino del
enlace. No es un error del playbook: el ensayo no puede simular una tarea que depende de otra que no se ha
ejecutado. Lo que sí te confirma es que la versión que se va a publicar es la correcta.

### 7 — Aplica la promoción y compara pre con prod

**Acción:**

```bash
ansible-playbook -i inventories/pre/hosts.yml portal.yml
curl -s localhost:8082/estado.json
curl -s localhost:8083/estado.json
curl -s localhost:8082 | grep Versión
```

**Por qué:** pre debe quedar en la `1.1.0` con su color de siempre; prod, que no se ha lanzado, sigue en la `1.0.0`.

**Resultado esperado:** `pre-web1 : ok=11 changed=4 … skipped=1` y:

```text
{
  "host": "pre-web1",
  "entorno": "pre",
  "version": "1.1.0",
  "color": "#d97706",
  "db": ""
}
{
  "host": "prod-web1",
  "entorno": "prod",
  "version": "1.0.0",
  "color": "#15803d",
  "db": ""
}
<p>Versión <strong>1.1.0</strong>. Nuevo: seguimiento de pedidos.</p>
```

## Comprueba tu entendimiento

**Un entorno, un inventario**
Lanza `ansible-playbook portal.yml` sin `-i`.
→ El `PLAY RECAP` solo muestra `dev-web1`: es el inventario de `ansible.cfg`. Para pre y prod hay que indicarlo con `-i`.

**Lo que no se ha lanzado no cambia**
`curl -s localhost:8084/estado.json`
→ `prod-web2` sigue en la `1.0.0`: cambiar `inventories/pre/` no afecta a prod hasta que se ejecuta contra prod.

**Idempotencia en todos los entornos**
Repite el paso 3.
→ Los tres resúmenes con `changed=0`.

## Reto

### 1 — Una cabecera con el entorno

El equipo de soporte quiere saber de qué entorno viene una respuesta sin abrir `estado.json`: cada nodo web
debe responder con la cabecera HTTP `X-Entorno: <entorno>`. Hazlo con una sola línea en una plantilla y
compruébalo en pre.

<details>
<summary>Ver solución</summary>

En `templates/portal.conf.j2`, debajo de `index index.html;`, añade:

```jinja
    add_header X-Entorno {{ portal_entorno }};
```

```bash
ansible-playbook -i inventories/pre/hosts.yml portal.yml
curl -sI localhost:8082 | grep X-Entorno
```

```text
PLAY RECAP *********************************************************************
pre-web1                   : ok=12   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

```text
X-Entorno: pre
```

Cambian la plantilla del sitio y la recarga. La misma línea dará `X-Entorno: dev` en 8081 y `X-Entorno: prod`
en 8083 cuando lances esos entornos. Si el `curl` llega justo al terminar el playbook y aún no ves la cabecera,
repítelo: nginx tarda un instante en relevar a los procesos antiguos tras la recarga.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `--check` falla en **Apuntar current a la release** con `src file does not exist` | En modo check no se crea la carpeta de la release nueva | Es una limitación del ensayo: revisa el diff de las tareas anteriores y aplica |
| Pre sale con el color o la versión de dev | Lanzaste sin `-i inventories/pre/hosts.yml` | Revisa el `PLAY RECAP`: debe salir `pre-web1` |
| `curl` a 8082 no conecta | Ese entorno aún no tiene nginx | Lanza `portal.yml` contra ese inventario |
| El portal muestra `403 Forbidden` | `portal_version` apunta a una release sin `index.html` (la `1.2.0` está rota a propósito) | Vuelve a una versión válida (`1.0.0` o `1.1.0`) y relanza |
| La cabecera nueva no aparece justo después de aplicar | La recarga de nginx aún no ha terminado | Repite el `curl` |
