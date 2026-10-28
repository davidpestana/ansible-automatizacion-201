# Lab — Cambio en producción

[← Página anterior](01-lab-parcheo.md) · [Siguiente página →](03-lab-troubleshooting.md)

Llega la campaña de rebajas y el equipo de Tienda Norte pide subir `worker_connections` de nginx a `1024` en los
servidores web de producción, para que aguanten más conexiones a la vez. En este lab llevas el cambio a prod como
se hace en un entorno productivo: lo simulas con `--check --diff`, lo aplicas primero en un canario, lo extiendes
al resto y después ves qué pasa cuando el valor viene mal escrito y el check no lo detecta.

### Objetivo

Dejar `worker_connections 1024` en `prod-web1`, con `prod-web2` intacto en su valor propio (`2048`), y comprobar
que un valor erróneo se queda parado en el canario sin tumbar el portal.

### Punto de partida

- Terminal del Codespace. Desde la raíz del repositorio:

  ```bash
  scripts/partida.sh m08
  cd proyecto
  ```

- Estado: prod con `site.yml` aplicado. Los web usan el valor por defecto del rol (`portal_worker_connections: 768`,
  en `roles/portal/defaults/main.yml`), salvo `prod-web2`, que tiene `2048` en
  `inventories/prod/host_vars/prod-web2.yml`. No hace falta nada de páginas anteriores.

### En qué consiste

Cambias una variable en `inventories/prod/group_vars/all.yml` y la llevas a prod con `web.yml --tags config`:
simulación, canario y resto. Después repites el ciclo con un valor inválido para ver dónde se para. No tocas los
roles ni el balanceador.

### 1 — Mira el valor actual en cada nodo

**Acción:**

```bash
ansible -i inventories/prod/hosts.yml web -m ansible.builtin.command -a 'grep worker_connections /etc/nginx/nginx.conf'
```

**Por qué:** antes de cambiar algo en prod, necesitas saber cómo está. Es la línea base con la que compararás.

**Resultado esperado:**

```text
prod-web1 | CHANGED | rc=0 >>
    worker_connections 768;
prod-web2 | CHANGED | rc=0 >>
    worker_connections 2048;
```

Los dos nodos no están igual: `prod-web2` ya tiene un valor propio.

### 2 — Cambia la variable para prod

**Acción:** añade esta línea al final de `inventories/prod/group_vars/all.yml`:

```yaml
# proyecto/inventories/prod/group_vars/all.yml (línea nueva)
portal_worker_connections: 1024
```

**Por qué:** la petición es para todo prod. `group_vars/all.yml` del inventario de prod es el sitio de los valores
de ese entorno; dev y pre no se enteran.

**Resultado esperado:** el fichero tiene cuatro líneas: `portal_entorno`, `portal_color`, `portal_version` y la
nueva.

### 3 — Simula el cambio con `--check --diff`

**Acción:**

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml --check --diff --tags config
```

**Por qué:** `--check` recorre el playbook sin cambiar nada; `--diff` enseña las líneas que cambiarían.
`--tags config` limita la simulación a las tareas de configuración de nginx, que son las únicas que afecta este
cambio.

**Resultado esperado:**

```text
TASK [portal : Configurar nginx (nginx.conf)] **********************************
ok: [prod-web2]
--- before: /etc/nginx/nginx.conf
+++ after: …/nginx.conf.j2
@@ -5,7 +5,7 @@
 include /etc/nginx/modules-enabled/*.conf;
 
 events {
-    worker_connections 768;
+    worker_connections 1024;
 }
 
 http {

changed: [prod-web1]
…
RUNNING HANDLER [portal : Recargar nginx] **************************************
changed: [prod-web1]

PLAY RECAP *********************************************************************
prod-web1                  : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

El check te descubre algo que la petición no decía: `prod-web2` no cambia.

### 4 — Averigua por qué `prod-web2` no cambia

**Acción:**

```bash
ansible -i inventories/prod/hosts.yml web -m ansible.builtin.debug -a var=portal_worker_connections
```

**Por qué:** antes de aplicar, cualquier diferencia entre lo que esperas y lo que dice el check se explica. Si no,
no se aplica.

**Resultado esperado:**

```text
prod-web1 | SUCCESS => {
    "portal_worker_connections": 1024
}
prod-web2 | SUCCESS => {
    "portal_worker_connections": 2048
}
```

`host_vars/prod-web2.yml` tiene más precedencia que `group_vars/all.yml`: `prod-web2` se queda con `2048`, que ya
es más que lo pedido. Es correcto, y ahora lo sabes antes de tocar nada.

### 5 — Aplica en el canario

**Acción:**

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml --tags config --limit prod-web1
```

**Por qué:** `--limit prod-web1` aplica el cambio en un solo nodo. Si algo sale mal, el balanceador sigue
teniendo a `prod-web2` para atender pedidos.

**Resultado esperado:**

```text
TASK [portal : Configurar nginx (nginx.conf)] **********************************
changed: [prod-web1]
…
RUNNING HANDLER [portal : Recargar nginx] **************************************
changed: [prod-web1]

PLAY RECAP *********************************************************************
prod-web1                  : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 6 — Comprueba el canario

**Acción:**

```bash
ansible -i inventories/prod/hosts.yml web -m ansible.builtin.command -a 'grep worker_connections /etc/nginx/nginx.conf'
curl -s localhost:8083/estado.json
```

**Por qué:** que Ansible diga `changed` no basta. Compruebas el valor en el nodo y que el portal del canario
responde.

**Resultado esperado:**

```text
prod-web1 | CHANGED | rc=0 >>
    worker_connections 1024;
prod-web2 | CHANGED | rc=0 >>
    worker_connections 2048;
{
  "host": "prod-web1",
  "entorno": "prod",
  "version": "1.0.0",
  "color": "#15803d",
  "db": ""
}
```

### 7 — Extiende el cambio al resto

**Acción:**

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml --tags config
```

**Por qué:** con el canario bien, se aplica a todo el grupo `web`. Aunque aquí `prod-web2` no cambie, la ejecución
sin `--limit` confirma que todo prod coincide con el proyecto.

**Resultado esperado:**

```text
PLAY RECAP *********************************************************************
prod-web1                  : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`changed=0` en los dos: el canario ya estaba y `prod-web2` mantiene su valor.

### 8 — Simula un cambio mal escrito

**Acción:** en `inventories/prod/group_vars/all.yml`, cambia la línea por un valor que nginx no acepta, como si
alguien hubiera copiado `1024k` de una hoja de cálculo:

```yaml
# proyecto/inventories/prod/group_vars/all.yml (línea cambiada)
portal_worker_connections: 1024k
```

Y simula:

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml --check --diff --tags config
```

**Por qué:** quieres ver cómo se presenta un cambio peligroso en la simulación.

**Resultado esperado:**

```text
TASK [portal : Configurar nginx (nginx.conf)] **********************************
ok: [prod-web2]
--- before: /etc/nginx/nginx.conf
+++ after: …/nginx.conf.j2
@@ -5,7 +5,7 @@
 include /etc/nginx/modules-enabled/*.conf;
 
 events {
-    worker_connections 1024;
+    worker_connections 1024k;
 }
 
 http {

changed: [prod-web1]
…
PLAY RECAP *********************************************************************
prod-web1                  : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

El check da el cambio por bueno: `failed=0`. La tarea tiene `validate: nginx -t -c %s`, pero en modo check la
validación no se ejecuta. El único aviso es el diff: `1024k` está ahí para quien lo lea.

> [!WARNING]
> Un check en verde no garantiza que el cambio funcione. Lee el diff línea a línea: es la parte del check que
> detecta este tipo de riesgo, y solo si alguien lo mira.

### 9 — Aplica el cambio erróneo en el canario

**Acción:**

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml --tags config --limit prod-web1
```

**Por qué:** es lo que pasaría si nadie hubiera leído el diff. Gracias al canario, el error solo puede afectar a
`prod-web1`.

**Resultado esperado:**

```text
TASK [portal : Configurar nginx (nginx.conf)] **********************************
[ERROR]: Task failed: Module failed: failed to validate
Origin: …/proyecto/roles/portal/tasks/main.yml:9:3

7   tags: [paquetes]
8
9 - name: Configurar nginx (nginx.conf)
    ^ column 3

fatal: [prod-web1]: FAILED! => {"changed": false, … "msg": "failed to validate", "stderr": "… [emerg] …: invalid number \"1024k\" in …/.source.conf:8\nnginx: configuration file …/.source.conf test failed\n", …}

PLAY RECAP *********************************************************************
prod-web1                  : ok=1    changed=0    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
```

`validate` ha probado el fichero nuevo con `nginx -t` antes de colocarlo, nginx lo ha rechazado (`invalid number
"1024k"`) y Ansible no ha sustituido `nginx.conf`.

### 10 — Comprueba que el canario sigue sano

**Acción:**

```bash
curl -s -o /dev/null -w "%{http_code}\n" localhost:8083
docker exec prod-web1 grep worker_connections /etc/nginx/nginx.conf
```

**Por qué:** tras un fallo en prod, lo primero es saber si el servicio sigue en pie.

**Resultado esperado:**

```text
200
    worker_connections 1024;
```

El portal responde y el fichero sigue con el valor bueno. `prod-web2` ni se ha tocado.

### 11 — Corrige el valor y verifica

**Acción:** vuelve a dejar `portal_worker_connections: 1024` en `inventories/prod/group_vars/all.yml` y simula:

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml --check --diff --tags config
```

**Por qué:** el cambio que hay en el proyecto tiene que coincidir con lo que hay en prod. Si no, la próxima
ejecución de cualquier compañero volvería a intentar el valor roto.

**Resultado esperado:**

```text
PLAY RECAP *********************************************************************
prod-web1                  : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

## Comprueba tu entendimiento

**El cambio está en prod**
`ansible -i inventories/prod/hosts.yml web -m ansible.builtin.command -a 'grep worker_connections /etc/nginx/nginx.conf'`
→ `prod-web1` con `1024` y `prod-web2` con `2048`.

**Proyecto y prod coinciden**
`ansible-playbook -i inventories/prod/hosts.yml web.yml --check --diff --tags config`
→ `changed=0` en los dos nodos y ningún diff.

**El portal no se ha resentido**
`for i in 1 2; do curl -sI localhost:8080 | grep X-Servidor; done`
→ Dos líneas, una con `172.30.0.21:80` y otra con `172.30.0.22:80`.

## Reto

### 1 — Igualar los dos web

El equipo decide que los dos web deben tener el mismo valor, `1024`. ¿Qué cambias para que `prod-web2` también lo
tome, y qué te dirá el check antes de aplicar?

<details>
<summary>Ver solución</summary>

Quita la línea `portal_worker_connections: 2048` de `inventories/prod/host_vars/prod-web2.yml` (o borra el
fichero si no tiene nada más). Con eso, `prod-web2` toma el valor de `group_vars/all.yml`.

`ansible-playbook -i inventories/prod/hosts.yml web.yml --check --diff --tags config` muestra ahora el diff en
`prod-web2` (`-    worker_connections 2048;` / `+    worker_connections 1024;`) y `changed=0` en `prod-web1`.
Después, el mismo ciclo: `--limit prod-web2` y una ejecución sin `--limit` para confirmar.

</details>

### 2 — ¿Qué detecta el check y qué no?

Del cambio erróneo de los pasos 8 y 9, ¿qué parte detectó el modo check, qué parte no y qué te protegió al final?

<details>
<summary>Ver solución</summary>

El check detectó **qué** iba a cambiar y dónde (la línea `1024k` en `prod-web1`), pero no **si** era válido: la
validación `validate:` no se ejecuta en modo check. Al aplicar, protegieron dos cosas: `validate`, que impidió
colocar un `nginx.conf` roto, y `--limit`, que dejó el intento en un solo nodo.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| El check no muestra diff aunque cambiaste la variable | Falta `--diff`, o la editaste en el inventario de otro entorno | Añade `--diff` y comprueba que editaste `inventories/prod/group_vars/all.yml` |
| Un nodo no cambia y esperabas que sí | Un `host_vars` del nodo tiene más precedencia | `ansible … -m ansible.builtin.debug -a var=portal_worker_connections` para ver el valor que gana |
| `Module failed: failed to validate` | `nginx -t` ha rechazado la plantilla renderizada | Lee el `stderr`: dice la directiva y la línea; corrige la variable y repite |
| `--limit prod-web1` dice `skipping: no hosts matched` | Nombre mal escrito o inventario de otro entorno | Usa `-i inventories/prod/hosts.yml` y el nombre exacto del inventario |
| Con `--tags config` no se despliega la release | Es lo esperado: solo corren las tareas etiquetadas `config` | Lanza sin `--tags` si también quieres el despliegue |
